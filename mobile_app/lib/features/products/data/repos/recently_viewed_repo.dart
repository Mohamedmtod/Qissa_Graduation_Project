import 'package:flutter/foundation.dart';
import 'package:perfume_app/features/products/data/local/recently_viewed_local_data_source.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';

class RecentlyViewedRepo {
  final RecentlyViewedLocalDataSource _localDataSource;
  final ProductRepo _productRepo;

  static const int defaultMaxItems = 20;
  static const int defaultPageSize = 10;

  RecentlyViewedRepo({
    required RecentlyViewedLocalDataSource localDataSource,
    required ProductRepo productRepo,
  }) : _localDataSource = localDataSource,
       _productRepo = productRepo;

  Future<void> addView(String productId, {int maxItems = defaultMaxItems}) async {
    try {
      final normalizedId = productId.trim();
      if (normalizedId.isEmpty) return;

      final ids = List<String>.from(
        await _localDataSource.getRecentlyViewedIds(),
      );
      
      debugPrint('🔍 RecentlyViewedRepo: Before addView - current IDs: $ids');

      ids.remove(normalizedId);
      ids.insert(0, normalizedId);

      if (ids.length > maxItems) {
        ids.removeRange(maxItems, ids.length);
      }

      await _localDataSource.saveRecentlyViewedIds(ids);
      debugPrint('✅ RecentlyViewedRepo: Saved product $productId. Current list: $ids');
    } catch (e) {
      // Keep product details flow resilient if local storage is unavailable.
      debugPrint('❌ RecentlyViewedRepo: Error in addView: $e');
    }
  }

  Future<List<String>> getRecentlyViewedIds() {
    return _localDataSource.getRecentlyViewedIds();
  }

  Future<List<String>> getRecentlyViewedIdsPage({
    int skip = 0,
    int limit = defaultPageSize,
  }) async {
    final ids = await getRecentlyViewedIds();
    if (skip >= ids.length) return const <String>[];
    return ids.skip(skip).take(limit).toList();
  }

  Future<List<ProductModel>> getRecentlyViewedProducts({
    int skip = 0,
    int limit = defaultPageSize,
  }) async {
    final ids = await getRecentlyViewedIdsPage(skip: skip, limit: limit);
    debugPrint('🔍 RecentlyViewedRepo: getRecentlyViewedProducts called - IDs: $ids');
    
    if (ids.isEmpty) {
      debugPrint('📭 RecentlyViewedRepo: No recently viewed products');
      return const <ProductModel>[];
    }

    final products = await _productRepo.fetchProductsByIds(ids);
    debugPrint('✅ RecentlyViewedRepo: Fetched ${products.length} products');
    return products;
  }

  Future<void> clear() {
    return _localDataSource.clear();
  }
}