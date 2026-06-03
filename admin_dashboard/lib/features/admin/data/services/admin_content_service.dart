import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_content_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_feature_highlight.dart';

class AdminProductUpsertInput {
  const AdminProductUpsertInput({
    required this.name,
    required this.nameAr,
    required this.brand,
    required this.brandAr,
    required this.aliases,
    required this.aliasesAr,
    required this.categoryName,
    required this.price,
    required this.description,
    required this.stock,
    required this.gender,
    required this.season,
    required this.time,
    required this.occasion,
    required this.intensity,
    required this.fragranceFamily,
    required this.topNotes,
    required this.middleNotes,
    required this.baseNotes,
    required this.tags,
    required this.imageUrls,
    this.size,
    this.salePrice,
    this.isActive = true,
    this.isBestSeller = false,
    this.isNew = false,
  });

  final String name;
  final String nameAr;
  final String brand;
  final String brandAr;
  final List<String> aliases;
  final List<String> aliasesAr;
  final String categoryName;
  final double price;
  final String description;
  final int stock;
  final String gender;
  final String season;
  final String time;
  final String occasion;
  final String intensity;
  final String fragranceFamily;
  final List<String> topNotes;
  final List<String> middleNotes;
  final List<String> baseNotes;
  final List<String> tags;
  final List<String> imageUrls;
  final String? size;
  final double? salePrice;
  final bool isActive;
  final bool isBestSeller;
  final bool isNew;
}

class AdminBannerUpsertInput {
  const AdminBannerUpsertInput({
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.targetPath,
    this.isActive = true,
    this.queuePosition = 0,
  });

  final String title;
  final String imageUrl;
  final String? subtitle;
  final String? targetPath;
  final bool isActive;
  final int queuePosition;
}

class AdminCategoryUpsertInput {
  const AdminCategoryUpsertInput({
    required this.name,
    this.imageUrl,
    this.queuePosition = 0,
    this.isActive = true,
  });

  final String name;
  final String? imageUrl;
  final int queuePosition;
  final bool isActive;
}

abstract class AdminContentService {
  static const int defaultProductPageSize = 50;

  Future<AdminContentSnapshot> fetchContentSnapshot({
    int productLimit = defaultProductPageSize,
  });

  Future<void> createProduct(AdminProductUpsertInput input);
  Future<void> updateProduct(String productId, AdminProductUpsertInput input);
  Future<void> setProductVisibility(String productId, {required bool visible});
  Future<void> archiveProduct(String productId);

  Future<void> createBanner(AdminBannerUpsertInput input);
  Future<void> updateBanner(String bannerId, AdminBannerUpsertInput input);
  Future<void> deleteBanner(String bannerId);
  Future<void> reorderBanners(List<String> orderedIds);

  Future<void> createCategory(AdminCategoryUpsertInput input);
  Future<void> updateCategory(
    String categoryId,
    AdminCategoryUpsertInput input,
  );
  Future<void> deleteCategory(String categoryId);
  Future<void> setCategoryVisibility(
    String categoryId, {
    required bool visible,
  });
  Future<void> reorderCategories(List<String> orderedIds);

  Future<void> updateBusinessInfo(AdminBusinessInfo input);
  Future<int> recomputeProductPublicStats();
}

