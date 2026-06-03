import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/scent_profile_scorer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

enum WorkerRecommendationAcceptancePolicy { exactCandidate, fallbackCandidate }

class WorkerRecommendationAcceptanceDecision {
  final bool isAccepted;
  final String? reasonCode;

  const WorkerRecommendationAcceptanceDecision._({
    required this.isAccepted,
    required this.reasonCode,
  });

  const WorkerRecommendationAcceptanceDecision.accepted()
    : this._(isAccepted: true, reasonCode: null);

  const WorkerRecommendationAcceptanceDecision.rejected(String reasonCode)
    : this._(isAccepted: false, reasonCode: reasonCode);
}

/// Filters candidates locally and ranks them using conditional scent-first logic.
class LocalCandidateFilter {
  static const double _upsellToleranceMultiplier = 1.10;
  static const double _strongSignalScentGate = ScentProfileScorer.scentGate;

  // Strong scent signal: scent-first ranking dominates.
  static const double _strongScentWeight = 0.55;
  static const double _strongGenderWeight = 0.20;
  static const double _strongPriceWeight = 0.15;
  static const double _strongContextWeight = 0.10;

  // Weak scent signal: broader fit ranking.
  static const double _weakScentWeight = 0.15;
  static const double _weakGenderWeight = 0.30;
  static const double _weakPriceWeight = 0.30;
  static const double _weakContextWeight = 0.25;

  static const double _dailyOccasionFallbackScore = 0.30;

  static RecommendedBudgetStatus? budgetStatusForProduct(
    ProductModel product,
    SessionPreferences preferences, {
    bool allowUpsell = true,
  }) {
    final maxBudget = preferences.maxBudget;
    if (maxBudget == null) return RecommendedBudgetStatus.withinBudget;

    if (product.effectivePrice <= maxBudget) {
      return RecommendedBudgetStatus.withinBudget;
    }

    if (!allowUpsell) return null;

    if (product.effectivePrice <= (maxBudget * _upsellToleranceMultiplier)) {
      return RecommendedBudgetStatus.slightlyAboveBudget;
    }

    return null;
  }

  static bool passesExactBudgetFilter(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    return budgetStatusForProduct(product, preferences) ==
        RecommendedBudgetStatus.withinBudget;
  }

  static bool passesUpsellBudgetFilter(
    ProductModel product,
    SessionPreferences preferences, {
    bool allowUpsell = true,
  }) {
    return budgetStatusForProduct(
          product,
          preferences,
          allowUpsell: allowUpsell,
        ) ==
        RecommendedBudgetStatus.slightlyAboveBudget;
  }

  static bool passesBudgetHardFilter(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    return passesExactBudgetFilter(product, preferences);
  }

  static bool passesNonBudgetHardFilters(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    return evaluateWorkerRecommendationCandidate(
      product,
      preferences,
      policy: WorkerRecommendationAcceptancePolicy.exactCandidate,
    ).isAccepted;
  }

