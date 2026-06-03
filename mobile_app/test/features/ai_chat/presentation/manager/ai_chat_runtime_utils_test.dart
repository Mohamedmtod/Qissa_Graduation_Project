import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_runtime_utils.dart';

void main() {
  group('pruneBotHistoryForFreshTurn', () {
    test('preserves bot text, recommendation cards, and user messages', () {
      final greeting = AIChatMessage.botText(
        'Hello! Tell me your preferences.',
      );
      final recommendation = AIChatMessage.botRecommendation(
        content: 'Old picks',
        products: const [],
      );
      final user = AIChatMessage.user('I want a fruity perfume');

      final pruned = pruneBotHistoryForFreshTurn([
        greeting,
        recommendation,
        user,
      ], enabled: true);

      expect(pruned, contains(greeting));
      expect(pruned, contains(user));
      expect(pruned, contains(recommendation));
    });

    test('preserves recommendation message type and card payload', () {
      final recommendation = AIChatMessage.botRecommendation(
        content: 'Based on your preferences, these are the best matches.',
        products: const [],
      );

      final pruned = pruneBotHistoryForFreshTurn([
        recommendation,
      ], enabled: true);

      expect(pruned, hasLength(1));
      expect(pruned.single.content, recommendation.content);
      expect(pruned.single.isRecommendation, isTrue);
      expect(pruned.single.recommendedProducts, isEmpty);
    });

    test('preserves historical product-detail bot text', () {
      final productDetails = AIChatMessage.botText(
        '1. Libre from Yves Saint Laurent. Notes: citrus, floral, vanilla.',
      );
      final normalAnswer = AIChatMessage.botText(
        'I can help you choose something lighter.',
      );

      final pruned = pruneBotHistoryForFreshTurn([
        productDetails,
        normalAnswer,
      ], enabled: true);

      expect(pruned, contains(productDetails));
      expect(pruned, contains(normalAnswer));
    });
  });
}
