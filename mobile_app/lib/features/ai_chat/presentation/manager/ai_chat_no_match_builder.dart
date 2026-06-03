import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

String buildNoMatchMessage(
  String message,
  SessionPreferences preferences,
  List<ProductModel> catalog,
  AIChatLanguage language, {
  String? reasonCode,
}) {
  final minPrice = _minCatalogPrice(catalog);
  final maxBudget = preferences.maxBudget;
  final normalized = message.toLowerCase();
  final wantsAquaticOud =
      preferences.preferredNotes.contains('aquatic') &&
      preferences.preferredNotes.contains('oud');

  if (maxBudget != null && minPrice != null && maxBudget < minPrice) {
    return _budgetBelowMinimum(language, maxBudget, minPrice);
  }

  switch (reasonCode) {
    case 'budget_no_match':
    case 'strict_budget_no_match':
      if (maxBudget != null) return _budgetNoMatch(language, maxBudget);
      break;
    case 'excluded_note_no_match':
      if (preferences.excludedNotes.isNotEmpty) {
        return _excludedNotesNoMatch(language, preferences.excludedNotes);
      }
      break;
    case 'external_known_no_substitute':
    case 'external_low_confidence':
      return _externalKnownNoSubstitute(language);
    case 'unknown_product_no_profile':
    case 'availability_not_found_unknown':
      return _unknownExternalNoProfile(language);
    case 'missing_required_note_data':
      return _missingNoteData(language);
    case 'strong_scent_no_match':
    case 'scent_no_match':
      return _scentNoMatch(language, preferences);
    case 'context_no_match':
      return _contextNoMatch(language);
  }

  if (wantsAquaticOud) {
    return language.isArabic
        ? 'مزج الإحساس المائي مع العود نادر في الكتالوج الحالي. أيهما أهم لك: الانتعاش المائي أم حضور العود؟'
        : 'That combination of aquatic freshness and oud is rare in the current catalog. Which matters more to you: the aquatic feel or the oud character?';
  }

  if (_wantsLuxury(normalized) && maxBudget != null && maxBudget <= 300) {
    return language.isArabic
        ? 'الطابع الفاخر جدًا غير متاح بهذه الميزانية حاليًا. أقدر أقرّب لك اختيارًا أنيقًا بميزانية أعلى قليلًا.'
        : 'A truly luxury style is not available at this budget right now. I can suggest the closest elegant option at a slightly higher budget.';
  }

  return language.isArabic
      ? 'مش لاقي اختيار مطابق بثقة من الكتالوج الحالي. قلّي الميزانية أو الفايب المفضل عشان أقرّب لك الاختيار.'
      : 'I cannot find a confident catalog match right now. Tell me the budget or the scent vibe you prefer so I can narrow it down.';
}

String buildExcludedNoteConflictQuestion(
  SessionPreferences preferences,
  AIChatLanguage language,
) {
  final excluded = preferences.excludedNotes.take(2).join(', ');
  return language.isArabic
      ? 'لقيت اختيارات قريبة، لكنها بتتعارض مع استبعاد قديم لنوتات: $excluded. تحب أفضل ملتزم بالاستبعاد، ولا أخففه عشان أرشح لك أقرب اختيارات؟'
      : 'I found close options, but they conflict with your earlier excluded notes: $excluded. Should I keep that exclusion strict, or relax it so I can recommend the closest matches?';
}

double? _minCatalogPrice(List<ProductModel> catalog) {
  if (catalog.isEmpty) return null;
  return catalog
      .map((product) => product.effectivePrice)
      .reduce((value, element) => value < element ? value : element);
}

String _budgetBelowMinimum(
  AIChatLanguage language,
  double budget,
  double minPrice,
) {
  final roundedMin = minPrice.toStringAsFixed(0);
  final roundedBudget = budget.toStringAsFixed(0);
  return language.isArabic
      ? 'مش لاقي اختيار مطابق ضمن ميزانيتك الحالية $roundedBudget جنيه. أقل سعر متاح في الكتالوج حوالي $roundedMin جنيه.'
      : 'I cannot find a match within your current $roundedBudget EGP budget. The lowest available catalog price is around $roundedMin EGP.';
}

