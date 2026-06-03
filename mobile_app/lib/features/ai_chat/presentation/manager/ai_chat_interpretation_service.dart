import 'dart:developer';

import 'package:perfume_app/features/ai_chat/data/models/ai_chat_interpretation_result.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_route_ownership_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_reference_profile_registry.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_product_matcher.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AIChatInterpretationApplication {
  final AIChatTurnContext incoming;
  final AIChatInterpretationResult result;

  const AIChatInterpretationApplication({
    required this.incoming,
    required this.result,
  });
}

class AIChatInterpretationService {
  final AIChatRepo _aiChatRepo;

  const AIChatInterpretationService({required AIChatRepo aiChatRepo})
    : _aiChatRepo = aiChatRepo;

  static const AIChatRouteOwnershipPolicy _ownershipPolicy =
      AIChatRouteOwnershipPolicy();

  Future<AIChatInterpretationApplication?> interpretIfUseful({
    required AIChatTurnContext incoming,
    required AIChatTurnDecision turnDecision,
    required AIChatState state,
    required List<ProductModel> catalog,
  }) async {
    if (!_shouldInterpret(incoming, turnDecision)) return null;

    final result = await _aiChatRepo.fetchAIInterpretation(
      currentMessage: incoming.trimmed,
      currentPreferences: state.preferences,
      responseLanguage: incoming.responseLanguage,
      hasRecommendationContext: incoming
          .effectiveRecommendationMemory
          .lastRecommendedProducts
          .isNotEmpty,
      hasAvailabilityContext: state.availabilityContext.hasContext,
      requestId: incoming.requestId,
    );
    if (result == null) return null;

    final rejection = _rejectionReason(
      result,
      incoming: incoming,
      state: state,
      catalog: catalog,
    );
    if (rejection != null) {
      log(
        'Interpretation rejected | requestId=${incoming.requestId} | '
        'intent=${result.intent} | confidence=${result.confidence} | reason=$rejection',
        name: 'AIChatInterpretationService',
      );
      return null;
    }

    final effectiveIntent = _effectiveIntent(incoming, result);
    final appliedPatch = result.preferencePatch.sanitize();
    log(
      'Interpretation accepted | requestId=${incoming.requestId} | '
      'intent=${result.intent} | confidence=${result.confidence} | reason=${result.reasonCode} | '
      'patch=${appliedPatch.toJson()}',
      name: 'AIChatInterpretationService',
    );

    return AIChatInterpretationApplication(
      incoming: incoming.copyWith(
        intent: effectiveIntent,
        isGreetingOnly: result.intent == 'greeting',
        interpretationPreferences: appliedPatch,
        interpretationReasonCode: result.reasonCode,
        availabilityProductQuery: result.intent == 'availability'
            ? result.productQueryCandidate
            : null,
      ),
      result: result,
    );
  }

  bool _shouldInterpret(
    AIChatTurnContext incoming,
    AIChatTurnDecision turnDecision,
  ) {
    if (incoming.isGreetingOnly) return false;

    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) return false;

    if (AIChatExperimentConfig.llmLedRouterV2 &&
        _ownershipPolicy.classify(incoming.trimmed).isSemantic) {
      return true;
    }

    if (AvailabilityIntentUtils.looksLikeGenderOnlyPreferenceReply(
          normalized,
        ) ||
        AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(normalized) ||
        AvailabilityIntentUtils.looksLikeGenericRecommendationOrPreferenceCommand(
          normalized,
        ) ||
        AvailabilityIntentUtils.looksLikePersonaOrPreferenceStatement(
          normalized,
        )) {
      return false;
    }

    if (turnDecision.shouldAllowAvailability) {
      return _hasWeakAvailabilityAnchor(incoming.trimmed);
    }

    if (turnDecision.reasonCode == 'reference_cheaper_recommendation') {
      return false;
    }

    if (turnDecision.route == AIChatTurnDecisionRoute.clarify) return true;
    if (turnDecision.reasonCode == 'ambiguous_standalone_latin_phrase') {
      return true;
    }
    if (_hasWeakAvailabilityAnchor(incoming.trimmed)) return true;

    if (incoming.intent == AIChatIntent.compareProducts &&
        _looksLikeFalseCompare(normalized)) {
      return true;
    }

