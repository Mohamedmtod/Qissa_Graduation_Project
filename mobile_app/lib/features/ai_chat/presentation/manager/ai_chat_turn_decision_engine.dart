import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_route_ownership_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_followup_detector.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_product_matcher.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser_keywords.dart'
    as parser_keywords;
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AIChatTurnDecisionEngine {
  const AIChatTurnDecisionEngine();

  static const AIChatRouteOwnershipPolicy _ownershipPolicy =
      AIChatRouteOwnershipPolicy();

  AIChatTurnDecision decide({
    required AIChatTurnContext incoming,
    required AIChatState state,
    required List<ProductModel> catalog,
    required bool Function(String message, AIChatIntent intent)
    shouldContinueAvailabilityClarification,
  }) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    final hasAvailabilityKeyword = LocalIntentParser.containsAny(
      normalized,
      AvailabilityIntentUtils.availabilityKeywords,
    );
    final ownershipDecision = AIChatExperimentConfig.llmLedRouterV2
        ? _ownershipPolicy.classify(incoming.trimmed)
        : null;

    if (normalized.isEmpty) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.clarify,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'empty_message',
        shouldAllowAvailability: false,
      );
    }

    if (incoming.isGreetingOnly ||
        LocalIntentParser.isGreetingOnly(normalized)) {
      if (AIChatExperimentConfig.llmLedRouterV2) {
        return const AIChatTurnDecision(
          route: AIChatTurnDecisionRoute.greeting,
          confidence: AIChatTurnDecisionConfidence.high,
          reasonCode: 'llm_led_router_v2_social',
          shouldAllowAvailability: false,
          decisionOwner: 'llmSemantic',
          ownershipClass: 'llmSemantic',
          semanticIntent: 'social',
          localSkippedReason: 'social_turn_requires_conversation_owner',
          llmEscalationReason: 'social_language',
        );
      }
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.greeting,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'greeting_only',
        shouldAllowAvailability: false,
      );
    }

    if (ownershipDecision?.semanticIntent ==
        AIChatSemanticIntent.subjectiveVisibleQuestion) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.recommendation,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode:
            'llm_led_router_v2_${ownershipDecision!.semanticIntent!.name}',
        shouldAllowAvailability: false,
        decisionOwner: ownershipDecision.ownershipClass.name,
        ownershipClass: ownershipDecision.ownershipClass.name,
        semanticIntent: ownershipDecision.semanticIntent!.name,
        localSkippedReason: ownershipDecision.localSkippedReason,
        llmEscalationReason: ownershipDecision.llmRouteReason,
      );
    }

    if (incoming.intent == AIChatIntent.compareProducts ||
        incoming.intent == AIChatIntent.summary) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.recommendation,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'non_availability_intent_${incoming.intent.name}',
        shouldAllowAvailability: false,
      );
    }

    final catalogProductQuery = _catalogBackedProductQuery(
      incoming.trimmed,
      catalog,
    );
    final isStandaloneLatin =
        AvailabilityIntentUtils.looksLikeLatinStandaloneName(incoming.trimmed);
    final looksStandaloneProductTitle =
        isStandaloneLatin && _looksLikeStandaloneProductTitle(incoming.trimmed);

    if (_looksLikeReferenceCheaperRecommendation(incoming.trimmed)) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.recommendation,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'reference_cheaper_recommendation',
        shouldAllowAvailability: false,
      );
    }

    if (catalogProductQuery != null &&
        !_looksLikeProductContextQuestion(normalized) &&
        (hasAvailabilityKeyword ||
            _looksLikePriceQuestion(
              CatalogProductMatcher.normalize(incoming.trimmed),
            ))) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'catalog_backed_product_query',
        productQuery: catalogProductQuery,
        shouldAllowAvailability: true,
      );
    }

    if (catalogProductQuery != null &&
        isStandaloneLatin &&
        !_looksLikeProductContextQuestion(normalized)) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'catalog_backed_standalone_product',
        productQuery: catalogProductQuery,
        shouldAllowAvailability: true,
      );
    }

    if (AIChatExperimentConfig.llmLedRouterV2 &&
        looksStandaloneProductTitle &&
        !_looksLikeProductContextQuestion(normalized)) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.medium,
        reasonCode: 'product_shaped_standalone_name',
        productQuery: LocalIntentParser.normalizeInput(incoming.trimmed),
        shouldAllowAvailability: true,
      );
    }

    if (LocalIntentParser.looksLikeOutOfDomainRequest(
      normalized,
      currentPreferences: state.preferences,
    )) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.offTopic,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'out_of_domain_non_perfume_request',
        shouldAllowAvailability: false,
      );
    }

    if (ownershipDecision?.semanticIntent == AIChatSemanticIntent.social) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.greeting,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode:
            'llm_led_router_v2_${ownershipDecision!.semanticIntent!.name}',
        shouldAllowAvailability: false,
        decisionOwner: ownershipDecision.ownershipClass.name,
        ownershipClass: ownershipDecision.ownershipClass.name,
        semanticIntent: ownershipDecision.semanticIntent!.name,
        localSkippedReason: ownershipDecision.localSkippedReason,
        llmEscalationReason: ownershipDecision.llmRouteReason,
      );
    }

    if (ownershipDecision?.isSemantic ?? false) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.recommendation,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode:
            'llm_led_router_v2_${ownershipDecision!.semanticIntent!.name}',
        shouldAllowAvailability: false,
        decisionOwner: ownershipDecision.ownershipClass.name,
        ownershipClass: ownershipDecision.ownershipClass.name,
        semanticIntent: ownershipDecision.semanticIntent!.name,
        localSkippedReason: ownershipDecision.localSkippedReason,
        llmEscalationReason: ownershipDecision.llmRouteReason,
      );
    }

    if (incoming.shouldContinueAvailabilityClarification ||
        shouldContinueAvailabilityClarification(
          incoming.trimmed,
          AIChatIntent.newRecommendation,
        )) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availabilityFollowUp,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'availability_clarification_context',
        shouldAllowAvailability: true,
      );
    }

    final redirectedProduct =
        AvailabilityIntentUtils.extractRedirectedProductQuery(
          incoming.trimmed,
          hasRecommendationContext: incoming
              .effectiveRecommendationMemory
              .lastRecommendedProducts
              .isNotEmpty,
        );
    if (redirectedProduct != null) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'redirected_product_request_after_rejection',
        productQuery: redirectedProduct,
        shouldAllowAvailability: true,
      );
    }

    final extractedProduct =
        incoming.availabilityProductQuery ??
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          incoming.trimmed,
        );
    final directAvailabilityProduct = _extractDirectAvailabilityProductQuery(
      incoming.trimmed,
    );
    final questionShapedProduct =
        AvailabilityIntentUtils.extractQuestionShapedLatinProductQuery(
          incoming.trimmed,
        );
    if (incoming.availabilityProductQuery != null) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'interpretation_availability_confirmed',
        productQuery: incoming.availabilityProductQuery,
        shouldAllowAvailability: true,
      );
    }
    if (hasAvailabilityKeyword && extractedProduct != null) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'explicit_availability_keyword_product',
        productQuery: extractedProduct,
        shouldAllowAvailability: true,
      );
    }
    if (directAvailabilityProduct != null) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'direct_availability_product_query',
        productQuery: directAvailabilityProduct,
        shouldAllowAvailability: true,
      );
    }
    if (questionShapedProduct != null &&
        _hasAvailabilityOrPriceAnchor(normalized)) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'question_shaped_product_lookup',
        productQuery: questionShapedProduct,
        shouldAllowAvailability: true,
      );
    }

    final followUpSignal = analyzeAvailabilityFollowUpSignal(incoming.trimmed);
    if (state.availabilityContext.hasContext &&
        !followUpSignal.hasExplicitAvailabilityProduct &&
        (incoming.intent == AIChatIntent.followUpProduct ||
            looksLikeAvailabilityFollowUp(incoming.trimmed) ||
            looksLikeContextualAvailabilityFollowUp(incoming.trimmed))) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availabilityFollowUp,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'availability_follow_up_context',
        shouldAllowAvailability: true,
      );
    }

    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.recommendation,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'recommendation_continuation_command',
        shouldAllowAvailability: false,
      );
    }

    if (AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(normalized)) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.localCommand,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'catalog_browse_request',
        shouldAllowAvailability: false,
      );
    }

    if (AvailabilityIntentUtils.looksLikeGenericRecommendationOrPreferenceCommand(
      normalized,
    )) {
      final route =
          LocalIntentParser.detectModifierPatch(incoming.trimmed) != null
          ? AIChatTurnDecisionRoute.modifier
          : AIChatTurnDecisionRoute.localCommand;
      return AIChatTurnDecision(
        route: route,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: route == AIChatTurnDecisionRoute.modifier
            ? 'preference_modifier_command'
            : 'generic_local_command',
        shouldAllowAvailability: false,
      );
    }

    if (AvailabilityIntentUtils.looksLikePersonaOrPreferenceStatement(
      normalized,
    )) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.recommendation,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'persona_or_preference_statement',
        shouldAllowAvailability: false,
      );
    }

    if (catalogProductQuery != null &&
        (hasAvailabilityKeyword ||
            _looksLikePriceQuestion(
              CatalogProductMatcher.normalize(incoming.trimmed),
            ))) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'catalog_backed_product_query',
        productQuery: catalogProductQuery,
        shouldAllowAvailability: true,
      );
    }

    if (catalogProductQuery != null && isStandaloneLatin) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'catalog_backed_standalone_product',
        productQuery: catalogProductQuery,
        shouldAllowAvailability: true,
      );
    }
    final parsedFresh = LocalIntentParser.parse(
      incoming.trimmed,
      SessionPreferences.empty(),
    );
    if (!hasAvailabilityKeyword &&
        _hasPreferenceSignal(parsedFresh, incoming.trimmed) &&
        !(looksStandaloneProductTitle && parsedFresh.maxBudget == null)) {
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.recommendation,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'fresh_preference_signal',
        shouldAllowAvailability: false,
      );
    }

    if (isStandaloneLatin) {
      if (looksStandaloneProductTitle) {
        return AIChatTurnDecision(
          route: AIChatTurnDecisionRoute.availability,
          confidence: AIChatTurnDecisionConfidence.medium,
          reasonCode: 'product_shaped_standalone_name',
          productQuery: LocalIntentParser.normalizeInput(incoming.trimmed),
          shouldAllowAvailability: true,
        );
      }
      return const AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.clarify,
        confidence: AIChatTurnDecisionConfidence.medium,
        reasonCode: 'ambiguous_standalone_latin_phrase',
        shouldAllowAvailability: false,
      );
    }

    if (incoming.intent == AIChatIntent.availabilityCheck &&
        hasAvailabilityKeyword &&
        extractedProduct != null) {
      return AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.availability,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: 'availability_intent_with_product',
        productQuery: extractedProduct,
        shouldAllowAvailability: true,
      );
    }

    return const AIChatTurnDecision(
      route: AIChatTurnDecisionRoute.recommendation,
      confidence: AIChatTurnDecisionConfidence.medium,
      reasonCode: 'default_recommendation_flow',
      shouldAllowAvailability: false,
    );
  }

  bool _hasPreferenceSignal(SessionPreferences prefs, String message) {
    if (prefs.activeCriteriaCount > 0 ||
        prefs.hasAnyNoteSignal ||
        prefs.tags.isNotEmpty ||
        prefs.intensity != null) {
      return true;
    }
    final normalized = LocalIntentParser.normalizeInput(message);
    return normalized.contains('daily use') ||
        normalized.contains('university') ||
        normalized.contains('office') ||
        normalized.contains('gym');
  }

  String? _catalogBackedProductQuery(
    String message,
    List<ProductModel> catalog,
  ) {
    final normalized = CatalogProductMatcher.normalize(message);
    for (final product in catalog) {
      if (CatalogProductMatcher.queryMentionsProduct(normalized, product)) {
        return product.name;
      }
    }
    return null;
  }

  bool _looksLikePriceQuestion(String normalized) {
    return RegExp(r'\b(price|cost|how much)\b').hasMatch(normalized) ||
        normalized.contains('\u0633\u0639\u0631') ||
        normalized.contains('\u0628\u0643\u0627\u0645') ||
        normalized.contains('\u0628\u0643\u0645') ||
        normalized.contains('\u0643\u0627\u0645') ||
        normalized.contains('\u0643\u0645 ');
  }

  bool _looksLikeProductContextQuestion(String normalized) {
    return normalized.contains('why') ||
        normalized.contains('details') ||
        normalized.contains('tell me more') ||
        normalized.contains('good for') ||
        normalized.contains('suitable') ||
        normalized.contains('fit for') ||
        normalized.contains('fits for') ||
        normalized.contains('work for') ||
        normalized.contains('works for') ||
        normalized.contains('\u0644\u064a\u0647') ||
        normalized.contains('\u062a\u0641\u0627\u0635\u064a\u0644') ||
        normalized.contains('\u064a\u0646\u0641\u0639') ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628');
  }

  bool _hasAvailabilityOrPriceAnchor(String normalized) {
    return LocalIntentParser.containsAny(
          normalized,
          AvailabilityIntentUtils.availabilityKeywords,
        ) ||
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0628\u0631\u0641\u0627\u0646') ||
        _looksLikePriceQuestion(normalized);
  }

  bool _looksLikeReferenceCheaperRecommendation(String message) {
    final signal = analyzeAvailabilityFollowUpSignal(message);
    return signal.hasSimilarityTerm && signal.hasCheaperTerm;
  }

  String? _extractDirectAvailabilityProductQuery(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return null;
    if (LocalIntentParser.looksLikeRankingRequest(normalized)) {
      return null;
    }
    if (AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(normalized)) {
      return null;
    }

    final hasDirectAvailabilitySignal =
        normalized.contains('do you have') ||
        normalized.contains('in stock') ||
        normalized.contains('sku') ||
        normalized.contains('\u0639\u0646\u062f\u0643\u0645') ||
        normalized.contains('\u0639\u0646\u062f\u0643') ||
        normalized.contains('\u0645\u062a\u0648\u0641\u0631') ||
        normalized.contains('\u0645\u0648\u062c\u0648\u062f');
    if (!hasDirectAvailabilitySignal) return null;
    if (AvailabilityIntentUtils.looksLikeGenericRecommendationOrPreferenceCommand(
      normalized,
    )) {
      return null;
    }
    if (LocalIntentParser.containsAny(
          normalized,
          parser_keywords.premiumKeywords,
        ) ||
        LocalIntentParser.containsAny(
          normalized,
          LocalIntentParser.cheapKeywords,
        )) {
      return null;
    }

    var candidate = normalized
        .replaceAll(RegExp(r'[?\u061F]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final stopPhrases = <String>[
      'do you have',
      'in stock',
      'available',
      'perfume',
      'fragrance',
      '\u0639\u0646\u062f\u0643\u0645',
      '\u0639\u0646\u062f\u0643',
      '\u0639\u0637\u0631',
      '\u0628\u0631\u0641\u0627\u0646',
      '\u0627\u0644\u062c\u062f\u064a\u062f',
      '\u062c\u062f\u064a\u062f',
      '\u0645\u062a\u0648\u0641\u0631',
      '\u0645\u0648\u062c\u0648\u062f',
    ];
    for (final phrase in stopPhrases) {
      candidate = candidate.replaceAll(
        RegExp(RegExp.escape(phrase), caseSensitive: false),
        ' ',
      );
    }
    candidate = _trimAvailabilityIntentBoundary(candidate);
    candidate = candidate.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (candidate.length < 3) return null;
    return candidate;
  }

  String _trimAvailabilityIntentBoundary(String value) {
    final padded = ' ${value.trim()} ';
    final boundaries = <String>[
      ' if not ',
      ' if available ',
      ' and compare ',
      ' compare ',
      ' and recommend ',
      ' recommend ',
      ' \u0648\u0644\u0648 ',
      ' \u0644\u0648 ',
      ' \u0642\u0627\u0631\u0646 ',
      ' \u0648\u0642\u0627\u0631\u0646 ',
      ' \u0631\u0634\u062d ',
      ' \u0648\u0631\u0634\u062d ',
    ];
    var bestIndex = -1;
    for (final boundary in boundaries) {
      final index = padded.indexOf(boundary);
      if (index > 0 && (bestIndex == -1 || index < bestIndex)) {
        bestIndex = index;
      }
    }
    if (bestIndex == -1) return value.trim();
    return padded.substring(1, bestIndex).trim();
  }

  bool _looksLikeStandaloneProductTitle(String message) {
    final cleaned = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length < 5 || cleaned.length > 70) return false;
    if (!RegExp(r"^[A-Za-z0-9][A-Za-z0-9 .'-]*$").hasMatch(cleaned)) {
      return false;
    }
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.length < 2 || tokens.length > 5) return false;
    const connectorTokens = {'de', 'du', 'le', 'la', 'el', 'of', 'the'};
    var strongTitleTokens = 0;
    for (final token in tokens) {
      final lower = token.toLowerCase();
      if (connectorTokens.contains(lower)) continue;
      final startsTitleCase = RegExp(r'^[A-Z][a-z0-9]').hasMatch(token);
      if (!startsTitleCase) return false;
      if (token.length >= 4) strongTitleTokens++;
    }
    return strongTitleTokens >= 1;
  }
}
