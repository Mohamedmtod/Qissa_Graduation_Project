import 'dart:convert';

class AIChatTextNormalizer {
  static final RegExp _arabicDiacritics = RegExp(r'[\u064B-\u0652\u0670]');
  static final RegExp _arabicScript = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _likelyMojibake = RegExp(r'[ÐÑØÙŠЩШЃЉ]');
  static const Map<String, String> _normalizedDigits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  static const Map<String, String> _francoPhrases = {
    '3awez': 'عايز',
    'عاوز': 'عايز',
    '3ayez': 'عايز',
    '3etr': 'عطر',
    'etr': 'عطر',
    '3otr': 'عطر',
    'rkhis': 'رخيص',
    'rekhis': 'رخيص',
    'lel gam3a': 'university',
    'lelgam3a': 'university',
    'gam3a': 'university',
    'gamaa': 'university',
    'gam3ah': 'university',
    'lel gym': 'جيم',
    'lelgym': 'جيم',
    'gym': 'gym',
    'fresh': 'fresh',
    'sweet': 'sweet',
    'long lasting': 'long lasting',
    'long-lasting': 'long lasting',
    'office': 'office',
    'longlasting': 'long lasting',
    'gamda': 'جامد',
    'boss': 'boss',
    'vip': 'vip',
    'masterpiece': 'masterpiece',
    'interview': 'interview',
    'bedtime': 'bedtime',
    'sleep': 'sleep',
    'sleeping': 'sleep',
    'workout': 'workout',
    'لابتوب': 'laptop',
    'لاب توب': 'laptop',
    'ماك بوك': 'macbook',
    'ماكبوك': 'macbook',
    'انترفيو': 'interview',
    'مقابله شغل': 'interview',
    'مقابلة شغل': 'interview',
    'قبل ما انام': 'bedtime',
    'قبل ما أنام': 'bedtime',
    'قبل النوم': 'bedtime',
    'للنوم': 'bedtime',
    'يريح الاعصاب': 'bedtime',
    'يريح الأعصاب': 'bedtime',
    'الحرم الجامعي': 'campus day',
    'تستحمل الحر': 'hot campus day',
    'بلعب حديد': 'heavy workout',
    'بشيل اوزان': 'heavy workout',
    'بشيل أوزان': 'heavy workout',
    'بعرق كتير': 'heavy workout',
    'الفلوس مش مشكلة': 'money is no object',
    'تحفة فنية': 'masterpiece',
    'تحفه فنيه': 'masterpiece',
    'حل وسط': 'balanced',
    'يرضينا احنا الاتنين': 'balanced',
    'يرضينا احنا الاثنين': 'balanced',
  };

  static const Map<String, String> _highConfidenceTypos = {
    'رجلي': 'رجالي',
    'عتر': 'عطر',
    'رخيس': 'رخيص',
    'عيظ': 'عايز',
    'برفان': 'عطر',
    'حنين': 'رخيص',
    'اخر الشارع': 'فواح',
    'آخر الشارع': 'فواح',
    'للجامعه': 'جامعه',
    'للجيم': 'جيم',
    'اقوي': 'قوي',
    'اقوى': 'قوي',
    'أقوي': 'قوي',
    'أقوى': 'قوي',
    'سويت اكتر': 'sweet',
    'حلو اكتر': 'sweet',
    'عملي': 'clean',
    'شيك': 'elegant',
  };

  static const Map<String, String> _englishDomainTypos = {
    'suumer': 'summer',
    'sumemr': 'summer',
    'summr': 'summer',
    'universty': 'university',
    'univercity': 'university',
    'univesity': 'university',
    'masuline': 'masculine',
    'masculin': 'masculine',
    'manli': 'manly',
  };

  static String normalizeForParsing(String input) {
    var result = _decodeLikelyMojibake(input).toLowerCase().trim();
    result = result.replaceAll(_arabicDiacritics, '');
    result = result.replaceAll('ـ', '');
    result = result
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه');

    _normalizedDigits.forEach((pattern, replacement) {
      result = result.replaceAll(pattern, replacement);
    });

    _francoPhrases.forEach((pattern, replacement) {
      result = result.replaceAll(pattern, replacement);
    });

    _highConfidenceTypos.forEach((pattern, replacement) {
      result = result.replaceAll(pattern, replacement);
    });

    _englishDomainTypos.forEach((pattern, replacement) {
      result = result.replaceAll(RegExp('\\b$pattern\\b'), replacement);
    });

    result = result.replaceAll(RegExp(r'\b(and|&)\b'), ' ');
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result.trim();
  }

  static String _decodeLikelyMojibake(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    if (_arabicScript.hasMatch(trimmed)) return trimmed;
    if (!_likelyMojibake.hasMatch(trimmed)) return trimmed;

    try {
      final decoded = utf8.decode(latin1.encode(trimmed), allowMalformed: true);
      if (_arabicScript.hasMatch(decoded)) {
        return decoded;
      }
    } catch (_) {}

    return trimmed;
  }
}
