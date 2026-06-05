import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

String buildWelcomeText(AIChatLanguage language) {
  return language.isArabic
      ? 'أهلًا بك في مساعد العطور. أخبرني بالنوع أو النوتات أو الميزانية التي تريدها، وسأرشح لك الأنسب.'
      : 'Welcome to the perfume assistant. Tell me the style, notes, or budget you want, and I will suggest the best matches.';
}

String buildWorkerUnavailableText(AIChatLanguage language) {
  if (language.isArabic) {
    return 'المساعد الذكي غير متاح للحظات. جرّب تاني، أو اكتب طلب العطر بوضوح وسأستخدم القواعد الآمنة المتاحة.';
  }
  return 'The AI assistant is temporarily unavailable. Try again, or send a clear perfume request and I will use the available safe rules.';
}

String buildSocialGreetingFallbackText(AIChatLanguage language) {
  return language.isArabic
      ? 'أهلاً! قلّي تفضيلاتك مثل النوع أو النوتات أو الميزانية، وسأرشح لك الأنسب.'
      : 'Hello! Tell me your preferences like gender, notes, or budget, and I will suggest the best fit.';
}

String buildSocialMicroTurnText(AIChatLanguage language) {
  return language.isArabic
      ? 'أنا بخير، جاهز أساعدك تختار عطر مناسب. قلّي بتحب ريحة منعشة، حلوة، قوية، أو ميزانية معينة؟'
      : 'I am doing well and ready to help you choose a perfume. Tell me if you want something fresh, sweet, strong, soft, or a specific budget.';
}

String buildDialogueNoPerfumeIntentText(AIChatLanguage language) {
  return language.isArabic
      ? 'أنا جاهز أساعدك تختار عطر مناسب. قلّي بتحب ريحة منعشة، قوية، حلوة، أو ميزانية معينة؟'
      : 'I can help you choose a perfume. Tell me the style, notes, occasion, or budget you want.';
}

String buildCompareWithoutContextClarificationText(AIChatLanguage language) {
  return language.isArabic
      ? 'حدّد لي المنتجين اللذين تريد مقارنتهما، مثل: قارن بين 1 و2.'
      : 'Please tell me which two products to compare, for example: compare 1 and 2.';
}

String buildVagueInputFallbackText(AIChatLanguage language) {
  return language.isArabic
      ? 'لم أفهم طلبك بشكل كافٍ. اكتب الميزانية أو النوتات المفضلة أو نوع الرائحة التي تريدها.'
      : 'I could not understand your preferences clearly. Please share your budget, preferred notes, or scent style.';
}

String buildMissingSlotGenericText(AIChatLanguage language) {
  return language.isArabic
      ? 'ممكن توضح تفضيل إضافي واحد عشان أدقق الترشيح؟'
      : 'Could you share one more preference so I can refine the recommendation?';
}

String buildQuestionForMissingSlot(String? slot, AIChatLanguage language) {
  if (slot == 'season') {
    return language.isArabic
        ? 'تفضل العطر للصيف ولا للشتاء ولا لأي موسم؟'
        : 'Do you want it for summer, winter, or any season?';
  }

  switch (slot) {
    case 'gender':
      return language.isArabic
          ? 'تفضل عطر رجالي ولا نسائي؟'
          : 'Do you prefer a men\'s or women\'s perfume?';
    case 'season':
      return language.isArabic
          ? 'تفضل العطر للصيف ولا للشتاء؟'
          : 'Do you want it for summer or winter?';
    case 'maxBudget':
      return language.isArabic
          ? 'ميزانيتك التقريبية كام؟'
          : 'What is your approximate budget?';
    case 'notesOrIntensity':
      return language.isArabic
          ? 'هل تفضل نوتات معينة أو درجة فوحان محددة؟'
          : 'Do you prefer specific notes or a certain intensity?';
    default:
      return buildMissingSlotGenericText(language);
  }
}

