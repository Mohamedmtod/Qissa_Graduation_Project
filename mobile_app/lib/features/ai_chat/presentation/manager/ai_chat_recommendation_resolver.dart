import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_copy_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_no_match_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_reply_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_followup_detector.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_reference_profile_registry.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/budget_amount_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_product_matcher.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_shadow_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/mentioned_product_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/product_comparison_engine.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/recommendation_reference_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/reference_product_similarity_ranker.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/suitability_policy_engine.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

typedef AIChatTranslate =
    String Function(
      AIChatLanguage language, {
      required String ar,
      required String en,
    });

class ReferenceCheaperCandidateResult {
  final ProductModel referenceProduct;
  final SessionPreferences pivotPreferences;
  final List<RecommendedProduct> displayCandidates;
  final List<RecommendedProduct> candidates;

  const ReferenceCheaperCandidateResult({
    required this.referenceProduct,
    required this.pivotPreferences,
    required this.displayCandidates,
    required this.candidates,
  });
}

class AIChatRecommendationResolver {
  final AIChatTranslate translate;

  const AIChatRecommendationResolver({required this.translate});

  static List<RecommendedProduct> mergeSearchPrimaryWithLocalFallback({
    required List<RecommendedProduct> searchCandidates,
    required List<RecommendedProduct> fallbackCandidates,
    required int limit,
  }) {
    if (searchCandidates.isEmpty) {
      return fallbackCandidates.take(limit).toList(growable: false);
    }

    final merged = <RecommendedProduct>[];
    final seen = <String>{};
    for (final candidate in searchCandidates) {
      if (seen.add(candidate.product.id)) {
        merged.add(candidate);
      }
      if (merged.length >= limit) return merged;
    }

    if (merged.length < 3) {
      for (final candidate in fallbackCandidates) {
        if (seen.add(candidate.product.id)) {
          merged.add(candidate);
        }
        if (merged.length >= limit) break;
      }
    }

    return merged;
  }

  static ReferenceCheaperCandidateResult? resolveReferenceCheaperCandidates({
    required String message,
    required List<ProductModel> catalog,
    required SessionPreferences sessionPreferences,
    required SessionPreferences effectivePreferences,
    RecommendationMemory referenceMemory = const RecommendationMemory(),
    int limit = 15,
    bool arabicReasons = false,
  }) {
    if (!_looksLikeReferenceCheaperRequest(message)) return null;

    final referenceProduct = _resolveReferenceProductFromMessage(
      message: message,
      catalog: catalog,
      referenceMemory: referenceMemory,
    );
    if (referenceProduct == null || referenceProduct.effectivePrice <= 0) {
      return null;
    }
    final referenceProfile =
        AvailabilityReferenceProfileRegistry.resolveByMessage(message);
    final scoringReferenceProduct = referenceProfile == null
        ? referenceProduct
        : _referenceProductWithProfile(referenceProduct, referenceProfile);

    final strictLowerBudget = referenceProduct.effectivePrice - 1;
    final hasExplicitBudget = BudgetAmountParser.containsBudgetNumber(message);
    final currentBudget = hasExplicitBudget
        ? effectivePreferences.maxBudget
        : sessionPreferences.maxBudget;
    final pivotBudget = currentBudget == null
        ? strictLowerBudget
        : (currentBudget < strictLowerBudget
              ? currentBudget
              : strictLowerBudget);
    final pivotPreferences = effectivePreferences.copyWith(
      maxBudget: pivotBudget,
    );

    final cheaperCatalog = catalog
        .where((product) => product.id != referenceProduct.id)
        .where(
          (product) => product.effectivePrice < referenceProduct.effectivePrice,
        )
        .toList(growable: false);

    final workerPoolRanked = ReferenceProductSimilarityRanker.rank(
      referenceProduct: scoringReferenceProduct,
      catalog: cheaperCatalog,
      sessionPreferences: sessionPreferences,
      effectivePreferences: pivotPreferences,
      mode: ReferenceSimilarityMode.similarCheaper,
      limit: limit,
      arabicReasons: arabicReasons,
      enforceScentGate: false,
      filterDistractingCandidates: false,
    );

    final displayRanked = ReferenceProductSimilarityRanker.rank(
      referenceProduct: scoringReferenceProduct,
      catalog: cheaperCatalog,
      sessionPreferences: sessionPreferences,
      effectivePreferences: pivotPreferences,
      mode: ReferenceSimilarityMode.similarCheaper,
      limit: 3,
      arabicReasons: arabicReasons,
      enforceScentGate: true,
      filterDistractingCandidates: true,
    );

    final cheaperCandidates = workerPoolRanked
        .where((candidate) => candidate.product.id != referenceProduct.id)
        .where(
          (candidate) =>
              candidate.product.effectivePrice <
              referenceProduct.effectivePrice,
        )
        .take(limit)
        .toList(growable: false);
    final displayCandidates = displayRanked.isNotEmpty
        ? displayRanked.take(3).toList(growable: false)
        : cheaperCandidates.take(3).toList(growable: false);

    return ReferenceCheaperCandidateResult(
      referenceProduct: referenceProduct,
      pivotPreferences: pivotPreferences,
      displayCandidates: displayCandidates,
      candidates: cheaperCandidates,
    );
  }

