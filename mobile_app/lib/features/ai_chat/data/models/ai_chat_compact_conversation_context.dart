import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

class AIChatCompactMessage {
  final String role;
  final String text;

  const AIChatCompactMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() {
    return {'role': role, 'text': text};
  }
}

class AIChatCompactProduct {
  final int index;
  final String id;
  final String name;
  final String brand;
  final double price;
  final String gender;
  final String family;
  final String season;
  final String occasion;
  final String time;
  final String intensity;
  final List<String> notes;
  final List<String> tags;

  const AIChatCompactProduct({
    required this.index,
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.gender,
    required this.family,
    required this.season,
    required this.occasion,
    required this.time,
    required this.intensity,
    this.notes = const [],
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'id': id,
      'name': name,
      'brand': brand,
      'price': price,
      if (gender.trim().isNotEmpty) 'gender': gender,
      if (family.trim().isNotEmpty) 'family': family,
      if (season.trim().isNotEmpty) 'season': season,
      if (occasion.trim().isNotEmpty) 'occasion': occasion,
      if (time.trim().isNotEmpty) 'time': time,
      if (intensity.trim().isNotEmpty) 'intensity': intensity,
      if (notes.isNotEmpty) 'notes': notes.take(6).toList(growable: false),
      if (tags.isNotEmpty) 'tags': tags.take(6).toList(growable: false),
    };
  }
}

class AIChatCompactConversationContext {
  static const int compactContextVersion = 3;
  static const int commerceContextVersion = 1;
  static const int defaultRecentMessageLimit = 5;
  static const int maxVisibleProducts = 5;
  static const int maxLastRecommendationIds = 10;
  static const int maxRejectedProductIds = 20;
  static const int maxMessageLength = 240;
  static const List<String> defaultAllowedTools = [
    'search_products',
    'update_preferences_and_recommend',
    'answer_product_question',
    'ask_product_clarification',
    'cheapest_catalog',
    'most_expensive_catalog',
    'similar_cheaper',
    'cheaper_followup',
    'show_lowest_available_after_budget_no_match',
    'reject_visible_products',
    'resolve_perfume_reference',
    'select_perfume_reference_option',
    'lookup_external_perfume_profile',
    'recommend_similar_to_external_profile',
    'similar_cheaper_to_external_profile',
    'ask_clarification',
  ];

  final List<AIChatCompactMessage> recentMessages;
  final String? lastAssistantQuestion;
  final String? lastAskSlot;
  final List<String> lastVisibleProductIds;
  final List<AIChatCompactProduct> visibleProducts;
  final String? lastFocusedProductId;
  final List<String> lastRecommendationIds;
  final LastNoMatchContext? lastNoMatch;
  final ExternalProfileRef? lastExternalProfile;
  final PendingPerfumeReferenceClarification?
  pendingPerfumeReferenceClarification;
  final SessionPreferences currentPreferences;
  final List<String> rejectedProductIds;
  final List<String> allowedTools;
  final bool hasRecommendationContext;
  final bool hasAvailabilityContext;
  final bool lastTurnWasAsk;

  const AIChatCompactConversationContext({
    this.recentMessages = const [],
    this.lastAssistantQuestion,
    this.lastAskSlot,
    this.lastVisibleProductIds = const [],
    this.visibleProducts = const [],
    this.lastFocusedProductId,
    this.lastRecommendationIds = const [],
    this.lastNoMatch,
    this.lastExternalProfile,
    this.pendingPerfumeReferenceClarification,
    this.currentPreferences = const SessionPreferences(),
    this.rejectedProductIds = const [],
    this.allowedTools = defaultAllowedTools,
    this.hasRecommendationContext = false,
    this.hasAvailabilityContext = false,
    this.lastTurnWasAsk = false,
  });

