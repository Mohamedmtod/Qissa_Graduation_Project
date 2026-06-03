import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

void main() {
  group('PreferencePatch', () {
    test('sets and clears scalar preferences explicitly', () {
      final result =
          (PreferencePatch()
                ..setScalar(PreferenceScalar.gender, 'women')
                ..setScalar(PreferenceScalar.season, 'winter')
                ..clearScalar(PreferenceScalar.maxBudget))
              .applyTo(
                const SessionPreferences(
                  gender: 'men',
                  season: 'summer',
                  maxBudget: 1500,
                ),
              );

      expect(result.gender, 'women');
      expect(result.season, 'winter');
      expect(result.maxBudget, isNull);
    });

    test('replaces, appends, and removes list values deterministically', () {
      final result =
          (PreferencePatch()
                ..replaceList(PreferenceListField.preferredNotes, ['vanilla'])
                ..appendList(PreferenceListField.preferredNotes, ['citrus'])
                ..removeFromList(PreferenceListField.preferredNotes, [
                  'vanilla',
                ])
                ..appendList(PreferenceListField.excludedNotes, ['oud']))
              .applyTo(
                const SessionPreferences(
                  preferredNotes: ['musk'],
                  excludedNotes: ['rose'],
                ),
              );

      expect(result.preferredNotes, ['citrus']);
      expect(result.excludedNotes, containsAll(['rose', 'oud']));
    });

    test('start-over style reset can replace all list fields and scalars', () {
      final result =
          (PreferencePatch()
                ..clearScalar(PreferenceScalar.gender)
                ..clearScalar(PreferenceScalar.season)
                ..clearScalar(PreferenceScalar.maxBudget)
                ..replaceList(PreferenceListField.preferredNotes, const [])
                ..replaceList(PreferenceListField.excludedNotes, const []))
              .applyTo(
                const SessionPreferences(
                  gender: 'men',
                  season: 'winter',
                  maxBudget: 2000,
                  preferredNotes: ['oud'],
                  excludedNotes: ['citrus'],
                ),
              );

      expect(result.gender, isNull);
      expect(result.season, isNull);
      expect(result.maxBudget, isNull);
      expect(result.preferredNotes, isEmpty);
      expect(result.excludedNotes, isEmpty);
    });

    test('parses explicit worker patch contract from json', () {
      final patch = PreferencePatch.fromJson({
        'clearScalars': ['maxBudget'],
        'replaceLists': {
          'preferredNotes': ['citrus'],
        },
        'removeLists': {
          'excludedNotes': ['oud'],
        },
      });

      final result = patch.applyTo(
        const SessionPreferences(
          maxBudget: 1500,
          preferredNotes: ['vanilla'],
          excludedNotes: ['oud', 'musk'],
        ),
      );

      expect(result.maxBudget, isNull);
      expect(result.preferredNotes, ['citrus']);
      expect(result.excludedNotes, ['musk']);
    });

    test('parses v2 replaceScalars alias from json', () {
      final patch = PreferencePatch.fromJson({
        'replaceScalars': {'season': 'all_seasons'},
      });

      final result = patch.applyTo(
        const SessionPreferences(gender: 'women', season: 'summer'),
      );

      expect(result.gender, 'women');
      expect(result.season, 'all_seasons');
    });

    test('serializes and applies ranking strategy patches', () {
      final patch = PreferencePatch()
        ..setScalar(
          PreferenceScalar.rankingStrategy,
          RankingStrategy.expensiveFirst,
        )
        ..clearScalar(PreferenceScalar.maxBudget);

      final json = patch.toJson();
      expect(json['setScalars'], equals({'rankingStrategy': 'expensiveFirst'}));
      expect(json['clearScalars'], equals(['maxBudget']));

      final roundTrip = PreferencePatch.fromJson(json);
      final result = roundTrip.applyTo(
        const SessionPreferences(
          rankingStrategy: RankingStrategy.cheapestFirst,
          maxBudget: 1200,
        ),
      );

      expect(result.rankingStrategy, RankingStrategy.expensiveFirst);
      expect(result.maxBudget, isNull);
    });
  });
}
