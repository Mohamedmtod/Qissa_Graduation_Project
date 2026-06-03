import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

void main() {
  group('SessionPreferences policy helpers', () {
    test('gender + season forms a valid base profile', () {
      const prefs = SessionPreferences(gender: 'men', season: 'summer');

      expect(prefs.canRecommendInitial, isTrue);
      expect(prefs.hasSufficientCriteria, isTrue);
      expect(prefs.shouldAskBudgetBeforeInitialRecommendation, isTrue);
      expect(prefs.missingSlotsForNextQuestion(), contains('maxBudget'));
    });

    test('notes signal + one scalar is enough for initial recommendation', () {
      const prefs = SessionPreferences(
        season: 'winter',
        excludedNotes: ['oud'],
      );

      expect(prefs.canRecommendInitial, isTrue);
      expect(prefs.missingSlotsForNextQuestion(), isEmpty);
    });

    test('without enough criteria returns practical missing slots', () {
      const prefs = SessionPreferences(gender: 'men');

      final missing = prefs.missingSlotsForNextQuestion();

      expect(missing, contains('season'));
      expect(missing, contains('maxBudget'));
      expect(missing, contains('notesOrIntensity'));
    });

    test('open budget tag satisfies budget slot', () {
      const prefs = SessionPreferences(gender: 'men', tags: ['open_budget']);

      expect(prefs.missingSlotsForNextQuestion(), isNot(contains('maxBudget')));
    });

    test('open budget patch clears stale budget during merge', () {
      const current = SessionPreferences(
        maxBudget: 1500,
        occasion: 'formal',
        time: 'night',
        intensity: 'strong',
        tags: ['elegant', 'classic'],
      );
      const patch = SessionPreferences(
        occasion: 'formal',
        time: 'night',
        intensity: 'strong',
        tags: ['elegant', 'classic', 'open_budget'],
      );

      final merged = current.mergePatch(patch);

      expect(merged.maxBudget, isNull);
      expect(merged.occasion, 'formal');
      expect(merged.time, 'night');
      expect(merged.intensity, 'strong');
      expect(merged.tags, contains('open_budget'));
    });

    test(
      'gender + season alone still asks for budget before first recommendation',
      () {
        const prefs = SessionPreferences(gender: 'men', season: 'summer');

        expect(prefs.canRecommendInitial, isTrue);
        expect(prefs.shouldAskBudgetBeforeInitialRecommendation, isTrue);
        expect(prefs.missingSlotsForNextQuestion().first, 'maxBudget');
      },
    );

    test(
      'recommendation context allows refinement from a single patch signal',
      () {
        const prefs = SessionPreferences(gender: 'men', excludedNotes: ['oud']);

        expect(
          prefs.canRefineExistingRecommendation(hasRecommendationContext: true),
          isTrue,
        );
        expect(
          prefs.missingSlotsForNextQuestion(hasRecommendationContext: true),
          isEmpty,
        );
      },
    );

    test('unisex daily under budget is practical-ready', () {
      const prefs = SessionPreferences(
        gender: 'unisex',
        occasion: 'daily',
        maxBudget: 1000,
      );

      expect(prefs.canRecommendPracticalInitial, isTrue);
      expect(prefs.missingSlotsForNextQuestion(), isEmpty);
    });

    test('fresh under budget is practical-ready', () {
      const prefs = SessionPreferences(maxBudget: 1200, tags: ['fresh']);

      expect(prefs.canRecommendPracticalInitial, isTrue);
      expect(prefs.missingSlotsForNextQuestion(), isEmpty);
    });

    test('fresh university under budget is practical-ready', () {
      const prefs = SessionPreferences(
        maxBudget: 1200,
        occasion: 'university',
        tags: ['fresh'],
      );

      expect(prefs.canRecommendPracticalInitial, isTrue);
      expect(prefs.missingSlotsForNextQuestion(), isEmpty);
    });

    test('budget only is not practical-ready', () {
      const prefs = SessionPreferences(maxBudget: 1000);

      expect(prefs.canRecommendPracticalInitial, isFalse);
      expect(prefs.canRecommendInitial, isFalse);
      expect(prefs.missingSlotsForNextQuestion(), isNotEmpty);
    });

    test('generic empty preference is not practical-ready', () {
      const prefs = SessionPreferences();

      expect(prefs.canRecommendPracticalInitial, isFalse);
      expect(prefs.canRecommendInitial, isFalse);
      expect(prefs.missingSlotsForNextQuestion(), isNotEmpty);
    });

    test('ranking strategy survives json round trip and copyWith', () {
      const prefs = SessionPreferences(
        gender: 'men',
        rankingStrategy: RankingStrategy.expensiveFirst,
      );

      final roundTrip = SessionPreferences.fromJson(prefs.toJson());
      expect(roundTrip.rankingStrategy, RankingStrategy.expensiveFirst);

      final cleared = prefs.copyWith(clearRankingStrategy: true);
      expect(cleared.rankingStrategy, isNull);
    });
  });
}