String _budgetNoMatch(AIChatLanguage language, double budget) {
  final roundedBudget = budget.toStringAsFixed(0);
  return language.isArabic
      ? 'مش لاقي اختيار يطابق باقي الشروط داخل ميزانية $roundedBudget جنيه. ممكن نزوّد الميزانية قليلًا أو نخفف شرط من الشروط؟'
      : 'No current option matches the rest of your criteria within the $roundedBudget EGP budget. We can raise the budget slightly or relax one condition.';
}

String _excludedNotesNoMatch(AIChatLanguage language, List<String> notes) {
  final excluded = notes.take(3).join(', ');
  return language.isArabic
      ? 'مش لاقي اختيار يطابق طلبك مع استبعاد: $excluded. تحب نخلي الاستبعاد صارم ولا نخففه عشان نلاقي بدائل أقرب؟'
      : 'No current perfume matches while excluding $excluded. Should I keep that exclusion strict or relax it for closer options?';
}

String _externalKnownNoSubstitute(AIChatLanguage language) {
  return language.isArabic
      ? 'العطر ده مش متوفر عندنا حاليًا، وقدرت أتعرف على طابعه، لكن مش لاقي بديل قريب بثقة كافية. تحب أقربه ناحية الحلاوة، الخشب، ولا الانتعاش؟'
      : 'That perfume is not available in our catalog right now. I can identify its style, but I do not have a confident substitute. Should I lean the alternative toward sweetness, woods, or freshness?';
}

String _unknownExternalNoProfile(AIChatLanguage language) {
  return language.isArabic
      ? 'مش لاقي الاسم ده في الكتالوج أو قاعدة معرفة العطور. وصفلي ريحته أو قلّي النوتات المهمة عشان أقرّب لك بديل متاح.'
      : 'I cannot find that name in the catalog or perfume knowledge base. Describe its scent or the notes that matter so I can find an available alternative.';
}

String _missingNoteData(AIChatLanguage language) {
  return language.isArabic
      ? 'بعض المنتجات لا تملك بيانات نوتات كافية لهذا الطلب. مش هخمن؛ قلّي الفايب أو الموسم ونقرّب الاختيار بأمان.'
      : 'Some catalog items do not have enough note data for this request. I will not guess; tell me the style or season and I can narrow it safely.';
}

String _scentNoMatch(AIChatLanguage language, SessionPreferences preferences) {
  final notes = [
    ...preferences.preferredNotes,
    ...preferences.preferredTopNotes,
    ...preferences.preferredMiddleNotes,
    ...preferences.preferredBaseNotes,
  ].take(3).join(', ');
  final suffix = notes.isEmpty ? 'the requested scent direction' : notes;
  return language.isArabic
      ? 'مش لاقي اختيار يطابق اتجاه الرائحة المطلوب ($suffix) بثقة كافية. أقدر أقرّبها بنوتات مشابهة لو تحب.'
      : 'No current perfume matches the scent direction ($suffix) closely enough. I can move to nearby notes if you want.';
}

String _contextNoMatch(AIChatLanguage language) {
  return language.isArabic
      ? 'مش لاقي اختيار يجمع شروط الاستخدام الحالية كلها. ممكن نخفف الموسم أو الاستخدام أو درجة القوة عشان نلاقي أقرب اختيار.'
      : 'No current option combines all those use-case constraints. We can relax season, use-case, or intensity to find the closest fit.';
}

bool _wantsLuxury(String normalized) {
  return normalized.contains('luxury') ||
      normalized.contains('premium') ||
      normalized.contains('royal') ||
      normalized.contains('فاخر') ||
      normalized.contains('فخم') ||
      normalized.contains('ملكي');
}
