import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_answer_grounding_guard.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product() {
  final now = Timestamp.now();
  return ProductModel(
    id: 'p1',
    name: 'Citrus Office',
    nameLower: 'citrus office',
    searchPrefixes: const ['ci', 'cit'],
    brand: 'Brand',
    price: 1200,
    stock: 5,
    gender: 'men',
    season: 'summer',
    fragranceFamily: 'fresh citrus',
    notes: const ['citrus', 'musk'],
    imageUrls: const ['https://example.com/p.png'],
    description: 'Fresh citrus and musk profile.',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: 'office',
    time: 'day',
    intensity: 'light',
    topNotes: const ['bergamot'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: const ['fresh', 'clean'],
  );
}

void main() {
  group('AIChatAnswerGroundingGuard', () {
    const guard = AIChatAnswerGroundingGuard();

    test('allows locally supported price and notes', () {
      final decision = guard.validate(
        reply: AIChatReply.answer(
          answer:
              'Citrus Office costs 1200 EGP and has citrus, bergamot, and musk notes.',
          updatedPreferences: const SessionPreferences(),
        ),
        localFacts: [_product()],
      );

      expect(decision.isAllowed, isTrue);
    });

    test('blocks fake price claims', () {
      final decision = guard.validate(
        reply: AIChatReply.answer(
          answer: 'Citrus Office costs 1800 EGP.',
          updatedPreferences: const SessionPreferences(),
        ),
        localFacts: [_product()],
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reasonCode, 'answer_unsupported_price');
    });

    test('blocks unsupported note claims', () {
      final decision = guard.validate(
        reply: AIChatReply.answer(
          answer: 'Citrus Office has pineapple and vanilla notes.',
          updatedPreferences: const SessionPreferences(),
        ),
        localFacts: [_product()],
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reasonCode, 'answer_unsupported_note');
    });

    test(
      'blocks answers that mention excluded notes even when old facts had them',
      () {
        final decision = guard.validate(
          reply: AIChatReply.answer(
            answer: 'Libre has vanilla and musk notes.',
            updatedPreferences: const SessionPreferences(
              excludedNotes: ['vanilla'],
            ),
          ),
          localFacts: [_product()],
          effectivePreferences: const SessionPreferences(
            excludedNotes: ['vanilla'],
          ),
        );

        expect(decision.isAllowed, isFalse);
        expect(decision.reasonCode, 'answer_mentions_excluded_note');
      },
    );

    test('blocks medical excluded note mentions in Arabic answers', () {
      final decision = guard.validate(
        reply: AIChatReply.answer(
          answer:
              '\u0627\u0644\u0639\u0637\u0631 \u0641\u064a\u0647 \u0641\u0627\u0646\u064a\u0644\u064a\u0627.',
          updatedPreferences: const SessionPreferences(
            medicalExcludedNotes: ['vanilla'],
          ),
        ),
        localFacts: [_product()],
        effectivePreferences: const SessionPreferences(
          medicalExcludedNotes: ['vanilla'],
        ),
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reasonCode, 'answer_mentions_excluded_note');
    });

    test('blocks answer responses that carry product ids', () {
      final decision = guard.validate(
        reply: AIChatReply(
          actionType: ActionType.answer,
          answer: 'This is a text answer.',
          productIds: const ['p1'],
          updatedPreferences: const SessionPreferences(),
        ),
        localFacts: [_product()],
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reasonCode, 'answer_contains_product_ids');
    });

    test('blocks internal schema and system prompt leakage', () {
      final decision = guard.validate(
        reply: AIChatReply.answer(
          answer:
              'According to the JSON schema and system prompt, I can answer.',
          updatedPreferences: const SessionPreferences(),
        ),
        localFacts: const [],
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reasonCode, 'answer_internal_leakage');
    });

    test('blocks availability claims without local facts', () {
      final decision = guard.validate(
        reply: AIChatReply.answer(
          answer: 'Dior Sauvage is available and in stock.',
          updatedPreferences: const SessionPreferences(),
        ),
        localFacts: const [],
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reasonCode, 'answer_has_no_local_facts');
    });

    test('allows educational answer without product facts', () {
      final decision = guard.validate(
        reply: AIChatReply.answer(
          answer:
              'Eau de Parfum is usually more concentrated than Eau de Toilette.',
          updatedPreferences: const SessionPreferences(),
        ),
        localFacts: const [],
      );

      expect(decision.isAllowed, isTrue);
    });
  });
}
