import 'package:equatable/equatable.dart';

enum InventoryTrend { up, down, surge }

class ProductVariant extends Equatable {
  const ProductVariant({
    required this.id,
    required this.label,
    required this.price,
    this.salePrice,
    this.costPrice,
    required this.unitType,
    required this.stock,
    this.isActive = true,
  });

  final String id;
  final String label;
  final double price;
  final double? salePrice;
  final double? costPrice;
  final String unitType;
  final double stock;
  final bool isActive;

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String? ?? 'default',
      label: json['label'] as String? ?? json['size'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (json['salePrice'] as num?)?.toDouble(),
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      unitType: json['unitType'] as String? ?? 'piece',
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'price': price,
      if (salePrice != null) 'salePrice': salePrice,
      if (costPrice != null) 'costPrice': costPrice,
      'unitType': unitType,
      'stock': stock,
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [
    id,
    label,
    price,
    salePrice,
    costPrice,
    unitType,
    stock,
    isActive,
  ];
}

class InventoryItem extends Equatable {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.collection,
    required this.imageUrl,
    required this.units,
    required this.waitingUsers,
    required this.trend,
    this.lowStock = false,
    this.productType = 'simple',
    this.isSellable = true,
    this.unitType = 'piece',
    this.variants = const [],
    this.staffTagScores = const {},
    this.staffWarnings = const [],
    this.staffSalesNotes = const {},
    this.similarFamousDna = const [],
    this.staffIntelligenceStatus = 'draft',
    this.reviewNeeded = false,
    this.staffConfidence = 1,
    this.staffDataCoverage = 0,
    this.staffTaxonomyVersion = 1,
    this.staffUpdatedBy,
    this.staffUpdatedAt,
    this.staffReviewCount = 0,
  });

  final String id;
  final String name;
  final String collection;
  final String imageUrl;
  final int units;
  final int waitingUsers;
  final InventoryTrend trend;
  final bool lowStock;

  // New POS properties
  final String productType;
  final bool isSellable;
  final String unitType;
  final List<ProductVariant> variants;
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
  final DateTime? staffUpdatedAt;
  final int staffReviewCount;

  static const int lowStockThreshold = 10;

  static bool determineLowStock(int units) => units <= lowStockThreshold;

  @override
  List<Object?> get props => [
    id,
    name,
    collection,
    imageUrl,
    units,
    waitingUsers,
    trend,
    lowStock,
    productType,
    isSellable,
    unitType,
    variants,
    staffTagScores,
    staffWarnings,
    staffSalesNotes,
    similarFamousDna,
    staffIntelligenceStatus,
    reviewNeeded,
    staffConfidence,
    staffDataCoverage,
    staffTaxonomyVersion,
    staffUpdatedBy,
    staffUpdatedAt,
    staffReviewCount,
  ];
}
