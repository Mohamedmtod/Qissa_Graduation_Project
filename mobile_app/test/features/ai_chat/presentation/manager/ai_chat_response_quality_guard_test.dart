import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_facts.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_quality_guard.dart';

void main() {
  group('AIChatResponseQualityGuard', () {
    const guard = AIChatResponseQualityGuard();

    test('blocks social replies that sound like availability clarification', () {
      final result = guard.validateText(
        intent: AIChatConversationIntent.social,
        cardPolicy: AIChatCardPolicy.answerOnly,
        text:
            'Do you want me to check availability for a specific perfume, or suggest a perfume from the catalog?',
      );

      expect(result.isAllowed, isFalse);
      expect(result.reasonCode, 'social_availability_wording');
    });

    test('blocks generic social preference prompts', () {
      final result = guard.validateText(
        intent: AIChatConversationIntent.social,
        cardPolicy: AIChatCardPolicy.answerOnly,
        text:
            'Hello! Tell me your preferences like gender, notes, or budget, and I will suggest the best fit.',
      );

      expect(result.isAllowed, isFalse);
      expect(result.reasonCode, 'social_generic_preference_prompt');
    });

    test('blocks generic recommendation copy for recommendation grids', () {
      final result = guard.validateText(
        intent: AIChatConversationIntent.catalogRecommendation,
        cardPolicy: AIChatCardPolicy.recommendationGrid,
        text:
            'Based on your preferences, these are the best matches for you right now.',
      );

      expect(result.isAllowed, isFalse);
      expect(result.reasonCode, 'generic_recommendation_intro');
    });

    test('allows grounded concise recommendation copy', () {
      final result = guard.validateText(
        intent: AIChatConversationIntent.catalogRecommendation,
        cardPolicy: AIChatCardPolicy.recommendationGrid,
        text:
            'I found 3 catalog options. The strongest starting point is Light Blue because it is fresh and easy to wear.',
      );

      expect(result.isAllowed, isTrue);
    });

    test('blocks answer-only facts that try to render products', () {
      final result = guard.validateFacts(
        const AIChatResponseFacts(
          intent: AIChatConversationIntent.visibleProductsQuestion,
          cardPolicy: AIChatCardPolicy.answerOnly,
          source: 'visible_products_answer',
          products: [
            AIChatProductResponseFact(
              id: 'p1',
              name: 'Light Blue',
              brand: 'D&G',
              price: 1000,
              stock: 2,
              family: 'fresh',
              intensity: 'medium',
              reason: 'Visible option.',
            ),
          ],
        ),
      );

      expect(result.isAllowed, isFalse);
      expect(result.reasonCode, 'answer_only_has_products');
    });

    test('blocks recommendation facts without products', () {
      final result = guard.validateFacts(
        const AIChatResponseFacts(
          intent: AIChatConversationIntent.catalogRecommendation,
          cardPolicy: AIChatCardPolicy.recommendationGrid,
          source: 'tool_searchProducts',
          products: [],
        ),
      );

      expect(result.isAllowed, isFalse);
      expect(result.reasonCode, 'recommendation_missing_products');
    });
  });
}
