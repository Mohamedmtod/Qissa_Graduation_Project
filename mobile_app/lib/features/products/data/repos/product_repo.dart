import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:perfume_app/features/products/data/local/catalog_local_data_source.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

/// Result class that bundles products with the raw snapshot for pagination.
class ProductQueryResult {
  final List<ProductModel> products;
  final Object? lastDocument;
  final bool hasMore;

  ProductQueryResult({
    required this.products,
    this.lastDocument,
    this.hasMore = false,
  });
}

class ProductRepo {
  static const Duration _catalogCacheTtl = Duration(minutes: 30);
  static const int _defaultCatalogWarmUpLimit = 200;

  final FirebaseFirestore _firestore;
  final ProductCatalogLocalDataSource _localCatalog;
  List<ProductModel> _inMemoryCatalog = const [];
  DateTime? _catalogCachedAt;
  Future<List<ProductModel>>? _catalogWarmUpInFlight;

  ProductRepo({
    FirebaseFirestore? firestore,
    ProductCatalogLocalDataSource? localCatalog,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localCatalog =
           localCatalog ?? SharedPreferencesProductCatalogLocalDataSource();

  bool get hasWarmCatalog => _inMemoryCatalog.isNotEmpty;

  Future<List<ProductModel>> warmUpCatalog({
    int limit = _defaultCatalogWarmUpLimit,
    bool forceRefresh = false,
  }) {
    final now = DateTime.now();
    final cachedAt = _catalogCachedAt;
    final isFresh =
        cachedAt != null && now.difference(cachedAt) <= _catalogCacheTtl;

    if (!forceRefresh && isFresh && _inMemoryCatalog.isNotEmpty) {
      return Future.value(_inMemoryCatalog);
    }

    final inFlight = _catalogWarmUpInFlight;
    if (!forceRefresh && inFlight != null) return inFlight;

    final fetch = _loadLocalCatalogIfNeeded(limit: limit)
        .then((_) => fetchAICatalog(limit: limit, forceServer: true))
        .then((products) async {
          _inMemoryCatalog = products.where(_isActive).take(limit).toList();
          _catalogCachedAt = DateTime.now();
          await _localCatalog.saveCatalog(_inMemoryCatalog);
          return _inMemoryCatalog;
        })
        .catchError((Object error) {
          if (_inMemoryCatalog.isNotEmpty) {
            return _inMemoryCatalog;
          }
          throw error;
        })
        .whenComplete(() {
          _catalogWarmUpInFlight = null;
        });

    _catalogWarmUpInFlight = fetch;
    return fetch;
  }

  Future<void> _loadLocalCatalogIfNeeded({required int limit}) async {
    if (_inMemoryCatalog.isNotEmpty) return;
    final cached = await _localCatalog.loadCatalog();
    if (cached.products.isEmpty) return;
    _inMemoryCatalog = cached.products.where(_isActive).take(limit).toList();
    _catalogCachedAt = cached.cachedAt;
  }

  bool _matchesCategory(ProductModel product, String categoryName) {
    final normalizedCategory = categoryName.trim().toLowerCase();
    if (normalizedCategory.isEmpty) return true;
    return product.categoryName.toLowerCase().contains(normalizedCategory);
  }

  bool _isActive(ProductModel product) => product.isActive;

  List<ProductModel> _activeCachedCatalog() {
    return _inMemoryCatalog.where(_isActive).toList(growable: false);
  }

  ProductModel? _productFromDoc(QueryDocumentSnapshot doc) {
    try {
      return ProductModel.fromMap(
        map: doc.data() as Map<String, dynamic>,
        documentId: doc.id,
      );
    } catch (e) {
      debugPrint('ProductRepo: Skipping malformed product [${doc.id}]: $e');
      return null;
    }
  }

  Future<ProductQueryResult> _fetchFilteredPage({
    required Query query,
    required bool Function(ProductModel product) include,
    Object? startAfterDocument,
    int limit = 20,
    int fetchMultiplier = 3,
  }) async {
    final pageLimit = limit < 1 ? 1 : limit;
    final fetchLimit = (pageLimit * fetchMultiplier).clamp(pageLimit, 100);
    var fbQuery = query.limit(fetchLimit);

    if (startAfterDocument != null && startAfterDocument is DocumentSnapshot) {
      fbQuery = fbQuery.startAfterDocument(startAfterDocument);
    }

    final products = <ProductModel>[];
    DocumentSnapshot? cursor;
    var hasMore = false;

    while (products.length < pageLimit) {
      final snapshot = await fbQuery.get();
      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }

      cursor = snapshot.docs.last;
      hasMore = snapshot.docs.length >= fetchLimit;

      for (final doc in snapshot.docs) {
        final product = _productFromDoc(doc);
        if (product != null && include(product)) {
          products.add(product);
          if (products.length == pageLimit) break;
        }
      }

      if (!hasMore || products.length >= pageLimit) break;
      fbQuery = query.startAfterDocument(cursor).limit(fetchLimit);
    }

    return ProductQueryResult(
      products: products,
      lastDocument: cursor,
      hasMore: hasMore,
    );
  }

  bool _matchesText(ProductModel product, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchableParts = <String>[
      product.nameLower,
      product.name,
      product.nameAr,
      product.brand,
      product.brandAr,
      product.categoryName,
      product.gender,
      product.season,
      product.fragranceFamily,
      product.description,
      product.occasion,
      product.time,
      product.intensity,
      if (product.size != null) product.size!,
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.tags,
      ...product.aliases,
      ...product.aliasesAr,
      ...product.variants.map((variant) => variant.label),
    ].join(' ').toLowerCase();

    return normalizedQuery
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .every(searchableParts.contains);
  }

  ProductQueryResult searchLocally({required String query, int limit = 20}) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) {
      return ProductQueryResult(products: const []);
    }

