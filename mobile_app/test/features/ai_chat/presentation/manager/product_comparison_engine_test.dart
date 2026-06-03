import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/product_comparison_engine.dart';

RecommendedProductRef _ref({
  required String id,
  required double price,
  required String season,
  required String intensity,
  required double matchScore,
}) {
  return RecommendedProductRef(
    productId: id,
    name: id,
    brand: 'Brand',
    displayIndex: 1,
    price: price,
    stock: 5,
    season: season,
    occasion: 'daily',
    intensity: intensity,
    notes: const ['fresh'],
    matchScore: matchScore,
  );
}

void main() {
  group('ProductComparisonEngine', () {
    test('prefers exact season match over all_seasons fallback', () {
      final result = ProductComparisonEngine.compare(
        products: [
          _ref(
            id: 'exact-summer',
            price: 1000,
            season: 'summer',
            intensity: 'medium',
            matchScore: 0.70,
          ),
          _ref(
            id: 'fallback-all',
            price: 900,
            season: 'all_seasons',
            intensity: 'strong',
            matchScore: 0.80,
          ),
        ],
        preferences: const SessionPreferences(season: 'summer'),
      );

      expect(result.factsWinners['best_for_season'], 'exact-summer');
    });

    test('uses all_seasons fallback when no exact season exists', () {
      final result = ProductComparisonEngine.compare(
        products: [
          _ref(
            id: 'winter-only',
            price: 1000,
            season: 'winter',
            intensity: 'medium',
            matchScore: 0.70,
          ),
          _ref(
            id: 'all-seasons',
            price: 900,
            season: 'all_seasons',
            intensity: 'strong',
            matchScore: 0.60,
          ),
        ],
        preferences: const SessionPreferences(season: 'summer'),
      );

      expect(result.factsWinners['best_for_season'], 'all-seasons');
    });

    test('returns expected fact and personalized winners', () {
      final result = ProductComparisonEngine.compare(
        products: [
          _ref(
            id: 'p-cheap',
            price: 700,
            season: 'summer',
            intensity: 'light',
            matchScore: 0.40,
          ),
          _ref(
            id: 'p-strong',
            price: 1200,
            season: 'summer',
            intensity: 'strong',
            matchScore: 0.95,
          ),
        ],
        preferences: const SessionPreferences(season: 'summer'),
      );

      expect(result.factsWinners['cheapest'], 'p-cheap');
      expect(result.factsWinners['strongest'], 'p-strong');
      expect(result.personalizedWinner, 'p-strong');
      expect(result.comparisonNotes['p-cheap'], contains('700 EGP'));
      expect(result.comparisonNotes['p-cheap'], contains('cheapest'));
      expect(result.comparisonNotes['p-strong'], contains('strongest'));
      expect(
        result.comparisonNotes['p-strong'],
        contains('closest to current taste'),
      );
    });
  });
}
