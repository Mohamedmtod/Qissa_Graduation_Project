import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfume_app/features/recommendations/data/local/user_taste_local_data_source.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';

void main() {
  late UserTasteRepo repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repo = UserTasteRepo(
      localDataSource: SharedPreferencesUserTasteLocalDataSource(),
      userIdResolver: () => 'user_a',
    );
  });

  test('applies event weights and merges scores', () async {
    await repo.recordEvent(
      eventType: EventType.view,
      notes: const ['Citrus', 'citrus', ''],
    );
    await repo.recordEvent(
      eventType: EventType.addToCart,
      notes: const ['citrus', 'oud'],
    );
    await repo.recordEvent(
      eventType: EventType.purchase,
      notes: const ['oud'],
    );

    final profile = await repo.getTasteProfile();
    expect(profile.noteScores['citrus'], 4); // view(1) + addToCart(3)
    expect(profile.noteScores['oud'], 8); // addToCart(3) + purchase(5)
  });

  test('persists profile across repo instances', () async {
    await repo.recordEvent(
      eventType: EventType.aiClick,
      notes: const ['amber'],
    );

    final freshRepo = UserTasteRepo(
      localDataSource: SharedPreferencesUserTasteLocalDataSource(),
      userIdResolver: () => 'user_a',
    );
    final profile = await freshRepo.getTasteProfile();

    expect(profile.noteScores['amber'], 3);
  });

  test('returns top notes sorted by score then alphabetical', () async {
    await repo.recordEvent(eventType: EventType.purchase, notes: const ['oud']);
    await repo.recordEvent(eventType: EventType.addToCart, notes: const ['amber']);
    await repo.recordEvent(eventType: EventType.addToCart, notes: const ['citrus']);

    final top = await repo.getTopNotes(limit: 3);
    expect(top, const ['oud', 'amber', 'citrus']);
  });

  test('normalization removes invalid and duplicate notes per event', () async {
    await repo.recordEvent(
      eventType: EventType.view,
      notes: const ['  ', 'ROSE', 'rose', ' Rose '],
    );

    final profile = await repo.getTasteProfile();
    expect(profile.noteScores.length, 1);
    expect(profile.noteScores['rose'], 1);
  });

  test('keeps taste profile isolated per user', () async {
    await repo.recordEvent(
      eventType: EventType.purchase,
      notes: const ['oud'],
    );

    final userBRepo = UserTasteRepo(
      localDataSource: SharedPreferencesUserTasteLocalDataSource(),
      userIdResolver: () => 'user_b',
    );
    final userBProfile = await userBRepo.getTasteProfile();
    final userAProfile = await repo.getTasteProfile();

    expect(userAProfile.noteScores['oud'], 5);
    expect(userBProfile.noteScores, isEmpty);
  });

  test('does not persist taste data when no user id is resolvable', () async {
    final anonymousRepo = UserTasteRepo(
      localDataSource: SharedPreferencesUserTasteLocalDataSource(),
      userIdResolver: () => null,
    );

    await anonymousRepo.recordEvent(
      eventType: EventType.purchase,
      notes: const ['amber'],
    );

    final anonymousTopNotes = await anonymousRepo.getTopNotes(limit: 5);
    final userAProfile = await repo.getTasteProfile();

    expect(anonymousTopNotes, isEmpty);
    expect(userAProfile.noteScores, isEmpty);
  });
}
