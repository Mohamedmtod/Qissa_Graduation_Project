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
  });
}