  RecommendationResolverResult resolve({
    required AIChatTurnContext incoming,
    required AIChatDiscoveryContext discovery,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
  }) {
    List<RecommendedProductRef> resolvedProducts = [];
    var mentionedProductsForCompare = const <ProductModel>[];
    if (discovery.isFollowUpOrCompare) {
      resolvedProducts = RecommendationReferenceResolver.resolve(
        message: incoming.trimmed,
        memory: incoming.effectiveRecommendationMemory,
      );
      if (incoming.intent == AIChatIntent.compareProducts &&
          resolvedProducts.length < 2) {
        mentionedProductsForCompare = MentionedProductResolver.resolveMany(
          message: incoming.trimmed,
          catalog: catalog,
          limit: 4,
        );
        if (mentionedProductsForCompare.length >= 2) {
          resolvedProducts = mentionedProductsForCompare
              .map(_refFromProduct)
              .toList(growable: false);
        }
      }
    }

    final exactCandidatesRefs = LocalCandidateFilter.getTopRecommendations(
      catalog: catalog,
      preferences: discovery.localPreferences,
    );
    final allowUpsell = discovery.budgetPolicy == AIChatBudgetPolicy.flexible;
    final upsellCandidatesRefs = allowUpsell
        ? LocalCandidateFilter.getTopUpsellRecommendations(
            catalog: catalog,
            preferences: discovery.localPreferences,
          )
        : const <RecommendedProduct>[];
    final mergedLocalCandidatesRefs = [
      ...exactCandidatesRefs,
      ...upsellCandidatesRefs.where(
        (upsell) => !exactCandidatesRefs.any(
          (exact) => exact.product.id == upsell.product.id,
        ),
      ),
    ];
    final catalogSearchCandidates =
        AIChatExperimentConfig.useCatalogSearchEngine
        ? const CatalogSearchShadowService().buildCandidates(
            catalog: catalog,
            preferences: discovery.localPreferences,
            limit: 15,
          )
        : const <RecommendedProduct>[];
    final primaryCandidateSeed = AIChatExperimentConfig.useCatalogSearchEngine
        ? mergeSearchPrimaryWithLocalFallback(
            searchCandidates: catalogSearchCandidates,
            fallbackCandidates: mergedLocalCandidatesRefs,
            limit: 15,
          )
        : mergedLocalCandidatesRefs;
    final localCandidatesRefs = AIChatExperimentConfig.useSuitabilityPolicy
        ? const SuitabilityPolicyEngine()
              .applyToRecommendations(
                products: primaryCandidateSeed,
                context: SuitabilityContext(
                  preferences: discovery.localPreferences,
                  hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(
                    incoming.trimmed,
                  ),
                  sourcePath: 'pre_worker_candidate_slice',
                ),
              )
              .products
        : primaryCandidateSeed;
    final catalogSearchShadow = AIChatExperimentConfig.catalogSearchShadow
        ? const CatalogSearchShadowService()
              .compare(
                scenario: incoming.trimmed,
                requestId: incoming.requestId,
                catalog: catalog,
                oldCandidates: localCandidatesRefs.take(15).toList(),
                preferences: discovery.localPreferences,
              )
              .trace
        : null;

    final trace = AIChatDecisionTrace(
      detectedLanguage: incoming.responseLanguage.code,
      detectedIntent: incoming.intent.name,
      discoveryReady: discovery.localReadyForRecommendation,
      readinessReason: discovery.readinessReason,
      budgetPolicy: discovery.budgetPolicy.name,
      missingSlots: discovery.localMissingSlots,
      candidateSource: _candidateSource(localCandidatesRefs, resolvedProducts),
      localCandidateCount: localCandidatesRefs.length,
      noMatchReason: localCandidatesRefs.isEmpty
          ? localNoMatchReasonForCatalog(discovery.localPreferences, catalog)
          : null,
      catalogSearchShadow: catalogSearchShadow,
      catalogSearchEngineEnabled: AIChatExperimentConfig.useCatalogSearchEngine,
      suitabilityPolicyEnabled: AIChatExperimentConfig.useSuitabilityPolicy,
    );

    final sensitiveSkinCandidates = _sensitiveSkinLocalCandidates(
      incoming,
      discovery,
      localCandidatesRefs,
      catalog,
    );
    if (sensitiveSkinCandidates.isNotEmpty) {
      return RecommendationResolverResult(
        trace: trace.copyWith(
          finalGuardDecision: 'local_sensitive_skin_choice',
          localCandidateCount: sensitiveSkinCandidates.length,
          workerCandidateCount: sensitiveSkinCandidates.length,
          candidateSource: 'sensitiveSkinLocal',
          noMatchReason: null,
        ),
        handledResult: AIChatHandledResult(
          handled: true,
          reply: buildRecommendReplyFromLocalCandidates(
            sensitiveSkinCandidates,
            updatedPreferences: discovery.localPreferences.copyWith(
              intensity: 'light',
            ),
          ),
          recommendedProducts: sensitiveSkinCandidates,
          source: 'local_sensitive_skin_choice',
          pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
        ),
      );
    }

    final referenceCheaperResult = resolveReferenceCheaperCandidates(
      message: incoming.trimmed,
      catalog: catalog,
      sessionPreferences: currentPreferences,
      effectivePreferences: discovery.localPreferences,
      referenceMemory: incoming.effectiveRecommendationMemory,
      arabicReasons: incoming.responseLanguage.isArabic,
    );
    if (referenceCheaperResult != null) {
      if (referenceCheaperResult.candidates.isEmpty) {
        return RecommendationResolverResult(
          trace: trace.copyWith(
            finalGuardDecision: 'reference_cheaper_no_match',
            localCandidateCount: 0,
            workerCandidateCount: 0,
            candidateSource: 'referenceCheaper',
            noMatchReason: 'reference_cheaper_no_match',
          ),
          handledResult: AIChatHandledResult(
            handled: true,
            fallbackText: buildNoMatchMessage(
              incoming.trimmed,
              referenceCheaperResult.pivotPreferences,
              catalog,
              incoming.responseLanguage,
              reasonCode: 'reference_cheaper_no_match',
            ),
            preferences: referenceCheaperResult.pivotPreferences,
            source: 'reference_cheaper_pivot',
            issueCode: 'no_candidate_match',
            reasonCode: 'reference_cheaper_no_match',
            isNoMatch: true,
            pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
          ),
        );
      }

      final topDisplayCandidates = referenceCheaperResult.displayCandidates;

      return RecommendationResolverResult(
        trace: trace.copyWith(
          finalGuardDecision: 'reference_cheaper_pivot',
          localCandidateCount: referenceCheaperResult.candidates.length,
          workerCandidateCount: referenceCheaperResult.candidates.length,
          candidateSource: 'referenceCheaper',
          noMatchReason: null,
        ),
        handledResult: AIChatHandledResult(
          handled: true,
          reply: buildRecommendReplyFromLocalCandidates(
            topDisplayCandidates,
            updatedPreferences: referenceCheaperResult.pivotPreferences,
          ),
          recommendedProducts: topDisplayCandidates,
          source: 'reference_cheaper_pivot',
          pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
        ),
      );
    }

    if (_shouldAnswerBestMatchLocally(
      incoming,
      discovery,
      localCandidatesRefs,
    )) {
      return RecommendationResolverResult(
        trace: trace.copyWith(finalGuardDecision: 'local_best_match'),
        handledResult: AIChatHandledResult(
          handled: true,
          reply: buildRecommendReplyFromLocalCandidates(
            localCandidatesRefs,
            updatedPreferences: discovery.localPreferences,
          ),
          recommendedProducts: localCandidatesRefs,
          source: 'local_best_match',
          pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
        ),
      );
    }

    if (_shouldRecommendSinglePickLocally(incoming, localCandidatesRefs)) {
      final singleCandidate = localCandidatesRefs.take(1).toList(growable: false);
      return RecommendationResolverResult(
        trace: trace.copyWith(finalGuardDecision: 'local_single_pick'),
        handledResult: AIChatHandledResult(
          handled: true,
          reply: buildRecommendReplyFromLocalCandidates(
            singleCandidate,
            updatedPreferences: discovery.localPreferences,
          ),
          recommendedProducts: singleCandidate,
          source: 'local_single_pick',
          pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
        ),
      );
    }

    if (!discovery.isFollowUpOrCompare && localCandidatesRefs.isEmpty) {
      if (!discovery.localReadyForRecommendation) {
        final nextMissingSlot = discovery.localMissingSlots.isNotEmpty
            ? discovery.localMissingSlots.first
            : null;
        return RecommendationResolverResult(
          trace: trace,
          handledResult: AIChatHandledResult(
            handled: true,
            reply: AIChatReply.ask(
              question: buildQuestionForMissingSlot(
                nextMissingSlot,
                incoming.responseLanguage,
              ),
              updatedPreferences: discovery.localPreferences,
            ),
            source: 'local_precheck',
            issueCode: 'insufficient_criteria',
            reasonCode: 'empty_local_candidates_missing_slots',
            pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
          ),
        );
      }

      final memoryBudgetRecoveryCandidates = _memoryBudgetRecoveryCandidates(
        incoming: incoming,
        discovery: discovery,
        catalog: catalog,
      );
      if (memoryBudgetRecoveryCandidates.isNotEmpty) {
        return RecommendationResolverResult(
          trace: trace.copyWith(
            finalGuardDecision: 'memory_budget_recovery',
            localCandidateCount: memoryBudgetRecoveryCandidates.length,
            candidateSource: 'memoryBudgetRecovery',
            noMatchReason: null,
          ),
          handledResult: AIChatHandledResult(
            handled: true,
            reply: buildRecommendReplyFromLocalCandidates(
              memoryBudgetRecoveryCandidates,
              updatedPreferences: discovery.localPreferences,
            ),
            recommendedProducts: memoryBudgetRecoveryCandidates,
            source: 'memory_budget_recovery',
            pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
          ),
        );
      }

      final reasonCode = localNoMatchReasonForCatalog(
        discovery.localPreferences,
        catalog,
      );
      if (reasonCode == 'excluded_note_no_match') {
        return RecommendationResolverResult(
          trace: trace.copyWith(
            noMatchReason: reasonCode,
            finalGuardDecision: 'excluded_note_conflict_clarification',
          ),
          handledResult: AIChatHandledResult(
            handled: true,
            reply: AIChatReply.ask(
              question: buildExcludedNoteConflictQuestion(
                discovery.localPreferences,
                incoming.responseLanguage,
              ),
              updatedPreferences: discovery.localPreferences,
            ),
            source: 'excluded_note_conflict',
            issueCode: 'constraint_conflict',
            reasonCode: reasonCode,
            pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
          ),
        );
      }
      return RecommendationResolverResult(
        trace: trace.copyWith(noMatchReason: reasonCode),
        handledResult: AIChatHandledResult(
          handled: true,
          fallbackText: buildNoMatchMessage(
            incoming.trimmed,
            discovery.localPreferences,
            catalog,
            incoming.responseLanguage,
            reasonCode: reasonCode,
          ),
          preferences: discovery.localPreferences,
          source: 'local_precheck',
          issueCode: 'no_candidate_match',
          reasonCode: reasonCode,
          isNoMatch: true,
          pruneHistoricalBotMessages: discovery.shouldPruneBotHistory,
        ),
      );
    }

    String? localFallbackAnswer;
    String? focusProductId;
    if (discovery.isFollowUpOrCompare) {
      if (incoming.intent == AIChatIntent.compareProducts &&
          resolvedProducts.length < 2) {
        final unresolvedProducts = _unresolvedComparisonFragments(
          message: incoming.trimmed,
          catalog: catalog,
          resolvedProducts: mentionedProductsForCompare,
        );
        if (unresolvedProducts.isNotEmpty) {
          final missingNames = unresolvedProducts.take(2).join(', ');
          return RecommendationResolverResult(
            trace: trace.copyWith(
              finalGuardDecision: 'comparison_unresolved_catalog_product',
            ),
            handledResult: AIChatHandledResult(
              handled: true,
              reply: AIChatReply.answer(
                answer: translate(
                  incoming.responseLanguage,
                  ar: 'لا أقدر أقارن $missingNames لأنه غير موجود في الكتالوج الحالي. ابعت اسمين موجودين في الكتالوج أو اختار من الترشيحات الظاهرة.',
                  en: 'I cannot compare $missingNames because it is not in the current catalog. Send two catalog product names or choose from the shown recommendations.',
                ),
                updatedPreferences: currentPreferences,
              ),
              source: 'compare_unresolved_catalog_product',
              reasonCode: 'comparison_unresolved_catalog_product',
            ),
          );
        }
        return RecommendationResolverResult(
          trace: trace,
          handledResult: AIChatHandledResult(
            handled: true,
            reply: AIChatReply.ask(
              question: buildCompareWithoutContextClarificationText(
                incoming.responseLanguage,
              ),
              updatedPreferences: currentPreferences,
            ),
            source: 'compare_clarification',
            reasonCode: 'compare_needs_more_products',
          ),
        );
      }

      if (resolvedProducts.isNotEmpty) {
        if (incoming.intent == AIChatIntent.compareProducts &&
            resolvedProducts.length >= 2) {
          localFallbackAnswer = _buildComparisonAnswer(
            resolvedProducts: resolvedProducts,
            preferences: currentPreferences,
            language: incoming.responseLanguage,
          );
          return RecommendationResolverResult(
            trace: trace.copyWith(
              finalGuardDecision: 'local_product_comparison',
            ),
            handledResult: AIChatHandledResult(
              handled: true,
              reply: AIChatReply.answer(
                answer: localFallbackAnswer,
                updatedPreferences: currentPreferences,
              ),
              source: 'local_product_comparison',
              reasonCode: 'catalog_products_resolved_for_compare',
            ),
          );
        } else {
          final product = resolvedProducts.first;
          focusProductId = product.productId;
          localFallbackAnswer = translate(
            incoming.responseLanguage,
            ar: 'هذا العطر (${product.name}) يتميز بـ ${product.notes.take(3).join("، ")} وهو مناسب لـ ${product.occasion}.',
            en: 'This perfume (${product.name}) features ${product.notes.take(3).join(", ")} and is perfect for ${product.occasion}.',
          );
        }
      }
    }

    final candidatesList =
        (discovery.isFollowUpOrCompare && resolvedProducts.isNotEmpty)
        ? resolvedProducts
              .map((ref) => _productFromRefOrCatalog(ref, catalog))
              .toList(growable: false)
        : localCandidatesRefs.take(15).map((ref) => ref.product).toList();

    return RecommendationResolverResult(
      trace: trace.copyWith(workerCandidateCount: candidatesList.length),
      recommendationContext: AIChatRecommendationContext(
        localCandidatesRefs: localCandidatesRefs,
        candidatesList: candidatesList,
        localFallbackAnswer: localFallbackAnswer,
        focusProductId: focusProductId,
        budgetPolicy: discovery.budgetPolicy,
        effectivePreferences: discovery.localPreferences,
      ),
    );
  }

