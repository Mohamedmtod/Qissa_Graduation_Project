import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';

RecommendationMemory latestVisibleRecommendationMemory(
  List<AIChatMessage> messages,
  RecommendationMemory currentMemory,
) {
  final latestRecommendationMessage = messages.lastWhere(
    (message) =>
        message.isRecommendation && message.recommendedProducts.isNotEmpty,
    orElse: () => AIChatMessage(
      id: '',
      content: '',
      sender: MessageSender.bot,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );

  if (!latestRecommendationMessage.isRecommendation ||
      latestRecommendationMessage.recommendedProducts.isEmpty) {
    return currentMemory;
  }

  final existingMetadataByProductId = {
    for (final ref in currentMemory.lastRecommendedProducts) ref.productId: ref,
  };

  final lastRecommendedProducts = latestRecommendationMessage
      .recommendedProducts
      .asMap()
      .entries
      .map((entry) {
        final recommendation = entry.value;
        final product = recommendation.product;
        final existingRef = existingMetadataByProductId[product.id];
        return RecommendedProductRef(
          productId: product.id,
          name: product.name,
          brand: product.brand,
          displayIndex: entry.key + 1,
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
          matchScore: recommendation.matchScore,
          matchReason: recommendation.matchReason,
          requestId: existingRef?.requestId,
          promptVersion: existingRef?.promptVersion,
          provider: existingRef?.provider,
          modelId: existingRef?.modelId,
        );
      })
      .toList();

  return RecommendationMemory(
    lastRecommendedProducts: lastRecommendedProducts,
    lastFocusedProductId: currentMemory.lastFocusedProductId,
    lastRecommendationBatchId: latestRecommendationMessage.id,
    lastNoMatchContext: currentMemory.lastNoMatchContext,
  );
}
