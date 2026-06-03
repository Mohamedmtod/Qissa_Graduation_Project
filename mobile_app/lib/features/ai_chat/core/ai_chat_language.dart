enum AIChatLanguage {
  arabic,
  english,
}

extension AIChatLanguageX on AIChatLanguage {
  String get code => this == AIChatLanguage.english ? 'en' : 'ar';

  bool get isArabic => this == AIChatLanguage.arabic;
}

class AIChatLanguageDetector {
  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _englishRegex = RegExp(r'[A-Za-z]');

  static AIChatLanguage detect(String text) {
    if (_arabicRegex.hasMatch(text)) return AIChatLanguage.arabic;
    if (_englishRegex.hasMatch(text)) return AIChatLanguage.english;
    return AIChatLanguage.arabic;
  }
}
