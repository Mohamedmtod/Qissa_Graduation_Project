import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_message_builder.dart';

void main() {
  test(
    'external lookup failure copy is user-facing and avoids verified claims',
    () {
      final text = buildAvailabilityExternalLookupFailedMessage(
        AIChatLanguage.english,
        'Fake Sauvage',
      );

      expect(text, contains('could not identify'));
      expect(text, contains('full name or brand'));
      expect(text, contains('catalog'));
      expect(text.toLowerCase(), isNot(contains('external lookup failed')));
      expect(text.toLowerCase(), isNot(contains('verified profile')));
    },
  );
}