  List<String> _unresolvedComparisonFragments({
    required String message,
    required List<ProductModel> catalog,
    required List<ProductModel> resolvedProducts,
  }) {
    final fragments = _latinComparisonFragments(message);
    if (fragments.isEmpty) return const [];

    final unresolved = <String>[];
    for (final fragment in fragments) {
      final normalizedFragment = CatalogProductMatcher.normalize(fragment);
      if (normalizedFragment.isEmpty) continue;
      final matchesResolved = resolvedProducts.any(
        (product) => CatalogProductMatcher.queryMentionsProduct(
          normalizedFragment,
          product,
        ),
      );
      if (matchesResolved) continue;
      final resolved = MentionedProductResolver.resolveBest(
        message: fragment,
        catalog: catalog,
      );
      if (resolved == null) unresolved.add(fragment);
    }
    return unresolved.toSet().toList(growable: false);
  }

  List<String> _latinComparisonFragments(String message) {
    final chunks = RegExp(
      r"[A-Za-z][A-Za-z0-9 .'-]*",
    ).allMatches(message).map((match) => match.group(0) ?? '').toList();
    if (chunks.isEmpty) return const [];

    const stopwords = {
      'compare',
      'between',
      'and',
      'them',
      'it',
      'first',
      'second',
      'third',
      'vs',
      'with',
      'for',
      'projection',
      'price',
      'perfume',
      'fragrance',
    };
    final fragments = <String>[];
    for (final chunk in chunks) {
      final tokens = chunk
          .split(RegExp(r'\s+'))
          .map((token) => token.trim())
          .where((token) => token.isNotEmpty)
          .where((token) => !stopwords.contains(token.toLowerCase()))
          .toList(growable: false);
      if (tokens.isEmpty) continue;
      final fragment = tokens.join(' ').trim();
      if (fragment.length < 3) continue;
      fragments.add(fragment);
    }
    return fragments;
  }