Map<String, dynamic> _productPayload(
  AdminProductUpsertInput input, {
  required bool includeDeletes,
  required bool includeStock,
}) {
  final normalizedName = input.name.trim();
  final normalizedNameAr = input.nameAr.trim();
  final normalizedBrand = input.brand.trim();
  final normalizedBrandAr = input.brandAr.trim();
  final normalizedSize = input.size?.trim();
  final normalizedImageUrls = input.imageUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList();
  final normalizedTopNotes = _cleanList(input.topNotes);
  final normalizedMiddleNotes = _cleanList(input.middleNotes);
  final normalizedBaseNotes = _cleanList(input.baseNotes);
  final normalizedTags = _cleanList(input.tags);
  final normalizedAliases = _cleanList(input.aliases);
  final normalizedAliasesAr = _cleanList(input.aliasesAr);
  final normalizedCategory = input.categoryName.trim();
  final normalizedFragranceFamily = input.fragranceFamily.trim();
  final notes = <String>[
    ...normalizedTopNotes,
    ...normalizedMiddleNotes,
    ...normalizedBaseNotes,
  ];

  final payload = <String, dynamic>{
    'name': normalizedName,
    'nameLower': normalizedName.toLowerCase(),
    'searchPrefixes': _buildSearchPrefixes([
      normalizedName,
      normalizedNameAr,
      normalizedBrand,
      normalizedBrandAr,
      ...normalizedAliases,
      ...normalizedAliasesAr,
    ]),
    if (normalizedNameAr.isNotEmpty) 'nameAr': normalizedNameAr,
    'brand': normalizedBrand,
    if (normalizedBrandAr.isNotEmpty) 'brandAr': normalizedBrandAr,
    if (normalizedAliases.isNotEmpty) 'aliases': normalizedAliases,
    if (normalizedAliasesAr.isNotEmpty) 'aliasesAr': normalizedAliasesAr,
    'categoryName': normalizedCategory,
    'categoryKey': _buildQueryKey(normalizedCategory),
    'price': input.price,
    if (includeStock) 'stock': input.stock,
    'gender': input.gender.trim(),
    'season': input.season.trim(),
    'time': input.time.trim(),
    'occasion': input.occasion.trim(),
    'intensity': input.intensity.trim(),
    'fragranceFamily': normalizedFragranceFamily,
    'fragranceFamilyKey': _buildQueryKey(normalizedFragranceFamily),
    'topNotes': normalizedTopNotes,
    'middleNotes': normalizedMiddleNotes,
    'baseNotes': normalizedBaseNotes,
    'notes': notes,
    'tags': normalizedTags,
    'description': input.description.trim(),
    'imageUrls': normalizedImageUrls,
    'isActive': input.isActive,
    'saleActive':
        input.salePrice != null &&
        input.salePrice! > 0 &&
        input.salePrice! < input.price,
    'isBestSeller': input.isBestSeller,
    'isNew': input.isNew,
  };

  if (normalizedSize != null && normalizedSize.isNotEmpty) {
    payload['size'] = normalizedSize;
  } else if (includeDeletes) {
    payload['size'] = FieldValue.delete();
  }

  if (input.salePrice != null) {
    payload['salePrice'] = input.salePrice;
  } else if (includeDeletes) {
    payload['salePrice'] = FieldValue.delete();
  }

  if (includeDeletes) {
    if (normalizedNameAr.isEmpty) payload['nameAr'] = FieldValue.delete();
    if (normalizedBrandAr.isEmpty) payload['brandAr'] = FieldValue.delete();
    if (normalizedAliases.isEmpty) payload['aliases'] = FieldValue.delete();
    if (normalizedAliasesAr.isEmpty) payload['aliasesAr'] = FieldValue.delete();
  }

  return payload;
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

List<String> _cleanList(List<String> values) {
  return values.map((value) => value.trim()).where((value) {
    return value.isNotEmpty;
  }).toList();
}

int _asPositiveInt(dynamic value) {
  if (value is int) return value < 0 ? 0 : value;
  if (value is num) {
    final parsed = value.toInt();
    return parsed < 0 ? 0 : parsed;
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim()) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }
  return 0;
}

class _MutableProductStats {
  int soldQty30d = 0;
  int soldQty90d = 0;
  int soldQtyAllTime = 0;
}

