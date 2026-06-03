import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

String buildPreferenceSummary(
  SessionPreferences preferences, {
  required AIChatLanguage language,
}) {
  final details = <String>[];
  void addLine(String label, String value) {
    details.add('$label: $value');
  }

  if (preferences.gender != null) {
    addLine(
      language.isArabic ? 'النوع' : 'Gender',
      language.isArabic
          ? preferences.gender == 'men'
                ? 'رجالي'
                : preferences.gender == 'women'
                ? 'نسائي'
                : 'للجنسين'
          : preferences.gender == 'men'
          ? 'Men'
          : preferences.gender == 'women'
          ? 'Women'
          : 'Unisex',
    );
  }
  if (preferences.maxBudget != null) {
    addLine(
      language.isArabic ? 'الميزانية' : 'Budget',
      '${preferences.maxBudget!.toStringAsFixed(0)} EGP',
    );
  }
  if (preferences.season != null) {
    addLine(language.isArabic ? 'الموسم' : 'Season', preferences.season!);
  }
  if (preferences.occasion != null) {
    addLine(language.isArabic ? 'المناسبة' : 'Occasion', preferences.occasion!);
  }
  if (preferences.time != null) {
    addLine(language.isArabic ? 'الوقت' : 'Time', preferences.time!);
  }
  if (preferences.intensity != null) {
    addLine(
      language.isArabic ? 'الفوحان' : 'Intensity',
      _displayScalar(preferences.intensity!, language),
    );
  }
  if (preferences.preferredNotes.isNotEmpty) {
    addLine(
      language.isArabic ? 'النوتات المفضلة' : 'Preferred notes',
      preferences.preferredNotes.join(', '),
    );
  }
  if (preferences.excludedNotes.isNotEmpty) {
    addLine(
      language.isArabic ? 'مستبعد' : 'Excluded',
      preferences.excludedNotes.join(', '),
    );
  }
  final visibleTags = preferences.tags
      .where((tag) => tag != 'open_budget')
      .toList(growable: false);
  if (visibleTags.isNotEmpty) {
    addLine(language.isArabic ? 'الطابع' : 'Vibe', visibleTags.join(', '));
  }

  if (details.isEmpty) {
    return language.isArabic
        ? 'لحد دلوقتي ما فيش قيود واضحة كفاية. قول لي النوع أو الميزانية أو النوتات اللي تفضلها.'
        : 'So far there are not enough clear constraints. Tell me the gender, budget, or notes you prefer.';
  }

  final intro = language.isArabic
      ? 'لحد دلوقتي أنت طالب:'
      : 'So far, you are asking for:';
  return '$intro\n${details.join('\n')}';
}

String _displayScalar(String value, AIChatLanguage language) {
  if (!language.isArabic) return value;
  return switch (value.trim().toLowerCase().replaceAll('_', ' ')) {
    'light' => 'هادي',
    'medium' => 'متوسط',
    'strong' => 'قوي',
    _ => value,
  };
}