    final products = _activeCachedCatalog()
        .where((product) {
          return product.searchPrefixes.contains(normalizedQuery) ||
              _matchesText(product, normalizedQuery);
        })
        .take(limit)
        .toList();

    return ProductQueryResult(products: products);
  }

  ProductQueryResult filterLocally({
    String? query,
    String? categoryName,
    String? gender,
    String? season,
    String? fragranceFamily,
    int limit = 20,
  }) {
    final normalizedGender = gender?.trim().toLowerCase();
    final normalizedSeason = season?.trim().toLowerCase();
    final normalizedFamily = fragranceFamily?.trim().toLowerCase();
    final normalizedCategory = categoryName?.trim().toLowerCase();
    final normalizedQuery = query?.trim();

    final products = _activeCachedCatalog()
        .where((product) {
          if (normalizedGender != null &&
              normalizedGender.isNotEmpty &&
              product.gender.toLowerCase() != normalizedGender) {
            return false;
          }

          if (normalizedSeason != null &&
              normalizedSeason.isNotEmpty &&
              normalizedSeason != 'all season' &&
              product.season.toLowerCase() != normalizedSeason) {
            return false;
          }

          if (normalizedFamily != null &&
              normalizedFamily.isNotEmpty &&
              !product.fragranceFamily.toLowerCase().contains(
                normalizedFamily,
              )) {
            return false;
          }

          if (normalizedCategory != null &&
              normalizedCategory.isNotEmpty &&
              !_matchesCategory(product, normalizedCategory)) {
            return false;
          }

          if (normalizedQuery != null &&
              normalizedQuery.isNotEmpty &&
              !_matchesText(product, normalizedQuery)) {
            return false;
          }

          return true;
        })
        .take(limit)
        .toList();

    return ProductQueryResult(products: products);
  }

  ProductQueryResult flashSaleLocally({int limit = 20}) {
    final products = _activeCachedCatalog()
        .where((product) => product.isOnSale)
        .take(limit)
        .toList();

    return ProductQueryResult(products: products);
  }

  // ── Home: Real-time stream for flash sale products ───────────
  Stream<List<ProductModel>> streamFlashSaleProducts() {
    int limit = 20;
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .where('saleActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return ProductModel.fromMap(
                    map: doc.data(),
                    documentId: doc.id,
                  );
                } catch (e) {
                  debugPrint(
                    '⚠️ ProductRepo: Skipping malformed product [${doc.id}]: $e',
                  );
                  return null;
                }
              })
              .whereType<ProductModel>()
              .where(_isActive)
              .where((product) => product.isOnSale)
              .toList();
        });
  }

  // ── Product Details: Real-time stream for single doc ───────────
  Stream<ProductModel?> streamProductById(String id) {
    return _firestore.collection('products').doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;

      return ProductModel.fromMap(map: doc.data()!, documentId: doc.id);
    });
  }

  Future<List<ProductModel>> fetchProductsByIds(List<String> ids) async {
    final uniqueIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return const [];

    final productsById = <String, ProductModel>{};

    for (int i = 0; i < uniqueIds.length; i += 10) {
      final chunk = uniqueIds.skip(i).take(10).toList();
      final snapshot = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        productsById[doc.id] = ProductModel.fromMap(
          map: doc.data(),
          documentId: doc.id,
        );
      }
    }

    return ids
        .map((id) => productsById[id.trim()])
        .whereType<ProductModel>()
        .where(_isActive)
        .toList();
  }

  // ── Search: Prefix search-as-you-type via arrayContains ────────
  /// Searches products by matching the query against the searchPrefixes
  /// array field. Supports search-as-you-type and multi-word queries.
  ///
  /// Single word: "tal" → arrayContains("tal") → matches "Talya ..."
  /// Multi-word: "talya perfume" → arrayContains("perfume") (longest word)
  ///   then client-side filters to ensure "talya" also matches.
  Future<ProductQueryResult> searchByPrefix({
    required String query,
    Object? startAfterDocument,
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();

    // Minimum 2 characters for prefix search
    if (q.length < 2) return ProductQueryResult(products: []);

    // Split into individual words, filter out short ones
    final words = q.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();

    if (words.isEmpty) return ProductQueryResult(products: []);

    // Pick the longest word as the primary Firestore filter
    // (most selective → smallest result set from server)
    final primaryWord = words.reduce((a, b) => a.length >= b.length ? a : b);

    Query fbQuery = _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .where('searchPrefixes', arrayContains: primaryWord)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDocument != null && startAfterDocument is DocumentSnapshot) {
      fbQuery = fbQuery.startAfterDocument(startAfterDocument);
    }

    final snapshot = await fbQuery.get();

    // If multi-word query, client-side filter: all other words must
    // also exist in the product's searchPrefixes
    final otherWords = words.where((w) => w != primaryWord).toList();

    final products = snapshot.docs
        .map(_productFromDoc)
        .whereType<ProductModel>()
        .where((product) {
          // Every other word must be found in searchPrefixes
          return otherWords.every(
            (w) =>
                product.searchPrefixes.contains(w) || _matchesText(product, w),
          );
        })
        .toList();

    return ProductQueryResult(
      products: products,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  // ── Filter: Server-side .where() + pagination ─────────────────
  Future<ProductQueryResult> filterProducts({
    String? query,
    String? categoryName,
    String? gender,
    String? season,
    String? fragranceFamily,
    Object? startAfterDocument,
    int limit = 20,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase();
    final hasQuery = normalizedQuery != null && normalizedQuery.length >= 2;
    final normalizedGender = gender?.trim().toLowerCase();
    final normalizedSeason = season?.trim().toLowerCase();
    final normalizedFamily = fragranceFamily?.trim().toLowerCase();
    final categoryKey = buildProductQueryKey(categoryName ?? '');

    // ── Client-side include predicate (shared by all paths) ─────
    bool include(ProductModel product) {
      if (normalizedGender != null &&
          normalizedGender.isNotEmpty &&
          product.gender.toLowerCase() != normalizedGender) {
        return false;
      }
      if (normalizedSeason != null &&
          normalizedSeason.isNotEmpty &&
          normalizedSeason != 'all season' &&
          product.season.toLowerCase() != normalizedSeason) {
        return false;
      }
      if (normalizedFamily != null &&
          normalizedFamily.isNotEmpty &&
          product.fragranceFamily.toLowerCase() != normalizedFamily &&
          !product.fragranceFamily.toLowerCase().contains(normalizedFamily)) {
        return false;
      }
      if (categoryKey.isNotEmpty &&
          product.categoryKey != categoryKey &&
          !_matchesCategory(product, categoryKey)) {
        return false;
      }
      if (hasQuery && !_matchesText(product, normalizedQuery)) {
        return false;
      }
      return true;
    }

    // ── When a text query is present, use searchPrefixes arrayContains ──
    // This mirrors searchByPrefix so that "dior" + gender:"men" only
    // fetches Dior products from Firestore, then filters gender client-side.
    if (hasQuery) {
      final words = normalizedQuery
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 2)
          .toList();

      if (words.isNotEmpty) {
        final primaryWord =
            words.reduce((a, b) => a.length >= b.length ? a : b);
        final otherWords = words.where((w) => w != primaryWord).toList();

        Query fbQuery = _firestore
            .collection('products')
            .where('isActive', isEqualTo: true)
            .where('searchPrefixes', arrayContains: primaryWord)
            .orderBy('createdAt', descending: true);

        if (startAfterDocument != null &&
            startAfterDocument is DocumentSnapshot) {
          fbQuery = fbQuery.startAfterDocument(startAfterDocument);
        }

        try {
          final snapshot = await fbQuery.limit(limit * 3).get();
          final products = snapshot.docs
              .map(_productFromDoc)
              .whereType<ProductModel>()
              .where((p) {
                // Ensure all other query words are also present
                if (otherWords.isNotEmpty &&
                    !otherWords.every((w) =>
                        p.searchPrefixes.contains(w) ||
                        _matchesText(p, w))) {
                  return false;
                }
                return include(p);
              })
              .take(limit)
              .toList();

          return ProductQueryResult(
            products: products,
            lastDocument:
                snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
            hasMore: snapshot.docs.length >= limit * 3,
          );
        } on FirebaseException catch (error) {
          if (error.code != 'failed-precondition') rethrow;
          debugPrint(
            'ProductRepo: searchPrefixes+filter fallback: $error',
          );
          // Fall through to attribute-only path below
        }
      }
    }

    // ── No text query (or fallback): filter by attributes only ────
    Query fbQuery = _firestore
        .collection('products')
        .where('isActive', isEqualTo: true);

    // Pick the most restrictive field for the primary Firestore query.
    // Family-only pages intentionally avoid fragranceFamilyKey here because
    // legacy catalog snapshots may not have that field populated yet.
    if (categoryKey.isNotEmpty) {
      fbQuery = fbQuery.where('categoryKey', isEqualTo: categoryKey);
    } else if (normalizedFamily == null || normalizedFamily.isEmpty) {
      if (normalizedGender != null && normalizedGender.isNotEmpty) {
        fbQuery = fbQuery.where('gender', isEqualTo: normalizedGender);
      } else if (normalizedSeason != null &&
          normalizedSeason.isNotEmpty &&
          normalizedSeason != 'all season') {
        fbQuery = fbQuery.where('season', isEqualTo: normalizedSeason);
      }
    }
    // When a family filter is present without a category filter, use a broader
    // active-products query and let the shared include predicate match the
    // family text against fragranceFamily.

    fbQuery = fbQuery.orderBy('createdAt', descending: true);

    try {
      return await _fetchFilteredPage(
        query: fbQuery,
        startAfterDocument: startAfterDocument,
        limit: limit,
        include: include,
      );
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') rethrow;

      debugPrint('ProductRepo: falling back for filterProducts query: $error');

      // Fallback without orderBy to avoid composite index requirement.
      Query fallbackQuery = _firestore
          .collection('products')
          .where('isActive', isEqualTo: true);

      if (categoryKey.isNotEmpty) {
        fallbackQuery =
            fallbackQuery.where('categoryKey', isEqualTo: categoryKey);
      } else if (normalizedFamily == null || normalizedFamily.isEmpty) {
        if (normalizedGender != null && normalizedGender.isNotEmpty) {
          fallbackQuery =
              fallbackQuery.where('gender', isEqualTo: normalizedGender);
        } else if (normalizedSeason != null &&
            normalizedSeason.isNotEmpty &&
            normalizedSeason != 'all season') {
          fallbackQuery =
              fallbackQuery.where('season', isEqualTo: normalizedSeason);
        }
      }

      final result = await _fetchFilteredPage(
        query: fallbackQuery,
        startAfterDocument: startAfterDocument,
        limit: limit,
        fetchMultiplier: 5,
        include: include,
      );

      result.products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    }
  }

  // ── Filter by Category Name ─────────────────────────────────────
  Future<ProductQueryResult> filterByCategory({
    required String categoryName,
    Object? startAfterDocument,
    int limit = 20,
  }) async {
    debugPrint('🔍 ProductRepo: Filtering category: "$categoryName"');
    final trimmedCategory = categoryName.trim();
    debugPrint(
      '🔍 ProductRepo: Filtering category (trimmed): "$trimmedCategory"',
    );

    if (trimmedCategory.isEmpty) {
      return ProductQueryResult(products: const []);
    }

    final categoryKey = buildProductQueryKey(trimmedCategory);
    Query fbQuery = _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .where('categoryKey', isEqualTo: categoryKey)
        .orderBy('createdAt', descending: true);

    try {
      return await _fetchFilteredPage(
        query: fbQuery,
        startAfterDocument: startAfterDocument,
        limit: limit,
        include: (product) =>
            product.categoryKey == categoryKey ||
            _matchesCategory(product, categoryKey),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') rethrow;
      
      debugPrint('ProductRepo: falling back for filterByCategory query: $error');
      
      Query fallbackQuery = _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('categoryKey', isEqualTo: categoryKey);
          
      final result = await _fetchFilteredPage(
        query: fallbackQuery,
        startAfterDocument: startAfterDocument,
        limit: limit,
        fetchMultiplier: 5,
        include: (product) =>
            product.categoryKey == categoryKey ||
            _matchesCategory(product, categoryKey),
      );
      
      result.products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    }
  }

  // ── Flash Sale ─────────────────────────────────────────────────
  Future<ProductQueryResult> getFlashSaleProducts({
    Object? startAfterDocument,
    int limit = 20,
  }) async {
    try {
      Query fbQuery = _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('saleActive', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      return await _fetchFilteredPage(
        query: fbQuery,
        startAfterDocument: startAfterDocument,
        limit: limit,
        include: (product) => product.isOnSale,
      );
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') rethrow;
      debugPrint('ProductRepo: falling back for flash sale query: $error');
      return _getFlashSaleProductsWithoutCompositeIndex(
        startAfterDocument: startAfterDocument,
        limit: limit,
      );
    }
  }

  Future<ProductQueryResult> _getFlashSaleProductsWithoutCompositeIndex({
    Object? startAfterDocument,
    int limit = 20,
  }) async {
    Query fbQuery = _firestore
        .collection('products')
        .where('saleActive', isEqualTo: true)
        .limit(limit);

    if (startAfterDocument != null && startAfterDocument is DocumentSnapshot) {
      fbQuery = fbQuery.startAfterDocument(startAfterDocument);
    }

    try {
      final snapshot = await fbQuery.get();
      final products = snapshot.docs
          .map(_productFromDoc)
          .whereType<ProductModel>()
          .where(_isActive)
          .where((product) => product.isOnSale)
          .toList();

      return ProductQueryResult(
        products: products,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length >= limit,
      );
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') rethrow;
      final snapshot = await _firestore.collection('products').limit(200).get();
      final products = snapshot.docs
          .map(_productFromDoc)
          .whereType<ProductModel>()
          .where(_isActive)
          .where((product) => product.isOnSale)
          .take(limit)
          .toList();
      return ProductQueryResult(products: products, hasMore: false);
    }
  }

  // ── AI Catalog: Full catalog fetch for local AI ranking ────────
  /// Fetches a broad product catalog suitable for local AI filtering
  /// and ranking. Unlike [streamProducts] (limited to 20) or
  /// [searchByPrefix] (requires a query), this returns a larger set
  /// that the AI feature can filter and rank locally.
  ///
  /// Products are ordered by creation date (newest first).
  /// Default limit is 200, adjust as catalog grows.
  Future<List<ProductModel>> fetchAICatalog({
    int limit = 200,
    bool forceServer = false,
  }) async {
    final cachedAt = _catalogCachedAt;
    final isFresh =
        cachedAt != null &&
        DateTime.now().difference(cachedAt) <= _catalogCacheTtl;
    if (!forceServer && isFresh && _inMemoryCatalog.isNotEmpty) {
      return _inMemoryCatalog.where(_isActive).take(limit).toList();
    }

    final snapshot = await _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final products = snapshot.docs
        .map((doc) {
          return ProductModel.fromMap(map: doc.data(), documentId: doc.id);
        })
        .where(_isActive)
        .toList();
    _inMemoryCatalog = products;
    _catalogCachedAt = DateTime.now();
    unawaited(_localCatalog.saveCatalog(products));
    return products;
  }
}
