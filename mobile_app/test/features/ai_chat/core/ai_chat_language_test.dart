import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';

void main() {
  group('AIChatLanguageDetector', () {
    test('detects Arabic and English messages correctly', () {
      expect(
        AIChatLanguageDetector.detect('عايز عطر صيفي'),
        AIChatLanguage.arabic,
      );
      expect(
        AIChatLanguageDetector.detect('I want a summer perfume'),
        AIChatLanguage.english,
      );
    });
  });
}
