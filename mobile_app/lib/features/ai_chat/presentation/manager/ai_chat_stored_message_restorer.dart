import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AIChatStoredMessageRestorer {
  const AIChatStoredMessageRestorer();

  Future<List<AIChatMessage>> restore(
    List<AIChatStoredMessage> storedMessages, {
    required Future<List<ProductModel>> Function(List<String> ids)
    fetchProductsByIds,
  }) async {
    final productIds = storedMessages
        .expand((message) => message.productIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final products = await fetchProductsByIds(productIds);
    final productsById = {for (final product in products) product.id: product};

    return storedMessages
        .where((message) => message.messageType != AIChatMessageType.loading)
        .map((message) {
          final restoredProducts = message.productIds
              .map((id) => productsById[id.trim()])
              .whereType<ProductModel>()
              .map(
                (product) => RecommendedProduct(
                  product: product,
                  matchScore: 0,
                  matchLabel: 'Restored',
                  matchReason: '',
                ),
              )
              .toList(growable: false);
          final type = restoredProducts.isEmpty
              ? _messageTypeWithoutCards(message.messageType)
              : _storedMessageTypeToUi(message.messageType);
          return AIChatMessage(
            id: message.id,
            content: message.content,
            sender: message.role == AIChatMessageRole.user
                ? MessageSender.user
                : MessageSender.bot,
            type: type,
            timestamp: message.createdAt,
            recommendedProducts: restoredProducts,
          );
        })
        .toList(growable: false);
  }

  MessageType _storedMessageTypeToUi(AIChatMessageType type) {
    return switch (type) {
      AIChatMessageType.recommendation => MessageType.recommendation,
      AIChatMessageType.availability => MessageType.availability,
      AIChatMessageType.error => MessageType.error,
      AIChatMessageType.loading => MessageType.loading,
      AIChatMessageType.text => MessageType.text,
    };
  }

  MessageType _messageTypeWithoutCards(AIChatMessageType type) {
    return type == AIChatMessageType.error
        ? MessageType.error
        : MessageType.text;
  }
}
