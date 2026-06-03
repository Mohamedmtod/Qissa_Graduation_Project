import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_product_context_signals.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

void main() {
  group('AIChatProductContextSignals', () {
    const signals = AIChatProductContextSignals();

    test('detects product suitability context questions', () {
      final normalized = LocalIntentParser.normalizeInput(
        'is it suitable for work?',
      );

      expect(signals.looksLikeContextSuitabilityQuestion(normalized), isTrue);
      expect(
        signals.looksLikeExplicitProductContextQuestion(normalized),
        isTrue,
      );
      expect(signals.extractContextLabel(normalized), 'office');
    });

    test('classifies natural refinement conflict separately from product ask', () {
      final normalized = LocalIntentParser.normalizeInput(
        'make it suitable for university',
      );

      expect(
        signals.classifyRecommendationRefinementConflict(normalized),
        'refinement',
      );
    });

    test('routes messy suitability refinement to llm', () {
      final normalized = LocalIntentParser.normalizeInput(
        'i wwantit too suitable for university',
      );

      expect(
        signals.classifyRecommendationRefinementConflict(normalized),
        'llm',
      );
    });

    test('does not treat explicit product question as refinement', () {
      final normalized = LocalIntentParser.normalizeInput(
        'is this suitable for university?',
      );

      expect(
        signals.classifyRecommendationRefinementConflict(normalized),
        isNull,
      );
    });
  });
}
