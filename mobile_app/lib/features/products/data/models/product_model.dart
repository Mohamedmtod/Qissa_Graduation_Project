import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/features/ai_chat/core/ai_normalizer.dart';
import 'package:perfume_app/features/ai_chat/core/staff_taste_taxonomy.dart';

/// Stop words excluded from prefix generation.
const _stopWords = {
  'de',
  'of',
  'the',
  'and',
  'for',
  'a',
  'an',
  'eau',
  'by',
  'le',
  'la',
  'les',
  'du',
  'des',
  'en',
  'et',
  'or',
  'with',
  'from',
};

/// Builds all prefixes (length 2+) for each meaningful word in [name].
///
/// Example: "Talya Rayan Perfume"
/// → Words: [talya, rayan, perfume]
/// → Prefixes: [ta, tal, taly, talya, ra, ray, raya, rayan, pe, per, perf, perfu, perfum, perfume]
List<String> buildSearchPrefixes(
  String name, {
  Iterable<String> extraTerms = const [],
}) {
  final words = <String>[name, ...extraTerms].expand(_searchWordsFor).where((
    w,
  ) {
    return w.length >= 2 && !_stopWords.contains(w);
  });

  final prefixes = <String>{};
  for (final word in words) {
    for (int i = 2; i <= word.length; i++) {
      prefixes.add(word.substring(0, i));
    }
  }

  return prefixes.toList();
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
    final withoutArticle = _stripArabicDefiniteArticle(word);
    if (withoutArticle != word && withoutArticle.length >= 2) {
      words.add(withoutArticle);
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

String _stripArabicDefiniteArticle(String value) {
  if (value.length <= 3) return value;
  return value.startsWith('\u0627\u0644') ? value.substring(2) : value;
}

String buildProductQueryKey(String value) {
  return _normalizeSearchText(value)
      .replaceAll(RegExp(r'[^\w\s\u0621-\u064A\u0660-\u0669]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _asStringList(dynamic value) {
  if (value is! Iterable) return const [];

  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, dynamic> _asDynamicMap(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return value.map((key, value) => MapEntry(key.toString().trim(), value));
}

Map<String, String> _asStringMap(dynamic value) {
  final map = _asDynamicMap(value);
  return {
    for (final entry in map.entries)
      if (entry.key.isNotEmpty && _asString(entry.value).isNotEmpty)
        entry.key: _asString(entry.value),
  };
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? fallback : normalized;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0.0;
  }
  return 0.0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
  return null;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final normalized = value.replaceAll(',', '').trim();
    final parsedInt = int.tryParse(normalized);
    if (parsedInt != null) return parsedInt;

    final parsedDouble = double.tryParse(normalized);
    if (parsedDouble != null) return parsedDouble.toInt();
  }
  return 0;
}

class ProductVariantModel {
  static const defaultVariantId = 'default';

  final String id;
  final String label;
  final double price;
  final double? salePrice;
  final int stock;

  const ProductVariantModel({
    required this.id,
    required this.label,
    required this.price,
    this.salePrice,
    required this.stock,
  });

  bool get isOnSale =>
      salePrice != null && salePrice! > 0 && salePrice! < price;

  double get effectivePrice => isOnSale ? salePrice! : price;

  factory ProductVariantModel.fromMap(Map<String, dynamic> map) {
    final id = _asString(
      map['id'] ?? map['variantId'],
      fallback: defaultVariantId,
    );
    final label = _asString(map['label'] ?? map['size'], fallback: id);
    return ProductVariantModel(
      id: id.isEmpty ? defaultVariantId : id,
      label: label.isEmpty ? id : label,
      price: _asDouble(map['price']),
      salePrice: _asNullableDouble(map['salePrice']),
      stock: _asInt(map['stock']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'price': price,
      if (salePrice != null) 'salePrice': salePrice,
      'stock': stock,
    };
  }
}

class ProductModel {
  static const Object _copyWithUnset = Object();

  final String id;
  final String name;
  final String nameLower;
  final List<String> searchPrefixes;
  final String nameAr;
  final String brand;
  final String brandAr;
  final List<String> aliases;
  final List<String> aliasesAr;
  final double price;
  final String? size;
  final double? salePrice;
  final int stock;
  final List<ProductVariantModel> variants;
  final String gender;
  final String season;
  final String fragranceFamily;
  final List<String> notes;
  final List<String> imageUrls;
  final String description;
  final String categoryName;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final bool isActive;

  // ── New AI Recommendation Fields ──
  final String occasion;
  final String time;
  final String intensity;
  final List<String> topNotes;
  final List<String> middleNotes;
  final List<String> baseNotes;
  final List<String> tags;
  final String? pyramidDescription;
  final bool isBestSeller;
  final bool isNew;
  final Map<String, int> staffTagScores;
  final List<String> staffWarnings;
  final Map<String, String> staffSalesNotes;
  final List<String> similarFamousDna;
  final String staffIntelligenceStatus;
  final bool reviewNeeded;
  final int staffConfidence;
  final double staffDataCoverage;
  final int staffTaxonomyVersion;
  final String? staffUpdatedBy;
  final Timestamp? staffUpdatedAt;
  final int staffReviewCount;

  ProductModel({
    required this.id,
    required this.name,
    required this.nameLower,
    required this.searchPrefixes,
    this.nameAr = '',
    required this.brand,
    this.brandAr = '',
    this.aliases = const [],
    this.aliasesAr = const [],
    required this.price,
    this.size,
    this.salePrice,
    required this.stock,
    this.variants = const [],
    required this.gender,
    required this.season,
    required this.fragranceFamily,
    required this.notes,
    required this.imageUrls,
    required this.description,
    required this.categoryName,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    required this.occasion,
    required this.time,
    required this.intensity,
    required this.topNotes,
    required this.middleNotes,
    required this.baseNotes,
    required this.tags,
    this.pyramidDescription,
    this.isBestSeller = false,
    this.isNew = false,
    this.staffTagScores = const <String, int>{},
    this.staffWarnings = const <String>[],
    this.staffSalesNotes = const <String, String>{},
    this.similarFamousDna = const <String>[],
    this.staffIntelligenceStatus = 'draft',
    this.reviewNeeded = false,
    this.staffConfidence = 1,
    double? staffDataCoverage,
    this.staffTaxonomyVersion = StaffTasteTaxonomy.version,
    this.staffUpdatedBy,
    this.staffUpdatedAt,
    this.staffReviewCount = 0,
  }) : staffDataCoverage =
           staffDataCoverage ??
           StaffTasteTaxonomy.calculateCoverage(staffTagScores);

  bool get isOnSale => defaultVariant.isOnSale;

  bool get saleActive => isOnSale;

  String get categoryKey => buildProductQueryKey(categoryName);

  String get fragranceFamilyKey => buildProductQueryKey(fragranceFamily);

  double get effectivePrice => defaultVariant.effectivePrice;

  ProductVariantModel get defaultVariant {
    if (variants.isNotEmpty) return variants.first;
    return ProductVariantModel(
      id: ProductVariantModel.defaultVariantId,
      label: (size ?? '').trim().isEmpty
          ? ProductVariantModel.defaultVariantId
          : size!.trim(),
      price: price,
      salePrice: salePrice,
      stock: stock,
    );
  }

  int? get discountPercent {
    final variant = defaultVariant;
    if (!variant.isOnSale || variant.price <= 0) return null;
    return ((variant.price - variant.salePrice!) / variant.price * 100).round();
  }

  String get staffDataCoverageLabel =>
      StaffTasteTaxonomy.coverageLabel(staffDataCoverage);

  bool get hasCompleteStaffData => staffDataCoverage >= 1.0;

  bool get hasReviewedStaffData =>
      !reviewNeeded &&
      hasCompleteStaffData &&
      (staffIntelligenceStatus == 'reviewed' ||
          staffIntelligenceStatus == 'trusted');

  factory ProductModel.fromMap({
    required Map<String, dynamic> map,
    required String documentId,
  }) {
    final name = _asString(map['name']);
    final nameAr = _asString(map['nameAr']);
    final brand = _asString(map['brand']);
    final brandAr = _asString(map['brandAr']);
    final aliases = _asStringList(map['aliases']);
    final aliasesAr = _asStringList(map['aliasesAr']);
    final description = _asString(map['description']);
    final categoryName = _asString(map['categoryName']);

    // Raw lists from Firestore
    final rawNotes = _asStringList(map['notes']);
    final rawTop = _asStringList(map['topNotes']);
    final rawMiddle = _asStringList(map['middleNotes']);
    final rawBase = _asStringList(map['baseNotes']);
    final rawTags = _asStringList(map['tags']);
    final staffTagScores = StaffTasteTaxonomy.sanitizeScores(
      _asDynamicMap(map['staffTagScores']),
    );
    final rawCoverage = _asNullableDouble(map['staffDataCoverage']);
    final calculatedCoverage = StaffTasteTaxonomy.calculateCoverage(
      staffTagScores,
    );
    final rawVariants = map['variants'] is Iterable
        ? (map['variants'] as Iterable)
              .whereType<Map>()
              .map(
                (entry) => ProductVariantModel.fromMap(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .where((variant) => variant.id.trim().isNotEmpty)
              .toList()
        : const <ProductVariantModel>[];

    return ProductModel(
      id: documentId,
      name: name,
      nameLower: _asString(map['nameLower'], fallback: name.toLowerCase()),
      searchPrefixes: map['searchPrefixes'] != null
          ? _asStringList(map['searchPrefixes'])
          : buildSearchPrefixes(
              name,
              extraTerms: [nameAr, brand, brandAr, ...aliases, ...aliasesAr],
            ),
      nameAr: nameAr,
      brand: brand,
      brandAr: brandAr,
      aliases: aliases,
      aliasesAr: aliasesAr,
      price: _asDouble(map['price']),
      size: _asString(map['size']).isEmpty ? null : _asString(map['size']),
      salePrice: _asNullableDouble(map['salePrice']),
      stock: _asInt(map['stock']),
      variants: rawVariants,

      // Normalized core fields
      gender:
          AINormalizer.normalizeGender(_asString(map['gender'])) ??
          _asString(map['gender']),
      season:
          AINormalizer.normalizeSeason(_asString(map['season'])) ??
          _asString(map['season']),
      fragranceFamily: _asString(map['fragranceFamily']),
      notes: AINormalizer.normalizeNotes(rawNotes).isNotEmpty
          ? AINormalizer.normalizeNotes(rawNotes)
          : rawNotes,

      imageUrls: _asStringList(map['imageUrls']),
      description: description,
      categoryName: categoryName,
      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt']
          : Timestamp.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? map['updatedAt']
          : Timestamp.now(),

      // Normalized AI recommendation fields (with safe fallbacks)
      occasion:
          AINormalizer.normalizeOccasion(_asString(map['occasion'])) ?? 'daily',
      time: AINormalizer.normalizeTime(_asString(map['time'])) ?? 'all_day',
      intensity:
          AINormalizer.normalizeIntensity(_asString(map['intensity'])) ??
          'medium',

      topNotes: AINormalizer.normalizeNotes(rawTop),
      middleNotes: AINormalizer.normalizeNotes(rawMiddle),
      baseNotes: AINormalizer.normalizeNotes(rawBase),
      tags: AINormalizer.normalizeTags(rawTags),

      pyramidDescription: map['pyramidDescription'] == null
          ? null
          : _asString(map['pyramidDescription']),
      isActive: map['isActive'] as bool? ?? true,
      isBestSeller: map['isBestSeller'] == true,
      isNew: map['isNew'] == true,
      staffTagScores: staffTagScores,
      staffWarnings: StaffTasteTaxonomy.sanitizeWarnings(
        _asStringList(map['staffWarnings']),
      ),
      staffSalesNotes: _asStringMap(map['staffSalesNotes']),
      similarFamousDna: _asStringList(
        map['similarFamousDna'],
      ).where(StaffTasteTaxonomy.famousDnaTagIds.contains).toList(),
      staffIntelligenceStatus: StaffTasteTaxonomy.normalizeStatus(
        _asString(map['staffIntelligenceStatus']),
      ),
      reviewNeeded: _asBool(map['reviewNeeded']),
      staffConfidence: StaffTasteTaxonomy.normalizeConfidence(
        map['staffConfidence'],
      ),
      staffDataCoverage: rawCoverage == null
          ? calculatedCoverage
          : rawCoverage.clamp(0.0, 1.0),
      staffTaxonomyVersion: _asInt(map['staffTaxonomyVersion']) <= 0
          ? StaffTasteTaxonomy.version
          : _asInt(map['staffTaxonomyVersion']),
      staffUpdatedBy: _asString(map['staffUpdatedBy']).isEmpty
          ? null
          : _asString(map['staffUpdatedBy']),
      staffUpdatedAt: map['staffUpdatedAt'] is Timestamp
          ? map['staffUpdatedAt'] as Timestamp
          : null,
      staffReviewCount: _asInt(map['staffReviewCount']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameLower': name.toLowerCase(),
      'searchPrefixes': buildSearchPrefixes(
        name,
        extraTerms: [nameAr, brand, brandAr, ...aliases, ...aliasesAr],
      ),
      if (nameAr.trim().isNotEmpty) 'nameAr': nameAr.trim(),
      'brand': brand,
      if (brandAr.trim().isNotEmpty) 'brandAr': brandAr.trim(),
      if (aliases.isNotEmpty) 'aliases': aliases,
      if (aliasesAr.isNotEmpty) 'aliasesAr': aliasesAr,
      'price': price,
      if (size != null && size!.trim().isNotEmpty) 'size': size,
      if (salePrice != null) 'salePrice': salePrice,
      'stock': stock,
      if (variants.isNotEmpty)
        'variants': variants.map((variant) => variant.toMap()).toList(),
      'gender': gender,
      'season': season,
      'fragranceFamily': fragranceFamily,
      'fragranceFamilyKey': fragranceFamilyKey,
      'notes': notes,
      'imageUrls': imageUrls,
      'description': description,
      'categoryName': categoryName,
      'categoryKey': categoryKey,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
      'saleActive': saleActive,
      // Save canonical representation
      'occasion': occasion,
      'time': time,
      'intensity': intensity,
      'topNotes': topNotes,
      'middleNotes': middleNotes,
      'baseNotes': baseNotes,
      'tags': tags,
      'pyramidDescription': pyramidDescription,
      'isBestSeller': isBestSeller,
      'isNew': isNew,
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
      if (staffTaxonomyVersion != StaffTasteTaxonomy.version ||
          staffTagScores.isNotEmpty)
        'staffTaxonomyVersion': staffTaxonomyVersion,
      if (staffUpdatedBy != null && staffUpdatedBy!.trim().isNotEmpty)
        'staffUpdatedBy': staffUpdatedBy,
      if (staffUpdatedAt != null) 'staffUpdatedAt': staffUpdatedAt,
      if (staffReviewCount > 0) 'staffReviewCount': staffReviewCount,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? nameAr,
    String? brand,
    String? brandAr,
    List<String>? aliases,
    List<String>? aliasesAr,
    double? price,
    Object? size = _copyWithUnset,
    Object? salePrice = _copyWithUnset,
    int? stock,
    List<ProductVariantModel>? variants,
    String? gender,
    String? season,
    String? fragranceFamily,
    List<String>? notes,
    List<String>? imageUrls,
    String? description,
    String? categoryName,
    Timestamp? updatedAt,
    bool? isActive,
    String? occasion,
    String? time,
    String? intensity,
    List<String>? topNotes,
    List<String>? middleNotes,
    List<String>? baseNotes,
    List<String>? tags,
    String? pyramidDescription,
    bool? isBestSeller,
    bool? isNew,
    Map<String, int>? staffTagScores,
    List<String>? staffWarnings,
    Map<String, String>? staffSalesNotes,
    List<String>? similarFamousDna,
    String? staffIntelligenceStatus,
    bool? reviewNeeded,
    int? staffConfidence,
    double? staffDataCoverage,
    int? staffTaxonomyVersion,
    String? staffUpdatedBy,
    Timestamp? staffUpdatedAt,
    int? staffReviewCount,
  }) {
    final newName = name ?? this.name;
    final newNameAr = nameAr ?? this.nameAr;
    final newBrand = brand ?? this.brand;
    final newBrandAr = brandAr ?? this.brandAr;
    final newAliases = aliases ?? this.aliases;
    final newAliasesAr = aliasesAr ?? this.aliasesAr;
    final String? resolvedSize = size == _copyWithUnset
        ? this.size
        : size as String?;
    final double? resolvedSalePrice = salePrice == _copyWithUnset
        ? this.salePrice
        : salePrice as double?;

    return ProductModel(
      id: id ?? this.id,
      name: newName,
      nameLower: newName.toLowerCase(),
      searchPrefixes: buildSearchPrefixes(
        newName,
        extraTerms: [
          newNameAr,
          newBrand,
          newBrandAr,
          ...newAliases,
          ...newAliasesAr,
        ],
      ),
      nameAr: newNameAr,
      brand: newBrand,
      brandAr: newBrandAr,
      aliases: newAliases,
      aliasesAr: newAliasesAr,
      price: price ?? this.price,
      size: resolvedSize,
      salePrice: resolvedSalePrice,
      stock: stock ?? this.stock,
      variants: variants ?? this.variants,
      gender: gender ?? this.gender,
      season: season ?? this.season,
      fragranceFamily: fragranceFamily ?? this.fragranceFamily,
      notes: notes ?? this.notes,
      imageUrls: imageUrls ?? this.imageUrls,
      description: description ?? this.description,
      categoryName: categoryName ?? this.categoryName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      occasion: occasion ?? this.occasion,
      time: time ?? this.time,
      intensity: intensity ?? this.intensity,
      topNotes: topNotes ?? this.topNotes,
      middleNotes: middleNotes ?? this.middleNotes,
      baseNotes: baseNotes ?? this.baseNotes,
      tags: tags ?? this.tags,
      pyramidDescription: pyramidDescription ?? this.pyramidDescription,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      isNew: isNew ?? this.isNew,
      staffTagScores: staffTagScores ?? this.staffTagScores,
      staffWarnings: staffWarnings ?? this.staffWarnings,
      staffSalesNotes: staffSalesNotes ?? this.staffSalesNotes,
      similarFamousDna: similarFamousDna ?? this.similarFamousDna,
      staffIntelligenceStatus:
          staffIntelligenceStatus ?? this.staffIntelligenceStatus,
      reviewNeeded: reviewNeeded ?? this.reviewNeeded,
      staffConfidence: staffConfidence ?? this.staffConfidence,
      staffDataCoverage: staffDataCoverage ?? this.staffDataCoverage,
      staffTaxonomyVersion: staffTaxonomyVersion ?? this.staffTaxonomyVersion,
      staffUpdatedBy: staffUpdatedBy ?? this.staffUpdatedBy,
      staffUpdatedAt: staffUpdatedAt ?? this.staffUpdatedAt,
      staffReviewCount: staffReviewCount ?? this.staffReviewCount,
    );
  }
}
