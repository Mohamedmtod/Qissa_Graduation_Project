import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

void main() {
  group('AIChatCompactConversationContext', () {
    test('caps recent messages and captures last assistant question', () {
      final context = AIChatCompactConversationContext.fromMessages(
        messages: [
          AIChatMessage.user('one'),
          AIChatMessage.botText('two'),
          AIChatMessage.user('three'),
          AIChatMessage.botText('four'),
          AIChatMessage.user('five'),
          AIChatMessage.botText('six'),
          AIChatMessage.user('seven'),
        ],
        lastAssistantQuestion: 'Season?',
        lastAskSlot: 'season',
        recentMessageLimit: 4,
      );

      expect(context.recentMessages.map((item) => item.text), [
        'four',
        'five',
        'six',
        'seven',
      ]);
      expect(context.lastAssistantQuestion, 'Season?');
      expect(context.lastAskSlot, 'season');
      expect(context.lastTurnWasAsk, isTrue);
    });

    test('redacts sensitive text before serialization', () {
      final context = AIChatCompactConversationContext.fromMessages(
        messages: [
          AIChatMessage.user('email me at user@example.com or 01012345678'),
        ],
      );

      final json = context.toJson();
      final recent = json['recentMessages'] as List<dynamic>;
      final text = (recent.first as Map<String, dynamic>)['text'] as String;
      expect(text, contains('[redacted_email]'));
      expect(text, contains('[redacted_phone]'));
      expect(text, isNot(contains('user@example.com')));
    });

    test('serializes commerce context versions and state snapshot', () {
      final context = AIChatCompactConversationContext.fromMessages(
        messages: [AIChatMessage.user('show me it')],
        recommendationMemory: const RecommendationMemory(
          lastFocusedProductId: 'p1',
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Light Blue',
              brand: 'Dolce & Gabbana',
              displayIndex: 1,
              price: 3250,
              stock: 30,
              season: 'summer',
              occasion: 'office',
              intensity: 'medium',
              notes: ['fruity'],
            ),
          ],
          lastNoMatchContext: LastNoMatchContext(
            reason: 'budget_no_match',
            requestedBudget: 600,
            lowestAvailablePrice: 790,
            lowestAvailableProductIds: ['floor_1'],
          ),
        ),
        currentPreferences: const SessionPreferences(
          gender: 'men',
          maxBudget: 600,
          preferredNotes: ['fruity'],
        ),
      );

      final json = context.toJson();
      expect(json['compactContextVersion'], 3);
      expect(json['commerceContextVersion'], 1);
      expect(json['lastFocusedProductId'], 'p1');
      expect(json['lastRecommendationIds'], ['p1']);
      expect(json['allowedTools'], contains('similar_cheaper'));
      expect(json['allowedTools'], contains('reject_visible_products'));
      expect(json['allowedTools'], contains('resolve_perfume_reference'));
      expect(
        json['allowedTools'],
        contains('recommend_similar_to_external_profile'),
      );
      expect(json['lastNoMatch'], {
        'reason': 'budget_no_match',
        'requestedBudget': 600.0,
        'lowestAvailablePrice': 790.0,
        'lowestAvailableProductIds': ['floor_1'],
      });
      expect(
        json['currentPreferences'],
        containsPair('preferredNotes', ['fruity']),
      );
    });

    test('serializes external profile and perfume clarification context', () {
      final context = AIChatCompactConversationContext.fromMessages(
        messages: [AIChatMessage.user('1')],
        recommendationMemory: const RecommendationMemory(
          lastExternalProfile: ExternalProfileRef(
            id: 'dior_sauvage',
            name: 'Dior Sauvage',
            brand: 'Dior',
            fragranceFamily: 'fresh spicy',
            notes: ['bergamot', 'pepper'],
            tags: ['fresh', 'spicy'],
            confidence: 0.91,
          ),
          pendingPerfumeReferenceClarification:
              PendingPerfumeReferenceClarification(
                query: 'Dior',
                options: [
                  PerfumeReferenceOptionRef(
                    index: 1,
                    name: 'Dior Sauvage',
                    brand: 'Dior',
                    source: 'perfumeKnowledge',
                    externalProfileId: 'dior_sauvage',
                    confidence: 0.91,
                  ),
                ],
              ),
        ),
      );

      final json = context.toJson();
      expect(json['lastExternalProfile'], containsPair('id', 'dior_sauvage'));
      expect(
        json['pendingPerfumeReferenceClarification'],
        containsPair('query', 'Dior'),
      );
    });
  });
}