String buildContextualQuestionForMissingSlot(
  String? slot,
  AIChatLanguage language,
  SessionPreferences preferences, {
  required bool hasRecommendationContext,
  String? fallbackQuestion,
}) {
  final baseQuestion =
      fallbackQuestion ?? buildQuestionForMissingSlot(slot, language);
  final summary = _preferenceSummary(language, preferences);
  if (summary.isEmpty) return baseQuestion;

  final contextualQuestion = switch (slot) {
    'gender' =>
      language.isArabic
          ? 'تمام، فهمت إنك عايز $summary. أخلّي الاختيار رجالي ولا حريمي ولا للجنسين؟'
          : 'I understand you want $summary. Should I keep it men, women, or unisex?',
    'season' =>
      language.isArabic
          ? 'تمام، فهمت إنك عايز $summary. الاستخدام صيفي ولا شتوي ولا لكل المواسم؟'
          : 'I understand you want $summary. Is this for summer, winter, or all seasons?',
    'maxBudget' =>
      language.isArabic
          ? 'تمام، فهمت إنك عايز $summary. ميزانيتك التقريبية كام؟'
          : 'I understand you want $summary. What approximate budget should I stay within?',
    'notesOrIntensity' =>
      language.isArabic
          ? 'تمام، فهمت إنك عايز $summary. تحب نوتات معينة أو درجة فوحان محددة؟'
          : 'I understand you want $summary. Any preferred notes or intensity level?',
    _ =>
      language.isArabic
          ? 'تمام، فهمت إنك عايز $summary. $baseQuestion'
          : 'I understand you want $summary. $baseQuestion',
  };

  return contextualQuestion;
}

String _preferenceSummary(
  AIChatLanguage language,
  SessionPreferences preferences,
) {
  final parts = <String>[];

  String label(String value) {
    final normalized = value.trim().toLowerCase();
    if (!language.isArabic) return normalized.replaceAll('_', ' ');
    return switch (normalized) {
      'men' => 'رجالي',
      'women' => 'حريمي',
      'unisex' => 'للجنسين',
      'summer' => 'صيفي',
      'winter' => 'شتوي',
      'all_seasons' => 'لكل المواسم',
      'strong' => 'فواح',
      'medium' => 'متوسط الفوحان',
      'light' => 'هادي',
      'formal' => 'رسمي',
      'daily' => 'يومي',
      'office' => 'للشغل',
      'work' => 'للشغل',
      'all_day' => 'طول اليوم',
      'evening' => 'للسهرة',
      'date' => 'لموعد',
      'casual' => 'كاجوال',
      'fresh' => 'فريش',
      'clean' => 'نظيف',
      'oud' => 'عود',
      'musk' => 'مسك',
      'vanilla' => 'فانيليا',
      'woody' => 'خشبي',
      'citrus' => 'حمضيات',
      'spicy' => 'توابل',
      'amber' => 'عنبر',
      'gift' => 'هدية',
      'elegant' => 'أنيق',
      'classic' => 'كلاسيكي',
      'bold' => 'واضح',
      'masculine' => 'بطابع رجالي',
      'romantic' => 'رومانسي',
      _ => normalized.replaceAll('_', ' '),
    };
  }

  if (preferences.gender != null) parts.add(label(preferences.gender!));
  if (preferences.season != null) parts.add(label(preferences.season!));
  if (preferences.occasion != null) parts.add(label(preferences.occasion!));
  if (preferences.time != null) parts.add(label(preferences.time!));
  if (preferences.intensity != null) parts.add(label(preferences.intensity!));
  if (preferences.maxBudget != null) {
    parts.add(
      language.isArabic
          ? 'في حدود ${preferences.maxBudget!.round()} جنيه'
          : 'within ${preferences.maxBudget!.round()} EGP',
    );
  }
  for (final note in preferences.preferredNotes.take(2)) {
    parts.add(label(note));
  }
  for (final tag in preferences.tags.take(2)) {
    if (tag == 'open_budget') continue;
    parts.add(label(tag));
  }

  final uniqueParts = <String>[];
  for (final part in parts) {
    final cleaned = part.trim();
    if (cleaned.isEmpty || uniqueParts.contains(cleaned)) continue;
    uniqueParts.add(cleaned);
  }

  if (uniqueParts.isEmpty) return '';
  return uniqueParts.take(4).join(language.isArabic ? ' و' : ', ');
}
