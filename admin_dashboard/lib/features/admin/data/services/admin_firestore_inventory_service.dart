import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_restock_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_restock_request.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_inventory_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_inventory_worker_client.dart';

/// Service that reads product data from Firestore and maps it to
/// admin-level [AdminInventorySnapshot] for the inventory page.
///
/// Maps Firestore product documents to [InventoryItem] with:
/// - `stock` -> `units`
/// - `categoryName` -> `collection`
/// - `imageUrls[0]` -> `imageUrl`
/// - `stock < threshold` -> `lowStock`
class FirestoreAdminInventoryService implements AdminInventoryService {
  FirestoreAdminInventoryService({
    FirebaseFirestore? firestore,
    required AdminInventoryWorkerClient workerClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _workerClient = workerClient;

  final FirebaseFirestore _firestore;
  final AdminInventoryWorkerClient _workerClient;
  static const int _inventoryPageLimit = 250;
  static const int _pendingRestockReadLimit = 2000;

  @override
  Future<String> createInventoryItem({
    required String name,
    required String nameAr,
    required String brand,
    required String brandAr,
    required List<String> aliases,
    required List<String> aliasesAr,
    required String description,
    required double price,
    String? size,
    double? salePrice,
    required String collection,
    required int stock,
    required bool isBestSeller,
    required bool isNew,
    required String gender,
    required String season,
    required String time,
    required String occasion,
    required String intensity,
    required String fragranceFamily,
    required List<String> topNotes,
    required List<String> middleNotes,
    required List<String> baseNotes,
    required List<String> tags,
    List<String>? imageUrls,
    String productType = 'simple',
    bool isSellable = true,
    String unitType = 'piece',
    List<ProductVariant> variants = const [],
    Map<String, int> staffTagScores = const {},
    List<String> staffWarnings = const [],
    Map<String, String> staffSalesNotes = const {},
    List<String> similarFamousDna = const [],
    String staffIntelligenceStatus = 'draft',
    bool reviewNeeded = false,
    int staffConfidence = 1,
    double staffDataCoverage = 0,
    int staffTaxonomyVersion = 1,
    String? staffUpdatedBy,
    int staffReviewCount = 0,
  }) async {
    final cleanedImageUrls = (imageUrls ?? <String>[])
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final cleanedAliases = aliases
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final cleanedAliasesAr = aliasesAr
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final cleanedNameAr = nameAr.trim();
    final cleanedBrandAr = brandAr.trim();
    final cleanedCollection = collection.trim();
    final cleanedFragranceFamily = fragranceFamily.trim();

    final docRef = _firestore.collection('products').doc();
    await docRef.set({
      'name': name,
      if (cleanedNameAr.isNotEmpty) 'nameAr': cleanedNameAr,
      'brand': brand,
      if (cleanedBrandAr.isNotEmpty) 'brandAr': cleanedBrandAr,
      if (cleanedAliases.isNotEmpty) 'aliases': cleanedAliases,
      if (cleanedAliasesAr.isNotEmpty) 'aliasesAr': cleanedAliasesAr,
      'nameLower': name.toLowerCase(),
      'searchPrefixes': _buildSearchPrefixes([
        name,
        cleanedNameAr,
        brand,
        cleanedBrandAr,
        ...cleanedAliases,
        ...cleanedAliasesAr,
      ]),
      'description': description,
      'price': price,
      if (size != null && size.trim().isNotEmpty) 'size': size.trim(),
      if (salePrice != null) 'salePrice': salePrice,
      'categoryName': cleanedCollection,
      'categoryKey': _buildQueryKey(cleanedCollection),
      'stock': stock,
      'saleActive': salePrice != null && salePrice > 0 && salePrice < price,
      'isBestSeller': isBestSeller,
      'isNew': isNew,
      'gender': gender,
      'season': season,
      'time': time,
      'occasion': occasion,
      'intensity': intensity,
      'fragranceFamily': cleanedFragranceFamily,
      'fragranceFamilyKey': _buildQueryKey(cleanedFragranceFamily),
      'topNotes': topNotes,
      'middleNotes': middleNotes,
      'baseNotes': baseNotes,
      'tags': tags,
      'imageUrls': cleanedImageUrls,
      'productType': productType,
      'isSellable': isSellable,
      'unitType': unitType,
      if (variants.isNotEmpty)
        'variants': variants.map((v) => v.toJson()).toList(),
      if (staffTagScores.isNotEmpty) 'staffTagScores': staffTagScores,
      if (staffWarnings.isNotEmpty) 'staffWarnings': staffWarnings,
      if (staffSalesNotes.isNotEmpty) 'staffSalesNotes': staffSalesNotes,
      if (similarFamousDna.isNotEmpty) 'similarFamousDna': similarFamousDna,
      if (staffTagScores.isNotEmpty ||
          staffWarnings.isNotEmpty ||
          staffSalesNotes.isNotEmpty ||
          staffIntelligenceStatus != 'draft' ||
          reviewNeeded)
        'staffIntelligenceStatus': staffIntelligenceStatus,
      if (reviewNeeded) 'reviewNeeded': reviewNeeded,
      if (staffConfidence != 1) 'staffConfidence': staffConfidence,
      if (staffTagScores.isNotEmpty) 'staffDataCoverage': staffDataCoverage,
      if (staffTagScores.isNotEmpty)
        'staffTaxonomyVersion': staffTaxonomyVersion,
      if (staffUpdatedBy != null && staffUpdatedBy.trim().isNotEmpty)
        'staffUpdatedBy': staffUpdatedBy.trim(),
      if (staffTagScores.isNotEmpty)
        'staffUpdatedAt': FieldValue.serverTimestamp(),
      if (staffReviewCount > 0) 'staffReviewCount': staffReviewCount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  List<String> _buildSearchPrefixes(Iterable<String> values) {
    final prefixes = <String>{};
    for (final value in values) {
      for (final word in _searchWordsFor(value)) {
        if (word.length < 2) continue;
        for (var i = 2; i <= word.length; i++) {
          prefixes.add(word.substring(0, i));
        }
      }
    }
    return prefixes.toList(growable: false);
  }

  List<String> _searchWordsFor(String value) {
    final cleaned = _normalizeSearchText(value)
        .replaceAll(RegExp(r'[^\w\s\u0621-\u064A\u0660-\u0669]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];

    final words = <String>[];
    for (final word in cleaned.split(' ')) {
      if (word.isEmpty) continue;
      words.add(word);
      if (word.length > 3 && word.startsWith('\u0627\u0644')) {
        words.add(word.substring(2));
      }
    }
    return words;
  }

  String _normalizeSearchText(String value) {
    var result = value.toLowerCase().trim();
    result = result.replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '');
    result = result.replaceAll('\u0640', '');
    result = result
        .replaceAll(RegExp(r'[\u0623\u0625\u0622]'), '\u0627')
        .replaceAll('\u0649', '\u064a')
        .replaceAll('\u0624', '\u0648')
        .replaceAll('\u0626', '\u064a')
        .replaceAll('\u0629', '\u0647');
    return result;
  }

  String _buildQueryKey(String value) {
    return _normalizeSearchText(value)
        .replaceAll(RegExp(r'[^\w\s\u0621-\u064A\u0660-\u0669]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Future<AdminInventorySnapshot> fetchInventorySnapshot() async {
    // Keep this bounded until the inventory UI supports cursor navigation.
    final snapshot = await _firestore
        .collection('products')
        .orderBy('name')
        .limit(_inventoryPageLimit)
        .get();

    final restockSnapshot = await _firestore
        .collection('restock_requests')
        .where('status', isEqualTo: 'pending')
        .limit(_pendingRestockReadLimit)
        .get();

    final waitingUsersCount = <String, int>{};
    for (final doc in restockSnapshot.docs) {
      final productId = doc.data()['productId'] as String? ?? '';
      waitingUsersCount[productId] = (waitingUsersCount[productId] ?? 0) + 1;
    }

    final items = snapshot.docs
        .map(
          (doc) => _mapDocToInventoryItem(
            doc.id,
            doc.data(),
            waitingUsersCount[doc.id] ?? 0,
          ),
        )
        .toList();

    final lowStockCount = items.where((item) => item.lowStock).length;
    final outOfStockCount = items.where((item) => item.units <= 0).length;
    final totalItems = items.length;

    // Health score: % of items that are NOT low stock
    final healthScore = totalItems > 0
        ? ((totalItems - lowStockCount) / totalItems * 100)
        : 100.0;

    // Overstock: items with > 200 units (arbitrary threshold)
    final overstockCount = items.where((item) => item.units > 200).length;

    final aiMessage = lowStockCount > 0
        ? '$lowStockCount product${lowStockCount > 1 ? "s" : ""} below stock threshold. $outOfStockCount out of stock.'
        : 'All products are well-stocked.';

    return AdminInventorySnapshot(
      items: items,
      healthScore: double.parse(healthScore.toStringAsFixed(1)),
      skuCount: totalItems,
      overstockCount: overstockCount,
      aiPredictionMessage: aiMessage,
      aiActionLabel: lowStockCount > 0 ? 'Review Low Stock' : 'Inventory OK',
    );
  }

  InventoryItem _mapDocToInventoryItem(
    String id,
    Map<String, dynamic> data,
    int waitingUsers,
  ) {
    final name = (data['name'] as String?) ?? 'Unknown Product';
    final categoryName = (data['categoryName'] as String?) ?? 'Uncategorized';

    // Image: first entry from imageUrls array
    final rawImageUrls = data['imageUrls'] as List<dynamic>? ?? [];
    final imageUrl = rawImageUrls.isNotEmpty
        ? (rawImageUrls.first as String?) ?? ''
        : '';

    // Stock
    final rawStock = data['stock'];
    final int units;
    if (rawStock is int) {
      units = rawStock;
    } else if (rawStock is double) {
      units = rawStock.toInt();
    } else {
      units = 0;
    }

    final lowStock = InventoryItem.determineLowStock(units);

    // Trend: no historical data yet, default to up
    // In the future this could compare against previous snapshot
    final trend = lowStock && units <= 0
        ? InventoryTrend.surge
        : lowStock
        ? InventoryTrend.down
        : InventoryTrend.up;

    final rawVariants = data['variants'] as List<dynamic>?;
    final List<ProductVariant> variantsList;
    if (rawVariants != null && rawVariants.isNotEmpty) {
      variantsList = rawVariants
          .map(
            (v) => ProductVariant.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList();
    } else {
      variantsList = [
        ProductVariant(
          id: 'default',
          label: (data['size'] as String?) ?? '',
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          salePrice: (data['salePrice'] as num?)?.toDouble(),
          costPrice: (data['costPrice'] as num?)?.toDouble(),
          unitType: (data['unitType'] as String?) ?? 'piece',
          stock: units.toDouble(),
          isActive: (data['isActive'] as bool?) ?? true,
        ),
      ];
    }

    final productType = (data['productType'] as String?) ?? 'simple';
    final isSellable = (data['isSellable'] as bool?) ?? true;
    final unitType = (data['unitType'] as String?) ?? 'piece';
    final staffUpdatedAt = data['staffUpdatedAt'] is Timestamp
        ? (data['staffUpdatedAt'] as Timestamp).toDate()
        : null;

    return InventoryItem(
      id: id,
      name: name,
      collection: categoryName,
      imageUrl: imageUrl,
      units: units,
      waitingUsers: waitingUsers,
      trend: trend,
      lowStock: lowStock,
      productType: productType,
      isSellable: isSellable,
      unitType: unitType,
      variants: variantsList,
      staffTagScores: _asIntMap(data['staffTagScores']),
      staffWarnings: _asStringList(data['staffWarnings']),
      staffSalesNotes: _asStringMap(data['staffSalesNotes']),
      similarFamousDna: _asStringList(data['similarFamousDna']),
      staffIntelligenceStatus:
          data['staffIntelligenceStatus'] as String? ?? 'draft',
      reviewNeeded: data['reviewNeeded'] as bool? ?? false,
      staffConfidence: (data['staffConfidence'] as num?)?.toInt() ?? 1,
      staffDataCoverage: (data['staffDataCoverage'] as num?)?.toDouble() ?? 0.0,
      staffTaxonomyVersion:
          (data['staffTaxonomyVersion'] as num?)?.toInt() ?? 1,
      staffUpdatedBy: data['staffUpdatedBy'] as String?,
      staffUpdatedAt: staffUpdatedAt,
      staffReviewCount: (data['staffReviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  List<String> _asStringList(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, String> _asStringMap(dynamic value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key.toString().trim().isNotEmpty &&
            entry.value.toString().trim().isNotEmpty)
          entry.key.toString().trim(): entry.value.toString().trim(),
    };
  }

  Map<String, int> _asIntMap(dynamic value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key.toString().trim().isNotEmpty &&
            (entry.value is num ||
                int.tryParse(entry.value.toString().trim()) != null))
          entry.key.toString().trim(): entry.value is num
              ? (entry.value as num).toInt()
              : int.parse(entry.value.toString().trim()),
    };
  }

  /// Fetches all pending restock requests, ordered by creation time.
  @override
  Future<List<AdminRestockRequest>> fetchPendingRestockRequests() async {
    final snapshot = await _firestore
        .collection('restock_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map(
          (doc) => AdminRestockRequest.fromJson({'id': doc.id, ...doc.data()}),
        )
        .toList();
  }

  @override
  Future<AdminInventoryRestockResult> executeRestock(
    String productId,
    int quantityDelta, {
    required String bearerToken,
    required String traceId,
    String? reason,
  }) async {
    final pendingRequests = await _firestore
        .collection('restock_requests')
        .where('productId', isEqualTo: productId)
        .where('status', isEqualTo: 'pending')
        .get();

    return _workerClient.executeRestock(
      productId: productId,
      delta: quantityDelta,
      bearerToken: bearerToken,
      traceId: traceId,
      reason: reason,
      requestIds: pendingRequests.docs.map((doc) => doc.id).toList(),
    );
  }
}
