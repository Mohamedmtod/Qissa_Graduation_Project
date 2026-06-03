import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

String buildWhyProductFollowUpAnswer(
  ProductModel product,
  AIChatLanguage language,
) {
  final highlights = <String>[
    ...product.notes.take(2),
    ...product.tags.take(1),
  ].where((item) => item.trim().isNotEmpty).toList(growable: false);
  final notesPart = highlights.isEmpty
      ? product.fragranceFamily
      : highlights.join(language.isArabic ? '، ' : ', ');

  return language.isArabic
      ? 'رشحته لأن ${product.name} من ${product.brand} بطابع $notesPart، ومناسب لـ ${product.occasion} ودرجة فوحانه ${_displayIntensity(product.intensity, language)}.'
      : 'I recommended it because ${product.name} by ${product.brand} has a $notesPart profile, works well for ${product.occasion}, and its intensity is ${_displayIntensity(product.intensity, language)}.';
}

String buildProductDetailsFollowUpAnswer(
  ProductModel product,
  AIChatLanguage language,
) {
  final notes = <String>[
    ...product.topNotes.take(1),
    ...product.middleNotes.take(1),
    ...product.baseNotes.take(1),
  ].where((item) => item.trim().isNotEmpty).toList(growable: false);
  final notesPart = notes.isEmpty
      ? product.notes.take(3).join(language.isArabic ? '، ' : ', ')
      : notes.join(language.isArabic ? '، ' : ', ');

  return language.isArabic
      ? '${product.name} من ${product.brand} طابعه ${product.fragranceFamily}، أبرز نوتاته $notesPart، مناسب لـ ${product.occasion} وفوحانه ${_displayIntensity(product.intensity, language)}.'
      : '${product.name} by ${product.brand} has a ${product.fragranceFamily} profile, with standout notes like $notesPart. It works well for ${product.occasion} and has ${_displayIntensity(product.intensity, language)} intensity.';
}

String _displayIntensity(String intensity, AIChatLanguage language) {
  if (!language.isArabic) return intensity;
  return switch (intensity.trim().toLowerCase().replaceAll('_', ' ')) {
    'light' => 'هادي',
    'medium' => 'متوسط',
    'strong' => 'قوي',
    _ => intensity,
  };
}

String buildKnownCatalogProductIntroAnswer(
  ProductModel product,
  AIChatLanguage language,
) {
  final notes = <String>[
    ...product.topNotes.take(1),
    if (product.topNotes.isEmpty) ...product.notes.take(2),
    ...product.middleNotes.take(1),
    ...product.baseNotes.take(1),
  ].where((item) => item.trim().isNotEmpty).take(4).toList(growable: false);
  final notesText = notes.isEmpty
      ? product.fragranceFamily
      : notes.join(language.isArabic ? '، ' : ', ');
  final price = product.effectivePrice.toStringAsFixed(0);

  return language.isArabic
      ? 'أيوه، أعرف ${product.name}. طابعه ${product.fragranceFamily} وبارز فيه $notesText. متوفر عندنا بسعر $price جنيه. تحب تشتريه ولا أرشح لك حاجة شبهه؟'
      : 'Yes, I know ${product.name}. It has a ${product.fragranceFamily} profile with $notesText. It is available for $price EGP. Do you want this one, or something similar?';
}
