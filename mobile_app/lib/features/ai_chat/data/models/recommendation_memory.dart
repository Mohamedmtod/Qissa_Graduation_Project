import 'package:equatable/equatable.dart';

class RecommendationMemory extends Equatable {
  final List<RecommendedProductRef> lastRecommendedProducts;
  final String? lastFocusedProductId;
  final String? lastRecommendationBatchId;
  final LastNoMatchContext? lastNoMatchContext;
  final ExternalProfileRef? lastExternalProfile;
  final PendingPerfumeReferenceClarification?
  pendingPerfumeReferenceClarification;

  const RecommendationMemory({
    this.lastRecommendedProducts = const [],
    this.lastFocusedProductId,
    this.lastRecommendationBatchId,
    this.lastNoMatchContext,
    this.lastExternalProfile,
    this.pendingPerfumeReferenceClarification,
  });

  factory RecommendationMemory.empty() => const RecommendationMemory();

  RecommendationMemory copyWith({
    List<RecommendedProductRef>? lastRecommendedProducts,
    String? lastFocusedProductId,
    String? lastRecommendationBatchId,
    LastNoMatchContext? lastNoMatchContext,
    ExternalProfileRef? lastExternalProfile,
    PendingPerfumeReferenceClarification? pendingPerfumeReferenceClarification,
    bool clearLastNoMatchContext = false,
    bool clearLastExternalProfile = false,
    bool clearPendingPerfumeReferenceClarification = false,
  }) {
    return RecommendationMemory(
      lastRecommendedProducts:
          lastRecommendedProducts ?? this.lastRecommendedProducts,
      lastFocusedProductId: lastFocusedProductId ?? this.lastFocusedProductId,
      lastRecommendationBatchId:
          lastRecommendationBatchId ?? this.lastRecommendationBatchId,
      lastNoMatchContext: clearLastNoMatchContext
          ? null
          : lastNoMatchContext ?? this.lastNoMatchContext,
      lastExternalProfile: clearLastExternalProfile
          ? null
          : lastExternalProfile ?? this.lastExternalProfile,
      pendingPerfumeReferenceClarification:
          clearPendingPerfumeReferenceClarification
          ? null
          : pendingPerfumeReferenceClarification ??
                this.pendingPerfumeReferenceClarification,
    );
  }

  @override
  List<Object?> get props => [
    lastRecommendedProducts,
    lastFocusedProductId,
    lastRecommendationBatchId,
    lastNoMatchContext,
    lastExternalProfile,
    pendingPerfumeReferenceClarification,
  ];
}

class ExternalProfileRef extends Equatable {
  final String id;
  final String name;
  final String brand;
  final String fragranceFamily;
  final List<String> notes;
  final List<String> tags;
  final String source;
  final double confidence;
  final double? priceReference;

  const ExternalProfileRef({
    required this.id,
    required this.name,
    this.brand = '',
    this.fragranceFamily = '',
    this.notes = const [],
    this.tags = const [],
    this.source = 'perfume_knowledge',
    this.confidence = 0,
    this.priceReference,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (brand.trim().isNotEmpty) 'brand': brand,
      if (fragranceFamily.trim().isNotEmpty) 'family': fragranceFamily,
      if (notes.isNotEmpty) 'notes': notes.take(8).toList(growable: false),
      if (tags.isNotEmpty) 'tags': tags.take(8).toList(growable: false),
      'source': source,
      if (confidence > 0) 'confidence': confidence,
      if (priceReference != null) 'priceReference': priceReference,
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    brand,
    fragranceFamily,
    notes,
    tags,
    source,
    confidence,
    priceReference,
  ];
}

class PendingPerfumeReferenceClarification extends Equatable {
  final String query;
  final List<PerfumeReferenceOptionRef> options;

  const PendingPerfumeReferenceClarification({
    required this.query,
    this.options = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'options': options.map((item) => item.toJson()).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [query, options];
}

class PerfumeReferenceOptionRef extends Equatable {
  final int index;
  final String name;
  final String brand;
  final String source;
  final String? productId;
  final String? externalProfileId;
  final double confidence;

  const PerfumeReferenceOptionRef({
    required this.index,
    required this.name,
    this.brand = '',
    required this.source,
    this.productId,
    this.externalProfileId,
    this.confidence = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'name': name,
      if (brand.trim().isNotEmpty) 'brand': brand,
      'source': source,
      if (productId != null) 'productId': productId,
      if (externalProfileId != null) 'externalProfileId': externalProfileId,
      if (confidence > 0) 'confidence': confidence,
    };
  }

  @override
  List<Object?> get props => [
    index,
    name,
    brand,
    source,
    productId,
    externalProfileId,
    confidence,
  ];
}

class LastNoMatchContext extends Equatable {
  final String reason;
  final double? requestedBudget;
  final double? lowestAvailablePrice;
  final List<String> lowestAvailableProductIds;

  const LastNoMatchContext({
    required this.reason,
    this.requestedBudget,
    this.lowestAvailablePrice,
    this.lowestAvailableProductIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
      if (requestedBudget != null) 'requestedBudget': requestedBudget,
      if (lowestAvailablePrice != null)
        'lowestAvailablePrice': lowestAvailablePrice,
      'lowestAvailableProductIds': lowestAvailableProductIds,
    };
  }

  @override
  List<Object?> get props => [
    reason,
    requestedBudget,
    lowestAvailablePrice,
    lowestAvailableProductIds,
  ];
}

class RecommendedProductRef extends Equatable {
  final String productId;
  final String name;
  final String brand;
  final int displayIndex;
  final double price;
  final int stock;
  final String season;
  final String occasion;
  final String intensity;
  final List<String> notes;
  final List<String> topNotes;
  final List<String> middleNotes;
  final List<String> baseNotes;
  final List<String> tags;
  final double matchScore;
  final String matchReason;
  final String? requestId;
  final String? promptVersion;
  final String? provider;
  final String? modelId;

  const RecommendedProductRef({
    required this.productId,
    required this.name,
    required this.brand,
    required this.displayIndex,
    required this.price,
    required this.stock,
    required this.season,
    required this.occasion,
    required this.intensity,
    required this.notes,
    this.topNotes = const [],
    this.middleNotes = const [],
    this.baseNotes = const [],
    this.tags = const [],
    this.matchScore = 0.0,
    this.matchReason = '',
    this.requestId,
    this.promptVersion,
    this.provider,
    this.modelId,
  });

  @override
  List<Object?> get props => [
    productId,
    name,
    brand,
    displayIndex,
    price,
    stock,
    season,
    occasion,
    intensity,
    notes,
    topNotes,
    middleNotes,
    baseNotes,
    tags,
    matchScore,
    matchReason,
    requestId,
    promptVersion,
    provider,
    modelId,
  ];

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'brand': brand,
      'displayIndex': displayIndex,
      'price': price,
      'stock': stock,
      'season': season,
      'occasion': occasion,
      'intensity': intensity,
      'notes': notes,
      'topNotes': topNotes,
      'middleNotes': middleNotes,
      'baseNotes': baseNotes,
      'tags': tags,
      'matchScore': matchScore,
      'matchReason': matchReason,
      'requestId': requestId,
      'promptVersion': promptVersion,
      'provider': provider,
      'modelId': modelId,
    };
  }
}