  List<RecommendedProduct> _memoryBudgetRecoveryCandidates({
    required AIChatTurnContext incoming,
    required AIChatDiscoveryContext discovery,
    required List<ProductModel> catalog,
  }) {
    final previousRefs =
        incoming.effectiveRecommendationMemory.lastRecommendedProducts;
    if (previousRefs.isEmpty || discovery.localPreferences.maxBudget == null) {
      return const <RecommendedProduct>[];
    }

    final recovered = <RecommendedProduct>[];
    for (final ref in previousRefs) {
      final product = _productFromRefOrCatalog(ref, catalog);
      if (product.stock <= 0) continue;

      final budgetStatus = LocalCandidateFilter.budgetStatusForProduct(
        product,
        discovery.localPreferences,
        allowUpsell: discovery.budgetPolicy == AIChatBudgetPolicy.flexible,
      );
      if (budgetStatus == null) continue;

      if (!_passesMemoryRecoveryHardGuards(
        product,
        discovery.localPreferences,
      )) {
        continue;
      }

      if (!_hasMemoryRecoveryContextOverlap(
        product,
        discovery.localPreferences,
      )) {
        continue;
      }

      recovered.add(
        RecommendedProduct(
          product: product,
          matchScore: ref.matchScore > 0
              ? ref.matchScore.clamp(0.0, 0.74)
              : 0.62,
          matchLabel: 'Candidate Match',
          matchReason:
              'Closest previously suggested option that still fits your updated budget.',
          budgetStatus: budgetStatus,
          exactBudget: discovery.localPreferences.maxBudget,
          candidateSource: RecommendedCandidateSource.relaxed,
        ),
      );
    }

    recovered.sort((a, b) {
      final byBudget = a.budgetStatus.index.compareTo(b.budgetStatus.index);
      if (byBudget != 0) return byBudget;
      final byScore = b.matchScore.compareTo(a.matchScore);
      if (byScore != 0) return byScore;
      return a.product.effectivePrice.compareTo(b.product.effectivePrice);
    });
    return recovered.take(3).toList(growable: false);
  }

