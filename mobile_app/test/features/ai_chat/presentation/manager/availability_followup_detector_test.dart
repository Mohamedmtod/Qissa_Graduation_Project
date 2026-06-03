import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_followup_detector.dart';

void main() {
  group('Availability follow-up signals', () {
    test('detects contextual similar + cheaper follow-up for pivot', () {
      final signal = analyzeAvailabilityFollowUpSignal(
        'is there any perfume like it but lower price?',
      );

      expect(signal.hasSimilarityTerm, isTrue);
      expect(signal.hasCheaperTerm, isTrue);
      expect(signal.hasContextRef, isTrue);
      expect(signal.hasExplicitAvailabilityProduct, isFalse);
      expect(signal.isContextualSimilarCheaperPivotCandidate, isTrue);
    });

    test('detects Arabic contextual similar + cheaper follow-up for pivot', () {
      final signal = analyzeAvailabilityFollowUpSignal(
        '\u0639\u0646\u062f\u0643 \u0639\u0637\u0631 \u0645\u0634\u0627\u0628\u0647 \u0628\u0633 \u0628\u0633\u0639\u0631 \u0627\u0642\u0644\u061f',
      );

      expect(signal.hasSimilarityTerm, isTrue);
      expect(signal.hasCheaperTerm, isTrue);
      expect(signal.hasContextRef, isTrue);
      expect(signal.isContextualSimilarCheaperPivotCandidate, isTrue);
    });

    test('detects colloquial Arabic similar cheaper continuation', () {
      final signal = analyzeAvailabilityFollowUpSignal(
        '\u0637\u064a\u0628 \u0631\u0634\u062d\u0644\u064a \u062d\u0627\u062c\u0629 \u0634\u0628\u0647\u0647 \u0628\u0633 \u0627\u0631\u062e\u0635',
      );

      expect(signal.hasSimilarityTerm, isTrue);
      expect(signal.hasCheaperTerm, isTrue);
      expect(signal.hasContextRef, isTrue);
      expect(signal.hasExplicitAvailabilityProduct, isFalse);
      expect(signal.isContextualSimilarCheaperPivotCandidate, isTrue);
    });

    test(
      'keeps explicit cheaper availability query out of pivot candidate set',
      () {
        final signal = analyzeAvailabilityFollowUpSignal(
          'is there cheaper Dior Sauvage available?',
        );

        expect(signal.hasCheaperTerm, isTrue);
        expect(signal.hasExplicitAvailabilityProduct, isTrue);
        expect(signal.isContextualSimilarCheaperPivotCandidate, isFalse);
      },
    );

    test('treats short English similarity-only follow-up as contextual', () {
      final examples = <String>[
        'show me something similar',
        'similar one',
        'something similar',
        'any alternative?',
      ];

      for (final message in examples) {
        final signal = analyzeAvailabilityFollowUpSignal(message);
        expect(signal.hasSimilarityTerm, isTrue, reason: message);
        expect(signal.hasExplicitAvailabilityProduct, isFalse, reason: message);
        expect(signal.isContextualSimilarityFollowUp, isTrue, reason: message);
      }
    });

    test('treats explicit anchored similarity as concrete product query', () {
      final signal = analyzeAvailabilityFollowUpSignal(
        'something similar to Bleu de Chanel',
      );

      expect(signal.hasSimilarityTerm, isTrue);
      expect(signal.hasExplicitAvailabilityProduct, isTrue);
      expect(signal.isContextualSimilarityFollowUp, isFalse);
    });

    test('does not treat Arabic "خليه" note edits as why follow-up', () {
      expect(
        looksLikeProductWhyFollowUp(
          '\u062e\u0644\u064a\u0647 \u0635\u0646\u062f\u0644 \u0645\u0639 \u0645\u0633\u0643',
        ),
        isFalse,
      );
      expect(
        looksLikeProductWhyFollowUp(
          '\u0644\u0627 \u0634\u064a\u0644 \u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627 \u0648\u062e\u0644\u064a\u0647 \u0635\u0646\u062f\u0644 \u0645\u0639 \u0645\u0633\u0643',
        ),
        isFalse,
      );
      expect(
        looksLikeProductDetailsFollowUp(
          '\u0644\u0627 \u0634\u064a\u0644 \u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627 \u0648\u062e\u0644\u064a\u0647 \u0635\u0646\u062f\u0644 \u0645\u0639 \u0645\u0633\u0643',
        ),
        isFalse,
      );
      expect(
        looksLikeProductWhyFollowUp(
          '\u0644\u064a\u0647 \u0631\u0634\u062d\u062a \u062f\u0647\u061f',
        ),
        isTrue,
      );
    });
  });
}
