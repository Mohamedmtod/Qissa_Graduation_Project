import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_conversation_orchestrator.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_facts.dart';

void main() {
  group('AIChatConversationOrchestrator', () {
    const orchestrator = AIChatConversationOrchestrator();

    AIChatConversationPlan plan(
      String message, {
      bool hasRecommendationContext = false,
      RecommendationMemory memory = const RecommendationMemory(),
    }) {
      return orchestrator.plan(
        message: message,
        language: AIChatLanguage.english,
        preferences: const SessionPreferences(),
        memory: memory,
        hasRecommendationContext: hasRecommendationContext,
      );
    }

    test('routes social turns to answer-only worker-led conversation', () {
      final result = plan('how are you');

      expect(result.intent, AIChatConversationIntent.social);
      expect(result.cardPolicy, AIChatCardPolicy.answerOnly);
      expect(result.shouldPreferWorker, isTrue);
      expect(result.safeFallbackPlan, 'social_answer');
    });

    test('routes availability turns to purchase card policy', () {
      final result = plan('Do you have Light Blue?');

      expect(result.intent, AIChatConversationIntent.availability);
      expect(result.cardPolicy, AIChatCardPolicy.purchaseCtaCard);
      expect(result.shouldPreferWorker, isFalse);
    });

    test('routes visible product questions to text-only answers', () {
      final result = plan(
        'which is cheapest among them?',
        hasRecommendationContext: true,
        memory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'One',
              brand: 'Brand',
              displayIndex: 1,
              price: 100,
              stock: 5,
              season: 'summer',
              occasion: 'daily',
              intensity: 'light',
              notes: ['citrus'],
            ),
          ],
        ),
      );

      expect(result.intent, AIChatConversationIntent.visibleProductsQuestion);
      expect(result.cardPolicy, AIChatCardPolicy.answerOnly);
      expect(result.safeFallbackPlan, 'answer_visible_products');
    });
  });
}
