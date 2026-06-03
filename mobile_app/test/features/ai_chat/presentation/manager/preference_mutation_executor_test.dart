import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/preference_mutation_executor.dart';

void main() {
  group('PreferenceMutationExecutor', () {
    const executor = PreferenceMutationExecutor();

    test('structured set intensity light updates scalar only', () {
      final result = executor.execute(
        current: const SessionPreferences(gender: 'men'),
        request: const PreferenceMutationRequest(
          operations: [
            PreferenceMutationOperation.setScalar(
              PreferenceScalar.intensity,
              'light',
            ),
          ],
        ),
      );

      expect(result.preferences.intensity, 'light');
      expect(result.preferences.gender, 'men');
      expect(result.preferences.excludedNotes, isEmpty);
      expect(result.didMutate, isTrue);
      expect(result.history.canUndo, isTrue);
    });

    test('structured clear intensity does not become excluded note', () {
      final result = executor.execute(
        current: const SessionPreferences(
          intensity: 'light',
          excludedNotes: ['vanilla'],
        ),
        request: const PreferenceMutationRequest(
          operations: [
            PreferenceMutationOperation.clearScalar(PreferenceScalar.intensity),
          ],
        ),
      );

      expect(result.preferences.intensity, isNull);
      expect(result.preferences.excludedNotes, ['vanilla']);
    });

    test('set light again after clear works', () {
      final cleared = executor.execute(
        current: const SessionPreferences(intensity: 'strong'),
        request: const PreferenceMutationRequest(
          operations: [
            PreferenceMutationOperation.clearScalar(PreferenceScalar.intensity),
          ],
        ),
      );
      final setAgain = executor.execute(
        current: cleared.preferences,
        history: cleared.history,
        request: const PreferenceMutationRequest(
          operations: [
            PreferenceMutationOperation.setScalar(
              PreferenceScalar.intensity,
              'light',
            ),
          ],
        ),
      );

      expect(cleared.preferences.intensity, isNull);
      expect(setAgain.preferences.intensity, 'light');
      expect(setAgain.history.entries.length, 2);
    });

    test(
      'without light modeled as clear scalar does not touch excluded notes',
      () {
        final result = executor.execute(
          current: const SessionPreferences(intensity: 'light'),
          request: const PreferenceMutationRequest(
            source: 'structured_without_light',
            operations: [
              PreferenceMutationOperation.clearScalar(
                PreferenceScalar.intensity,
              ),
            ],
          ),
        );

        expect(result.preferences.intensity, isNull);
        expect(result.preferences.excludedNotes, isEmpty);
        expect(result.preferences.preferredNotes, isEmpty);
      },
    );

    test('list operations mutate only requested list fields', () {
      final result = executor.execute(
        current: const SessionPreferences(preferredNotes: ['musk']),
        request: PreferenceMutationRequest(
          operations: [
            PreferenceMutationOperation.appendList(
              PreferenceListField.preferredNotes,
              ['citrus'],
            ),
            PreferenceMutationOperation.removeFromList(
              PreferenceListField.preferredNotes,
              ['musk'],
            ),
          ],
        ),
      );

      expect(result.preferences.preferredNotes, ['citrus']);
      expect(result.preferences.excludedNotes, isEmpty);
    });

    test('applyPatch executes worker style structured patch', () {
      final patch = PreferencePatch()
        ..setScalar(PreferenceScalar.intensity, 'strong')
        ..appendList(PreferenceListField.tags, ['bold']);
      final result = executor.applyPatch(
        current: const SessionPreferences(intensity: 'light'),
        patch: patch,
        source: 'worker_preference_patch',
      );

      expect(result.preferences.intensity, 'strong');
      expect(result.preferences.tags, ['bold']);
      expect(result.history.entries.single.source, 'worker_preference_patch');
    });
  });
}
