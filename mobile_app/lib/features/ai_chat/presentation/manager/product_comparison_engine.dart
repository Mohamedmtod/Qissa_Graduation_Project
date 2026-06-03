import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

class ComparisonResult {
  final Map<String, String> factsWinners;
  final String? personalizedWinner;
  final Map<String, String> comparisonNotes;

  const ComparisonResult({
    required this.factsWinners,
    this.personalizedWinner,
    this.comparisonNotes = const {},
  });
}

class ProductComparisonEngine {
  static ComparisonResult compare({
    required List<RecommendedProductRef> products,
    required SessionPreferences preferences,
  }) {
    if (products.isEmpty) {
      return const ComparisonResult(factsWinners: {});
    }

    final factsWinners = <String, String>{};
    final comparisonNotes = <String, String>{};

    final cheapest = products.reduce((a, b) => a.price < b.price ? a : b);
    factsWinners['cheapest'] = cheapest.productId;

    final strongest = products.reduce(
      (a, b) =>
          _intensityScore(a.intensity) > _intensityScore(b.intensity) ? a : b,
    );
    factsWinners['strongest'] = strongest.productId;

    if (preferences.season != null) {
      final prefSeason = preferences.season!.toLowerCase();
      var seasonalWinners = products
          .where((p) => p.season.toLowerCase() == prefSeason)
          .toList();
      if (seasonalWinners.isEmpty) {
        seasonalWinners = products.where((p) {
          final season = p.season.toLowerCase();
          return season == 'all_seasons' || season == 'all seasons';
        }).toList();
      }
      if (seasonalWinners.isNotEmpty) {
        factsWinners['best_for_season'] = seasonalWinners.first.productId;
      }
    }

    final personalizedBest = products.reduce(
      (a, b) => a.matchScore >= b.matchScore ? a : b,
    );

    for (final product in products) {
      final notes = <String>['${product.price.toStringAsFixed(0)} EGP'];
      if (product.intensity.trim().isNotEmpty) {
        notes.add('intensity: ${product.intensity}');
      }
      if (product.season.trim().isNotEmpty) {
        notes.add('season: ${product.season}');
      }
      if (product.occasion.trim().isNotEmpty) {
        notes.add('use: ${product.occasion}');
      }
      final scent = [
        ...product.topNotes,
        ...product.middleNotes,
        ...product.baseNotes,
        ...product.notes,
        ...product.tags,
      ].where((note) => note.trim().isNotEmpty).toSet().take(4).join(', ');
      if (scent.isNotEmpty) notes.add('vibe: $scent');
      if (product.productId == cheapest.productId) notes.add('cheapest');
      if (product.productId == strongest.productId) notes.add('strongest');
      if (product.productId == personalizedBest.productId) {
        notes.add('closest to current taste');
      }
      comparisonNotes[product.productId] = notes.join(' | ');
    }

    return ComparisonResult(
      factsWinners: factsWinners,
      personalizedWinner: personalizedBest.productId,
      comparisonNotes: comparisonNotes,
    );
  }

  static int _intensityScore(String intensity) {
    switch (intensity.toLowerCase()) {
      case 'intense':
      case 'strong':
      case 'high':
        return 3;
      case 'moderate':
      case 'medium':
        return 2;
      case 'soft':
      case 'light':
        return 1;
      default:
        return 0;
    }
  }
}
