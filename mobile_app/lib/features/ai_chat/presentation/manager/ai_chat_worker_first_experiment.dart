import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_copy_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_no_match_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/budget_amount_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_shadow_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/scent_profile_scorer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/suitability_policy_engine.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AIChatWorkerFirstExperimentResolver {
  const AIChatWorkerFirstExperimentResolver();

  RecommendationResolverResult resolve({
    required AIChatTurnContext incoming,
    required AIChatDiscoveryContext discovery,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
  }) {
    final effectivePreferences = discovery.shouldPruneBotHistory
        ? discovery.localPreferences
        : currentPreferences.mergePatch(discovery.localPreferences);
    final referenceCheaperResult =
        AIChatRecommendationResolver.resolveReferenceCheaperCandidates(
          message: incoming.trimmed,
          catalog: catalog,
          sessionPreferences: currentPreferences,
          effectivePreferences: effectivePreferences,
          referenceMemory: incoming.effectiveRecommendationMemory,
          arabicReasons: incoming.responseLanguage.isArabic,
        );

    if (referenceCheaperResult == null &&
        !discovery.localReadyForRecommendation &&
        discovery.localPreferences.activeCriteriaCount == 0 &&
        !_shouldLetWorkerInterpretUnparsedMessage(incoming.trimmed) &&
        !_hasRareScentLanguage(incoming.trimmed) &&
        !ScentProfileScorer.hasStrongPreferenceSignal(
          discovery.localPreferences,
        )) {
      return _askForScentAnchor(
        incoming,
        discovery,
        trace: AIChatDecisionTrace(
          detectedLanguage: incoming.responseLanguage.isArabic ? 'ar' : 'en',
          detectedIntent: incoming.intent.name,
          discoveryReady: discovery.localReadyForRecommendation,
          readinessReason: discovery.readinessReason,
          budgetPolicy: discovery.budgetPolicy.name,
          missingSlots: discovery.localMissingSlots,
          candidateSource: 'none',
          localCandidateCount: 0,
          workerCandidateCount: 0,
          noMatchReason: 'missing_scent_anchor',
          finalGuardDecision: 'worker_first_missing_scent_anchor',
        ),
      );
    }

    final exactCandidates = LocalCandidateFilter.getTopRecommendations(
      catalog: catalog,
      preferences: discovery.localPreferences,
    );
    final upsellCandidates =
        discovery.budgetPolicy == AIChatBudgetPolicy.flexible
        ? LocalCandidateFilter.getTopUpsellRecommendations(
            catalog: catalog,
            preferences: discovery.localPreferences,
          )
        : const <RecommendedProduct>[];
    final localCandidatesRefs =
        referenceCheaperResult?.candidates ??
        [
          ...exactCandidates,
          ...upsellCandidates.where(
            (upsell) => !exactCandidates.any(
              (exact) => exact.product.id == upsell.product.id,
            ),
          ),
        ];
    final searchCandidates =
        referenceCheaperResult == null &&
            AIChatExperimentConfig.useCatalogSearchEngine
        ? const CatalogSearchShadowService().buildCandidates(
            catalog: catalog,
            preferences: discovery.localPreferences,
            limit: 15,
          )
        : const <RecommendedProduct>[];
    final primaryCandidateSeed =
        referenceCheaperResult != null ||
            !AIChatExperimentConfig.useCatalogSearchEngine
        ? localCandidatesRefs
        : AIChatRecommendationResolver.mergeSearchPrimaryWithLocalFallback(
            searchCandidates: searchCandidates,
            fallbackCandidates: localCandidatesRefs,
            limit: 15,
          );
    final policyCandidates = AIChatExperimentConfig.useSuitabilityPolicy
        ? const SuitabilityPolicyEngine()
              .applyToRecommendations(
                products: primaryCandidateSeed,
                context: SuitabilityContext(
                  preferences: discovery.localPreferences,
                  hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(
                    incoming.trimmed,
                  ),
                  sourcePath: 'worker_first_pre_worker_candidate_slice',
                ),
              )
              .products
        : primaryCandidateSeed;
    final workerCandidates = policyCandidates
        .take(15)
        .map((candidate) => candidate.product)
        .toList(growable: false);

    final trace = AIChatDecisionTrace(
      detectedLanguage: incoming.responseLanguage.isArabic ? 'ar' : 'en',
      detectedIntent: incoming.intent.name,
      discoveryReady: discovery.localReadyForRecommendation,
      readinessReason: discovery.readinessReason,
      budgetPolicy: discovery.budgetPolicy.name,
      missingSlots: discovery.localMissingSlots,
      candidateSource: workerCandidates.isEmpty
          ? 'none'
          : referenceCheaperResult != null
          ? 'workerFirstReferenceCheaper'
          : AIChatExperimentConfig.useCatalogSearchEngine
          ? 'workerFirstCatalogSearchPrimary'
          : 'workerFirstFiltered',
      localCandidateCount: policyCandidates.length,
      workerCandidateCount: workerCandidates.length,
      noMatchReason: workerCandidates.isEmpty
          ? referenceCheaperResult != null
                ? 'reference_cheaper_no_match'
                : AIChatRecommendationResolver.localNoMatchReasonForCatalog(
                    discovery.localPreferences,
                    catalog,
                  )
          : null,
      catalogSearchEngineEnabled: AIChatExperimentConfig.useCatalogSearchEngine,
      suitabilityPolicyEnabled: AIChatExperimentConfig.useSuitabilityPolicy,
    );

    if (workerCandidates.isEmpty) {
      final reasonCode = referenceCheaperResult != null
          ? 'reference_cheaper_no_match'
          : AIChatRecommendationResolver.localNoMatchReasonForCatalog(
              discovery.localPreferences,
              catalog,
            );
      if (_shouldLetWorkerInterpretBroadContext(
        incoming,
        discovery,
        noMatchReason: reasonCode,
      )) {
        return RecommendationResolverResult(
          trace: trace.copyWith(
            finalGuardDecision: 'worker_first_broad_context_worker',
          ),
          recommendationContext: AIChatRecommendationContext(
            localCandidatesRefs: localCandidatesRefs,
            candidatesList: catalog.take(15).toList(growable: false),
            localFallbackAnswer: null,
            budgetPolicy: discovery.budgetPolicy,
            effectivePreferences:
                referenceCheaperResult?.pivotPreferences ??
                effectivePreferences,
          ),
        );
      }

      if (!discovery.localReadyForRecommendation) {
        final nextMissingSlot = discovery.localMissingSlots.isNotEmpty
            ? discovery.localMissingSlots.first
            : null;
        return RecommendationResolverResult(
          trace: trace.copyWith(finalGuardDecision: 'worker_first_local_ask'),
          handledResult: AIChatHandledResult(
            handled: true,
            reply: AIChatReply.ask(
              question: buildQuestionForMissingSlot(
                nextMissingSlot,
                incoming.responseLanguage,
              ),
              updatedPreferences: discovery.localPreferences,
            ),
            source: 'worker_first_local_precheck',
            issueCode: 'insufficient_criteria',
            reasonCode: 'worker_first_empty_candidates_missing_slots',
            pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
          ),
        );
      }

      return RecommendationResolverResult(
        trace: trace.copyWith(
          noMatchReason: reasonCode,
          finalGuardDecision: 'worker_first_local_no_match',
        ),
        handledResult: AIChatHandledResult(
          handled: true,
          fallbackText: buildNoMatchMessage(
            incoming.trimmed,
            referenceCheaperResult?.pivotPreferences ??
                discovery.localPreferences,
            catalog,
            incoming.responseLanguage,
            reasonCode: reasonCode,
          ),
          preferences:
              referenceCheaperResult?.pivotPreferences ??
              discovery.localPreferences,
          source: 'worker_first_local_precheck',
          issueCode: 'no_candidate_match',
          reasonCode: reasonCode,
          isNoMatch: true,
          pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
        ),
      );
    }

    return RecommendationResolverResult(
      trace: trace.copyWith(
        finalGuardDecision: 'worker_first_worker_candidate_set',
      ),
      recommendationContext: AIChatRecommendationContext(
        localCandidatesRefs: policyCandidates,
        candidatesList: workerCandidates,
        localFallbackAnswer: null,
        budgetPolicy: discovery.budgetPolicy,
        effectivePreferences:
            referenceCheaperResult?.pivotPreferences ?? effectivePreferences,
      ),
    );
  }

  RecommendationResolverResult _askForScentAnchor(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery, {
    required AIChatDecisionTrace trace,
  }) {
    return RecommendationResolverResult(
      trace: trace,
      handledResult: AIChatHandledResult(
        handled: true,
        reply: AIChatReply.ask(
          question: buildQuestionForMissingSlot(
            'notesOrIntensity',
            incoming.responseLanguage,
          ),
          updatedPreferences: discovery.localPreferences,
        ),
        source: 'worker_first_scent_clarification',
        issueCode: 'insufficient_criteria',
        reasonCode: 'missing_scent_anchor',
        pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
      ),
    );
  }

  bool _shouldLetWorkerInterpretBroadContext(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery, {
    required String noMatchReason,
  }) {
    if (_hasRareScentLanguage(incoming.trimmed)) return true;
    if (_shouldLetWorkerInterpretUnparsedMessage(incoming.trimmed)) {
      return true;
    }
    return noMatchReason == 'missing_scent_anchor' &&
        discovery.localPreferences.activeCriteriaCount >= 2;
  }

  bool _shouldLetWorkerInterpretUnparsedMessage(String message) {
    final normalized = message.toLowerCase();
    final looksFranco =
        normalized.contains('3ayz') ||
        normalized.contains('fawa7') ||
        normalized.contains('t2eel') ||
        normalized.contains('seif') ||
        normalized.contains('mesh');
    if (looksFranco &&
        (normalized.contains('perfume') ||
            normalized.contains('fawa7') ||
            normalized.contains('seif'))) {
      return true;
    }
    return false;
  }

  bool _hasRareScentLanguage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('petrichor') ||
        normalized.contains('rain on soil') ||
        normalized.contains('rain') ||
        normalized.contains('earthy');
  }
}
