import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_copy_engine.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_facts.dart';

void main() {
  group('AIChatResponseCopyEngine', () {
    const engine = AIChatResponseCopyEngine();

    test('returns a natural social answer without availability wording', () {
      final text = engine.socialAnswer(AIChatLanguage.english);

      expect(text, contains('ready to help'));
      expect(text.toLowerCase(), isNot(contains('check availability')));
      expect(text.toLowerCase(), isNot(contains('specific perfume')));
    });

    test('rejects generic recommendation intros and builds from facts', () {
      final facts = const AIChatResponseFacts(
        intent: AIChatConversationIntent.catalogRecommendation,
        cardPolicy: AIChatCardPolicy.recommendationGrid,
        source: 'local_test',
        renderIntent: 'initial_recommendation',
        products: [
          AIChatProductResponseFact(
            id: 'p1',
            name: 'Light Blue',
            brand: 'Dolce & Gabbana',
            price: 1200,
            stock: 3,
            family: 'fresh citrus',
            intensity: 'light',
            reason: 'it is fresh and easy to wear',
          ),
        ],
      );

      final text = engine.recommendationIntro(
        facts,
        AIChatLanguage.english,
        llmIntro:
            'Based on your preferences, these are the best matches for you right now.',
      );

      expect(text, contains('Light Blue'));
      expect(text, contains('fresh and easy to wear'));
      expect(text.toLowerCase(), isNot(contains('based on your preferences')));
    });

    test('preserves budget-floor disclosure as the lead message', () {
      final facts = const AIChatResponseFacts(
        intent: AIChatConversationIntent.catalogRecommendation,
        cardPolicy: AIChatCardPolicy.recommendationGrid,
        source: 'tool_showLowestAvailableAfterBudgetNoMatch',
        renderIntent: 'budgetFloor',
        disclosures: ['This option is above your original 600 EGP budget.'],
        products: [
          AIChatProductResponseFact(
            id: 'p1',
            name: 'Floor',
            brand: 'Qissa',
            price: 850,
            stock: 2,
            family: 'fresh',
            intensity: 'medium',
            reason: '',
          ),
        ],
      );

      final text = engine.recommendationIntro(facts, AIChatLanguage.english);

      expect(text, 'This option is above your original 600 EGP budget.');
    });

    test('retargets generic ask from facts instead of repeating weak copy', () {
      final facts = const AIChatResponseFacts(
        intent: AIChatConversationIntent.clarification,
        cardPolicy: AIChatCardPolicy.noCards,
        source: 'ask_retarget',
        question:
            'Hello! Tell me your preferences like gender, notes, or budget.',
        constraints: ['gender'],
        products: [],
      );

      final text = engine.askQuestion(
        facts,
        AIChatLanguage.english,
        llmQuestion: facts.question,
      );

      expect(text, contains('gender'));
      expect(text.toLowerCase(), isNot(contains('tell me your preferences')));
    });

    test('turns generic no-match into useful recovery copy', () {
      final facts = const AIChatResponseFacts(
        intent: AIChatConversationIntent.noMatch,
        cardPolicy: AIChatCardPolicy.noCards,
        source: 'local_fallback',
        answer:
            'I could not find an in-stock catalog match that safely respects your current constraints.',
        products: [],
      );

      final text = engine.noMatch(
        facts,
        AIChatLanguage.english,
        llmText: facts.answer,
      );

      expect(text, contains('exact catalog match'));
      expect(text, contains('different scent direction'));
    });

    test('rejects internal reason strings in LLM recommendation intro', () {
      final facts = const AIChatResponseFacts(
        intent: AIChatConversationIntent.catalogRecommendation,
        cardPolicy: AIChatCardPolicy.recommendationGrid,
        source: 'ai_worker',
        renderIntent: 'initial_recommendation',
        products: [
          AIChatProductResponseFact(
            id: 'p1',
            name: 'Fresh Pick',
            brand: 'Qissa',
            price: 900,
            stock: 4,
            family: 'fresh',
            intensity: 'medium',
            reason: 'safe catalog pick',
          ),
        ],
      );

      final text = engine.recommendationIntro(
        facts,
        AIChatLanguage.english,
        llmIntro: 'catalog note gap; fallback from candidates',
      );

      expect(text, contains('Fresh Pick'));
      expect(text, isNot(contains('catalog note gap')));
      expect(text, isNot(contains('fallback from candidates')));
    });
  });
}