  static WorkerRecommendationAcceptanceDecision
  evaluateWorkerRecommendationCandidate(
    ProductModel product,
    SessionPreferences preferences, {
    required WorkerRecommendationAcceptancePolicy policy,
  }) {
    if (preferences.gender != null &&
        preferences.gender!.toLowerCase() != 'unisex' &&
        product.gender.isNotEmpty &&
        product.gender.toLowerCase() != 'unisex' &&
        product.gender.toLowerCase() != preferences.gender!.toLowerCase()) {
      return const WorkerRecommendationAcceptanceDecision.rejected(
        'gender_mismatch',
      );
    }

    if (preferences.time != null && product.time.isNotEmpty) {
      final pTime = product.time.toLowerCase();
      final prefTime = preferences.time!.toLowerCase();
      if (prefTime == 'all_day' || prefTime == 'all day') {
        // Flexible preference.
      } else if (pTime != prefTime &&
          pTime != 'all_day' &&
          pTime != 'all day') {
        return const WorkerRecommendationAcceptanceDecision.rejected(
          'time_mismatch',
        );
      }
    }

    if (preferences.season != null && product.season.isNotEmpty) {
      final pSeason = product.season.toLowerCase();
      final prefSeason = preferences.season!.toLowerCase();
      if (prefSeason == 'all_seasons' || prefSeason == 'all seasons') {
        // Flexible preference.
      } else if (pSeason != prefSeason &&
          pSeason != 'all_seasons' &&
          pSeason != 'all seasons') {
        return const WorkerRecommendationAcceptanceDecision.rejected(
          'season_mismatch',
        );
      }
    }

    if (preferences.intensity != null && product.intensity.isNotEmpty) {
      final pIntensity = product.intensity.toLowerCase();
      final prefIntensity = preferences.intensity!.toLowerCase();
      if (prefIntensity == 'light' && pIntensity == 'strong') {
        // In office/formal context, a strong product is a soft-pass ONLY when:
        //   1. The user has explicit note preferences.
        //   2. The product shares at least one note with those preferences.
        // Without both guards, strong products remain a hard block even in
        // office context, preventing arbitrary leaks.
        final isOfficeSoftened =
            preferences.occasion == 'office' ||
            preferences.occasion == 'formal';

        final preferredAnchors = _preferenceScentAnchors(preferences);
        final productAnchors = _productScentAnchors(product);
        final hasPreferredNoteSignal = preferredAnchors.isNotEmpty;
        final hasScentOverlap = preferredAnchors.any(productAnchors.contains);

        if (!isOfficeSoftened || !hasPreferredNoteSignal || !hasScentOverlap) {
          return const WorkerRecommendationAcceptanceDecision.rejected(
            'intensity_mismatch',
          );
        }
      }
      if (prefIntensity == 'strong' && pIntensity == 'light') {
        return const WorkerRecommendationAcceptanceDecision.rejected(
          'intensity_mismatch',
        );
      }
    }

    if (preferences.excludedNotes.isNotEmpty) {
      final productText = [
        ...product.notes,
        ...product.topNotes,
        ...product.middleNotes,
        ...product.baseNotes,
        product.fragranceFamily,
        product.description,
        ...product.tags,
      ].join(' ').toLowerCase();
      final productAnchors = _productScentAnchors(product);

      for (final excluded in preferences.excludedNotes) {
        final blockedAnchors = _expandScentAnchors([excluded]);
        final blockedByAnchor = blockedAnchors.any(productAnchors.contains);
        final blockedByText = blockedAnchors.any(productText.contains);
        if (blockedByAnchor || blockedByText) {
          return const WorkerRecommendationAcceptanceDecision.rejected(
            'excluded_note',
          );
        }
      }
    }

    final hasAnyNotePref =
        preferences.preferredNotes.isNotEmpty ||
        preferences.preferredTopNotes.isNotEmpty ||
        preferences.preferredMiddleNotes.isNotEmpty ||
        preferences.preferredBaseNotes.isNotEmpty;

    if (hasAnyNotePref) {
      final productHasAnyNotes =
          product.notes.isNotEmpty ||
          product.topNotes.isNotEmpty ||
          product.middleNotes.isNotEmpty ||
          product.baseNotes.isNotEmpty;
      if (!productHasAnyNotes) {
        return policy == WorkerRecommendationAcceptancePolicy.exactCandidate
            ? const WorkerRecommendationAcceptanceDecision.rejected(
                'missing_required_note_data',
              )
            : const WorkerRecommendationAcceptanceDecision.accepted();
      }

      final allProductNotes = [
        ...product.notes.map((n) => n.toLowerCase()),
        ...product.topNotes.map((n) => n.toLowerCase()),
        ...product.middleNotes.map((n) => n.toLowerCase()),
        ...product.baseNotes.map((n) => n.toLowerCase()),
      ];

      final allPreferredNotes = [
        ...preferences.preferredNotes,
        ...preferences.preferredTopNotes,
        ...preferences.preferredMiddleNotes,
        ...preferences.preferredBaseNotes,
      ];

      final preferredDirectTerms = allPreferredNotes
          .map(_normalizeTerm)
          .where((item) => item.isNotEmpty)
          .toSet();
      final productDirectTerms = <String>{
        ...allProductNotes.map(_normalizeTerm),
        _normalizeTerm(product.fragranceFamily),
        ...product.tags.map(_normalizeTerm),
      };
      final hasDirectMatch = preferredDirectTerms.any(
        productDirectTerms.contains,
      );
      if (policy == WorkerRecommendationAcceptancePolicy.exactCandidate &&
          !hasDirectMatch) {
        return const WorkerRecommendationAcceptanceDecision.rejected(
          'missing_preferred_note',
        );
      }
      if (policy == WorkerRecommendationAcceptancePolicy.fallbackCandidate &&
          !hasDirectMatch) {
        return const WorkerRecommendationAcceptanceDecision.rejected(
          'missing_preferred_note',
        );
      }
    }

    if (policy == WorkerRecommendationAcceptancePolicy.fallbackCandidate &&
        ScentProfileScorer.hasStrongPreferenceSignal(preferences)) {
      final scentScore = ScentProfileScorer.scorePreferenceToProduct(
        preferences,
        product,
      );
      if (scentScore < _strongSignalScentGate) {
        return const WorkerRecommendationAcceptanceDecision.rejected(
          'missing_required_scent_anchor',
        );
      }
    }

    return const WorkerRecommendationAcceptanceDecision.accepted();
  }

