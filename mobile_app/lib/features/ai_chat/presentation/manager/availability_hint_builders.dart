import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_reference_profile_registry.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_substitute_engine.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

RecommendedProduct buildAvailabilityCardProduct(
  ProductModel product,
  AIChatLanguage language,
) {
  return RecommendedProduct(
    product: product,
    matchScore: 1,
    matchLabel: language.isArabic ? 'متاح' : 'Available',
    matchReason: language.isArabic
        ? 'تمت مطابقة المنتج المطلوب.'
        : 'Matched the requested product.',
  );
}

SessionPreferences availabilityHintsFromProduct(ProductModel product) {
  return SessionPreferences(
    gender: product.gender,
    season: product.season,
    occasion: product.occasion,
    intensity: product.intensity,
    preferredNotes: product.notes,
    preferredTopNotes: product.topNotes,
    preferredMiddleNotes: product.middleNotes,
    preferredBaseNotes: product.baseNotes,
    tags: product.tags,
  ).sanitize();
}

SessionPreferences availabilityHintsFromProfile(
  AvailabilityReferenceProfile profile,
) {
  return SessionPreferences(
    gender: profile.genderHint,
    season: profile.seasonHint,
    occasion: profile.occasionHint,
    intensity: profile.intensityHint,
    preferredNotes: {...profile.preferredNotes, ...profile.accords}.toList(),
    preferredTopNotes: profile.topNotes.toList(),
    preferredMiddleNotes: profile.middleNotes.toList(),
    preferredBaseNotes: profile.baseNotes.toList(),
    tags: profile.tags.toList(),
    time: profile.timeHint,
  ).sanitize();
}

List<RecommendedProduct> buildAvailabilitySubstituteProducts(
  List<AvailabilitySubstituteSuggestion> suggestions,
  AIChatLanguage language,
) {
  return suggestions
      .map(
        (item) => RecommendedProduct(
          product: item.product,
          matchScore: item.score,
          matchLabel: language.isArabic ? 'بديل متاح' : 'Available alternative',
          matchReason: item.reason,
        ),
      )
      .toList(growable: false);
}
