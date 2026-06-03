import 'package:perfume_app/features/recommendations/data/local/user_taste_local_data_source.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/models/user_taste_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef TasteUserIdResolver = String? Function();

class UserTasteRepo {
  final UserTasteLocalDataSource localDataSource;
  final TasteUserIdResolver _userIdResolver;

  UserTasteRepo({
    required this.localDataSource,
    TasteUserIdResolver? userIdResolver,
  }) : _userIdResolver = userIdResolver ?? _defaultUserIdResolver;

  static String? _defaultUserIdResolver() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static const Map<EventType, double> _eventWeights = <EventType, double>{
    EventType.view: 1,
    EventType.addToCart: 3,
    EventType.aiClick: 3,
    EventType.purchase: 5,
  };

  Future<UserTasteProfile> getTasteProfile({String? userId}) async {
    final resolvedUserId = _tryResolveUserId(userId);
    if (resolvedUserId == null) {
      return UserTasteProfile.empty;
    }
    final map = await localDataSource.getTasteProfileMap(resolvedUserId);
    if (map.isEmpty) return UserTasteProfile.empty;
    return UserTasteProfile.fromMap(map);
  }

  Future<void> recordEvent({
    required EventType eventType,
    required List<String> notes,
    String? userId,
  }) async {
    final normalizedNotes = _normalizeNotes(notes);
    if (normalizedNotes.isEmpty) return;

    final resolvedUserId = _tryResolveUserId(userId);
    if (resolvedUserId == null) {
      return;
    }
    final profile = await getTasteProfile(userId: resolvedUserId);
    final updatedScores = Map<String, double>.from(profile.noteScores);
    final weight = _eventWeights[eventType] ?? 1;

    for (final note in normalizedNotes) {
      updatedScores[note] = (updatedScores[note] ?? 0) + weight;
    }

    final updatedProfile = UserTasteProfile(noteScores: updatedScores);
    await localDataSource.saveTasteProfileMap(
      resolvedUserId,
      updatedProfile.toMap(),
    );
  }

  Future<List<String>> getTopNotes({int limit = 12, String? userId}) async {
    final profile = await getTasteProfile(userId: userId);
    return _sortedTopNotes(profile.noteScores, limit: limit);
  }

  Future<void> clear({String? userId}) {
    final resolvedUserId = _tryResolveUserId(userId);
    if (resolvedUserId == null) {
      return Future<void>.value();
    }
    return localDataSource.clear(resolvedUserId);
  }

  List<String> normalizeNotesForTesting(List<String> notes) {
    return _normalizeNotes(notes);
  }

  List<String> _sortedTopNotes(Map<String, double> scores, {required int limit}) {
    final entries = scores.entries.where((entry) => entry.value > 0).toList();
    entries.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      return a.key.compareTo(b.key);
    });

    return entries.take(limit).map((entry) => entry.key).toList();
  }

  List<String> _normalizeNotes(List<String> notes) {
    final unique = <String>{};
    for (final raw in notes) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      unique.add(normalized);
    }
    return unique.toList();
  }

  String? _tryResolveUserId(String? userId) {
    final explicit = userId?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;

    final current = _userIdResolver()?.trim() ?? '';
    if (current.isNotEmpty) return current;

    return null;
  }
}