  static bool _passesRelaxedFallbackFilters(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    if (!passesExactBudgetFilter(product, preferences)) {
      return false;
    }

    return evaluateWorkerRecommendationCandidate(
      product,
      preferences,
      policy: WorkerRecommendationAcceptancePolicy.fallbackCandidate,
    ).isAccepted;
  }

  static bool passesHardFilters(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    if (!passesExactBudgetFilter(product, preferences)) {
      return false;
    }

    return passesNonBudgetHardFilters(product, preferences);
  }

  static List<RecommendedProduct> getTopRecommendations({
    required List<ProductModel> catalog,
    required SessionPreferences preferences,
  }) {
    final strongScentSignal = ScentProfileScorer.hasStrongPreferenceSignal(
      preferences,
    );

    final strictFiltered = catalog
        .where((p) => passesHardFilters(p, preferences))
        .toList();

    final usingRelaxedFallback = strictFiltered.isEmpty;
    final preFiltered = usingRelaxedFallback
        ? catalog
              .where((p) => _passesRelaxedFallbackFilters(p, preferences))
              .toList()
        : strictFiltered;

    return _scoreAndSelect(
      preFiltered: preFiltered,
      preferences: preferences,
      budgetStatus: RecommendedBudgetStatus.withinBudget,
      exactBudget: preferences.maxBudget,
      strongScentSignal: strongScentSignal,
      candidateSource: usingRelaxedFallback
          ? RecommendedCandidateSource.relaxed
          : RecommendedCandidateSource.strict,
    );
  }

  static List<RecommendedProduct> getTopUpsellRecommendations({
    required List<ProductModel> catalog,
    required SessionPreferences preferences,
    bool allowUpsell = true,
  }) {
    if (!allowUpsell) return const [];
    if (preferences.maxBudget == null) return const [];

    final strongScentSignal = ScentProfileScorer.hasStrongPreferenceSignal(
      preferences,
    );
    final preFiltered = catalog
        .where(
          (p) =>
              passesUpsellBudgetFilter(
                p,
                preferences,
                allowUpsell: allowUpsell,
              ) &&
              passesNonBudgetHardFilters(p, preferences),
        )
        .toList();

    return _scoreAndSelect(
      preFiltered: preFiltered,
      preferences: preferences,
      budgetStatus: RecommendedBudgetStatus.slightlyAboveBudget,
      exactBudget: preferences.maxBudget,
      strongScentSignal: strongScentSignal,
      candidateSource: RecommendedCandidateSource.upsell,
    );
  }

