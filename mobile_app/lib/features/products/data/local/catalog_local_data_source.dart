import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductCatalogCacheEntry {
  final List<ProductModel> products;
  final DateTime? cachedAt;

  const ProductCatalogCacheEntry({
    required this.products,
    required this.cachedAt,
  });

  static const empty = ProductCatalogCacheEntry(
    products: <ProductModel>[],
    cachedAt: null,
  );
}

abstract class ProductCatalogLocalDataSource {
  Future<ProductCatalogCacheEntry> loadCatalog();
  Future<void> saveCatalog(List<ProductModel> products);
  Future<void> clear();
}

class SharedPreferencesProductCatalogLocalDataSource
    implements ProductCatalogLocalDataSource {
  static const String _catalogKey = 'product_catalog_cache_v1';
  static const int _schemaVersion = 1;

  @override
  Future<ProductCatalogCacheEntry> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catalogKey);
    if (raw == null || raw.trim().isEmpty) {
      return ProductCatalogCacheEntry.empty;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return ProductCatalogCacheEntry.empty;
      if (decoded['schemaVersion'] != _schemaVersion) {
        return ProductCatalogCacheEntry.empty;
      }
      final products = decoded['products'];
      if (products is! Iterable) return ProductCatalogCacheEntry.empty;
      final cachedAt = _decodeCachedAt(decoded['cachedAt']);

      final restoredProducts = products
          .whereType<Map>()
          .map((entry) {
            final id = entry['id']?.toString().trim() ?? '';
            final data = entry['data'];
            if (id.isEmpty || data is! Map) return null;
            return ProductModel.fromMap(
              documentId: id,
              map: _decodeProductMap(Map<String, dynamic>.from(data)),
            );
          })
          .whereType<ProductModel>()
          .toList(growable: false);
      return ProductCatalogCacheEntry(
        products: restoredProducts,
        cachedAt: cachedAt,
      );
    } catch (_) {
      await prefs.remove(_catalogKey);
      return ProductCatalogCacheEntry.empty;
    }
  }

  @override
  Future<void> saveCatalog(List<ProductModel> products) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'cachedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
      'products': products
          .map(
            (product) => <String, dynamic>{
              'id': product.id,
              'data': _encodeProductMap(product.toMap()),
            },
          )
          .toList(growable: false),
    };
    await prefs.setString(_catalogKey, jsonEncode(payload));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_catalogKey);
  }

  Map<String, dynamic> _encodeProductMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _encodeValue(value)));
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return <String, dynamic>{
        '__timestampMillis': value.millisecondsSinceEpoch,
      };
    }
    if (value is DateTime) {
      return <String, dynamic>{
        '__timestampMillis': value.toUtc().millisecondsSinceEpoch,
      };
    }
    if (value is Map) {
      return value.map(
        (key, child) => MapEntry(key.toString(), _encodeValue(child)),
      );
    }
    if (value is Iterable) {
      return value.map(_encodeValue).toList(growable: false);
    }
    return value;
  }

  Map<String, dynamic> _decodeProductMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _decodeValue(value)));
  }

  dynamic _decodeValue(dynamic value) {
    if (value is Map && value.containsKey('__timestampMillis')) {
      final millis = value['__timestampMillis'];
      if (millis is int) return Timestamp.fromMillisecondsSinceEpoch(millis);
      if (millis is num) {
        return Timestamp.fromMillisecondsSinceEpoch(millis.toInt());
      }
    }
    if (value is Map) {
      return value.map(
        (key, child) => MapEntry(key.toString(), _decodeValue(child)),
      );
    }
    if (value is Iterable) {
      return value.map(_decodeValue).toList(growable: false);
    }
    return value;
  }

  DateTime? _decodeCachedAt(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return null;
  }
}