    return _looksLikeInterpretationCandidate(normalized);
  }

  String? _rejectionReason(
    AIChatInterpretationResult result, {
    required AIChatTurnContext incoming,
    required AIChatState state,
    required List<ProductModel> catalog,
  }) {
    if (result.confidence < 0.65) return 'low_confidence';
    if (result.hasForbiddenFields) return 'forbidden_fields';

    if (result.intent == 'availability') {
      final hasAvailabilityKeyword = LocalIntentParser.containsAny(
        LocalIntentParser.normalizeInput(incoming.trimmed),
        AvailabilityIntentUtils.availabilityKeywords,
      );
      final hasPriceKeyword = _looksLikePriceQuestion(incoming.trimmed);
      final query =
          result.productQueryCandidate ??
          AvailabilityIntentUtils.extractAvailabilityProductQuery(
            incoming.trimmed,
          );
      if ((!hasAvailabilityKeyword && !hasPriceKeyword) || query == null) {
        return 'availability_without_local_anchor';
      }
      final queryRejection = _availabilityCandidateRejectionReason(
        query,
        catalog,
      );
      if (queryRejection != null) return queryRejection;
    }

    if (result.intent == 'compare') {
      if (!_hasConcreteCompareAnchor(incoming, state)) {
        return 'compare_without_concrete_anchor';
      }
    }

    final budget = result.preferencePatch.maxBudget;
    if (budget != null && (budget < 100 || budget > 250000)) {
      return 'budget_out_of_bounds';
    }

    if (result.intent == 'off_topic') return 'off_topic';
    if (result.intent == 'unclear' && !result.hasPreferencePatch) {
      return 'unclear_without_patch';
    }

    return null;
  }

  AIChatIntent _effectiveIntent(
    AIChatTurnContext incoming,
    AIChatInterpretationResult result,
  ) {
    switch (result.intent) {
      case 'greeting':
        return AIChatIntent.newRecommendation;
      case 'recommendation':
      case 'modifier':
      case 'answer':
      case 'unclear':
        return AIChatIntent.newRecommendation;
      case 'compare':
        return incoming.intent == AIChatIntent.compareProducts
            ? AIChatIntent.compareProducts
            : AIChatIntent.newRecommendation;
      case 'availability':
        return AIChatIntent.availabilityCheck;
      default:
        return incoming.intent;
    }
  }

  bool _hasWeakAvailabilityAnchor(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (_looksLikeScentStyleRequest(normalized)) return false;
    final hasAvailabilityKeyword = LocalIntentParser.containsAny(
      normalized,
      AvailabilityIntentUtils.availabilityKeywords,
    );
    if (!hasAvailabilityKeyword && !_looksLikePriceQuestion(message)) {
      return false;
    }
    final query = AvailabilityIntentUtils.extractAvailabilityProductQuery(
      message,
    );
    return query == null ||
        AvailabilityIntentUtils.isGenericAvailabilityCandidate(query);
  }

  bool _looksLikeScentStyleRequest(String normalized) {
    return normalized.contains('something like') ||
        normalized.contains('smells like') ||
        normalized.contains('scent like') ||
        normalized.contains('petrichor') ||
        normalized.contains('rain on soil') ||
        normalized.contains('wet soil') ||
        normalized.contains('rain smell') ||
        normalized.contains('smell of rain');
  }

  bool _looksLikePriceQuestion(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    return normalized.contains('price') ||
        normalized.contains('cost') ||
        normalized.contains('how much') ||
        normalized.contains('\u0628\u0643\u0627\u0645') ||
        normalized.contains('\u0628\u0643\u0645') ||
        normalized.contains('\u0643\u0645 \u0633\u0639\u0631') ||
        normalized.contains('\u0643\u0627\u0645 \u0633\u0639\u0631');
  }

  String? _availabilityCandidateRejectionReason(
    String candidate,
    List<ProductModel> catalog,
  ) {
    final normalized = LocalIntentParser.normalizeInput(candidate);
    if (normalized.isEmpty) return 'availability_empty_candidate';
    if (AvailabilityIntentUtils.isGenericAvailabilityCandidate(normalized)) {
      return 'availability_generic_candidate';
    }
    if (AvailabilityIntentUtils.looksLikeGenderOnlyPreferenceReply(
          normalized,
        ) ||
        AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(normalized) ||
        AvailabilityIntentUtils.looksLikeGenericRecommendationOrPreferenceCommand(
          normalized,
        )) {
      return 'availability_blocked_candidate';
    }

    final catalogNormalized = CatalogProductMatcher.normalize(candidate);
    final matchesCatalog = catalog.any(
      (product) => CatalogProductMatcher.queryMentionsProduct(
        catalogNormalized,
        product,
      ),
    );
    if (matchesCatalog) return null;

    if (AvailabilityReferenceProfileRegistry.resolveByMessage(candidate) !=
        null) {
      return null;
    }

    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .toList(growable: false);
    final productShapedLatin =
        tokens.length >= 2 &&
        RegExp(r"^[a-z0-9][a-z0-9 .'-]*$").hasMatch(normalized) &&
        !tokens.every(
          AvailabilityIntentUtils.genericSimilarityFollowUpTokens.contains,
        );
    if (productShapedLatin) return null;

    return 'availability_unanchored_candidate';
  }

  bool _hasConcreteCompareAnchor(
    AIChatTurnContext incoming,
    AIChatState state,
  ) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (RegExp(r'\b[12]\b').hasMatch(normalized) &&
        state.recommendationMemory.lastRecommendedProducts.length >= 2) {
      return true;
    }
    return normalized.contains(' vs ') ||
        normalized.contains(' versus ') ||
        normalized.contains('compare between');
  }

  bool _looksLikeFalseCompare(String normalized) {
    return normalized.contains('للأثنين') ||
        normalized.contains('للاثنين') ||
        normalized.contains('للاتنين') ||
        normalized.contains('للجنسين') ||
        normalized.contains('خليط بين ريحتين') ||
        normalized.contains('خليط بين راحتين') ||
        normalized.contains('خليط بين نوتتين') ||
        normalized.contains('mix of two') ||
        normalized.contains('between two scents');
  }

  bool _looksLikeInterpretationCandidate(String normalized) {
    return normalized.contains('reccomend') ||
        normalized.contains('recomend') ||
        normalized.contains('somthing') ||
        normalized.contains('just suggest') ||
        normalized.contains('no idea') ||
        normalized.contains('ليس عندي فكرة') ||
        normalized.contains('مش عندي فكرة') ||
        normalized.contains('مش عارف') ||
        normalized.contains('للأثنين') ||
        normalized.contains('للاثنين') ||
        normalized.contains('للاتنين') ||
        normalized.contains('للجنسين') ||
        normalized.contains('قوة الرواح') ||
        normalized.contains('قوه الرواح') ||
        normalized.contains('فوحان') ||
        normalized.contains('ثبات') ||
        normalized.contains('خليط بين ريحتين') ||
        normalized.contains('خليط بين راحتين') ||
        normalized.contains('خليط بين نوتتين') ||
        normalized.contains('between two scents') ||
        normalized.contains('mix of two');
  }
}