  static List<RecommendedProduct> _scoreAndSelect({
    required List<ProductModel> preFiltered,
    required SessionPreferences preferences,
    required RecommendedBudgetStatus budgetStatus,
    required double? exactBudget,
    required bool strongScentSignal,
    required RecommendedCandidateSource candidateSource,
  }) {
    final scoredProducts = <RecommendedProduct>[];

    for (final product in preFiltered) {
      final scentScore = ScentProfileScorer.scorePreferenceToProduct(
        preferences,
        product,
      );
      if (strongScentSignal && scentScore < _strongSignalScentGate) {
        continue;
      }

      final genderScore = _genderScore(preferences.gender, product.gender);
      final priceScore = _priceScore(
        product: product,
        preferences: preferences,
        budgetStatus: budgetStatus,
      );
      final contextScore = _contextScore(product, preferences);

      final finalScore = _blendFinalScore(
        scentScore: scentScore,
        genderScore: genderScore,
        priceScore: priceScore,
        contextScore: contextScore,
        strongScentSignal: strongScentSignal,
      );

      scoredProducts.add(
        RecommendedProduct(
          product: product,
          matchScore: finalScore,
          matchLabel: _matchLabel(finalScore),
          matchReason: _buildReason(
            product: product,
            preferences: preferences,
            budgetStatus: budgetStatus,
            candidateSource: candidateSource,
            strongScentSignal: strongScentSignal,
            scentScore: scentScore,
            contextScore: contextScore,
          ),
          budgetStatus: budgetStatus,
          exactBudget: exactBudget,
          candidateSource: candidateSource,
        ),
      );
    }

    scoredProducts.sort((a, b) {
      final byScore = b.matchScore.compareTo(a.matchScore);
      if (byScore != 0) return byScore;

      final byStock = b.product.stock.compareTo(a.product.stock);
      if (byStock != 0) return byStock;

      final byPrice = _comparePriceByStrategy(
        a.product.effectivePrice,
        b.product.effectivePrice,
        preferences.rankingStrategy,
      );
      if (byPrice != 0) return byPrice;

      return a.product.name.compareTo(b.product.name);
    });

    final finalSelection = <RecommendedProduct>[];
    var outOfStockCount = 0;
    for (final rec in scoredProducts) {
      if (finalSelection.length >= 3) break;

      if (rec.product.stock > 0) {
        finalSelection.add(rec);
        continue;
      }

      if (outOfStockCount == 0 && rec.matchScore >= 0.85) {
        finalSelection.add(rec);
        outOfStockCount++;
      }
    }

    return finalSelection;
  }

  static double _blendFinalScore({
    required double scentScore,
    required double genderScore,
    required double priceScore,
    required double contextScore,
    required bool strongScentSignal,
  }) {
    if (strongScentSignal) {
      return ((scentScore * _strongScentWeight) +
              (genderScore * _strongGenderWeight) +
              (priceScore * _strongPriceWeight) +
              (contextScore * _strongContextWeight))
          .clamp(0.0, 1.0);
    }

    return ((scentScore * _weakScentWeight) +
            (genderScore * _weakGenderWeight) +
            (priceScore * _weakPriceWeight) +
            (contextScore * _weakContextWeight))
        .clamp(0.0, 1.0);
  }

  static double _genderScore(String? preferredGender, String productGender) {
    if (preferredGender == null || preferredGender.toLowerCase() == 'unisex') {
      return 0.60;
    }

    final normalizedProduct = productGender.toLowerCase();
    final normalizedPreferred = preferredGender.toLowerCase();
    if (normalizedProduct == normalizedPreferred) return 1.0;
    if (normalizedProduct == 'unisex') return 0.70;
    if (normalizedProduct.isEmpty) return 0.45;
    return 0.0;
  }

