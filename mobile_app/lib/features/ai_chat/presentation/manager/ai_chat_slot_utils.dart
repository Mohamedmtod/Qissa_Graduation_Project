import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';

const Set<String> _genderSlotTerms = {
  'رجالي',
  'رجال',
  'حريمي',
  'نسائي',
  'نساء',
};

const Set<String> _seasonSlotTerms = {'صيف', 'شت', 'مواسم', 'فصول'};

const Set<String> _budgetSlotTerms = {'ميزاني', 'سعر', 'فلوس', 'جنيه'};

const Set<String> _notesSlotTerms = {'نوت', 'ريحة', 'فوحان', 'ثبات'};

bool _containsCurrentArabicSlotTerms(String normalized, Set<String> terms) {
  return terms.any(normalized.contains);
}

String? inferAskedSlot(String question) {
  final normalized = AIChatTextNormalizer.normalizeForParsing(question);
  if (normalized.isEmpty) return null;

  if (normalized.contains('صيفي ولا شتوي') ||
      normalized.contains('صيف ولا شت') ||
      normalized.contains('لكل المواسم')) {
    return 'season';
  }

  if (normalized.contains('رجالي ولا حريمي') ||
      normalized.contains('حريمي ولا رجالي') ||
      normalized.contains('للرجال ولا للنساء')) {
    return 'gender';
  }

  if (_containsCurrentArabicSlotTerms(normalized, _genderSlotTerms)) {
    return 'gender';
  }
  if (_containsCurrentArabicSlotTerms(normalized, _seasonSlotTerms)) {
    return 'season';
  }
  if (_containsCurrentArabicSlotTerms(normalized, _budgetSlotTerms)) {
    return 'maxBudget';
  }
  if (_containsCurrentArabicSlotTerms(normalized, _notesSlotTerms)) {
    return 'notesOrIntensity';
  }

  if (normalized.contains('رجالي') ||
      normalized.contains('نسائي') ||
      normalized.contains('رجالي') ||
      normalized.contains('رجال') ||
      normalized.contains('نسائي') ||
      normalized.contains('نساء') ||
      normalized.contains('men') ||
      normalized.contains('women') ||
      normalized.contains('gender')) {
    return 'gender';
  }

  if (normalized.contains('صيف') ||
      normalized.contains('شت') ||
      normalized.contains('season')) {
    return 'season';
  }

  if (normalized.contains('ميزاني') ||
      normalized.contains('budget') ||
      normalized.contains('price') ||
      normalized.contains('سعر')) {
    return 'maxBudget';
  }

  if (normalized.contains('نوت') ||
      normalized.contains('notes') ||
      normalized.contains('ريحة') ||
      normalized.contains('intensity') ||
      normalized.contains('فوحان')) {
    return 'notesOrIntensity';
  }

  return null;
}

bool isSlotAlreadyFilled(SessionPreferences preferences, String slot) {
  switch (slot) {
    case 'gender':
      return preferences.gender != null;
    case 'season':
      return preferences.season != null;
    case 'maxBudget':
      return preferences.maxBudget != null ||
          preferences.tags.contains('open_budget');
    case 'notesOrIntensity':
      return preferences.hasAnyNoteSignal || preferences.intensity != null;
    default:
      return false;
  }
}

bool looksLikeGenericPreferenceAsk(String question) {
  final normalized = AIChatTextNormalizer.normalizeForParsing(question);
  if (normalized.isEmpty) return false;
  return normalized.contains('one more preference') ||
      normalized.contains('share one more') ||
      normalized.contains('refine the recommendation') ||
      normalized.contains('additional preference') ||
      normalized.contains('more preference') ||
      normalized.contains('تفضيل اضافي') ||
      normalized.contains('تفضيل إضافي');
}

String? nextUsefulAskSlot(
  SessionPreferences preferences,
  List<String> missingSlots,
) {
  if (preferences.gender != null &&
      preferences.season != null &&
      missingSlots.contains('notesOrIntensity') &&
      !isSlotAlreadyFilled(preferences, 'notesOrIntensity')) {
    return 'notesOrIntensity';
  }
  for (final slot in missingSlots) {
    if (!isSlotAlreadyFilled(preferences, slot)) {
      return slot;
    }
  }
  if (preferences.gender == null) return 'gender';
  if (preferences.season == null) return 'season';
  if (preferences.maxBudget == null &&
      !preferences.tags.contains('open_budget')) {
    return 'maxBudget';
  }
  if (!preferences.hasAnyNoteSignal && preferences.tags.isEmpty) {
    return 'notesOrIntensity';
  }
  return null;
}