  bool _passesMemoryRecoveryHardGuards(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    final preferredGender = preferences.gender?.toLowerCase();
    final productGender = product.gender.toLowerCase();
    if (preferredGender != null &&
        preferredGender != 'unisex' &&
        productGender.isNotEmpty &&
        productGender != 'unisex' &&
        productGender != preferredGender) {
      return false;
    }

    if (preferences.excludedNotes.isNotEmpty) {
      final productText = [
        product.fragranceFamily,
        product.description,
        ...product.notes,
        ...product.topNotes,
        ...product.middleNotes,
        ...product.baseNotes,
        ...product.tags,
      ].join(' ').toLowerCase();
      for (final excluded in preferences.excludedNotes) {
        if (productText.contains(excluded.toLowerCase())) return false;
      }
    }

    return true;
  }

  bool _hasMemoryRecoveryContextOverlap(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    final productTerms = <String>{
      product.occasion.toLowerCase(),
      product.time.toLowerCase(),
      product.intensity.toLowerCase(),
      product.fragranceFamily.toLowerCase(),
      ...product.notes.map((note) => note.toLowerCase()),
      ...product.topNotes.map((note) => note.toLowerCase()),
      ...product.middleNotes.map((note) => note.toLowerCase()),
      ...product.baseNotes.map((note) => note.toLowerCase()),
      ...product.tags.map((tag) => tag.toLowerCase()),
    }..removeWhere((term) => term.trim().isEmpty);

    final preferenceTerms = <String>{
      if (preferences.occasion != null) preferences.occasion!.toLowerCase(),
      if (preferences.time != null) preferences.time!.toLowerCase(),
      if (preferences.intensity != null) preferences.intensity!.toLowerCase(),
      ...preferences.preferredNotes.map((note) => note.toLowerCase()),
      ...preferences.preferredTopNotes.map((note) => note.toLowerCase()),
      ...preferences.preferredMiddleNotes.map((note) => note.toLowerCase()),
      ...preferences.preferredBaseNotes.map((note) => note.toLowerCase()),
      ...preferences.tags.map((tag) => tag.toLowerCase()),
    }..removeWhere((term) => term.trim().isEmpty);

    return preferenceTerms.any(productTerms.contains);
  }

  static bool _looksLikeReferenceCheaperRequest(String message) {
    final signal = analyzeAvailabilityFollowUpSignal(message);
    if (signal.isContextualSimilarCheaperPivotCandidate ||
        (signal.hasSimilarityTerm && signal.hasCheaperTerm)) {
      return true;
    }

    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    final hasCheaperSignal =
        normalized.contains('cheaper') ||
        normalized.contains('less expensive') ||
        normalized.contains('lower price') ||
        normalized.contains('ارخص') ||
        normalized.contains('أرخص') ||
        normalized.contains('اقل') ||
        normalized.contains('أقل');
    if (!hasCheaperSignal) return false;

    final hasReferenceSignal =
        normalized.contains('like') ||
        normalized.contains('similar') ||
        normalized.contains('same vibe') ||
        normalized.contains('same smell') ||
        normalized.contains('زي') ||
        normalized.contains('شبه') ||
        normalized.contains('نفس');
    return hasReferenceSignal;
  }

