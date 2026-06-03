import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply_validator.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

void main() {
  group('AIChatReplyValidator', () {
    test('recommend callback fires when match_reason is missing', () {
      var missingReasonCount = 0;

      final reply = AIChatReplyValidator.parseMap(
        {
          'action_type': 'recommend',
          'product_ids': ['p1', 'p2'],
          'match_reason': {'p1': 'Great fit.'},
        },
        language: AIChatLanguage.english,
        onMissingReasonCount: (count) => missingReasonCount = count,
      );

      expect(reply, isNotNull);
      expect(reply!.isRecommend, isTrue);
      expect(reply.productIds, equals(['p1', 'p2']));
      expect(
        reply.matchReasons['p2'],
        equals('This perfume matches your current preferences.'),
      );
      expect(missingReasonCount, equals(1));
    });

    test('ask callback does not fire even if product_ids exist in payload', () {
      var callbackCalled = false;

      final reply = AIChatReplyValidator.parseMap(
        {
          'action_type': 'ask',
          'question': 'What notes do you like?',
          'product_ids': ['p1'],
        },
        language: AIChatLanguage.english,
        onMissingReasonCount: (_) => callbackCalled = true,
      );

      expect(reply, isNotNull);
      expect(reply!.isAsk, isTrue);
      expect(callbackCalled, isFalse);
    });

    test(
      'answer callback does not fire even if product_ids exist in payload',
      () {
        var callbackCalled = false;

        final reply = AIChatReplyValidator.parseMap(
          {
            'action_type': 'answer',
            'answer': 'Here are more details.',
            'product_ids': ['p1'],
          },
          language: AIChatLanguage.english,
          onMissingReasonCount: (_) => callbackCalled = true,
        );

        expect(reply, isNotNull);
        expect(reply!.isAnswer, isTrue);
        expect(callbackCalled, isFalse);
      },
    );

    test(
      'parses explicit preference_patch for safe clear/remove operations',
      () {
        final reply = AIChatReplyValidator.parseMap({
          'action_type': 'ask',
          'question': 'Budget cleared.',
          'updated_preferences': {'gender': 'men'},
          'preference_patch': {
            'clearScalars': ['maxBudget'],
            'removeLists': {
              'preferredNotes': ['oud'],
            },
          },
        }, language: AIChatLanguage.english);

        final merged = reply!.preferencePatch!.applyTo(
          const SessionPreferences(
            gender: 'men',
            maxBudget: 1500,
            preferredNotes: ['oud', 'citrus'],
          ),
        );

        expect(merged.maxBudget, isNull);
        expect(merged.preferredNotes, ['citrus']);
      },
    );

    test('parses v2 structured recommendation as current AIChatReply', () {
      final reply = AIChatReplyValidator.parseMap({
        'schemaVersion': 2,
        'type': 'recommendation',
        'message': 'These fit.',
        'preferencesPatch': {
          'replaceScalars': {'season': 'all_seasons'},
        },
        'commands': [
          {
            'action': 'show_recommendation_cards',
            'productIds': ['p1', 'p2'],
          },
        ],
        'recommendations': [
          {'productId': 'p1', 'reason': 'Fresh and within budget.'},
        ],
        'metadata': {'requestId': 'req-1', 'provider': 'openrouter'},
      }, language: AIChatLanguage.english);

      expect(reply, isNotNull);
      expect(reply!.isRecommend, isTrue);
      expect(reply.productIds, ['p1', 'p2']);
      expect(reply.matchReasons['p1'], 'Fresh and within budget.');
      expect(reply.matchReasons['p2'], isNotEmpty);
      expect(reply.answer, 'These fit.');
      expect(reply.preferencePatch, isNotNull);
      expect(reply.requestId, 'req-1');
    });

    test('ignores unknown v2 commands and falls back to answer', () {
      final reply = AIChatReplyValidator.parseMap({
        'schemaVersion': 2,
        'type': 'message',
        'message': 'I can help with that.',
        'commands': [
          {
            'action': 'clear_cards',
            'productIds': ['p1'],
          },
        ],
      }, language: AIChatLanguage.english);

      expect(reply, isNotNull);
      expect(reply!.isAnswer, isTrue);
      expect(reply.answer, 'I can help with that.');
    });

    test('parses tool_call reply before structured v2 fallback', () {
      final reply = AIChatReplyValidator.parseMap({
        'schemaVersion': 2,
        'type': 'tool_call',
        'message': 'Searching catalog.',
        'toolCall': {
          'name': 'search_products',
          'arguments': {
            'gender': 'men',
            'occasion': 'university',
            'tags': ['fresh', 'clean'],
          },
        },
        'metadata': {'requestId': 'tool-1', 'provider': 'openrouter'},
      }, language: AIChatLanguage.english);

      expect(reply, isNotNull);
      expect(reply!.isToolCall, isTrue);
      expect(reply.toolCall!.name, AIChatToolName.searchProducts);
      expect(reply.answer, 'Searching catalog.');
      expect(reply.toolCall!.arguments['gender'], 'men');
      expect(reply.requestId, 'tool-1');
    });

    test('ignores unknown tool_call names safely', () {
      final reply = AIChatReplyValidator.parseMap({
        'action_type': 'tool_call',
        'tool_call': {
          'name': 'delete_products',
          'arguments': {'limit': 3},
        },
      }, language: AIChatLanguage.english);

      expect(reply, isNull);
    });

    test('parses update_preferences patch from dynamic tool args', () {
      final reply = AIChatReplyValidator.parseMap({
        'type': 'tool_call',
        'toolCall': {
          'name': 'update_preferences',
          'arguments': {
            'preferencePatch': {
              'clearScalars': ['intensity'],
            },
          },
        },
      }, language: AIChatLanguage.english);

      expect(reply, isNotNull);
      expect(
        reply!.toolCall!.name,
        AIChatToolName.updatePreferencesAndRecommend,
      );
      expect(reply.toolCall!.preferencePatch, isNotNull);
    });

    test('parses semantic commerce tool names and confidence', () {
      final reply = AIChatReplyValidator.parseMap({
        'type': 'tool_call',
        'toolCall': {
          'name': 'show_lowest_available_after_budget_no_match',
          'confidence': 0.92,
          'arguments': {'requestedBudget': 600},
        },
      }, language: AIChatLanguage.english);

      expect(reply, isNotNull);
      expect(
        reply!.toolCall!.name,
        AIChatToolName.showLowestAvailableAfterBudgetNoMatch,
      );
      expect(reply.toolCall!.confidence, 0.92);
    });

    test('parses perfume reference tool names safely', () {
      final reply = AIChatReplyValidator.parseMap({
        'type': 'tool_call',
        'toolCall': {
          'name': 'resolve_perfume_reference',
          'confidence': 0.88,
          'arguments': {'query': 'Dior'},
        },
      }, language: AIChatLanguage.english);

      expect(reply, isNotNull);
      expect(reply!.toolCall!.name, AIChatToolName.resolvePerfumeReference);
      expect(reply.toolCall!.arguments['query'], 'Dior');
      expect(reply.toolCall!.confidence, 0.88);
    });
  });
}
