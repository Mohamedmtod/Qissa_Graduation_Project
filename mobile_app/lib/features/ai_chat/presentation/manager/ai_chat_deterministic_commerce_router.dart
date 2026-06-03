import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

class AIChatDeterministicCommerceRoute {
  final AIChatToolName toolName;
  final Map<String, dynamic> arguments;
  final String reasonCode;

  const AIChatDeterministicCommerceRoute({
    required this.toolName,
    required this.reasonCode,
    this.arguments = const <String, dynamic>{},
  });
}

class AIChatDeterministicCommerceRouter {
  const AIChatDeterministicCommerceRouter();

  AIChatDeterministicCommerceRoute? resolve({
    required String message,
    required RecommendationMemory memory,
  }) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return null;

    if (_looksLikeBudgetFloorAcceptance(normalized, memory)) {
      return const AIChatDeterministicCommerceRoute(
        toolName: AIChatToolName.showLowestAvailableAfterBudgetNoMatch,
        reasonCode: 'budget_floor_acceptance_followup',
      );
    }

    if (_looksLikeVisibleRejection(normalized) &&
        memory.lastRecommendedProducts.isNotEmpty) {
      return AIChatDeterministicCommerceRoute(
        toolName: AIChatToolName.rejectVisibleProducts,
        reasonCode: 'reject_visible_products_followup',
        arguments: {
          'rejectedProductIds': memory.lastRecommendedProducts
              .map((item) => item.productId)
              .toList(growable: false),
        },
      );
    }

    if (_looksLikeSimilarCheaperFollowUp(normalized, memory)) {
      return const AIChatDeterministicCommerceRoute(
        toolName: AIChatToolName.similarCheaper,
        reasonCode: 'similar_cheaper_followup',
      );
    }

    if (_looksLikeExternalProfileCheaperFollowUp(normalized, memory)) {
      return AIChatDeterministicCommerceRoute(
        toolName: AIChatToolName.similarCheaperToExternalProfile,
        reasonCode: 'external_profile_cheaper_followup',
        arguments: {'externalProfileId': memory.lastExternalProfile!.id},
      );
    }

    if (_looksLikeCheaperFollowUp(normalized, memory)) {
      return const AIChatDeterministicCommerceRoute(
        toolName: AIChatToolName.cheaperFollowup,
        reasonCode: 'cheaper_followup',
      );
    }

    return null;
  }

  bool _looksLikeBudgetFloorAcceptance(
    String normalized,
    RecommendationMemory memory,
  ) {
    if (memory.lastNoMatchContext?.reason != 'budget_no_match') return false;
    return normalized.contains('show me it') ||
        normalized.contains('show it') ||
        normalized.contains('show me the available') ||
        normalized.contains('available one') ||
        RegExp(
          r'\b(ok|okay|yes|fine|sure)\b.*\b(show|available|it)\b',
        ).hasMatch(normalized);
  }

  bool _looksLikeVisibleRejection(String normalized) {
    return RegExp(
          r"\b(i don'?t like|dont like|not these|change these|other options|different options|show me others|try others)\b",
        ).hasMatch(normalized) ||
        normalized.contains('\u0645\u0634 \u0639\u0627\u062c\u0628') ||
        normalized.contains('\u063a\u064a\u0631\u0647\u0645');
  }

  bool _looksLikeSimilarCheaperFollowUp(
    String normalized,
    RecommendationMemory memory,
  ) {
    if (memory.lastFocusedProductId == null &&
        memory.lastRecommendedProducts.isEmpty) {
      return false;
    }
    return normalized.contains('similar but cheaper') ||
        normalized.contains('something similar but cheaper') ||
        normalized.contains('like it but cheaper') ||
        normalized.contains('like this but cheaper') ||
        (normalized.contains('\u0634\u0628\u0647') &&
            normalized.contains('\u0627\u0631\u062e\u0635'));
  }

  bool _looksLikeCheaperFollowUp(
    String normalized,
    RecommendationMemory memory,
  ) {
    if (memory.lastFocusedProductId == null &&
        memory.lastRecommendedProducts.isEmpty) {
      return false;
    }
    return normalized.contains('anything cheaper') ||
        (memory.lastFocusedProductId != null &&
            normalized.contains('cheaper than it')) ||
        normalized.contains('cheaper one') ||
        normalized.contains('less expensive') ||
        RegExp(
          r'\b(any|something|show me).*\bcheaper\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u0627\u0631\u062e\u0635') ||
        normalized.contains('\u0623\u0631\u062e\u0635');
  }

  bool _looksLikeExternalProfileCheaperFollowUp(
    String normalized,
    RecommendationMemory memory,
  ) {
    if (memory.lastExternalProfile == null) return false;
    return normalized.contains('cheaper than it') ||
        normalized.contains('cheaper than this') ||
        normalized.contains('cheaper than that') ||
        normalized.contains('\u0627\u0631\u062e\u0635 \u0645\u0646\u0647') ||
        normalized.contains('\u0623\u0631\u062e\u0635 \u0645\u0646\u0647');
  }
}