  factory AIChatCompactConversationContext.fromMessages({
    required List<AIChatMessage> messages,
    String? lastAssistantQuestion,
    String? lastAskSlot,
    bool hasAvailabilityContext = false,
    int recentMessageLimit = defaultRecentMessageLimit,
    RecommendationMemory recommendationMemory = const RecommendationMemory(),
    SessionPreferences currentPreferences = const SessionPreferences(),
    List<String> rejectedProductIds = const [],
  }) {
    final visibleMessages = messages
        .where((message) => !message.isLoading)
        .toList(growable: false);
    final recentMessages = visibleMessages
        .skip(
          visibleMessages.length > recentMessageLimit
              ? visibleMessages.length - recentMessageLimit
              : 0,
        )
        .map((message) {
          return AIChatCompactMessage(
            role: message.isFromUser ? 'user' : 'assistant',
            text: _cleanText(message.content),
          );
        })
        .where((message) => message.text.isNotEmpty)
        .toList(growable: false);

    AIChatMessage? lastCardsMessage;
    for (final message in visibleMessages) {
      if ((message.isRecommendation || message.isAvailability) &&
          message.recommendedProducts.isNotEmpty) {
        lastCardsMessage = message;
      }
    }
    final lastVisibleProductIds =
        lastCardsMessage?.recommendedProducts
            .map((item) => item.product.id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false) ??
        const <String>[];
    final visibleProducts =
        lastCardsMessage?.recommendedProducts
            .take(maxVisibleProducts)
            .toList(growable: false)
            .asMap()
            .entries
            .map((entry) {
              final product = entry.value.product;
              return AIChatCompactProduct(
                index: entry.key + 1,
                id: product.id,
                name: product.name,
                brand: product.brand,
                price: product.effectivePrice,
                gender: product.gender,
                family: product.fragranceFamily,
                season: product.season,
                occasion: product.occasion,
                time: product.time,
                intensity: product.intensity,
                notes: product.notes,
                tags: product.tags,
              );
            })
            .toList(growable: false) ??
        const <AIChatCompactProduct>[];
    final memoryRecommendationIds = recommendationMemory.lastRecommendedProducts
        .map((item) => item.productId.trim())
        .where((id) => id.isNotEmpty)
        .take(maxLastRecommendationIds)
        .toList(growable: false);

    return AIChatCompactConversationContext(
      recentMessages: recentMessages,
      lastAssistantQuestion: _nullableCleanText(lastAssistantQuestion),
      lastAskSlot: _nullableCleanText(lastAskSlot),
      lastVisibleProductIds: lastVisibleProductIds,
      visibleProducts: visibleProducts,
      lastFocusedProductId: _boundedId(
        recommendationMemory.lastFocusedProductId,
      ),
      lastRecommendationIds: memoryRecommendationIds.isNotEmpty
          ? memoryRecommendationIds
          : lastVisibleProductIds.take(maxLastRecommendationIds).toList(),
      lastNoMatch: recommendationMemory.lastNoMatchContext,
      lastExternalProfile: recommendationMemory.lastExternalProfile,
      pendingPerfumeReferenceClarification:
          recommendationMemory.pendingPerfumeReferenceClarification,
      currentPreferences: currentPreferences,
      rejectedProductIds: rejectedProductIds
          .map(_boundedId)
          .whereType<String>()
          .take(maxRejectedProductIds)
          .toList(growable: false),
      hasRecommendationContext:
          lastVisibleProductIds.isNotEmpty ||
          memoryRecommendationIds.isNotEmpty,
      hasAvailabilityContext: hasAvailabilityContext,
      lastTurnWasAsk:
          lastAssistantQuestion != null &&
          lastAssistantQuestion.trim().isNotEmpty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'compactContextVersion': compactContextVersion,
      'commerceContextVersion': commerceContextVersion,
      if (recentMessages.isNotEmpty)
        'recentMessages': recentMessages
            .map((message) => message.toJson())
            .toList(growable: false),
      if (lastAssistantQuestion != null)
        'lastAssistantQuestion': lastAssistantQuestion,
      if (lastAskSlot != null) 'lastAskSlot': lastAskSlot,
      'lastVisibleProductIds': lastVisibleProductIds,
      if (visibleProducts.isNotEmpty)
        'visibleProducts': visibleProducts
            .map((product) => product.toJson())
            .toList(growable: false),
      if (lastFocusedProductId != null)
        'lastFocusedProductId': lastFocusedProductId,
      if (lastRecommendationIds.isNotEmpty)
        'lastRecommendationIds': lastRecommendationIds,
      if (lastNoMatch != null) 'lastNoMatch': lastNoMatch!.toJson(),
      if (pendingPerfumeReferenceClarification != null)
        'pendingPerfumeReferenceClarification':
            pendingPerfumeReferenceClarification!.toJson(),
      if (lastExternalProfile != null)
        'lastExternalProfile': lastExternalProfile!.toJson(),
      'currentPreferences': currentPreferences.toJson(),
      if (rejectedProductIds.isNotEmpty)
        'rejectedProductIds': rejectedProductIds,
      'allowedTools': allowedTools,
      'conversationContext': {
        'hasRecommendationContext': hasRecommendationContext,
        'hasAvailabilityContext': hasAvailabilityContext,
        'lastTurnWasAsk': lastTurnWasAsk,
      },
    };
  }

  static String? _nullableCleanText(String? value) {
    final cleaned = _cleanText(value ?? '');
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _cleanText(String value) {
    var result = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (result.isEmpty) return result;
    result = _redactSensitiveText(result);
    if (result.length > maxMessageLength) {
      result = result.substring(0, maxMessageLength).trim();
    }
    return result;
  }

  static String? _boundedId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.length > 80) {
      return null;
    }
    if (!RegExp(r'^[A-Za-z0-9_\-:.]+$').hasMatch(trimmed)) return null;
    return trimmed;
  }

  static String _redactSensitiveText(String value) {
    return value
        .replaceAll(
          RegExp(
            r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
            caseSensitive: false,
          ),
          '[redacted_email]',
        )
        .replaceAll(
          RegExp(r'(?<!\d)(?:\+?\d[\d\s().-]{7,}\d)(?!\d)'),
          '[redacted_phone]',
        )
        .replaceAll(RegExp(r'\b(?:\d[ -]*?){13,19}\b'), '[redacted_payment]');
  }
}
