import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

class PreferenceMutationHistoryEntry {
  final SessionPreferences before;
  final SessionPreferences after;
  final String source;
  final DateTime createdAt;

  const PreferenceMutationHistoryEntry({
    required this.before,
    required this.after,
    required this.source,
    required this.createdAt,
  });
}

class PreferenceMutationHistory {
  static const int defaultLimit = 5;

  final List<PreferenceMutationHistoryEntry> entries;
  final int limit;

  const PreferenceMutationHistory({
    this.entries = const <PreferenceMutationHistoryEntry>[],
    this.limit = defaultLimit,
  });

  factory PreferenceMutationHistory.empty({int limit = defaultLimit}) {
    return PreferenceMutationHistory(limit: limit);
  }

  bool get canUndo => entries.isNotEmpty;

  PreferenceMutationHistory push({
    required SessionPreferences before,
    required SessionPreferences after,
    required String source,
    DateTime? createdAt,
  }) {
    if (before == after) return this;
    final next = [
      ...entries,
      PreferenceMutationHistoryEntry(
        before: before,
        after: after,
        source: source,
        createdAt: createdAt ?? DateTime.now(),
      ),
    ];
    final trimmed = next.length > limit
        ? next.sublist(next.length - limit)
        : next;
    return PreferenceMutationHistory(
      entries: List<PreferenceMutationHistoryEntry>.unmodifiable(trimmed),
      limit: limit,
    );
  }

  PreferenceMutationUndoResult undo(SessionPreferences current) {
    if (entries.isEmpty) {
      return PreferenceMutationUndoResult(
        preferences: current,
        history: this,
        didUndo: false,
      );
    }
    final last = entries.last;
    return PreferenceMutationUndoResult(
      preferences: last.before,
      history: PreferenceMutationHistory(
        entries: List<PreferenceMutationHistoryEntry>.unmodifiable(
          entries.take(entries.length - 1),
        ),
        limit: limit,
      ),
      didUndo: true,
    );
  }
}

class PreferenceMutationUndoResult {
  final SessionPreferences preferences;
  final PreferenceMutationHistory history;
  final bool didUndo;

  const PreferenceMutationUndoResult({
    required this.preferences,
    required this.history,
    required this.didUndo,
  });
}
