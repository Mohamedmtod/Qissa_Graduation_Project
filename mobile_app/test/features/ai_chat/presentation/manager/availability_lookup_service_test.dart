import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_lookup_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_reference_profile_registry.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  required String brand,
  String nameAr = '',
  String brandAr = '',
  List<String> aliases = const [],
  List<String> aliasesAr = const [],
  int stock = 10,
}) {
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const [],
    nameAr: nameAr,
    brand: brand,
    brandAr: brandAr,
    aliases: aliases,
    aliasesAr: aliasesAr,
    price: 1000,
    stock: stock,
    gender: 'men',
    season: 'all',
    fragranceFamily: 'woody',
    notes: const ['citrus', 'woody', 'musk'],
    imageUrls: const ['https://example.com/product.png'],
    description: 'Test product',
    categoryName: 'Perfumes',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    occasion: 'daily',
    time: 'all_day',
    intensity: 'medium',
    topNotes: const ['citrus'],
    middleNotes: const ['woody'],
    baseNotes: const ['musk'],
    tags: const ['fresh'],
  );
}

void main() {
  group('lookupAvailability', () {
    test('does not treat short French stopwords as substring matches', () {
      final result = lookupAvailability('Le Male Elixir', [
        _product(id: 'bleu', name: 'Bleu De Chanel', brand: 'Chanel'),
        _product(id: 'clean', name: 'Clean Musk Hour', brand: 'Qissa'),
      ]);

      expect(result.matchType, AvailabilityMatchType.none);
      expect(result.product, isNull);
      expect(result.options, isEmpty);
      expect(result.isAmbiguous, isFalse);
    });

    test('still finds a real catalog phrase after stopword filtering', () {
      final result = lookupAvailability('is Bleu De Chanel available', [
        _product(id: 'bleu', name: 'Bleu De Chanel', brand: 'Chanel'),
        _product(id: 'clean', name: 'Clean Musk Hour', brand: 'Qissa'),
      ]);

      expect(result.matchType, isNot(AvailabilityMatchType.none));
      expect(result.product?.id, 'bleu');
      expect(result.stockState, AvailabilityStockState.inStock);
    });

    test('resolves a minor typo in an availability product name', () {
      final result = lookupAvailability('is Dior Savag availble', [
        _product(id: 'dior-sauvage', name: 'Dior Sauvage', brand: 'Dior'),
        _product(id: 'bleu', name: 'Bleu De Chanel', brand: 'Chanel'),
      ]);

      expect(result.matchType, isNot(AvailabilityMatchType.none));
      expect(result.product?.id, 'dior-sauvage');
      expect(result.stockState, AvailabilityStockState.inStock);
    });

    test(
      'does not match a multi-word external perfume by one generic token',
      () {
        final result = lookupAvailability('Le Male Elixir', [
          _product(
            id: 'warm-sand',
            name: 'Warm Sand Elixir',
            brand: 'Qissa',
            stock: 0,
          ),
          _product(id: 'honey', name: 'Honey Amber Dusk', brand: 'Desert Muse'),
        ]);

        expect(result.matchType, AvailabilityMatchType.none);
        expect(result.product, isNull);
        expect(result.isAmbiguous, isFalse);
      },
    );

    test('matches Arabic product aliases before external fallback', () {
      final result = lookupAvailability('كم سعر السوفاج', [
        _product(
          id: 'dior-sauvage',
          name: 'Dior Sauvage',
          brand: 'Dior',
          aliasesAr: const ['سوفاج', 'السوفاج', 'ديور سوفاج'],
        ),
        _product(id: 'bleu', name: 'Bleu De Chanel', brand: 'Chanel'),
      ]);

      expect(result.matchType, isNot(AvailabilityMatchType.none));
      expect(result.product?.id, 'dior-sauvage');
      expect(result.stockState, AvailabilityStockState.inStock);
    });

    test('matches Arabic alias with definite article stripped', () {
      final result = lookupAvailability('السوفاج بكام؟', [
        _product(
          id: 'dior-sauvage',
          name: 'Dior Sauvage',
          brand: 'Dior',
          aliasesAr: const ['سوفاج'],
        ),
      ]);

      expect(result.product?.id, 'dior-sauvage');
    });
  });

  group('resolveAvailabilityContextForFollowUp', () {
    SessionPreferences hintsFromProduct(ProductModel product) =>
        const SessionPreferences();

    SessionPreferences hintsFromProfile(AvailabilityReferenceProfile profile) =>
        const SessionPreferences();

    test('keeps current context over incidental product mention', () {
      final catalog = [
        _product(id: 'current', name: 'Current Oud', brand: 'Brand'),
        _product(id: 'mentioned', name: 'Mentioned Musk', brand: 'Brand'),
      ];

      final context = resolveAvailabilityContextForFollowUp(
        message: 'هل Mentioned Musk سعره قريب؟',
        catalog: catalog,
        currentAvailabilityContext: const AvailabilityContext(
          lastQuery: 'Current Oud',
          matchedProductId: 'current',
          matchedProductName: 'Current Oud',
          availabilityStatus: AvailabilityStatus.found,
        ),
        recommendationMemory: const RecommendationMemory(),
        availabilityHintsFromProduct: hintsFromProduct,
        availabilityHintsFromProfile: hintsFromProfile,
      );

      expect(context?.matchedProductId, 'current');
    });

    test('allows explicit switch intent to move to a different product', () {
      final catalog = [
        _product(id: 'current', name: 'Current Oud', brand: 'Brand'),
        _product(id: 'mentioned', name: 'Mentioned Musk', brand: 'Brand'),
      ];

      final context = resolveAvailabilityContextForFollowUp(
        message: 'طب Mentioned Musk متوفر؟',
        catalog: catalog,
        currentAvailabilityContext: const AvailabilityContext(
          lastQuery: 'Current Oud',
          matchedProductId: 'current',
          matchedProductName: 'Current Oud',
          availabilityStatus: AvailabilityStatus.found,
        ),
        recommendationMemory: const RecommendationMemory(),
        availabilityHintsFromProduct: hintsFromProduct,
        availabilityHintsFromProfile: hintsFromProfile,
      );

      expect(context?.matchedProductId, 'mentioned');
    });

    test('uses last focused product before incidental explicit mention', () {
      final catalog = [
        _product(id: 'focused', name: 'Focused Amber', brand: 'Brand'),
        _product(id: 'mentioned', name: 'Mentioned Musk', brand: 'Brand'),
      ];

      final context = resolveAvailabilityContextForFollowUp(
        message: 'هل Mentioned Musk سعره قريب؟',
        catalog: catalog,
        currentAvailabilityContext: const AvailabilityContext.empty(),
        recommendationMemory: const RecommendationMemory(
          lastFocusedProductId: 'focused',
        ),
        availabilityHintsFromProduct: hintsFromProduct,
        availabilityHintsFromProfile: hintsFromProfile,
      );

      expect(context?.matchedProductId, 'focused');
    });
  });
}