  static ProductModel? _resolveReferenceProductFromMessage({
    required String message,
    required List<ProductModel> catalog,
    required RecommendationMemory referenceMemory,
  }) {
    final direct = MentionedProductResolver.resolveBest(
      message: message,
      catalog: catalog,
    );
    if (direct != null) return direct;

    final profile = AvailabilityReferenceProfileRegistry.resolveByMessage(
      message,
    );
    if (profile == null) {
      return _resolveReferenceProductFromMemory(
        message: message,
        catalog: catalog,
        referenceMemory: referenceMemory,
      );
    }

    final profileTerms =
        <String>{
              profile.displayName,
              if (profile.brand.trim().isNotEmpty &&
                  profile.displayName.trim().isNotEmpty)
                '${profile.brand} ${profile.displayName}',
              ...profile.aliases,
            }
            .map(CatalogProductMatcher.normalize)
            .where((term) => term.isNotEmpty)
            .toSet();

    for (final product in catalog) {
      final productTerms = CatalogProductMatcher.termsFor(product);
      for (final profileTerm in profileTerms) {
        for (final productTerm in productTerms) {
          if (CatalogProductMatcher.containsTerm(productTerm, profileTerm)) {
            return product;
          }
        }
      }
    }

    return _resolveReferenceProductFromMemory(
      message: message,
      catalog: catalog,
      referenceMemory: referenceMemory,
    );
  }

  static ProductModel? _resolveReferenceProductFromMemory({
    required String message,
    required List<ProductModel> catalog,
    required RecommendationMemory referenceMemory,
  }) {
    final signal = analyzeAvailabilityFollowUpSignal(message);
    if ((!signal.hasContextRef && signal.hasExplicitAvailabilityProduct) ||
        referenceMemory.lastRecommendedProducts.isEmpty) {
      return null;
    }
    final resolvedRefs = RecommendationReferenceResolver.resolve(
      message: message,
      memory: referenceMemory,
    );
    final contextualRef = resolvedRefs.isNotEmpty
        ? resolvedRefs.first
        : _focusedOrFirstMemoryRef(referenceMemory);
    if (contextualRef == null) return null;
    return _productFromMemoryRefOrCatalog(contextualRef, catalog);
  }

  static RecommendedProductRef? _focusedOrFirstMemoryRef(
    RecommendationMemory memory,
  ) {
    if (memory.lastRecommendedProducts.isEmpty) return null;
    final focusedId = memory.lastFocusedProductId;
    if (focusedId != null) {
      for (final ref in memory.lastRecommendedProducts) {
        if (ref.productId == focusedId) return ref;
      }
    }
    return memory.lastRecommendedProducts.first;
  }

  static ProductModel _productFromMemoryRefOrCatalog(
    RecommendedProductRef ref,
    List<ProductModel> catalog,
  ) {
    for (final product in catalog) {
      if (product.id == ref.productId) return product;
    }

    return ProductModel(
      id: ref.productId,
      name: ref.name,
      nameLower: ref.name.toLowerCase(),
      searchPrefixes: const [],
      brand: ref.brand,
      price: ref.price,
      stock: ref.stock,
      gender: 'unisex',
      season: ref.season,
      fragranceFamily: 'Unknown',
      notes: ref.notes,
      imageUrls: const [],
      description: '',
      categoryName: 'Uncategorized',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      occasion: ref.occasion,
      time: 'all_day',
      intensity: ref.intensity,
      topNotes: ref.topNotes,
      middleNotes: ref.middleNotes,
      baseNotes: ref.baseNotes,
      tags: ref.tags,
    );
  }

  static ProductModel _referenceProductWithProfile(
    ProductModel referenceProduct,
    AvailabilityReferenceProfile profile,
  ) {
    return referenceProduct.copyWith(
      name: profile.displayName.trim().isEmpty
          ? referenceProduct.name
          : profile.displayName,
      brand: profile.brand.trim().isEmpty
          ? referenceProduct.brand
          : profile.brand,
      gender: profile.genderHint ?? referenceProduct.gender,
      fragranceFamily: profile.fragranceFamily.trim().isEmpty
          ? referenceProduct.fragranceFamily
          : profile.fragranceFamily,
      notes: profile.preferredNotes.isEmpty
          ? referenceProduct.notes
          : profile.preferredNotes.toList(growable: false),
      topNotes: profile.topNotes.isEmpty
          ? referenceProduct.topNotes
          : profile.topNotes.toList(growable: false),
      middleNotes: profile.middleNotes.isEmpty
          ? referenceProduct.middleNotes
          : profile.middleNotes.toList(growable: false),
      baseNotes: profile.baseNotes.isEmpty
          ? referenceProduct.baseNotes
          : profile.baseNotes.toList(growable: false),
      tags: profile.tags.isEmpty
          ? referenceProduct.tags
          : profile.tags.toList(growable: false),
      season: profile.seasonHint ?? referenceProduct.season,
      occasion: profile.occasionHint ?? referenceProduct.occasion,
      time: profile.timeHint ?? referenceProduct.time,
      intensity: profile.intensityHint ?? referenceProduct.intensity,
    );
  }

  static String localNoMatchReason(SessionPreferences preferences) {
    if (preferences.excludedNotes.isNotEmpty) {
      return 'excluded_note_no_match';
    }
    if (preferences.maxBudget != null) {
      return 'budget_no_match';
    }
    if (preferences.preferredNotes.length >= 2) {
      return 'strong_scent_no_match';
    }
    if (preferences.preferredNotes.isNotEmpty ||
        preferences.preferredTopNotes.isNotEmpty ||
        preferences.preferredMiddleNotes.isNotEmpty ||
        preferences.preferredBaseNotes.isNotEmpty) {
      return 'scent_no_match';
    }
    if (preferences.gender != null ||
        preferences.season != null ||
        preferences.time != null ||
        preferences.occasion != null ||
        preferences.intensity != null) {
      return 'context_no_match';
    }
    return 'local_candidate_no_match';
  }

