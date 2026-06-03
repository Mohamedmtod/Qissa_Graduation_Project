import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

String buildAvailabilityMessageForFound(
  AIChatLanguage language,
  ProductModel product,
) {
  final roundedPrice = product.effectivePrice.toStringAsFixed(0);
  if (product.stock <= 0) {
    return language.isArabic
        ? 'أيوه، المنتج موجود لكنه غير متوفر حاليًا: ${product.name} بسعر $roundedPrice جنيه. أقدر أجهز لك تنبيه عند رجوعه.'
        : 'Yes, this product exists but is currently out of stock: ${product.name} for $roundedPrice EGP. If you want, I can set a Notify Me alert for it.';
  }

  return language.isArabic
      ? 'أيوه، المنتج موجود ومتوفر الآن: ${product.name} بسعر $roundedPrice جنيه.'
      : 'Yes, it is available now: ${product.name} for $roundedPrice EGP.';
}

String buildAvailabilityUnknownClarificationMessage(AIChatLanguage language) {
  return language.isArabic
      ? 'لم أجد هذا الاسم في الكتالوج حاليًا. ممكن تكتب الاسم الأدق أو تقول لي الطابع الذي تبحث عنه: فريش، خشبي، حلو؟'
      : 'We could not find that exact name in our catalog. Can you share the exact name or the scent style you want (fresh, woody, sweet)?';
}

String buildAvailabilityExternalLookupFailedMessage(
  AIChatLanguage language,
  String query,
) {
  return language.isArabic
      ? '$query غير موجود في كتالوجنا حاليًا، ولم أتمكن من التحقق من مصدر خارجي الآن. اذكر طابعه أو أهم النوتات لأرشح لك أقرب بديل متاح.'
      : 'I could not identify "$query" confidently as an external perfume. Send me the full name or brand and I will match it more accurately from our catalog.';
}

String buildAvailabilityBrandAmbiguousMessage(
  AIChatLanguage language,
  String query,
) {
  return language.isArabic
      ? 'الاسم "$query" عام وقد يشير لأكثر من عطر. اكتب اسم العطر الكامل أو الطابع المطلوب لأرشح لك بديلًا مناسبًا.'
      : '"$query" is too broad and may refer to multiple perfumes. Share the full perfume name or the style you want and I can suggest a suitable alternative.';
}

String buildAvailabilityCatalogOptionsClarificationMessage(
  AIChatLanguage language,
  String query,
  List<ProductModel> options,
) {
  final limitedOptions = options.take(3).toList(growable: false);
  if (limitedOptions.length == 1) {
    final name = limitedOptions.first.name;
    return language.isArabic ? 'تقصد $name؟' : 'Do you mean $name?';
  }

  final optionLines = limitedOptions
      .asMap()
      .entries
      .map((entry) => '${entry.key + 1}. ${entry.value.name}')
      .join('\n');

  return language.isArabic
      ? 'الاسم "$query" قد يشير لأكثر من عطر عندنا. تقصد أي واحد من دول؟\n$optionLines'
      : 'I found more than one close match for "$query". Which one do you mean?\n$optionLines';
}

String buildAvailabilityProactiveSubstituteMessage({
  required AIChatLanguage language,
  required String query,
  required String substituteName,
  required bool outOfStock,
}) {
  if (outOfStock) {
    return language.isArabic
        ? '$query غير متوفر حاليًا، لكن أقرب بديل متاح قريب في الطابع هو $substituteName.'
        : '$query is currently out of stock, but the closest available alternative with a similar profile is $substituteName.';
  }

  return language.isArabic
      ? '$query غير موجود في كتالوجنا حاليًا، لكن أقرب بديل متاح قريب في الطابع هو $substituteName.'
      : 'We could not find $query in our catalog right now, but the closest alternative with a similar profile is $substituteName.';
}

String buildAvailabilityKnowledgeSubstituteMessage({
  required AIChatLanguage language,
  required String requestedName,
  required String substituteName,
  required Iterable<String> profileHints,
}) {
  final hints = profileHints.take(4).join(language.isArabic ? '، ' : ', ');
  if (language.isArabic) {
    final reason = hints.isEmpty ? 'الطابع العام' : hints;
    return '$requestedName غير موجود في كتالوجنا حاليًا، لكن أقرب بديل متاح هو $substituteName. السبب أنه قريب منه في الطابع: $reason.';
  }
  final reason = hints.isEmpty ? 'the overall scent profile' : hints;
  return '$requestedName is not available in our catalog right now, but the closest available alternative is $substituteName. It is similar in profile: $reason.';
}

String buildAvailabilityLowConfidenceFallbackMessage(
  AIChatLanguage language,
  String query,
) {
  return language.isArabic
      ? 'لم أجد $query عندنا حاليًا. اذكر الطابع الذي تبحث عنه وسأرشح لك أقرب بديل.'
      : 'We could not find $query right now. If you want, tell me the scent profile you are looking for and I will suggest the closest available alternative.';
}

String buildKnownProfileLowConfidenceFallbackMessage(
  AIChatLanguage language,
  String query,
) {
  if (language.isArabic) {
    return 'لم أجد هذا العطر في الكتالوج الحالي. $query غير موجود في كتالوجنا حاليًا. عرفت الطابع العام، لكن لا يوجد بديل متاح قريب بدرجة كافية. قل لي أهم جزء في الرائحة بالنسبة لك وسأرشح لك الأقرب.';
  }
  return 'We could not find $query in our catalog right now. I found its scent profile, but I do not have an available alternative close enough to recommend confidently. Tell me the most important part of its style for you and I will suggest the closest option.';
}

String buildAvailabilityClarifyMissingNameMessage(AIChatLanguage language) {
  return language.isArabic
      ? 'ممكن تكتب اسم العطر بشكل أوضح حتى أتأكد من توفره؟'
      : 'Could you share the perfume name more clearly so I can check availability?';
}

String buildAvailabilityAmbiguousMessage(
  AIChatLanguage language,
  String query,
  List<ProductModel> options,
) {
  return buildAvailabilityCatalogOptionsClarificationMessage(
    language,
    query,
    options,
  );
}

String buildExternalPerfumeAmbiguousMessage(
  AIChatLanguage language,
  List<ExternalPerfumeCandidate> candidates,
) {
  if (candidates.length == 1) {
    final label = candidates.first.label;
    return language.isArabic ? 'تقصد $label؟' : 'Do you mean $label?';
  }
  final options = candidates
      .take(3)
      .indexed
      .map((entry) => '${entry.$1 + 1}. ${entry.$2.label}')
      .join('\n');
  if (language.isArabic) {
    return 'وجدت أكثر من عطر قريب من هذا الاسم. أي واحد تقصد؟\n$options';
  }
  return 'I found more than one perfume close to that name. Which one do you mean?\n$options';
}

String buildExternalPerfumeStillAmbiguousMessage(
  AIChatLanguage language,
  List<ExternalPerfumeCandidate> candidates,
) {
  final options = candidates
      .take(3)
      .indexed
      .map((entry) => '${entry.$1 + 1}. ${entry.$2.label}')
      .join('\n');
  if (language.isArabic) {
    return 'ما زال الاختيار غير واضح. اختر رقمًا أو اكتب جزءًا مميزًا من الاسم:\n$options';
  }
  return 'That choice is still unclear. Pick a number or type a distinctive part of the name:\n$options';
}
