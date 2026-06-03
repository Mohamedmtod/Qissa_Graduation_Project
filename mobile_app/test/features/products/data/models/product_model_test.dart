import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

void main() {
  group('ProductModel.fromMap', () {
    test('parses numeric strings into double and int safely', () {
      final now = Timestamp.now();

      final product = ProductModel.fromMap(
        documentId: 'p1',
        map: {
          'name': 'String Price Perfume',
          'brand': 'Brand',
          'price': '1299.50',
          'stock': '7',
          'gender': 'men',
          'season': 'summer',
          'fragranceFamily': 'fresh',
          'notes': ['vanilla'],
          'imageUrls': ['https://example.com/p.png'],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
        },
      );

      expect(product.price, 1299.50);
      expect(product.stock, 7);
      expect(product.size, isNull);
      expect(product.salePrice, isNull);
      expect(product.isOnSale, isFalse);
      expect(product.effectivePrice, 1299.50);
      expect(product.discountPercent, isNull);
    });

    test('falls back to safe defaults for invalid numeric strings', () {
      final now = Timestamp.now();

      final product = ProductModel.fromMap(
        documentId: 'p2',
        map: {
          'name': 'Broken Numbers Perfume',
          'brand': 'Brand',
          'price': 'not-a-number',
          'stock': 'oops',
          'gender': 'men',
          'season': 'summer',
          'fragranceFamily': 'fresh',
          'notes': const [],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
        },
      );

      expect(product.price, 0.0);
      expect(product.stock, 0);
      expect(product.size, isNull);
      expect(product.salePrice, isNull);
      expect(product.isOnSale, isFalse);
      expect(product.effectivePrice, 0.0);
      expect(product.discountPercent, isNull);
    });

    test('reads optional size and salePrice and computes sale helpers', () {
      final now = Timestamp.now();

      final product = ProductModel.fromMap(
        documentId: 'p3',
        map: {
          'name': 'Sale Perfume',
          'brand': 'Brand',
          'price': 2000,
          'salePrice': 1499,
          'size': '100 ml',
          'stock': 4,
          'gender': 'women',
          'season': 'winter',
          'fragranceFamily': 'oriental',
          'notes': const ['amber'],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
        },
      );

      expect(product.size, '100 ml');
      expect(product.salePrice, 1499);
      expect(product.isOnSale, isTrue);
      expect(product.effectivePrice, 1499);
      expect(product.discountPercent, 25);
    });

    test('reads isActive and preserves it in toMap', () {
      final now = Timestamp.now();

      final product = ProductModel.fromMap(
        documentId: 'p3a',
        map: {
          'name': 'Inactive Perfume',
          'brand': 'Brand',
          'price': 2000,
          'stock': 4,
          'gender': 'women',
          'season': 'winter',
          'fragranceFamily': 'oriental',
          'notes': const ['amber'],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
          'isActive': false,
        },
      );

      expect(product.isActive, isFalse);
      expect(product.toMap()['isActive'], isFalse);
    });

    test('derives query keys and saleActive for Firestore queries', () {
      final now = Timestamp.now();

      final product = ProductModel.fromMap(
        documentId: 'p3b',
        map: {
          'name': 'Query Key Perfume',
          'brand': 'Brand',
          'price': 2000,
          'salePrice': 1500,
          'stock': 4,
          'gender': 'women',
          'season': 'winter',
          'fragranceFamily': ' Floral  Musk ',
          'notes': const ['amber'],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': ' Luxury   Perfumes ',
          'createdAt': now,
          'updatedAt': now,
        },
      );

      expect(product.categoryKey, 'luxury perfumes');
      expect(product.fragranceFamilyKey, 'floral musk');
      expect(product.saleActive, isTrue);
      expect(product.toMap()['categoryKey'], 'luxury perfumes');
      expect(product.toMap()['fragranceFamilyKey'], 'floral musk');
      expect(product.toMap()['saleActive'], isTrue);
    });

    test('ignores invalid sale combinations', () {
      final now = Timestamp.now();

      final equalSale = ProductModel.fromMap(
        documentId: 'p4',
        map: {
          'name': 'Equal Sale',
          'brand': 'Brand',
          'price': 1200,
          'salePrice': 1200,
          'stock': 4,
          'gender': 'women',
          'season': 'winter',
          'fragranceFamily': 'oriental',
          'notes': const ['amber'],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
        },
      );

      final negativeSale = ProductModel.fromMap(
        documentId: 'p5',
        map: {
          'name': 'Negative Sale',
          'brand': 'Brand',
          'price': 1200,
          'salePrice': -1,
          'stock': 4,
          'gender': 'women',
          'season': 'winter',
          'fragranceFamily': 'oriental',
          'notes': const ['amber'],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
        },
      );

      expect(equalSale.isOnSale, isFalse);
      expect(equalSale.effectivePrice, 1200);
      expect(equalSale.discountPercent, isNull);

      expect(negativeSale.isOnSale, isFalse);
      expect(negativeSale.effectivePrice, 1200);
      expect(negativeSale.discountPercent, isNull);
    });

    test('copyWith supports explicitly clearing size and salePrice', () {
      final now = Timestamp.now();
      final base = ProductModel(
        id: 'p6',
        name: 'Editable Perfume',
        nameLower: 'editable perfume',
        searchPrefixes: buildSearchPrefixes('Editable Perfume'),
        brand: 'Brand',
        price: 1500,
        size: '100 ml',
        salePrice: 1200,
        stock: 5,
        gender: 'unisex',
        season: 'summer',
        fragranceFamily: 'fresh',
        notes: const ['citrus'],
        imageUrls: const [],
        description: 'desc',
        categoryName: 'Perfume',
        createdAt: now,
        updatedAt: now,
        isActive: true,
        occasion: 'daily',
        time: 'day',
        intensity: 'light',
        topNotes: const [],
        middleNotes: const [],
        baseNotes: const [],
        tags: const [],
      );

      final cleared = base.copyWith(size: null, salePrice: null);

      expect(cleared.size, isNull);
      expect(cleared.salePrice, isNull);
      expect(cleared.isOnSale, isFalse);
      expect(cleared.effectivePrice, 1500);
    });

    test('reads optional staff taste intelligence safely', () {
      final now = Timestamp.now();

      final legacy = ProductModel.fromMap(
        documentId: 'legacy',
        map: {
          'name': 'Legacy Perfume',
          'brand': 'Brand',
          'price': 1200,
          'stock': 2,
          'gender': 'unisex',
          'season': 'summer',
          'fragranceFamily': 'fresh',
          'notes': const ['citrus'],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
        },
      );

      expect(legacy.staffTagScores, isEmpty);
      expect(legacy.staffWarnings, isEmpty);
      expect(legacy.staffIntelligenceStatus, 'draft');
      expect(legacy.reviewNeeded, isFalse);
      expect(legacy.staffDataCoverage, 0);
      expect(legacy.staffDataCoverageLabel, 'none');

      final enriched = ProductModel.fromMap(
        documentId: 'staffed',
        map: {
          'name': 'Staffed Perfume',
          'brand': 'Brand',
          'price': 1200,
          'stock': 2,
          'gender': 'unisex',
          'season': 'summer',
          'fragranceFamily': 'fresh',
          'notes': const ['citrus'],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
          'staffTagScores': const {
            'office': 3,
            'elegant': 2,
            'soft_on_nose': 2,
            'unknown_tag': 3,
            'fresh': 4,
          },
          'staffWarnings': const ['too_sweet_for_some', 'unknown_warning'],
          'staffSalesNotes': const {'en': 'Clean office pick', 'ar': 'ШґЩЉЩѓ'},
          'similarFamousDna': const ['sauvage_like', 'unknown_dna'],
          'staffIntelligenceStatus': 'trusted',
          'reviewNeeded': true,
          'staffConfidence': 9,
          'staffTaxonomyVersion': 1,
          'staffUpdatedBy': 'employee_1',
          'staffReviewCount': 2,
        },
      );

      expect(enriched.staffTagScores, {
        'office': 3,
        'elegant': 2,
        'soft_on_nose': 2,
      });
      expect(enriched.staffWarnings, ['too_sweet_for_some']);
      expect(enriched.similarFamousDna, ['sauvage_like']);
      expect(enriched.staffIntelligenceStatus, 'trusted');
      expect(enriched.reviewNeeded, isTrue);
      expect(enriched.staffConfidence, 3);
      expect(enriched.staffDataCoverage, 1);
      expect(enriched.staffDataCoverageLabel, 'complete');

      final serialized = enriched.toMap();
      expect(serialized['staffTagScores'], enriched.staffTagScores);
      expect(serialized['staffWarnings'], ['too_sweet_for_some']);
      expect(serialized['staffDataCoverage'], 1);
      expect(serialized['reviewNeeded'], isTrue);
    });

    test('reads Arabic names and aliases and indexes them for search', () {
      final now = Timestamp.now();

      final product = ProductModel.fromMap(
        documentId: 'p7',
        map: {
          'name': 'Dior Sauvage',
          'nameAr': 'ديور سوفاج',
          'brand': 'Dior',
          'brandAr': 'ديور',
          'aliases': const ['Sauvage'],
          'aliasesAr': const ['السوفاج', 'سوفاج'],
          'price': 2500,
          'stock': 3,
          'gender': 'men',
          'season': 'all_seasons',
          'fragranceFamily': 'fresh',
          'notes': const ['bergamot'],
          'imageUrls': const [],
          'description': 'desc',
          'categoryName': 'Perfume',
          'createdAt': now,
          'updatedAt': now,
        },
      );

      expect(product.nameAr, 'ديور سوفاج');
      expect(product.brandAr, 'ديور');
      expect(product.aliases, contains('Sauvage'));
      expect(product.aliasesAr, contains('السوفاج'));
      expect(product.searchPrefixes, contains('سو'));
      expect(product.searchPrefixes, contains('سوفاج'));
    });
  });
}
