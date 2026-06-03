import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_query_detector.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_query_service.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  required double price,
  int stock = 5,
  bool isActive = true,
  String gender = 'unisex',
  String season = 'all_seasons',
  String family = 'fresh',
  List<String> notes = const <String>[],
  List<String> tags = const <String>[],
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const <String>[],
    brand: 'Brand',
    price: price,
    stock: stock,
    gender: gender,
    season: season,
    fragranceFamily: family,
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: '',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: isActive,
    occasion: 'daily',
    time: 'all_day',
    intensity: 'medium',
    topNotes: const <String>[],
    middleNotes: const <String>[],
    baseNotes: const <String>[],
    tags: tags,
  );
}

void main() {
  group('CatalogQueryService', () {
    test('most expensive returns highest active in-stock products', () {
      final service = CatalogQueryService();
      final result = service.resolve(
        message: 'most expensive perfume you have',
        catalog: [
          _product(id: 'mid', name: 'Mid', price: 1200),
          _product(id: 'high', name: 'High', price: 2500),
          _product(id: 'out', name: 'Out', price: 5000, stock: 0),
        ],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
      );

      expect(result, isNotNull);
      expect(result!.query.type, CatalogQueryType.mostExpensive);
      expect(result.recommendations.first.product.id, 'high');
      expect(
        result.recommendations.map((item) => item.product.id),
        isNot(contains('out')),
      );
    });

    test('cheapest men summer applies explicit message filters', () {
      final service = CatalogQueryService();
      final result = service.resolve(
        message: 'cheapest men summer perfume',
        catalog: [
          _product(
            id: 'fit',
            name: 'Fit',
            price: 900,
            gender: 'men',
            season: 'summer',
          ),
          _product(
            id: 'wrong_gender',
            name: 'Wrong Gender',
            price: 500,
            gender: 'women',
            season: 'summer',
          ),
          _product(
            id: 'wrong_season',
            name: 'Wrong Season',
            price: 400,
            gender: 'men',
            season: 'winter',
          ),
        ],
        currentPreferences: const SessionPreferences(gender: 'women'),
        language: AIChatLanguage.english,
      );

      expect(result, isNotNull);
      expect(result!.query.type, CatalogQueryType.cheapest);
      expect(result.recommendations.map((item) => item.product.id), ['fit']);
    });

    test('explicit strawberry note query returns exact facet products', () {
      final service = CatalogQueryService();
      final result = service.resolve(
        message: 'strawberry scent perfume',
        catalog: [
          _product(
            id: 'strawberry',
            name: 'Strawberry Musk',
            price: 900,
            notes: const ['strawberry', 'musk'],
          ),
          _product(
            id: 'citrus',
            name: 'Citrus Musk',
            price: 800,
            notes: const ['citrus', 'musk'],
          ),
        ],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
      );

      expect(result, isNotNull);
      expect(result!.query.type, CatalogQueryType.noteSearch);
      expect(result.recommendations.map((item) => item.product.id), [
        'strawberry',
      ]);
    });

    test('ranked by price returns cheapest-first catalog results', () {
      final service = CatalogQueryService();
      final result = service.resolve(
        message: 'sort by price from cheapest to most expensive',
        catalog: [
          _product(id: 'mid', name: 'Mid', price: 1200),
          _product(id: 'cheap', name: 'Cheap', price: 700),
          _product(id: 'high', name: 'High', price: 2000),
        ],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
      );

      expect(result, isNotNull);
      expect(result!.query.type, CatalogQueryType.rankedByPrice);
      expect(result.recommendations.map((item) => item.product.id), [
        'cheap',
        'mid',
        'high',
      ]);
    });

    test('missing strawberry facet returns no exact facet answer', () {
      final service = CatalogQueryService();
      final result = service.resolve(
        message: 'strawberry scent perfume',
        catalog: [
          _product(
            id: 'fruity',
            name: 'Fruity Musk',
            price: 900,
            notes: const ['apple', 'musk'],
            tags: const ['fruity'],
          ),
        ],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
      );

      expect(result, isNotNull);
      expect(result!.isNoMatch, isTrue);
      expect(result.hasRecommendations, isFalse);
      expect(result.reply.answer, contains('explicit strawberry'));
    });

    test('note-only availability wording becomes local note search', () {
      final service = CatalogQueryService();
      final result = service.resolve(
        message: 'is there with pineapple',
        catalog: [
          _product(
            id: 'pineapple',
            name: 'Pineapple Fresh',
            price: 900,
            notes: const ['pineapple', 'musk'],
          ),
          _product(
            id: 'citrus',
            name: 'Citrus Musk',
            price: 800,
            notes: const ['citrus', 'musk'],
          ),
        ],
        currentPreferences: const SessionPreferences(
          gender: 'women',
          season: 'summer',
        ),
        language: AIChatLanguage.english,
      );

      expect(result, isNotNull);
      expect(result!.query.type, CatalogQueryType.noteSearch);
      expect(result.responseSource, 'local_catalog_query_note_search');
      expect(result.recommendations.map((item) => item.product.id), [
        'pineapple',
      ]);
    });

    test('missing note-only fruit gives exact note caveat without worker', () {
      final service = CatalogQueryService();
      final result = service.resolve(
        message: 'is there with mango',
        catalog: [
          _product(
            id: 'fruity',
            name: 'Fruity Musk',
            price: 900,
            notes: const ['apple', 'musk'],
            tags: const ['fruity'],
          ),
        ],
        currentPreferences: const SessionPreferences(
          gender: 'women',
          season: 'summer',
          preferredNotes: ['vanilla'],
        ),
        language: AIChatLanguage.english,
      );

      expect(result, isNotNull);
      expect(result!.query.type, CatalogQueryType.noteSearch);
      expect(result.responseSource, 'local_catalog_query_no_exact_facet');
      expect(result.hasRecommendations, isFalse);
      expect(result.reply.answer, contains('explicit mango'));
    });
  });
}
