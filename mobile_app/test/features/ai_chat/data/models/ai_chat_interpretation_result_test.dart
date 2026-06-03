import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_interpretation_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

void main() {
  group('AIChatInterpretationResult', () {
    test('sanitizes valid preference patch', () {
      final result = AIChatInterpretationResult.fromJson({
        'intent': 'recommendation',
        'confidence': 0.82,
        'preferencePatch': {
          'gender': 'unisex',
          'season': 'winter',
          'maxBudget': '1,200',
          'preferredNotes': ['woody'],
          'rankingStrategy': 'expensiveFirst',
        },
        'askSlot': 'notesOrIntensity',
        'productQueryCandidate': 'Rosendo Mateu',
        'reasonCode': 'model_ok',
      });

      expect(result.intent, 'recommendation');
      expect(result.confidence, 0.82);
      expect(result.preferencePatch.gender, 'unisex');
      expect(result.preferencePatch.season, 'winter');
      expect(result.preferencePatch.maxBudget, 1200);
      expect(result.preferencePatch.preferredNotes, contains('woody'));
      expect(
        result.preferencePatch.rankingStrategy,
        RankingStrategy.expensiveFirst,
      );
      expect(result.askSlot, 'notesOrIntensity');
      expect(result.productQueryCandidate, 'Rosendo Mateu');
      expect(result.hasPreferencePatch, isTrue);
    });

    test('keeps ranking-only patches as meaningful preference patches', () {
      final result = AIChatInterpretationResult.fromJson({
        'intent': 'recommendation',
        'confidence': 0.75,
        'preferencePatch': {'rankingStrategy': 'cheapestFirst'},
      });

      expect(
        result.preferencePatch.rankingStrategy,
        RankingStrategy.cheapestFirst,
      );
      expect(result.hasPreferencePatch, isTrue);
    });

    test('rejects invalid enums and marks forbidden fields', () {
      final result = AIChatInterpretationResult.fromJson({
        'intent': 'invent_products',
        'confidence': 2,
        'preferencePatch': {'gender': 'invalid', 'season': 'winter'},
        'askSlot': 'bad_slot',
        'product_ids': ['p1'],
      });

      expect(result.intent, 'unclear');
      expect(result.confidence, 1);
      expect(result.preferencePatch.gender, isNull);
      expect(result.preferencePatch.season, 'winter');
      expect(result.askSlot, isNull);
      expect(result.hasForbiddenFields, isTrue);
    });
  });
}
