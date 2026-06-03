import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_followup_detector.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

enum AvailabilityRoute {
  none,
  direct,
  followUp,
  similarCheaperPivot,
  clarification,
}

class AvailabilityRouteResult {
  final List<AvailabilityRouteDecision> decisions;
  final AvailabilityFollowUpSignal followUpSignal;

  const AvailabilityRouteResult({
    required this.decisions,
    required this.followUpSignal,
  });

  List<AvailabilityRoute> get routes =>
      decisions.map((decision) => decision.route).toList(growable: false);

  AvailabilityRoute get route =>
      decisions.isEmpty ? AvailabilityRoute.none : decisions.first.route;

  String get reasonCode => decisions.isEmpty
      ? 'availability_route_none'
      : decisions.first.reasonCode;

  bool get shouldSkip =>
      routes.isEmpty || routes.first == AvailabilityRoute.none;
}

class AvailabilityRouteDecision {
  final AvailabilityRoute route;
  final String reasonCode;

  const AvailabilityRouteDecision({
    required this.route,
    required this.reasonCode,
  });

  static const none = AvailabilityRouteDecision(
    route: AvailabilityRoute.none,
    reasonCode: 'availability_route_none',
  );
}

class AvailabilityRouteResolver {
  const AvailabilityRouteResolver();

