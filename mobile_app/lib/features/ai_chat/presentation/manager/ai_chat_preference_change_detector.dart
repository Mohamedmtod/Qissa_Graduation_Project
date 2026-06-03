import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

class AIChatPreferenceChangeDetector {
  const AIChatPreferenceChangeDetector();

  bool hasPreferenceDelta(SessionPreferences before, SessionPreferences after) {
    return before.gender != after.gender ||
        before.maxBudget != after.maxBudget ||
        before.season != after.season ||
        before.occasion != after.occasion ||
        before.time != after.time ||
        before.intensity != after.intensity ||
        before.rankingStrategy != after.rankingStrategy ||
        !listsEqual(before.preferredNotes, after.preferredNotes) ||
        !listsEqual(before.preferredTopNotes, after.preferredTopNotes) ||
        !listsEqual(before.preferredMiddleNotes, after.preferredMiddleNotes) ||
        !listsEqual(before.preferredBaseNotes, after.preferredBaseNotes) ||
        !listsEqual(before.excludedNotes, after.excludedNotes) ||
        !listsEqual(before.medicalExcludedNotes, after.medicalExcludedNotes) ||
        !listsEqual(before.tags, after.tags);
  }

  bool hasNoteConstraintDelta(
    SessionPreferences before,
    SessionPreferences after,
  ) {
    return !listsEqual(before.preferredNotes, after.preferredNotes) ||
        !listsEqual(before.preferredTopNotes, after.preferredTopNotes) ||
        !listsEqual(before.preferredMiddleNotes, after.preferredMiddleNotes) ||
        !listsEqual(before.preferredBaseNotes, after.preferredBaseNotes) ||
        !listsEqual(before.excludedNotes, after.excludedNotes) ||
        !listsEqual(before.medicalExcludedNotes, after.medicalExcludedNotes);
  }

  bool listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
