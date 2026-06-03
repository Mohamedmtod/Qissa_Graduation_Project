import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/preference_mutation_executor.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/preference_mutation_history.dart';

void main() {
  group('PreferenceMutationHistory', () {
    test('undo restores previous preferences and removes last entry', () {
      const executor = PreferenceMutationExecutor();
      final first = executor.execute(
        current: const SessionPreferences(gender: 'men'),
        history: PreferenceMutationHistory.empty(),
        request: const PreferenceMutationRequest(
          operations: [
            PreferenceMutationOperation.setScalar(
              PreferenceScalar.intensity,
              'light',
            ),
          ],
        ),
      );
      final undo = executor.execute(
        current: first.preferences,
        history: first.history,
        request: const PreferenceMutationRequest(
          operations: [PreferenceMutationOperation.undo()],
        ),
      );

      expect(undo.didUndo, isTrue);
      expect(undo.preferences, const SessionPreferences(gender: 'men'));
      expect(undo.history.canUndo, isFalse);
    });

    test('history keeps only the configured number of entries', () {
      var history = PreferenceMutationHistory.empty(limit: 3);
      for (var index = 0; index < 5; index++) {
        history = history.push(
          before: SessionPreferences(maxBudget: index.toDouble()),
          after: SessionPreferences(maxBudget: index + 1.0),
          source: 'mutation_$index',
          createdAt: DateTime.utc(2026, 1, index + 1),
        );
      }

      expect(history.entries.length, 3);
      expect(history.entries.map((entry) => entry.source), [
        'mutation_2',
        'mutation_3',
        'mutation_4',
      ]);
    });

    test('undo on empty history is a no-op', () {
      final history = PreferenceMutationHistory.empty();
      const current = SessionPreferences(intensity: 'light');

      final undo = history.undo(current);

      expect(undo.didUndo, isFalse);
      expect(undo.preferences, current);
      expect(undo.history, history);
    });
  });
}