  AvailabilityRouteResult resolve({
    required AIChatTurnContext incoming,
    required AIChatState state,
    required bool Function(String message, AIChatIntent intent)
    shouldContinueAvailabilityClarification,
  }) {
    final emptySignal = analyzeAvailabilityFollowUpSignal(incoming.trimmed);
    if (incoming.intent == AIChatIntent.compareProducts ||
        incoming.intent == AIChatIntent.summary) {
      return AvailabilityRouteResult(
        decisions: const <AvailabilityRouteDecision>[
          AvailabilityRouteDecision(
            route: AvailabilityRoute.none,
            reasonCode: 'availability_route_non_availability_intent',
          ),
        ],
        followUpSignal: emptySignal,
      );
    }
    if (_shouldSkipAvailabilityRouting(incoming, state)) {
      return AvailabilityRouteResult(
        decisions: const <AvailabilityRouteDecision>[
          AvailabilityRouteDecision(
            route: AvailabilityRoute.none,
            reasonCode: 'availability_route_skipped_recommendation_signal',
          ),
        ],
        followUpSignal: emptySignal,
      );
    }

    final followUpSignal = emptySignal;
    final decisions = <AvailabilityRouteDecision>[];

    if (incoming.shouldContinueAvailabilityClarification ||
        shouldContinueAvailabilityClarification(
          incoming.trimmed,
          AIChatIntent.newRecommendation,
        )) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.clarification,
          reasonCode: 'availability_clarification_continuation',
        ),
      );
    }

    final shouldPivot = _shouldPivotFoundAvailabilitySimilarCheaper(
      incoming,
      state,
      followUpSignal,
    );
    if (shouldPivot) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.similarCheaperPivot,
          reasonCode: 'availability_matched_similar_cheaper_pivot',
        ),
      );
    }

    if (!shouldPivot &&
        followUpSignal.hasExplicitAvailabilityProduct &&
        (!AIChatExperimentConfig.llmLedRouterV2 ||
            !_looksLikeV2SemanticAvailabilityPhrase(incoming.trimmed)) &&
        (incoming.intent == AIChatIntent.availabilityCheck ||
            incoming.intent == AIChatIntent.followUpProduct) &&
        LocalIntentParser.containsAny(
          LocalIntentParser.normalizeInput(incoming.trimmed),
          AvailabilityIntentUtils.availabilityKeywords,
        )) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.direct,
          reasonCode: 'availability_explicit_product',
        ),
      );
    }

    if (!shouldPivot &&
        _shouldRouteToMatchedAvailabilitySimilarityFollowUp(
          incoming,
          state,
          followUpSignal,
        )) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.followUp,
          reasonCode: 'availability_matched_similarity_follow_up',
        ),
      );
    }

    final shouldHandleAsAvailabilityFollowUp =
        state.availabilityContext.hasContext &&
        !followUpSignal.hasExplicitAvailabilityProduct &&
        (incoming.intent == AIChatIntent.followUpProduct ||
            looksLikeAvailabilityFollowUp(incoming.trimmed) ||
            looksLikeContextualAvailabilityFollowUp(incoming.trimmed));
    if (!shouldPivot && shouldHandleAsAvailabilityFollowUp) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.followUp,
          reasonCode: 'availability_contextual_follow_up',
        ),
      );
    }

    if (incoming.intent == AIChatIntent.availabilityCheck &&
        !AvailabilityIntentUtils.looksLikeLatinStandaloneName(
          incoming.trimmed,
        ) &&
        _allowsDirectAvailabilityIntentInCurrentMode(
          incoming,
          state,
          followUpSignal,
        )) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.direct,
          reasonCode: 'availability_direct_intent',
        ),
      );
    }

    final isAvailabilityFollowUp =
        incoming.intent == AIChatIntent.followUpProduct &&
        !followUpSignal.hasExplicitAvailabilityProduct &&
        looksLikeAvailabilityFollowUp(incoming.trimmed) &&
        state.availabilityContext.hasContext;
    if (!shouldPivot && isAvailabilityFollowUp) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.followUp,
          reasonCode: 'availability_follow_up_intent',
        ),
      );
    }

    final standaloneAvailabilityProduct =
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          incoming.trimmed,
        );
    if (standaloneAvailabilityProduct != null &&
        !AvailabilityIntentUtils.looksLikeLatinStandaloneName(
          incoming.trimmed,
        ) &&
        !_hasFreshRecommendationSignal(incoming.trimmed) &&
        (!AIChatExperimentConfig.llmLedRouterV2 ||
            (!_looksLikeV2SemanticAvailabilityPhrase(incoming.trimmed) &&
                !AvailabilityIntentUtils.isGenericAvailabilityCandidate(
                  standaloneAvailabilityProduct,
                ))) &&
        AvailabilityIntentUtils.looksLikeAvailabilityQuery(
          incoming.trimmed,
          hasRecommendationContext: incoming
              .effectiveRecommendationMemory
              .lastRecommendedProducts
              .isNotEmpty,
          extractedProduct: standaloneAvailabilityProduct,
        )) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.direct,
          reasonCode: 'availability_standalone_extracted_product',
        ),
      );
    }

    if (AvailabilityIntentUtils.looksLikeLatinStandaloneName(
          incoming.trimmed,
        ) &&
        (!AIChatExperimentConfig.llmLedRouterV2 ||
            !_looksLikeV2SemanticAvailabilityPhrase(incoming.trimmed))) {
      decisions.add(
        const AvailabilityRouteDecision(
          route: AvailabilityRoute.direct,
          reasonCode: 'availability_standalone_latin_name',
        ),
      );
    }

    if (decisions.isEmpty) {
      decisions.add(AvailabilityRouteDecision.none);
    }
    return AvailabilityRouteResult(
      decisions: _dedupeDecisions(decisions),
      followUpSignal: followUpSignal,
    );
  }

  List<AvailabilityRouteDecision> _dedupeDecisions(
    List<AvailabilityRouteDecision> decisions,
  ) {
    final seen = <AvailabilityRoute>{};
    final deduped = <AvailabilityRouteDecision>[];
    for (final decision in decisions) {
      if (seen.add(decision.route)) {
        deduped.add(decision);
      }
    }
    return deduped;
  }

  bool _shouldSkipAvailabilityRouting(
    AIChatTurnContext incoming,
    AIChatState state,
  ) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (_isLanguagePreferenceOnly(normalized)) return true;
    if (_isOpenChoiceOnly(normalized)) return true;
    if (LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized)) {
      return true;
    }
    if (_looksLikeV2SemanticAvailabilityPhrase(incoming.trimmed)) {
      return true;
    }
    final followUpSignal = analyzeAvailabilityFollowUpSignal(incoming.trimmed);
    if (state.availabilityContext.hasContext &&
        !followUpSignal.hasExplicitAvailabilityProduct &&
        (incoming.intent == AIChatIntent.followUpProduct ||
            looksLikeAvailabilityFollowUp(incoming.trimmed) ||
            looksLikeContextualAvailabilityFollowUp(incoming.trimmed))) {
      return false;
    }
    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return true;
    }
    if (AvailabilityIntentUtils.looksLikeGenericRecommendationOrPreferenceCommand(
      normalized,
    )) {
      return true;
    }
    if (AvailabilityIntentUtils.looksLikePersonaOrPreferenceStatement(
      normalized,
    )) {
      return true;
    }
    if (AvailabilityIntentUtils.looksLikeLatinStandaloneName(
      incoming.trimmed,
    )) {
      return false;
    }
    if (incoming.shouldContinueAvailabilityClarification ||
        AvailabilityIntentUtils.extractRedirectedProductQuery(
              incoming.trimmed,
              hasRecommendationContext: incoming
                  .effectiveRecommendationMemory
                  .lastRecommendedProducts
                  .isNotEmpty,
            ) !=
            null) {
      return false;
    }
    final extractedAvailabilityProduct =
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          incoming.trimmed,
        );
    if (AIChatExperimentConfig.llmLedRouterV2 &&
        incoming.intent == AIChatIntent.availabilityCheck) {
      final extractedLooksLikePreference =
          extractedAvailabilityProduct != null &&
          _hasFreshRecommendationSignal(incoming.trimmed);
      final hasAvailabilityProductAnchor =
          incoming.availabilityProductQuery != null ||
          (extractedAvailabilityProduct != null &&
              !extractedLooksLikePreference) ||
          followUpSignal.hasExplicitAvailabilityProduct ||
          state.availabilityContext.hasContext;
      if (!hasAvailabilityProductAnchor) {
        return true;
      }
    }
    if (state.availabilityContext.hasContext &&
        extractedAvailabilityProduct != null) {
      return false;
    }
    if (incoming.intent == AIChatIntent.availabilityCheck) {
      final hasExplicitAvailabilityKeyword = LocalIntentParser.containsAny(
        normalized,
        AvailabilityIntentUtils.availabilityKeywords,
      );
      final hasFreshRecommendationSignal = _hasFreshRecommendationSignal(
        incoming.trimmed,
      );
      if (!hasExplicitAvailabilityKeyword && hasFreshRecommendationSignal) {
        return true;
      }
      if (!hasExplicitAvailabilityKeyword &&
          LocalIntentParser.isVague(incoming.trimmed)) {
        return true;
      }
    }
    return false;
  }

  bool _allowsDirectAvailabilityIntentInCurrentMode(
    AIChatTurnContext incoming,
    AIChatState state,
    AvailabilityFollowUpSignal followUpSignal,
  ) {
    if (!AIChatExperimentConfig.llmLedRouterV2) return true;
    final extractedAvailabilityProduct =
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          incoming.trimmed,
        );
    final extractedLooksLikePreference =
        extractedAvailabilityProduct != null &&
        (_hasFreshRecommendationSignal(incoming.trimmed) ||
            _looksLikeV2SemanticAvailabilityPhrase(incoming.trimmed));
    return incoming.availabilityProductQuery != null ||
        followUpSignal.hasExplicitAvailabilityProduct ||
        state.availabilityContext.hasContext ||
        (extractedAvailabilityProduct != null &&
            !AvailabilityIntentUtils.isGenericAvailabilityCandidate(
              extractedAvailabilityProduct,
            ) &&
            !extractedLooksLikePreference);
  }

  bool _hasFreshRecommendationSignal(String message) {
    final freshPreferences = LocalIntentParser.parse(
      message,
      SessionPreferences.empty(),
    );
    return freshPreferences.activeCriteriaCount > 0 ||
        freshPreferences.hasAnyNoteSignal ||
        freshPreferences.intensity != null ||
        freshPreferences.tags.isNotEmpty;
  }

  bool _looksLikeV2SemanticAvailabilityPhrase(String message) {
    if (!AIChatExperimentConfig.llmLedRouterV2) return false;
    final normalized = LocalIntentParser.normalizeInput(message);
    if (LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized)) {
      return true;
    }
    if (AvailabilityIntentUtils.looksLikeGenericRecommendationOrPreferenceCommand(
      normalized,
    )) {
      return true;
    }
    return normalized.contains('anything fresh') ||
        normalized.contains('something fresh') ||
        normalized.contains('anything soft') ||
        normalized.contains('something soft') ||
        normalized.contains('anything elegant') ||
        normalized.contains('something elegant') ||
        normalized.contains('حاجة فريش') ||
        normalized.contains('حاجه فريش') ||
        normalized.contains('حاجة ناعمة') ||
        normalized.contains('حاجه ناعمه');
  }

  bool _isLanguagePreferenceOnly(String normalized) {
    if (normalized.isEmpty) return false;
    const languagePhrases = {
      'in arabic',
      'arabic please',
      'answer in arabic',
      'in english',
      'english please',
      'answer in english',
      '\u0628\u0627\u0644\u0639\u0631\u0628\u064a',
      '\u0639\u0631\u0628\u064a',
      '\u0628\u0627\u0644\u0627\u0646\u062c\u0644\u064a\u0632\u064a',
      '\u0627\u0646\u062c\u0644\u064a\u0632\u064a',
    };
    if (languagePhrases.contains(normalized)) return true;
    return normalized.contains('\u0628\u0627\u0644\u0639\u0631\u0628\u064a') ||
        normalized.contains(
          '\u0628\u0627\u0644\u0627\u0646\u062c\u0644\u064a\u0632\u064a',
        ) ||
        normalized.contains('in arabic') ||
        normalized.contains('in english');
  }

  bool _isOpenChoiceOnly(String normalized) {
    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    const phrases = {
      'anything',
      'any thing',
      'whatever',
      '\u0627\u064a \u062d\u0627\u062c\u0629',
      '\u0627\u064a \u062d\u0627\u062c\u0647',
      '\u0623\u064a \u062d\u0627\u062c\u0629',
      '\u0623\u064a \u062d\u0627\u062c\u0647',
    };
    return phrases.contains(compact);
  }

  bool _shouldRouteToMatchedAvailabilitySimilarityFollowUp(
    AIChatTurnContext incoming,
    AIChatState state,
    AvailabilityFollowUpSignal signal,
  ) {
    if (!state.availabilityContext.hasContext) return false;
    if (state.availabilityContext.matchedProductId == null) return false;
    if (signal.hasExplicitAvailabilityProduct) return false;

    final hasSimilarityFollowUpSignal =
        signal.isContextualSimilarityFollowUp ||
        looksLikeAvailabilityFollowUp(incoming.trimmed) ||
        (incoming.intent == AIChatIntent.followUpProduct &&
            signal.hasSimilarityTerm);
    if (!hasSimilarityFollowUpSignal) return false;

    return incoming.intent == AIChatIntent.followUpProduct ||
        incoming.intent == AIChatIntent.availabilityCheck ||
        looksLikeContextualAvailabilityFollowUp(incoming.trimmed);
  }

  bool _shouldPivotFoundAvailabilitySimilarCheaper(
    AIChatTurnContext incoming,
    AIChatState state,
    AvailabilityFollowUpSignal signal,
  ) {
    if (!state.availabilityContext.hasContext) return false;
    final canUseResolvedOrClarifiedProduct =
        state.availabilityContext.availabilityStatus ==
            AvailabilityStatus.found ||
        state.availabilityContext.candidateOptionIds.isNotEmpty;
    if (!canUseResolvedOrClarifiedProduct) {
      return false;
    }
    if ((signal.hasCheaperTerm && signal.hasContextRef) ||
        signal.isContextualCheaperPivotCandidate ||
        signal.isContextualSimilarCheaperPivotCandidate) {
      return true;
    }
    if (incoming.intent == AIChatIntent.availabilityCheck &&
        signal.hasExplicitAvailabilityProduct) {
      return false;
    }
    return signal.isContextualCheaperPivotCandidate ||
        signal.isContextualSimilarCheaperPivotCandidate ||
        (!signal.hasExplicitAvailabilityProduct &&
            signal.hasSimilarityTerm &&
            signal.hasCheaperTerm);
  }
}
