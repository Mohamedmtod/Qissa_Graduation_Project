import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_preference_change_detector.dart';

void main() {
  const detector = AIChatPreferenceChangeDetector();

  test('detects scalar preference changes', () {
    const before = SessionPreferences(gender: 'men');
    const after = SessionPreferences(gender: 'women');

    expect(detector.hasPreferenceDelta(before, after), isTrue);
  });

  test('detects note constraint changes separately', () {
    const before = SessionPreferences(preferredNotes: ['citrus']);
    const after = SessionPreferences(preferredNotes: ['woody']);

    expect(detector.hasNoteConstraintDelta(before, after), isTrue);
    expect(detector.hasPreferenceDelta(before, after), isTrue);
  });

  test('preserves ordered list comparison semantics', () {
    const before = SessionPreferences(preferredNotes: ['citrus', 'woody']);
    const after = SessionPreferences(preferredNotes: ['woody', 'citrus']);

    expect(detector.hasPreferenceDelta(before, after), isTrue);
  });
}