  static double _priceScore({
    required ProductModel product,
    required SessionPreferences preferences,
    required RecommendedBudgetStatus budgetStatus,
  }) {
    final maxBudget = preferences.maxBudget;
    if (maxBudget == null || maxBudget <= 0) return 0.50;

    final price = product.effectivePrice;
    if (budgetStatus == RecommendedBudgetStatus.withinBudget) {
      final ratio = (price / maxBudget).clamp(0.0, 1.0);
      return (1.0 - (ratio * 0.35)).clamp(0.0, 1.0);
    }

    final allowedOverage = maxBudget * (_upsellToleranceMultiplier - 1.0);
    if (allowedOverage <= 0) return 0.0;
    final overage = (price - maxBudget).clamp(0.0, allowedOverage);
    return (1.0 - (overage / allowedOverage)).clamp(0.0, 1.0);
  }

  static double _contextScore(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    final factors = <double>[];

    if (preferences.season != null) {
      factors.add(
        _seasonScore(
          preferences.season!.toLowerCase(),
          product.season.toLowerCase(),
        ),
      );
    }

    if (preferences.occasion != null) {
      factors.add(
        _occasionScore(
          preferences.occasion!.toLowerCase(),
          product.occasion.toLowerCase(),
        ),
      );
    }

    if (preferences.time != null) {
      factors.add(
        _timeScore(preferences.time!.toLowerCase(), product.time.toLowerCase()),
      );
    }

    if (preferences.intensity != null) {
      factors.add(
        _intensityContextScore(
          preferences.intensity!.toLowerCase(),
          product.intensity.toLowerCase(),
        ),
      );
    }

    if (factors.isEmpty) return 0.50;
    final sum = factors.reduce((a, b) => a + b);
    return (sum / factors.length).clamp(0.0, 1.0);
  }

  static double _seasonScore(String target, String candidate) {
    if (candidate.isEmpty) return 0.40;
    if (target == candidate) return 1.0;
    if (target == 'all_seasons' || target == 'all seasons') return 0.80;
    if (candidate == 'all_seasons' || candidate == 'all seasons') return 0.80;
    return 0.0;
  }

  static double _occasionScore(String target, String candidate) {
    if (candidate.isEmpty) return 0.40;
    if (target == candidate) return 1.0;
    if (candidate == 'daily') return _dailyOccasionFallbackScore;
    return 0.0;
  }

  static double _timeScore(String target, String candidate) {
    if (candidate.isEmpty) return 0.40;
    if (target == candidate) return 1.0;
    if (target == 'all_day' && (candidate == 'day' || candidate == 'night')) {
      return 0.70;
    }
    if (candidate == 'all_day') return 0.80;
    return 0.0;
  }

  static double _intensityContextScore(String target, String candidate) {
    if (candidate.isEmpty) return 0.40;
    if (target == candidate) return 1.0;
    if ((target == 'light' && candidate == 'medium') ||
        (target == 'strong' && candidate == 'medium')) {
      return 0.50;
    }
    return 0.10;
  }

  static String _matchLabel(double score) {
    if (score >= 0.80) return 'Closest Match';
    if (score >= 0.65) return 'Strong Match';
    return 'Candidate Match';
  }