  static String localNoMatchReasonForCatalog(
    SessionPreferences preferences,
    List<ProductModel> catalog,
  ) {
    if (preferences.excludedNotes.isNotEmpty) {
      final relaxedExclusionPreferences = preferences.copyWith(
        excludedNotes: const [],
      );
      final relaxedExclusionCandidates =
          LocalCandidateFilter.getTopRecommendations(
            catalog: catalog,
            preferences: relaxedExclusionPreferences,
          );
      if (relaxedExclusionCandidates.isNotEmpty) {
        return 'excluded_note_no_match';
      }
      return localNoMatchReasonForCatalog(relaxedExclusionPreferences, catalog);
    }

    if (preferences.maxBudget != null && catalog.isNotEmpty) {
      final budgetlessPreferences = preferences.copyWith(clearBudget: true);
      final budgetlessCandidates = LocalCandidateFilter.getTopRecommendations(
        catalog: catalog,
        preferences: budgetlessPreferences,
      );
      if (budgetlessCandidates.isNotEmpty) {
        return 'budget_no_match';
      }

      return localNoMatchReason(budgetlessPreferences);
    }

    return localNoMatchReason(preferences);
  }

  bool _shouldAnswerBestMatchLocally(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery,
    List<RecommendedProduct> localCandidatesRefs,
  ) {
    if (localCandidatesRefs.isEmpty) return false;
    if (incoming.intent != AIChatIntent.newRecommendation) return false;
    if (discovery.shouldPruneBotHistory) return false;
    if (discovery.localPreferences.activeCriteriaCount < 3) return false;

    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) return false;
    if (!AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return false;
    }

