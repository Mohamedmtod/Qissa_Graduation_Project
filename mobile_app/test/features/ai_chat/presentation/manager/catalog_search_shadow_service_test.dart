import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_shadow_service.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  required double price,
  String gender = 'unisex',
  String season = 'all_seasons',
  String occasion = 'daily',
  String time = 'all_day',
  String intensity = 'medium',
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
    stock: 5,
    gender: gender,
    season: season,
    fragranceFamily: 'fresh',
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: '',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: true,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: const <String>[],
    middleNotes: const <String>[],
    baseNotes: const <String>[],
    tags: tags,
  );
}

RecommendedProduct _recommendation(ProductModel product) {
  return RecommendedProduct(
    product: product,
    matchScore: 0.70,
    matchLabel: 'Catalog Match',
    matchReason: 'Old candidate.',
  );
}

void main() {
  group('CatalogSearchShadowService', () {
    test('buildCandidates prefers university day light search results', () {
      final night = _product(
        id: 'night',
        name: 'Night',
        price: 2500,
        gender: 'men',
        season: 'winter',
        occasion: 'date',
        time: 'night',
        intensity: 'strong',
        notes: const ['amber'],
        tags: const ['sweet'],
      );
      final day = _product(
        id: 'day',
        name: 'Day',
        price: 1000,
        gender: 'men',
        season: 'summer',
        occasion: 'office',
        time: 'day',
        intensity: 'light',
        notes: const ['citrus', 'musk'],
        tags: const ['fresh', 'clean', 'university'],
      );

      final candidates = const CatalogSearchShadowService().buildCandidates(
        catalog: [night, day],
        preferences: const SessionPreferences(
          gender: 'men',
          occasion: 'university',
          intensity: 'light',
          tags: ['fresh', 'clean'],
        ),
        limit: 15,
      );

      expect(candidates.map((item) => item.product.id), ['day']);
    });

    test(
      'records old ids search ids overlap dropped ids and suitability metadata',
      () {
        final oldNight = _product(
          id: 'night',
          name: 'Night',
          price: 2000,
          season: 'winter',
          occasion: 'date',
          time: 'night',
          intensity: 'strong',
          notes: const ['amber'],
        );
        final day = _product(
          id: 'day',
          name: 'Day',
          price: 1000,
          gender: 'men',
          season: 'summer',
          occasion: 'office',
          time: 'day',
          intensity: 'light',
          notes: const ['citrus', 'musk'],
          tags: const ['fresh', 'clean', 'university'],
        );
        final service = CatalogSearchShadowService();

        final result = service.compare(
          scenario: 'recommend a men university light fresh perfume',
          requestId: 'req1',
          catalog: [oldNight, day],
          oldCandidates: [_recommendation(oldNight)],
          preferences: const SessionPreferences(
            gender: 'men',
            occasion: 'university',
            intensity: 'light',
            tags: ['fresh', 'clean'],
          ),
        );

        expect(result.trace['oldCandidateIds'], ['night']);
        expect(result.trace['searchCandidateIds'], contains('day'));
        expect(result.trace['overlapCount'], 0);
        expect(result.trace['searchWouldHaveDroppedIds'], ['night']);
        expect(
          (result.trace['suitabilityReasons'] as Map<String, dynamic>)['day'],
          isA<List<dynamic>>(),
        );
        expect(
          (result.trace['suitabilityScores'] as Map<String, dynamic>)['day'],
          isA<double>(),
        );
      },
    );

    test('primary merge fills too-few search results from local fallback', () {
      final searchOnly = _product(id: 'search', name: 'Search', price: 1000);
      final fallbackA = _product(
        id: 'fallback_a',
        name: 'Fallback A',
        price: 900,
      );
      final fallbackB = _product(
        id: 'fallback_b',
        name: 'Fallback B',
        price: 800,
      );

      final merged =
          AIChatRecommendationResolver.mergeSearchPrimaryWithLocalFallback(
            searchCandidates: [_recommendation(searchOnly)],
            fallbackCandidates: [
              _recommendation(searchOnly),
              _recommendation(fallbackA),
              _recommendation(fallbackB),
            ],
            limit: 15,
          );

      expect(merged.map((item) => item.product.id), [
        'search',
        'fallback_a',
        'fallback_b',
      ]);
    });
  });
}
