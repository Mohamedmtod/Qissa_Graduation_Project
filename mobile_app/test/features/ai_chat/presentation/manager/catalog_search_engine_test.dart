import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_engine.dart';
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
  List<String> topNotes = const <String>[],
  List<String> middleNotes = const <String>[],
  List<String> baseNotes = const <String>[],
  List<String> tags = const <String>[],
  String description = '',
  String occasion = 'daily',
  String time = 'all_day',
  String intensity = 'medium',
  Timestamp? createdAt,
}) {
  final now = createdAt ?? Timestamp.now();
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
    description: description,
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: isActive,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: topNotes,
    middleNotes: middleNotes,
    baseNotes: baseNotes,
    tags: tags,
  );
}

void main() {
  group('CatalogSearchEngine', () {
    test('notes strawberry returns strawberry products only', () {
      final engine = CatalogSearchEngine(
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
      );

      final results = engine.search(
        filters: const CatalogSearchFilters(notes: ['strawberry']),
      );

      expect(results.map((r) => r.product.id), ['strawberry']);
      expect(results.single.matchedFacets, contains('note:strawberry'));
    });

    test('Arabic strawberry alias searches catalog facets', () {
      final engine = CatalogSearchEngine(
        catalog: [
          _product(
            id: 'strawberry',
            name: 'Strawberry Musk',
            price: 900,
            notes: const ['strawberry'],
          ),
        ],
      );

      final results = engine.search(
        filters: const CatalogSearchFilters(
          notes: ['\u0641\u0631\u0627\u0648\u0644\u0629'],
        ),
      );

      expect(results.map((r) => r.product.id), ['strawberry']);
    });

    test('gender season and max price filters are all respected', () {
      final engine = CatalogSearchEngine(
        catalog: [
          _product(
            id: 'fit',
            name: 'Fit',
            price: 1200,
            gender: 'men',
            season: 'summer',
          ),
          _product(
            id: 'wrong_gender',
            name: 'Wrong Gender',
            price: 900,
            gender: 'women',
            season: 'summer',
          ),
          _product(
            id: 'wrong_season',
            name: 'Wrong Season',
            price: 900,
            gender: 'men',
            season: 'winter',
          ),
          _product(
            id: 'too_high',
            name: 'Too High',
            price: 1600,
            gender: 'men',
            season: 'summer',
          ),
        ],
      );

      final results = engine.search(
        filters: const CatalogSearchFilters(
          gender: 'men',
          season: 'summer',
          maxPrice: 1500,
        ),
      );

      expect(results.map((r) => r.product.id), ['fit']);
    });

    test('cheapest and most expensive sorts use effective price', () {
      final engine = CatalogSearchEngine(
        catalog: [
          _product(id: 'mid', name: 'Mid', price: 1200),
          _product(id: 'cheap', name: 'Cheap', price: 800),
          _product(id: 'expensive', name: 'Expensive', price: 1800),
        ],
      );

      final cheapest = engine.search(
        filters: const CatalogSearchFilters(),
        sort: CatalogSearchSort.cheapest,
      );
      final expensive = engine.search(
        filters: const CatalogSearchFilters(),
        sort: CatalogSearchSort.mostExpensive,
      );

      expect(cheapest.map((r) => r.product.id), ['cheap', 'mid', 'expensive']);
      expect(expensive.map((r) => r.product.id), ['expensive', 'mid', 'cheap']);
    });

    test('best match prefers higher facet overlap', () {
      final engine = CatalogSearchEngine(
        catalog: [
          _product(
            id: 'partial',
            name: 'Partial',
            price: 800,
            gender: 'unisex',
            notes: const ['strawberry'],
            tags: const ['sweet'],
          ),
          _product(
            id: 'full',
            name: 'Full',
            price: 900,
            gender: 'men',
            notes: const ['strawberry', 'musk'],
            tags: const ['fresh', 'sweet'],
            occasion: 'daily',
            intensity: 'light',
          ),
        ],
      );

      final results = engine.search(
        filters: const CatalogSearchFilters(
          gender: 'men',
          notes: ['strawberry'],
        ),
      );

      expect(results.first.product.id, 'full');
      expect(results.first.matchScore, greaterThan(results.last.matchScore));
    });

    test('out-of-stock and inactive products are hidden by default', () {
      final engine = CatalogSearchEngine(
        catalog: [
          _product(id: 'safe', name: 'Safe', price: 1000),
          _product(id: 'out', name: 'Out', price: 800, stock: 0),
          _product(
            id: 'inactive',
            name: 'Inactive',
            price: 700,
            isActive: false,
          ),
        ],
      );

      final results = engine.search(filters: const CatalogSearchFilters());

      expect(results.map((r) => r.product.id), ['safe']);
    });

    test('strongest and newest sorts are deterministic', () {
      final older = Timestamp.fromDate(DateTime.utc(2024, 1, 1));
      final newer = Timestamp.fromDate(DateTime.utc(2025, 1, 1));
      final engine = CatalogSearchEngine(
        catalog: [
          _product(
            id: 'light_new',
            name: 'Light New',
            price: 900,
            intensity: 'light',
            createdAt: newer,
          ),
          _product(
            id: 'strong_old',
            name: 'Strong Old',
            price: 900,
            intensity: 'strong',
            createdAt: older,
          ),
        ],
      );

      final strongest = engine.search(
        filters: const CatalogSearchFilters(),
        sort: CatalogSearchSort.strongest,
      );
      final newest = engine.search(
        filters: const CatalogSearchFilters(),
        sort: CatalogSearchSort.newest,
      );

      expect(strongest.first.product.id, 'strong_old');
      expect(newest.first.product.id, 'light_new');
    });
  });
}