    return normalized.contains('best match') ||
        normalized.contains('best option') ||
        normalized.contains('best recommendation') ||
        normalized.contains('show me the best') ||
        normalized.contains('give me the best') ||
        normalized.contains('give me your best') ||
        normalized.contains('give me best') ||
        normalized.contains('recommend one') ||
        normalized.contains('افضل اختيار') ||
        normalized.contains('أفضل اختيار') ||
        normalized.contains('رشحلي افضل') ||
        normalized.contains('رشحلي أفضل') ||
        normalized.contains('رشح افضل') ||
        normalized.contains('رشح أفضل') ||
        normalized.contains('اقترح افضل') ||
        normalized.contains('اقترح أفضل');
  }

  bool _shouldRecommendSinglePickLocally(
    AIChatTurnContext incoming,
    List<RecommendedProduct> localCandidatesRefs,
  ) {
    if (localCandidatesRefs.isEmpty) return false;
    if (incoming.intent != AIChatIntent.newRecommendation) return false;
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) return false;
    final asksForRecommendation =
        normalized.contains('recommend') ||
        normalized.contains('\u0631\u0634\u062d') ||
        normalized.contains('\u0627\u0642\u062a\u0631\u062d');
    if (!asksForRecommendation) return false;
    return normalized.contains('recommend one') ||
        normalized.contains('one perfume') ||
        normalized.contains('one option') ||
        normalized.contains('single recommendation') ||
        normalized.contains('\u0639\u0637\u0631 \u0648\u0627\u062d\u062f') ||
        normalized.contains('\u0627\u062e\u062a\u064a\u0627\u0631 \u0648\u0627\u062d\u062f') ||
        normalized.contains('\u0648\u0627\u062d\u062f \u0648\u062e\u0644\u0627\u0635');
  }

  List<RecommendedProduct> _sensitiveSkinLocalCandidates(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery,
    List<RecommendedProduct> localCandidatesRefs,
    List<ProductModel> catalog,
  ) {
    if (incoming.intent != AIChatIntent.newRecommendation) {
      return const [];
    }
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) return const [];
    final hasSensitiveSignal =
        normalized.contains('sensitive skin') ||
        (normalized.contains('\u0628\u0634\u0631') &&
            normalized.contains('\u062d\u0633\u0627\u0633'));
    if (!hasSensitiveSignal) return const [];
    final asksForChoice = normalized.contains('choose') ||
        normalized.contains('pick') ||
        normalized.contains('recommend') ||
        normalized.contains('\u0627\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0623\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0631\u0634\u062d');
    if (!asksForChoice) return const [];
    if (localCandidatesRefs.isNotEmpty) {
      return localCandidatesRefs.take(3).toList(growable: false);
    }
    if (catalog.isEmpty) return const [];
    final filtered = LocalCandidateFilter.getTopRecommendations(
      catalog: catalog,
      preferences: discovery.localPreferences.copyWith(intensity: 'light'),
    ).take(3).toList(growable: false);
    if (filtered.isNotEmpty) return filtered;

    final fallbackCatalog = catalog.where((product) => product.stock > 0).toList(
      growable: false,
    )..sort((a, b) {
        final aScore = _sensitiveSkinFallbackScore(a);
        final bScore = _sensitiveSkinFallbackScore(b);
        if (aScore != bScore) return bScore.compareTo(aScore);
        return a.effectivePrice.compareTo(b.effectivePrice);
      });
    return fallbackCatalog
        .take(3)
        .map(
          (product) => RecommendedProduct(
            product: product,
            matchScore: _sensitiveSkinFallbackScore(product).toDouble(),
            matchLabel: 'Safe catalog fallback',
            matchReason: 'Lightweight catalog option.',
            candidateSource: RecommendedCandidateSource.strict,
          ),
        )
        .toList(growable: false);
  }

  int _sensitiveSkinFallbackScore(ProductModel product) {
    final terms =
        <String>{
          product.intensity,
          product.fragranceFamily,
          ...product.notes,
          ...product.tags,
        }.map((term) => LocalIntentParser.normalizeInput(term)).join(' ');
    var score = 0;
    if (terms.contains('light')) score += 4;
    if (terms.contains('fresh')) score += 3;
    if (terms.contains('soft')) score += 3;
    if (terms.contains('clean')) score += 2;
    if (terms.contains('musk')) score += 1;
    return score;
  }

  String _candidateSource(
    List<RecommendedProduct> localCandidates,
    List<RecommendedProductRef> resolvedProducts,
  ) {
    if (resolvedProducts.isNotEmpty) return 'resolvedFollowUp';
    if (localCandidates.isEmpty) return 'none';
    if (AIChatExperimentConfig.useCatalogSearchEngine) {
      return 'catalogSearchPrimary';
    }
    final sources = localCandidates
        .map((candidate) => candidate.candidateSource.name)
        .toSet();
    if (sources.length == 1) return sources.first;
    return sources.join('+');
  }

  String _buildComparisonAnswer({
    required List<RecommendedProductRef> resolvedProducts,
    required SessionPreferences preferences,
    required AIChatLanguage language,
  }) {
    final comparisonProducts = _dedupeResolvedProducts(resolvedProducts);
    final comparison = ProductComparisonEngine.compare(
      products: comparisonProducts,
      preferences: preferences,
    );
    final byId = <String, RecommendedProductRef>{
      for (final product in comparisonProducts) product.productId: product,
    };
    final personalizedWinner = comparison.personalizedWinner;
    final personalizedName =
        (personalizedWinner != null && byId.containsKey(personalizedWinner))
        ? _comparisonDisplayName(byId[personalizedWinner]!)
        : _comparisonDisplayName(comparisonProducts.first);
    final cheapestName = _comparisonDisplayNameOrNull(
      byId[comparison.factsWinners['cheapest']],
    );
    final strongestName = _comparisonDisplayNameOrNull(
      byId[comparison.factsWinners['strongest']],
    );
    final seasonBestName = _comparisonDisplayNameOrNull(
      byId[comparison.factsWinners['best_for_season']],
    );
    final comparedNames = comparisonProducts
        .take(3)
        .map(_comparisonDisplayName)
        .join(' vs ');

    return translate(
      language,
      ar:
          'تمت المقارنة:\n'
          '• الأرخص: ${cheapestName ?? "غير متاح"}\n'
          '• الأقوى ثباتًا/فوحانًا: ${strongestName ?? "غير متاح"}\n'
          '${seasonBestName != null ? "• الأنسب للموسم الحالي: $seasonBestName\n" : ""}'
          '• الأفضل لذوقك الحالي: $personalizedName',
      en:
          'Comparison complete: $comparedNames\n'
          '• Cheapest: ${cheapestName ?? "N/A"}\n'
          '• Strongest projection/longevity: ${strongestName ?? "N/A"}\n'
          '${seasonBestName != null ? "• Best for current season: $seasonBestName\n" : ""}'
          '• Best for your current taste: $personalizedName',
    );
  }

  List<RecommendedProductRef> _dedupeResolvedProducts(
    List<RecommendedProductRef> products,
  ) {
    final seen = <String>{};
    final seenDisplayNames = <String>{};
    final unique = <RecommendedProductRef>[];
    for (final product in products) {
      final key = product.productId.trim().isNotEmpty
          ? 'id:${product.productId.trim().toLowerCase()}'
          : 'name:${product.brand.trim().toLowerCase()}|${product.name.trim().toLowerCase()}';
      final displayName = _comparisonDisplayName(product).toLowerCase();
      if (!seen.add(key)) continue;
      if (!seenDisplayNames.add(displayName)) continue;
      unique.add(product);
    }
    return unique;
  }

  String? _comparisonDisplayNameOrNull(RecommendedProductRef? product) {
    if (product == null) return null;
    return _comparisonDisplayName(product);
  }

  String _comparisonDisplayName(RecommendedProductRef product) {
    final name = product.name.trim();
    final brand = product.brand.trim();
    if (brand.isEmpty || name.isEmpty) return name.isEmpty ? brand : name;
    if (name.toLowerCase().contains(brand.toLowerCase())) return name;
    return '$brand $name';
  }

  ProductModel _productFromRefOrCatalog(
    RecommendedProductRef ref,
    List<ProductModel> catalog,
  ) {
    for (final product in catalog) {
      if (product.id == ref.productId) return product;
    }

    return ProductModel(
      id: ref.productId,
      name: ref.name,
      nameLower: ref.name.toLowerCase(),
      searchPrefixes: const [],
      brand: ref.brand,
      price: ref.price,
      stock: ref.stock,
      gender: 'unisex',
      season: ref.season,
      fragranceFamily: 'Unknown',
      notes: ref.notes,
      imageUrls: const [],
      description: '',
      categoryName: 'Uncategorized',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      occasion: ref.occasion,
      time: 'all_day',
      intensity: ref.intensity,
      topNotes: ref.topNotes,
      middleNotes: ref.middleNotes,
      baseNotes: ref.baseNotes,
      tags: ref.tags,
    );
  }

  RecommendedProductRef _refFromProduct(ProductModel product) {
    return RecommendedProductRef(
      productId: product.id,
      name: product.name,
      brand: product.brand,
      displayIndex: 0,
      price: product.effectivePrice,
      stock: product.stock,
      season: product.season,
      occasion: product.occasion,
      intensity: product.intensity,
      notes: product.notes,
      topNotes: product.topNotes,
      middleNotes: product.middleNotes,
      baseNotes: product.baseNotes,
      tags: product.tags,
    );
  }
}
