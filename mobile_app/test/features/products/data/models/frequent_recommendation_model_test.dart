import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/products/data/models/frequent_recommendation_model.dart';

void main() {
  group('FrequentRecommendationModel.fromMap', () {
    test('sorts recommended products by confidence then lift then support', () {
      final model = FrequentRecommendationModel.fromMap({
        'trigger_product_id': 'oud_123',
        'updated_at': Timestamp.now(),
        'source': 'fp_growth_v1',
        'recommended_products': [
          {
            'product_id': 'c',
            'confidence': 0.7,
            'lift': 1.8,
            'support': 0.1,
          },
          {
            'product_id': 'a',
            'confidence': 0.8,
            'lift': 1.2,
            'support': 0.1,
          },
          {
            'product_id': 'b',
            'confidence': 0.8,
            'lift': 1.6,
            'support': 0.08,
          },
        ],
      });

      expect(
        model.recommendedProducts.map((item) => item.productId).toList(),
        ['b', 'a', 'c'],
      );
    });

    test('drops invalid empty product ids and parses numeric strings', () {
      final model = FrequentRecommendationModel.fromMap({
        'trigger_product_id': 'oud_123',
        'recommended_products': [
          {
            'product_id': 'musk_456',
            'confidence': '0.85',
            'support': '0.12',
            'lift': '1.44',
          },
          {
            'product_id': '',
            'confidence': '0.99',
            'support': '0.12',
            'lift': '1.99',
          },
        ],
      });

      expect(model.recommendedProducts, hasLength(1));
      expect(model.recommendedProducts.first.productId, 'musk_456');
      expect(model.recommendedProducts.first.confidence, 0.85);
      expect(model.recommendedProducts.first.support, 0.12);
      expect(model.recommendedProducts.first.lift, 1.44);
    });
  });
}
