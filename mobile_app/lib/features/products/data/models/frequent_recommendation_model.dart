import 'package:cloud_firestore/cloud_firestore.dart';

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.trim()) ?? 0.0;
  }
  return 0.0;
}

class RecommendedProductRule {
  final String productId;
  final double confidence;
  final double support;
  final double lift;

  const RecommendedProductRule({
    required this.productId,
    required this.confidence,
    required this.support,
    required this.lift,
  });

  factory RecommendedProductRule.fromMap(Map<String, dynamic> map) {
    return RecommendedProductRule(
      productId: (map['product_id'] ?? '').toString().trim(),
      confidence: _asDouble(map['confidence']),
      support: _asDouble(map['support']),
      lift: _asDouble(map['lift']),
    );
  }
}

class FrequentRecommendationModel {
  final String triggerProductId;
  final List<RecommendedProductRule> recommendedProducts;
  final Timestamp? updatedAt;
  final String source;

  const FrequentRecommendationModel({
    required this.triggerProductId,
    required this.recommendedProducts,
    required this.updatedAt,
    required this.source,
  });

  factory FrequentRecommendationModel.fromMap(Map<String, dynamic> map) {
    final rawRecommendations =
        (map['recommended_products'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => RecommendedProductRule.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.productId.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final byConfidence = b.confidence.compareTo(a.confidence);
            if (byConfidence != 0) return byConfidence;

            final byLift = b.lift.compareTo(a.lift);
            if (byLift != 0) return byLift;

            return b.support.compareTo(a.support);
          });

    return FrequentRecommendationModel(
      triggerProductId: (map['trigger_product_id'] ?? '').toString().trim(),
      recommendedProducts: rawRecommendations,
      updatedAt: map['updated_at'] is Timestamp ? map['updated_at'] as Timestamp : null,
      source: (map['source'] ?? '').toString().trim(),
    );
  }
}