class FirestoreAdminContentService implements AdminContentService {
  FirestoreAdminContentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<AdminContentSnapshot> fetchContentSnapshot({
    int productLimit = AdminContentService.defaultProductPageSize,
  }) async {
    final safeProductLimit = productLimit.clamp(1, 500);
    final productsSnapshot = await _firestore
        .collection('products')
        .orderBy('updatedAt', descending: true)
        .limit(safeProductLimit)
        .get();
    final bannersSnapshot = await _firestore.collection('banner').get();
    final categoriesSnapshot = await _firestore.collection('categories').get();
    final businessInfo = await _fetchBusinessInfoSafely();

    final products =
        productsSnapshot.docs
            .map((doc) => _mapProduct(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final banners =
        bannersSnapshot.docs
            .map((doc) => _mapBanner(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
    final categories =
        categoriesSnapshot.docs
            .map((doc) => _mapCategory(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));

    return AdminContentSnapshot(
      products: products,
      banners: banners,
      categories: categories,
      businessInfo: businessInfo,
      featuredEditorial: _buildFeaturedEditorial(
        banners: banners,
        products: products,
      ),
    );
  }

  Future<AdminBusinessInfo> _fetchBusinessInfoSafely() async {
    try {
      final snapshot = await _firestore
          .collection('config')
          .doc('business_info')
          .get();
      return AdminBusinessInfo.fromMap(snapshot.data());
    } catch (_) {
      return const AdminBusinessInfo();
    }
  }

  @override
  Future<void> createProduct(AdminProductUpsertInput input) {
    final now = FieldValue.serverTimestamp();
    final payload = _productPayload(
      input,
      includeDeletes: false,
      includeStock: true,
    );
    return _firestore.collection('products').add({
      '_schemaVersion': 1,
      'isArchived': false,
      'createdAt': now,
      'updatedAt': now,
      ...payload,
    });
  }

  @override
  Future<void> updateProduct(String productId, AdminProductUpsertInput input) {
    final payload = _productPayload(
      input,
      includeDeletes: true,
      includeStock: false,
    );
    return _firestore.collection('products').doc(productId).update({
      ...payload,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setProductVisibility(String productId, {required bool visible}) {
    return _firestore.collection('products').doc(productId).update({
      'isActive': visible,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateBusinessInfo(AdminBusinessInfo input) {
    return _firestore.collection('config').doc('business_info').set({
      ...input.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<int> recomputeProductPublicStats() async {
    final now = DateTime.now();
    final since30 = now.subtract(const Duration(days: 30));
    final since90 = now.subtract(const Duration(days: 90));
    final productsSnapshot = await _firestore.collection('products').get();
    final stats = <String, _MutableProductStats>{
      for (final doc in productsSnapshot.docs) doc.id: _MutableProductStats(),
    };
    final orders = await _firestore
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .get();

    for (final doc in orders.docs) {
      final data = doc.data();
      final createdAt = data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null;
      final rawItems = data['items'];
      if (rawItems is! Iterable) continue;

      for (final rawItem in rawItems) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final productId = item['productId']?.toString().trim() ?? '';
        if (productId.isEmpty) continue;
        final quantity = _asPositiveInt(item['quantity']);
        if (quantity <= 0) continue;
        final entry = stats.putIfAbsent(productId, _MutableProductStats.new);
        entry.soldQtyAllTime += quantity;
        if (createdAt != null && !createdAt.isBefore(since90)) {
          entry.soldQty90d += quantity;
        }
        if (createdAt != null && !createdAt.isBefore(since30)) {
          entry.soldQty30d += quantity;
        }
      }
    }

    var batch = _firestore.batch();
    var pendingWrites = 0;
    for (final entry in stats.entries) {
      final ref = _firestore.collection('product_public_stats').doc(entry.key);
      batch.set(ref, {
        'productId': entry.key,
        'soldQty30d': entry.value.soldQty30d,
        'soldQty90d': entry.value.soldQty90d,
        'soldQtyAllTime': entry.value.soldQtyAllTime,
        'lastComputedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      pendingWrites += 1;
      if (pendingWrites >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        pendingWrites = 0;
      }
    }
    if (pendingWrites > 0) {
      await batch.commit();
    }
    return stats.length;
  }

  @override
  Future<void> archiveProduct(String productId) {
    return _firestore.collection('products').doc(productId).update({
      'isArchived': true,
      'isActive': false,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> createBanner(AdminBannerUpsertInput input) {
    return _firestore.collection('banner').add({
      '_schemaVersion': 1,
      'title': input.title.trim(),
      'imageUrl': input.imageUrl.trim(),
      'subtitle': input.subtitle?.trim(),
      'targetPath': input.targetPath?.trim(),
      'queuePosition': input.queuePosition,
      'isActive': input.isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateBanner(String bannerId, AdminBannerUpsertInput input) {
    return _firestore.collection('banner').doc(bannerId).update({
      'title': input.title.trim(),
      'imageUrl': input.imageUrl.trim(),
      'subtitle': input.subtitle?.trim(),
      'targetPath': input.targetPath?.trim(),
      'queuePosition': input.queuePosition,
      'isActive': input.isActive,
    });
  }

  @override
  Future<void> deleteBanner(String bannerId) {
    return _firestore.collection('banner').doc(bannerId).delete();
  }

  @override
  Future<void> reorderBanners(List<String> orderedIds) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      final ref = _firestore.collection('banner').doc(orderedIds[i]);
      batch.update(ref, {'queuePosition': i});
    }
    await batch.commit();
  }

  @override
  Future<void> createCategory(AdminCategoryUpsertInput input) {
    return _firestore.collection('categories').add({
      '_schemaVersion': 1,
      'name': input.name.trim(),
      'query': input.name.trim().toLowerCase(),
      'imageUrl': input.imageUrl?.trim(),
      'queuePosition': input.queuePosition,
      'sortOrder': input.queuePosition,
      'isActive': input.isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateCategory(
    String categoryId,
    AdminCategoryUpsertInput input,
  ) {
    return _firestore.collection('categories').doc(categoryId).update({
      'name': input.name.trim(),
      'query': input.name.trim().toLowerCase(),
      'imageUrl': input.imageUrl?.trim(),
      'queuePosition': input.queuePosition,
      'sortOrder': input.queuePosition,
      'isActive': input.isActive,
    });
  }

  @override
  Future<void> deleteCategory(String categoryId) {
    return _firestore.collection('categories').doc(categoryId).delete();
  }

  @override
  Future<void> setCategoryVisibility(
    String categoryId, {
    required bool visible,
  }) {
    return _firestore.collection('categories').doc(categoryId).update({
      'isActive': visible,
    });
  }

  @override
  Future<void> reorderCategories(List<String> orderedIds) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      final ref = _firestore.collection('categories').doc(orderedIds[i]);
      batch.update(ref, {'queuePosition': i, 'sortOrder': i});
    }
    await batch.commit();
  }
}

ProductEntry _mapProduct(String id, Map<String, dynamic> data) {
  final name = (data['name'] as String?)?.trim();
  final categoryName = (data['categoryName'] as String?)?.trim();
  final description = (data['description'] as String?)?.trim();
  final updatedAt = _parseDateTime(data['updatedAt']);
  final isActive = (data['isActive'] as bool?) ?? true;
  final isArchived = (data['isArchived'] as bool?) ?? false;
  final imageUrls = data['imageUrls'] as List<dynamic>? ?? const [];
  final price = _normalizeProductPrice(data['price']);
  final salePrice = _normalizeNullableProductPrice(data['salePrice']);
  final size = (data['size'] as String?)?.trim();
  final nameAr = (data['nameAr'] as String?)?.trim();
  final brand = (data['brand'] as String?)?.trim();
  final brandAr = (data['brandAr'] as String?)?.trim();
  final aliases = _stringList(data['aliases']);
  final aliasesAr = _stringList(data['aliasesAr']);
  final topNotes = _stringList(data['topNotes']);
  final middleNotes = _stringList(data['middleNotes']);
  final baseNotes = _stringList(data['baseNotes']);
  final tags = _stringList(data['tags']);
  final imageUrlList = imageUrls.map((value) => value.toString()).toList();
  final isBestSeller = (data['isBestSeller'] as bool?) ?? false;
  final isNew = (data['isNew'] as bool?) ?? false;

  return ProductEntry(
    id: id,
    title: name == null || name.isEmpty ? 'Untitled Product' : name,
    collection: categoryName == null || categoryName.isEmpty
        ? 'Uncategorized'
        : categoryName,
    status: isArchived ? 'Archived' : (isActive ? 'Visible' : 'Hidden'),
    updatedAt: _formatDateTime(updatedAt),
    notes: description == null || description.isEmpty
        ? 'No description'
        : description,
    isVisible: isActive,
    isArchived: isArchived,
    isBestSeller: isBestSeller,
    isNew: isNew,
    imageUrl: imageUrlList.isNotEmpty ? imageUrlList.first : '',
    imageUrls: imageUrlList,
    nameAr: nameAr ?? '',
    brand: brand == null || brand.isEmpty ? 'Qissa' : brand,
    brandAr: brandAr ?? '',
    aliases: aliases,
    aliasesAr: aliasesAr,
    price: price,
    stock: (data['stock'] as num?)?.toInt() ?? 0,
    gender: (data['gender'] as String?)?.trim().isNotEmpty == true
        ? (data['gender'] as String).trim()
        : 'unisex',
    season: (data['season'] as String?)?.trim().isNotEmpty == true
        ? (data['season'] as String).trim()
        : 'all_season',
    time: (data['time'] as String?)?.trim().isNotEmpty == true
        ? (data['time'] as String).trim()
        : 'any',
    occasion: (data['occasion'] as String?)?.trim().isNotEmpty == true
        ? (data['occasion'] as String).trim()
        : 'casual',
    intensity: (data['intensity'] as String?)?.trim().isNotEmpty == true
        ? (data['intensity'] as String).trim()
        : 'moderate',
    fragranceFamily:
        (data['fragranceFamily'] as String?)?.trim().isNotEmpty == true
        ? (data['fragranceFamily'] as String).trim()
        : 'floral',
    topNotes: topNotes,
    middleNotes: middleNotes,
    baseNotes: baseNotes,
    tags: tags,
    size: size == null || size.isEmpty ? null : size,
    salePrice: salePrice,
  );
}

List<String> _stringList(dynamic raw) {
  if (raw is! List<dynamic>) {
    return const <String>[];
  }
  return raw.map((value) => value.toString().trim()).where((value) {
    return value.isNotEmpty;
  }).toList();
}

double _normalizeProductPrice(dynamic raw) {
  if (raw == null) {
    return 0;
  }
  if (raw is num) {
    return raw.toDouble();
  }
  if (raw is String) {
    return double.tryParse(raw.replaceAll(',', '').trim()) ?? 0;
  }
  return 0;
}

double? _normalizeNullableProductPrice(dynamic raw) {
  final value = _normalizeProductPrice(raw);
  return value > 0 ? value : null;
}

BannerEntry _mapBanner(String id, Map<String, dynamic> data) {
  return BannerEntry(
    id: id,
    title: (data['title'] as String?)?.trim().isNotEmpty == true
        ? (data['title'] as String).trim()
        : 'Untitled Banner',
    slot: 'Position ${(data['queuePosition'] as num?)?.toInt() ?? 0}',
    mood: (data['subtitle'] as String?)?.trim().isNotEmpty == true
        ? (data['subtitle'] as String).trim()
        : 'No subtitle',
    performance: ((data['isActive'] as bool?) ?? true) ? 'Visible' : 'Hidden',
    queuePosition: (data['queuePosition'] as num?)?.toInt() ?? 0,
    isActive: (data['isActive'] as bool?) ?? true,
    imageUrl: (data['imageUrl'] as String?) ?? '',
    targetPath: data['targetPath'] as String?,
  );
}

CategoryEntry _mapCategory(String id, Map<String, dynamic> data) {
  final queuePosition =
      (data['queuePosition'] as num?)?.toInt() ??
      (data['sortOrder'] as num?)?.toInt() ??
      0;
  return CategoryEntry(
    id: id,
    name: (data['name'] as String?)?.trim().isNotEmpty == true
        ? (data['name'] as String).trim()
        : 'Unnamed Category',
    productCount: (data['productCount'] as num?)?.toInt() ?? 0,
    description: ((data['isActive'] as bool?) ?? true) ? 'Visible' : 'Hidden',
    queuePosition: queuePosition,
    isActive: (data['isActive'] as bool?) ?? true,
    imageUrl: (data['imageUrl'] as String?) ?? '',
  );
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return 'Updated recently';
  }
  final yyyy = dateTime.year.toString().padLeft(4, '0');
  final mm = dateTime.month.toString().padLeft(2, '0');
  final dd = dateTime.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

AdminFeatureHighlight? _buildFeaturedEditorial({
  required List<BannerEntry> banners,
  required List<ProductEntry> products,
}) {
  final banner = banners
      .where((entry) => entry.isActive && entry.imageUrl.trim().isNotEmpty)
      .cast<BannerEntry?>()
      .firstWhere((entry) => entry != null, orElse: () => null);
  if (banner != null) {
    return AdminFeatureHighlight(
      title: banner.title,
      description: banner.mood,
      imageUrl: banner.imageUrl,
      actionLabel: 'content.openEditor',
    );
  }

  final product = products
      .where(
        (entry) =>
            entry.isVisible &&
            !entry.isArchived &&
            entry.imageUrl.trim().isNotEmpty,
      )
      .cast<ProductEntry?>()
      .firstWhere((entry) => entry != null, orElse: () => null);
  if (product == null) return null;
  return AdminFeatureHighlight(
    title: product.title,
    description: product.notes,
    imageUrl: product.imageUrl,
    actionLabel: 'content.openEditor',
  );
}
