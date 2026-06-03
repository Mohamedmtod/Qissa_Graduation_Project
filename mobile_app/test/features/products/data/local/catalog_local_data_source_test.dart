import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/products/data/local/catalog_local_data_source.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProductModel createProduct(String id) {
    return ProductModel(
      id: id,
      name: 'Product $id',
      nameLower: 'product $id',
      searchPrefixes: buildSearchPrefixes('Product $id'),
      brand: 'Brand',
      price: 100,
      stock: 5,
      gender: 'unisex',
      season: 'all_seasons',
      fragranceFamily: 'fresh',
      notes: const ['citrus'],
      imageUrls: const ['https://example.com/p.png'],
      description: 'desc',
      categoryName: 'Perfume',
      createdAt: Timestamp.fromMillisecondsSinceEpoch(1000),
      updatedAt: Timestamp.fromMillisecondsSinceEpoch(2000),
      isActive: true,
      occasion: 'daily',
      time: 'day',
      intensity: 'medium',
      topNotes: const ['bergamot'],
      middleNotes: const ['jasmine'],
      baseNotes: const ['musk'],
      tags: const ['fresh'],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and restores product catalog with timestamps', () async {
    final dataSource = SharedPreferencesProductCatalogLocalDataSource();
    final product = createProduct('p1');

    await dataSource.saveCatalog([product]);
    final restored = await dataSource.loadCatalog();

    expect(restored.products, hasLength(1));
    expect(restored.cachedAt, isNotNull);
    expect(restored.products.single.id, 'p1');
    expect(restored.products.single.name, product.name);
    expect(restored.products.single.createdAt.millisecondsSinceEpoch, 1000);
    expect(restored.products.single.updatedAt.millisecondsSinceEpoch, 2000);
    expect(restored.products.single.fragranceFamily, product.fragranceFamily);
  });

  test('restores persisted cachedAt value', () async {
    SharedPreferences.setMockInitialValues({
      'product_catalog_cache_v1': '''
{"schemaVersion":1,"cachedAt":123456789,"products":[]}
''',
    });
    final dataSource = SharedPreferencesProductCatalogLocalDataSource();

    final restored = await dataSource.loadCatalog();

    expect(restored.cachedAt?.millisecondsSinceEpoch, 123456789);
    expect(restored.products, isEmpty);
  });

  test('returns empty catalog and clears corrupt cache', () async {
    SharedPreferences.setMockInitialValues({
      'product_catalog_cache_v1': '{not-json',
    });
    final dataSource = SharedPreferencesProductCatalogLocalDataSource();

    final restored = await dataSource.loadCatalog();

    expect(restored.products, isEmpty);
    expect(restored.cachedAt, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('product_catalog_cache_v1'), isNull);
  });
}
