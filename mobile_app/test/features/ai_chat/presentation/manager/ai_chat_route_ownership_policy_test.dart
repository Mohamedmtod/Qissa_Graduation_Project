import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_route_ownership_policy.dart';

void main() {
  group('AIChatRouteOwnershipPolicy', () {
    const policy = AIChatRouteOwnershipPolicy();

    test('classifies exact deterministic and semantic ownership', () {
      final availability = policy.classify('Do you have Light Blue?');
      expect(
        availability.ownershipClass,
        AIChatRouteOwnershipClass.localDeterministic,
      );

      final note = policy.classify('is there with mango?');
      expect(note.ownershipClass, AIChatRouteOwnershipClass.llmSemantic);
      expect(note.semanticIntent, AIChatSemanticIntent.noteSearch);
      expect(note.localSkippedReason, 'note_request_without_product_anchor');

      final subjective = policy.classify('which one is better?');
      expect(subjective.ownershipClass, AIChatRouteOwnershipClass.llmSemantic);
      expect(
        subjective.semanticIntent,
        AIChatSemanticIntent.subjectiveVisibleQuestion,
      );

      final external = policy.classify('Something like Dior Sauvage');
      expect(external.ownershipClass, AIChatRouteOwnershipClass.llmSemantic);
      expect(external.semanticIntent, AIChatSemanticIntent.externalReference);
    });

    test('classifies occasion and luxury-store scent requests as semantic', () {
      final interview = policy.classify('عندي interview وعايز ريحة كويسة.');
      expect(interview.ownershipClass, AIChatRouteOwnershipClass.llmSemantic);
      expect(
        interview.semanticIntent,
        AIChatSemanticIntent.recommendationRefinement,
      );

      final luxuryStore = policy.classify(
        'عايز عطر ريحته زي محل براندات فخمة.',
      );
      expect(luxuryStore.ownershipClass, AIChatRouteOwnershipClass.llmSemantic);
      expect(luxuryStore.semanticIntent, AIChatSemanticIntent.vibeSearch);

      final luxuryStores = policy.classify('عايز عطر شبه ريحة المحلات الفخمة.');
      expect(
        luxuryStores.ownershipClass,
        AIChatRouteOwnershipClass.llmSemantic,
      );
      expect(luxuryStores.semanticIntent, AIChatSemanticIntent.vibeSearch);
    });

    test('classifies contextual Arabic pilot requests as semantic', () {
      final outdoorEvent = policy.classify(
        '\u0639\u0646\u062f\u064a \u0645\u0646\u0627\u0633\u0628\u0629 \u0641\u064a \u0645\u0643\u0627\u0646 \u0645\u0641\u062a\u0648\u062d\u060c \u0623\u0633\u062a\u062e\u062f\u0645 \u0625\u064a\u0647\u061f',
      );
      expect(
        outdoorEvent.ownershipClass,
        AIChatRouteOwnershipClass.llmSemantic,
      );
      expect(
        outdoorEvent.semanticIntent,
        AIChatSemanticIntent.recommendationRefinement,
      );

      final clientMeetings = policy.classify(
        '\u0634\u063a\u0644\u064a \u0641\u064a\u0647 \u0645\u0642\u0627\u0628\u0644\u0629 \u0639\u0645\u0644\u0627\u0621 \u0643\u062a\u064a\u0631\u060c \u0645\u062d\u062a\u0627\u062c \u0639\u0637\u0631 \u0645\u0646\u0627\u0633\u0628.',
      );
      expect(
        clientMeetings.ownershipClass,
        AIChatRouteOwnershipClass.llmSemantic,
      );
      expect(
        clientMeetings.semanticIntent,
        AIChatSemanticIntent.recommendationRefinement,
      );

      final bedtime = policy.classify(
        '\u0639\u0627\u064a\u0632\u0629 \u0639\u0637\u0631 \u0644\u0644\u0646\u0648\u0645.',
      );
      expect(bedtime.ownershipClass, AIChatRouteOwnershipClass.llmSemantic);
      expect(bedtime.semanticIntent, AIChatSemanticIntent.vibeSearch);
    });
  });
}
