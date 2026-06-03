import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';

enum AIChatToolName {
  searchProducts,
  cheapestCatalog,
  mostExpensiveCatalog,
  updatePreferencesAndRecommend,
  answerProductQuestion,
  askProductClarification,
  similarCheaper,
  cheaperFollowup,
  showLowestAvailableAfterBudgetNoMatch,
  rejectVisibleProducts,
  resolvePerfumeReference,
  selectPerfumeReferenceOption,
  lookupExternalPerfumeProfile,
  recommendSimilarToExternalProfile,
  similarCheaperToExternalProfile,
  askClarification,
}

class AIChatToolCall {
  final AIChatToolName name;
  final Map<String, dynamic> arguments;
  final double? confidence;

  const AIChatToolCall({
    required this.name,
    this.arguments = const {},
    this.confidence,
  });

  factory AIChatToolCall.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('missing_tool_call');
    }
    final name = _toolNameFromWire(json['name']);
    if (name == null) {
      throw const FormatException('unknown_tool_name');
    }
    final rawArguments = json['arguments'];
    return AIChatToolCall(
      name: name,
      arguments: rawArguments is Map
          ? rawArguments.map((key, value) => MapEntry(key.toString(), value))
          : const <String, dynamic>{},
      confidence: _confidenceFromWire(json['confidence']),
    );
  }

  PreferencePatch? get preferencePatch {
    if (name != AIChatToolName.updatePreferencesAndRecommend) return null;
    final patchRaw = arguments['preferencePatch'] ?? arguments['patch'];
    if (patchRaw is! Map) return null;
    final patch = PreferencePatch.fromJson(
      patchRaw.map((key, value) => MapEntry(key.toString(), value)),
    );
    return patch.isEmpty ? null : patch;
  }

  static AIChatToolName? _toolNameFromWire(Object? raw) {
    switch (raw?.toString().trim()) {
      case 'search_products':
        return AIChatToolName.searchProducts;
      case 'cheapest_catalog':
      case 'get_cheapest_products':
        return AIChatToolName.cheapestCatalog;
      case 'most_expensive_catalog':
      case 'get_most_expensive_products':
        return AIChatToolName.mostExpensiveCatalog;
      case 'update_preferences_and_recommend':
      case 'update_preferences':
        return AIChatToolName.updatePreferencesAndRecommend;
      case 'answer_product_question':
        return AIChatToolName.answerProductQuestion;
      case 'ask_product_clarification':
        return AIChatToolName.askProductClarification;
      case 'similar_cheaper':
        return AIChatToolName.similarCheaper;
      case 'cheaper_followup':
        return AIChatToolName.cheaperFollowup;
      case 'show_lowest_available_after_budget_no_match':
        return AIChatToolName.showLowestAvailableAfterBudgetNoMatch;
      case 'reject_visible_products':
        return AIChatToolName.rejectVisibleProducts;
      case 'resolve_perfume_reference':
        return AIChatToolName.resolvePerfumeReference;
      case 'select_perfume_reference_option':
        return AIChatToolName.selectPerfumeReferenceOption;
      case 'lookup_external_perfume_profile':
        return AIChatToolName.lookupExternalPerfumeProfile;
      case 'recommend_similar_to_external_profile':
        return AIChatToolName.recommendSimilarToExternalProfile;
      case 'similar_cheaper_to_external_profile':
        return AIChatToolName.similarCheaperToExternalProfile;
      case 'ask_clarification':
        return AIChatToolName.askClarification;
    }
    return null;
  }

  static double? _confidenceFromWire(Object? raw) {
    if (raw is num) return raw.toDouble().clamp(0, 1);
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed == null) return null;
      return parsed.clamp(0, 1);
    }
    return null;
  }
}