  static String _buildReason({
    required ProductModel product,
    required SessionPreferences preferences,
    required RecommendedBudgetStatus budgetStatus,
    required RecommendedCandidateSource candidateSource,
    required bool strongScentSignal,
    required double scentScore,
    required double contextScore,
  }) {
    if (candidateSource == RecommendedCandidateSource.relaxed) {
      if (preferences.maxBudget != null) {
        return 'Broad available match within budget; add scent or occasion details to narrow it.';
      }
      return 'Broad available match; add budget, scent, or occasion details to narrow it.';
    }

    final rankingStrategy = preferences.rankingStrategy;
    if (rankingStrategy == RankingStrategy.expensiveFirst) {
      final highlights = _productHighlights(product);
      if (highlights.isNotEmpty) {
        return 'يعتبر من أرقى وأفخم الخيارات المتاحة حالياً مع ${_joinCompact(highlights)}.';
      }
      return 'يعتبر من أرقى وأفخم الخيارات المتاحة حالياً.';
    }
    if (rankingStrategy == RankingStrategy.cheapestFirst) {
      final highlights = _productHighlights(product);
      if (highlights.isNotEmpty) {
        return 'يعتبر من أوفر الخيارات المتاحة حالياً مع ${_joinCompact(highlights)}.';
      }
      return 'يعتبر من أوفر الخيارات المتاحة حالياً.';
    }

    if (budgetStatus == RecommendedBudgetStatus.slightlyAboveBudget) {
      final highlights = _productHighlights(product);
      if (highlights.isNotEmpty) {
        return 'Closest profile fit with ${_joinCompact(highlights)}, but slightly above your budget.';
      }
      return 'Closest profile fit, but slightly above your budget.';
    }

    final noteOverlap = _preferredNoteOverlap(product, preferences);
    if (strongScentSignal) {
      if (noteOverlap.isNotEmpty) {
        final context = _matchedContextBits(product, preferences);
        final suffix = context.isEmpty
            ? ''
            : ' and fits ${_joinCompact(context)} context';
        return 'Matches your ${_joinCompact(noteOverlap)} scent preference${noteOverlap.length == 1 ? '' : 's'}$suffix.';
      }
      if (scentScore >= 0.75) {
        final highlights = _productHighlights(product);
        if (highlights.isNotEmpty) {
          return 'Strong scent-profile match with ${_joinCompact(highlights)} highlights.';
        }
        return 'Strong scent-profile match to your requested notes and style.';
      }
      if (scentScore >= 0.55) {
        final highlights = _productHighlights(product);
        if (highlights.isNotEmpty) {
          return 'Good scent-profile match built around ${_joinCompact(highlights)}.';
        }
        return 'Good scent-profile match with your requested style.';
      }
      return 'Closest available option with partial scent overlap.';
    }

    if (preferences.maxBudget != null && contextScore >= 0.60) {
      final contextBits = _matchedContextBits(product, preferences);
      if (contextBits.isNotEmpty) {
        final highlights = _productHighlights(product);
        final scentText = highlights.isEmpty
            ? ''
            : ' with ${_joinCompact(highlights)} highlights';
        return 'Fits your budget and ${_joinCompact(contextBits)} context$scentText.';
      }
      return 'Fits your budget and usage context.';
    }
    if (preferences.maxBudget != null) {
      final highlights = _productHighlights(product);
      if (highlights.isNotEmpty) {
        return 'Fits your budget with ${_joinCompact(highlights)} scent highlights.';
      }
      return 'Fits your budget and general preferences.';
    }
    if (contextScore >= 0.60) {
      final contextBits = _matchedContextBits(product, preferences);
      final highlights = _productHighlights(product);
      if (contextBits.isNotEmpty && highlights.isNotEmpty) {
        return 'Aligned with ${_joinCompact(contextBits)} use and ${_joinCompact(highlights)} notes.';
      }
      return 'Aligned with your usage context and profile.';
    }
    final highlights = _productHighlights(product);
    if (highlights.isNotEmpty) {
      return 'Best available fit with ${_joinCompact(highlights)} notes.';
    }
    return 'Best overall fit from current preferences.';
  }

  static List<String> _preferredNoteOverlap(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    final requested = {
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
    }.map(_normalize).where((note) => note.isNotEmpty).toSet();
    if (requested.isEmpty) return const <String>[];

    final productNotes = {
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      product.fragranceFamily,
      ...product.tags,
    }.map(_normalize).where((note) => note.isNotEmpty).toSet();

    return requested
        .where((note) => productNotes.any((productNote) => productNote == note))
        .take(2)
        .toList(growable: false);
  }

