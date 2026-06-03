import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_product_matcher.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

enum AIChatDeterministicGateResult {
  localSafe,
  needsClarification,
  needsLlm,
  blocked,
}

enum AIChatDeterministicGateProofLevel { deterministic, insufficient, blocked }

class AIChatDeterministicGateDecision {
  const AIChatDeterministicGateDecision({
    required this.result,
    required this.route,
    required this.wouldSendToLlm,
    required this.shouldRenderCards,
    required this.proofLevel,
    this.proofReasons = const <String>[],
    this.ambiguityReasons = const <String>[],
  });

  final AIChatDeterministicGateResult result;
  final String route;
  final bool wouldSendToLlm;
  final bool shouldRenderCards;
  final AIChatDeterministicGateProofLevel proofLevel;
  final List<String> proofReasons;
  final List<String> ambiguityReasons;

  bool get isLocalSafe => result == AIChatDeterministicGateResult.localSafe;
}

class AIChatDeterministicGate {
  const AIChatDeterministicGate();

  AIChatDeterministicGateDecision evaluate({
    required String message,
    required AIChatLanguage language,
    required List<ProductModel> catalog,
    required RecommendationMemory memory,
  }) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) {
      return _needsClarification(
        route: 'empty_message',
        proofReasons: const ['empty_message'],
      );
    }

    if (LocalIntentParser.looksLikeOutOfDomainRequest(
      normalized,
      currentPreferences: const SessionPreferences(),
    )) {
      return const AIChatDeterministicGateDecision(
        result: AIChatDeterministicGateResult.blocked,
        route: 'out_of_domain',
        wouldSendToLlm: false,
        shouldRenderCards: false,
        proofLevel: AIChatDeterministicGateProofLevel.blocked,
        proofReasons: ['out_of_domain_non_perfume_request'],
      );
    }

    final pending = memory.pendingPerfumeReferenceClarification;
    if (pending != null) {
      if (_matchesPendingClarificationOption(normalized, pending)) {
        return _localSafe(
          route: 'pending_clarification_selection',
          proofReasons: const [
            'pending_clarification_context',
            'deterministic_option_selection',
          ],
          shouldRenderCards: false,
        );
      }
      return _needsClarification(
        route: 'pending_clarification_selection',
        proofReasons: const ['pending_clarification_context'],
        ambiguityReasons: const ['selection_not_clear'],
      );
    }

    if (_looksLikeAmbiguousEgyptianSweet(message)) {
      return _needsClarification(
        route: 'ambiguous_egyptian_sweet',
        proofReasons: const ['egyptian_sweet_phrase'],
        ambiguityReasons: const ['sweet_vs_beautiful_meaning'],
      );
    }

    if (_looksLikeExactBusinessInfo(normalized)) {
      return _localSafe(
        route: 'exact_business_info',
        proofReasons: const ['business_info_keyword'],
        shouldRenderCards: false,
      );
    }

    final visibleDecision = _evaluateVisibleProductsQuestion(
      normalized,
      memory,
    );
    if (visibleDecision != null) return visibleDecision;

    if (_looksLikeRelativeRecommendationFollowUp(normalized)) {
      return const AIChatDeterministicGateDecision(
        result: AIChatDeterministicGateResult.needsLlm,
        route: 'needs_llm',
        wouldSendToLlm: true,
        shouldRenderCards: false,
        proofLevel: AIChatDeterministicGateProofLevel.insufficient,
        ambiguityReasons: ['relative_recommendation_followup'],
      );
    }

    if (_looksLikeDirectCatalogQuery(normalized)) {
      return _localSafe(
        route: 'direct_catalog_query',
        proofReasons: const ['direct_catalog_query'],
        shouldRenderCards: true,
      );
    }

    final availabilityQuery =
        AvailabilityIntentUtils.extractAvailabilityProductQuery(message);
    if (availabilityQuery != null &&
        _hasAvailabilityCue(normalized) &&
        _exactCatalogMatches(availabilityQuery, catalog).length == 1) {
      return _localSafe(
        route: 'exact_catalog_availability',
        proofReasons: const [
          'availability_phrase',
          'single_exact_catalog_match',
        ],
        shouldRenderCards: true,
      );
    }

    final exactMentionMatches = _exactCatalogMatches(message, catalog);
    if (exactMentionMatches.length == 1 &&
        _looksLikeExplicitProductContextQuestion(normalized)) {
      return _localSafe(
        route: 'exact_product_context',
        proofReasons: const [
          'explicit_product_mention',
          'product_context_question',
        ],
        shouldRenderCards: false,
      );
    }

    final looseMatches = _looseShortReferenceMatches(message, catalog);
    if (looseMatches.length > 1) {
      return _needsClarification(
        route: 'ambiguous_product_reference',
        proofReasons: const ['multiple_catalog_reference_matches'],
        ambiguityReasons: const ['ambiguous_product_reference'],
      );
    }

    return const AIChatDeterministicGateDecision(
      result: AIChatDeterministicGateResult.needsLlm,
      route: 'needs_llm',
      wouldSendToLlm: true,
      shouldRenderCards: false,
      proofLevel: AIChatDeterministicGateProofLevel.insufficient,
      ambiguityReasons: ['natural_language_or_insufficient_proof'],
    );
  }

  AIChatDeterministicGateDecision? _evaluateVisibleProductsQuestion(
    String normalized,
    RecommendationMemory memory,
  ) {
    final refs = memory.lastRecommendedProducts;
    if (refs.isEmpty) return null;

    final hasOrdinal = _hasVisibleOrdinalSelection(normalized);
    if (hasOrdinal) {
      return _localSafe(
        route: 'deterministic_visible_product_question',
        proofReasons: const ['visible_products_context', 'ordinal_selection'],
        shouldRenderCards: false,
      );
    }

    if (refs.length < 2 || !_referencesVisibleOptions(normalized)) return null;

    if (_hasVisiblePriceProperty(normalized)) {
      return _localSafe(
        route: 'deterministic_visible_product_question',
        proofReasons: const [
          'visible_products_context',
          'deterministic_price_property',
        ],
        shouldRenderCards: false,
      );
    }

    if (_looksLikeSubjectiveVisibleQuestion(normalized)) {
      return const AIChatDeterministicGateDecision(
        result: AIChatDeterministicGateResult.needsLlm,
        route: 'needs_llm',
        wouldSendToLlm: true,
        shouldRenderCards: false,
        proofLevel: AIChatDeterministicGateProofLevel.insufficient,
        ambiguityReasons: ['subjective_visible_product_question'],
      );
    }

    return null;
  }

  bool _matchesPendingClarificationOption(
    String normalized,
    PendingPerfumeReferenceClarification pending,
  ) {
    final trimmed = normalized.trim();
    final index = int.tryParse(trimmed);
    if (index != null) {
      return pending.options.any((option) => option.index == index);
    }
    if (RegExp(r'\b(first|second|third)\b').hasMatch(trimmed)) return true;
    if (trimmed.contains('\u0627\u0644\u0627\u0648\u0644') ||
        trimmed.contains('\u0627\u0644\u0623\u0648\u0644') ||
        trimmed.contains('\u0627\u0644\u062a\u0627\u0646\u064a') ||
        trimmed.contains('\u0627\u0644\u062b\u0627\u0646\u064a')) {
      return true;
    }
    return pending.options.any((option) {
      final name = CatalogProductMatcher.normalize(option.name);
      return name.isNotEmpty && name.contains(trimmed) && trimmed.length >= 3;
    });
  }

  bool _looksLikeAmbiguousEgyptianSweet(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    return normalized.contains('\u0631\u064a\u062d') &&
        normalized.contains('\u062d\u0644\u0648') &&
        !_hasExplicitSweetMeaning(normalized) &&
        (normalized.contains('\u0631\u0634\u062d') ||
            normalized.contains('recommend') ||
            normalized.contains('suggest'));
  }

  bool _hasExplicitSweetMeaning(String normalized) {
    return normalized.contains('\u0645\u0633\u0643\u0631') ||
        normalized.contains('\u0633\u0643\u0631') ||
        normalized.contains('\u0641\u0627\u0646\u064a\u0644\u064a\u0627') ||
        normalized.contains('\u062d\u0644\u0648\u0629 \u0627\u0648\u064a') ||
        normalized.contains('\u062d\u0644\u0648\u0647 \u0627\u0648\u064a') ||
        RegExp(r'\b(sweet|sugary|vanilla)\b').hasMatch(normalized);
  }

  bool _looksLikeExactBusinessInfo(String normalized) {
    return normalized.contains('payment') ||
        normalized.contains('delivery') ||
        normalized.contains('contact') ||
        normalized.contains('\u0627\u0644\u062f\u0641\u0639') ||
        normalized.contains('\u0627\u0644\u062a\u0648\u0635\u064a\u0644') ||
        normalized.contains('\u0627\u0644\u062a\u0648\u0627\u0635\u0644');
  }

  bool _looksLikeDirectCatalogQuery(String normalized) {
    return LocalIntentParser.looksLikeRankingRequest(normalized) ||
        AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(normalized);
  }

  bool _looksLikeRelativeRecommendationFollowUp(String normalized) {
    if (normalized.contains('cheapest') ||
        normalized.contains('lowest price') ||
        normalized.contains('most expensive') ||
        normalized.contains('highest price')) {
      return false;
    }
    final hasRelativePrice =
        normalized.contains('cheaper') ||
        normalized.contains('less expensive') ||
        normalized.contains('\u0627\u0631\u062e\u0635') ||
        normalized.contains('\u0623\u0631\u062e\u0635');
    final hasContextAnchor =
        normalized.contains('similar') ||
        normalized.contains('like it') ||
        normalized.contains('than it') ||
        normalized.contains('something') ||
        normalized.contains('anything') ||
        normalized.contains('option') ||
        normalized.contains('alternative') ||
        normalized.contains('\u0634\u0628\u0647') ||
        normalized.contains('\u0632\u064a\u0647') ||
        normalized.contains('\u0628\u062f\u064a\u0644');
    return hasRelativePrice && hasContextAnchor;
  }

  bool _hasAvailabilityCue(String normalized) {
    return normalized.contains('do you have') ||
        normalized.contains('available') ||
        normalized.contains('in stock') ||
        normalized.contains('\u0639\u0646\u062f\u0643') ||
        normalized.contains('\u0645\u062a\u0648\u0641\u0631') ||
        normalized.contains('\u0645\u0648\u062c\u0648\u062f');
  }

  bool _looksLikeExplicitProductContextQuestion(String normalized) {
    return normalized.contains('suitable') ||
        normalized.contains('better for') ||
        normalized.contains('price') ||
        normalized.contains('work') ||
        normalized.contains('office') ||
        normalized.contains('\u064a\u0646\u0641\u0639') ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628') ||
        normalized.contains('\u0628\u0643\u0627\u0645') ||
        normalized.contains('\u0628\u0643\u0645');
  }

  List<ProductModel> _exactCatalogMatches(
    String query,
    List<ProductModel> catalog,
  ) {
    final normalized = CatalogProductMatcher.normalize(query);
    if (normalized.isEmpty) return const <ProductModel>[];
    return catalog
        .where((product) {
          final names =
              <String>{
                    product.name,
                    product.nameAr,
                    ...product.aliases,
                    ...product.aliasesAr,
                  }
                  .map(CatalogProductMatcher.normalize)
                  .where((item) => item.isNotEmpty);
          return names.any((name) => name == normalized);
        })
        .toList(growable: false);
  }

  List<ProductModel> _looseShortReferenceMatches(
    String query,
    List<ProductModel> catalog,
  ) {
    final normalized = CatalogProductMatcher.normalize(query);
    if (normalized.length < 3) return const <ProductModel>[];
    final tokens = normalized.split(RegExp(r'\s+'));
    if (tokens.length > 2) return const <ProductModel>[];
    if (_hasAvailabilityCue(normalized) ||
        _looksLikeDirectCatalogQuery(normalized) ||
        _looksLikeExactBusinessInfo(normalized)) {
      return const <ProductModel>[];
    }
    return catalog
        .where((product) {
          final searchable = <String>{
            product.name,
            product.nameAr,
            product.brand,
            product.brandAr,
            ...product.aliases,
            ...product.aliasesAr,
          }.map(CatalogProductMatcher.normalize).join(' ');
          return RegExp(
            '(^| )${RegExp.escape(normalized)}( |\\\$)',
          ).hasMatch(searchable);
        })
        .toList(growable: false);
  }

  bool _referencesVisibleOptions(String normalized) {
    return RegExp(
          r'\b(them|these|those|among|between|options?|recommendations?|one|ones?)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u0641\u064a\u0647\u0645') ||
        normalized.contains('\u0628\u064a\u0646\u0647\u0645') ||
        normalized.contains('\u062f\u0648\u0644') ||
        normalized.contains('\u0647\u0645');
  }

  bool _hasVisiblePriceProperty(String normalized) {
    return normalized.contains('cheapest') ||
        normalized.contains('lowest price') ||
        normalized.contains('most expensive') ||
        normalized.contains('highest price') ||
        normalized.contains('price') ||
        normalized.contains('\u0627\u0631\u062e\u0635') ||
        normalized.contains('\u0623\u0631\u062e\u0635') ||
        normalized.contains('\u0627\u063a\u0644\u0649') ||
        normalized.contains('\u0623\u063a\u0644\u0649') ||
        normalized.contains('\u0627\u0644\u0633\u0639\u0631');
  }

  bool _hasVisibleOrdinalSelection(String normalized) {
    return RegExp(r'\b(first|second|third|1|2|3)\b').hasMatch(normalized) ||
        normalized.contains('\u0627\u0644\u0627\u0648\u0644') ||
        normalized.contains('\u0627\u0644\u0623\u0648\u0644') ||
        normalized.contains('\u0627\u0644\u062a\u0627\u0646\u064a') ||
        normalized.contains('\u0627\u0644\u062b\u0627\u0646\u064a') ||
        normalized.contains('\u0627\u0644\u062b\u0627\u0644\u062b');
  }

  bool _looksLikeSubjectiveVisibleQuestion(String normalized) {
    return normalized.contains('better') ||
        normalized.contains('best') ||
        normalized.contains('suits me') ||
        normalized.contains('\u0627\u062d\u0633\u0646') ||
        normalized.contains('\u0623\u062d\u0633\u0646') ||
        normalized.contains('\u0627\u0641\u0636\u0644') ||
        normalized.contains('\u0623\u0641\u0636\u0644');
  }

  AIChatDeterministicGateDecision _localSafe({
    required String route,
    required List<String> proofReasons,
    required bool shouldRenderCards,
  }) {
    return AIChatDeterministicGateDecision(
      result: AIChatDeterministicGateResult.localSafe,
      route: route,
      wouldSendToLlm: false,
      shouldRenderCards: shouldRenderCards,
      proofLevel: AIChatDeterministicGateProofLevel.deterministic,
      proofReasons: proofReasons,
    );
  }

  AIChatDeterministicGateDecision _needsClarification({
    required String route,
    required List<String> proofReasons,
    List<String> ambiguityReasons = const <String>[],
  }) {
    return AIChatDeterministicGateDecision(
      result: AIChatDeterministicGateResult.needsClarification,
      route: route,
      wouldSendToLlm: false,
      shouldRenderCards: false,
      proofLevel: AIChatDeterministicGateProofLevel.deterministic,
      proofReasons: proofReasons,
      ambiguityReasons: ambiguityReasons,
    );
  }
}