  static List<String> _matchedContextBits(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    return <String>[
      if (preferences.gender != null &&
          _normalize(product.gender) == _normalize(preferences.gender!))
        preferences.gender!,
      if (preferences.season != null &&
          (_normalize(product.season) == _normalize(preferences.season!) ||
              _normalize(product.season) == 'all_seasons' ||
              _normalize(product.season) == 'all seasons'))
        preferences.season!,
      if (preferences.occasion != null &&
          _normalize(product.occasion) == _normalize(preferences.occasion!))
        preferences.occasion!,
      if (preferences.time != null &&
          _normalize(product.time) == _normalize(preferences.time!))
        preferences.time!,
      if (preferences.intensity != null &&
          _normalize(product.intensity) == _normalize(preferences.intensity!))
        preferences.intensity!,
    ].take(2).toList(growable: false);
  }

  static List<String> _productHighlights(ProductModel product) {
    return <String>[
          ...product.topNotes,
          if (product.topNotes.isEmpty) ...product.notes,
          ...product.middleNotes.take(1),
          ...product.baseNotes.take(1),
        ]
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList(growable: false);
  }

  static String _joinCompact(List<String> items) {
    if (items.length <= 1) return items.join();
    if (items.length == 2) return '${items.first} and ${items.last}';
    return '${items.take(items.length - 1).join(', ')}, and ${items.last}';
  }

  static int _comparePriceByStrategy(
    double left,
    double right,
    RankingStrategy? rankingStrategy,
  ) {
    switch (rankingStrategy) {
      case RankingStrategy.expensiveFirst:
        return right.compareTo(left);
      case RankingStrategy.cheapestFirst:
      case null:
        return left.compareTo(right);
    }
  }

  static Set<String> _preferenceScentAnchors(SessionPreferences preferences) {
    return _expandScentAnchors([
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
      ...preferences.tags.where(_isScentTagAnchor),
    ]);
  }

  static Set<String> _productScentAnchors(ProductModel product) {
    return _expandScentAnchors([
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      product.fragranceFamily,
      ...product.tags,
    ]);
  }

  static bool _isScentTagAnchor(String value) {
    const scentTags = {
      'smoky',
      'woody',
      'amber',
      'cedar',
      'fresh',
      'clean',
      'citrus',
      'aromatic',
      'spicy',
      'musk',
      'musky',
      'leather',
      'oud',
      'vanilla',
      'sweet',
      'warm',
    };
    return scentTags.contains(_normalize(value));
  }

  static Set<String> _expandScentAnchors(Iterable<String> values) {
    final anchors = <String>{};
    for (final value in values) {
      final normalized = _normalize(value);
      if (normalized.isEmpty) continue;
      anchors.add(normalized);

      if (normalized.contains('cedar') || normalized.contains('wood')) {
        anchors.addAll(const {'cedar', 'woody'});
      }
      if (normalized.contains('smok') || normalized.contains('tobacco')) {
        anchors.addAll(const {'smoky', 'tobacco', 'woody'});
      }
      if (normalized.contains('amber')) {
        anchors.addAll(const {'amber', 'warm'});
      }
      if (normalized.contains('musk')) {
        anchors.add('musk');
      }
      if (normalized.contains('aromatic')) {
        anchors.addAll(const {'aromatic', 'fresh'});
      }
      if (normalized.contains('citrus') ||
          normalized.contains('lemon') ||
          normalized.contains('bergamot') ||
          normalized.contains('orange')) {
        anchors.addAll(const {'citrus', 'lemon', 'bergamot', 'orange'});
      }
      if (normalized.contains('rose')) {
        anchors.add('rose');
      }
      if (normalized.contains('jasmine')) {
        anchors.add('jasmine');
      }
    }
    return anchors;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  static String _normalizeTerm(String value) {
    return _normalize(value).replaceAll(RegExp(r'\s+'), ' ');
  }
}
