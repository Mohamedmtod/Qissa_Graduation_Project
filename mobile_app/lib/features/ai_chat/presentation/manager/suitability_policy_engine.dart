import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_facet_index.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/staff_taste_scorer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class SuitabilityContext {
  final SessionPreferences preferences;
  final String? detectedUseCase;
  final bool hasExplicitBudget;
  final String sourcePath;

  const SuitabilityContext({
    required this.preferences,
    this.detectedUseCase,
    this.hasExplicitBudget = false,
    this.sourcePath = 'unknown',
  });
}

class SuitabilityPolicyResult {
  final String productId;
  final double suitabilityScore;
  final List<String> suitabilityReasons;
  final bool blockedBySuitability;
  final String? caveat;
  final double staffTasteScore;
  final List<String> staffTasteReasons;
  final double staffDataCoverage;
  final String staffIntelligenceStatus;
  final bool reviewNeeded;
  final int staffTaxonomyVersion;

  const SuitabilityPolicyResult({
    required this.productId,
    required this.suitabilityScore,
    this.suitabilityReasons = const <String>[],
    this.blockedBySuitability = false,
    this.caveat,
    this.staffTasteScore = 0,
    this.staffTasteReasons = const <String>[],
    this.staffDataCoverage = 0,
    this.staffIntelligenceStatus = 'draft',
    this.reviewNeeded = false,
    this.staffTaxonomyVersion = 1,
  });
}

class SuitabilityPolicyApplication {
  final List<RecommendedProduct> products;
  final Map<String, SuitabilityPolicyResult> resultsByProductId;

  const SuitabilityPolicyApplication({
    required this.products,
    required this.resultsByProductId,
  });
}

class SuitabilityPolicyEngine {
  static const double premiumWithoutBudgetPrice = 5000;

  const SuitabilityPolicyEngine({StaffTasteScorer? staffTasteScorer})
    : _staffTasteScorer = staffTasteScorer ?? const StaffTasteScorer();

  final StaffTasteScorer _staffTasteScorer;

  Map<String, SuitabilityPolicyResult> evaluateProducts({
    required List<ProductModel> products,
    required SuitabilityContext context,
  }) {
    final raw = <ProductModel, _RawSuitability>{};
    for (final product in products) {
      raw[product] = _evaluateRaw(product, context);
    }

    return {
      for (final entry in raw.entries)
        entry.key.id: _finalize(entry.key, entry.value, context),
    };
  }

  SuitabilityPolicyApplication applyToRecommendations({
    required List<RecommendedProduct> products,
    required SuitabilityContext context,
  }) {
    final resultsById = evaluateProducts(
      products: products.map((item) => item.product).toList(growable: false),
      context: context,
    );
    final ranked = <RecommendedProduct>[];

    for (final recommendation in products) {
      final result = resultsById[recommendation.product.id];
      if (result == null || result.blockedBySuitability) continue;
      ranked.add(_withSuitability(recommendation, result));
    }

    ranked.sort((a, b) {
      final aResult = resultsById[a.product.id];
      final bResult = resultsById[b.product.id];
      final scoreCompare = (bResult?.suitabilityScore ?? 1.0).compareTo(
        aResult?.suitabilityScore ?? 1.0,
      );
      if (scoreCompare != 0) return scoreCompare;
      return b.matchScore.compareTo(a.matchScore);
    });

    return SuitabilityPolicyApplication(
      products: ranked,
      resultsByProductId: resultsById,
    );
  }

  _RawSuitability _evaluateRaw(
    ProductModel product,
    SuitabilityContext context,
  ) {
    final reasons = <String>[];
    final severe = <String>{};
    var score = 1.0;
    final useCase = _resolveUseCase(context);
    final normalizedTags = _normalizedList(product.tags);
    final productText = _normalizedText([
      product.name,
      product.brand,
      product.fragranceFamily,
      product.description,
      product.occasion,
      product.time,
      product.intensity,
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.tags,
    ]);

    void penalize(String code, double amount, {bool hardBlock = false}) {
      reasons.add(code);
      score -= amount;
      if (hardBlock) severe.add(code);
    }

    _applyHardSafetyScoring(
      product: product,
      context: context,
      productText: productText,
      penalize: penalize,
    );

    _applyGenericPreferenceScoring(
      product: product,
      context: context,
      productText: productText,
      normalizedTags: normalizedTags,
      penalize: penalize,
    );

    if (useCase == 'university') {
      if (!_isDayFriendly(product.time)) {
        penalize('night_for_university', 0.35);
      }
      if (_isWinter(product.season) && !_requestedWinter(context.preferences)) {
        penalize('winter_for_university', 0.22);
      }
      if (_isStrong(product.intensity)) {
        penalize('too_strong_for_university', 0.30);
      }
      if (!_isPracticalOccasion(product.occasion, normalizedTags)) {
        penalize('weak_university_occasion_fit', 0.12);
      }
      if (!_hasFreshCleanSignal(productText)) {
        penalize('missing_fresh_clean_signal', 0.08);
      }
      if (_isPremiumWithoutBudget(product, context)) {
        penalize('premium_without_budget', 0.18);
      }
    } else if (useCase == 'daily_fresh') {
      if (!_isDayFriendly(product.time)) {
        penalize('night_for_daily_fresh', 0.30);
      }
      if (_isStrong(product.intensity)) {
        penalize('too_strong_for_daily_fresh', 0.28);
      }
      if (_isDatePartyOccasion(product.occasion, normalizedTags)) {
        penalize('date_party_for_daily_fresh', 0.26);
      }
      if (!_hasFreshCleanSignal(productText)) {
        penalize('missing_fresh_clean_signal', 0.10);
      }
    } else if (useCase == 'gym') {
      if (!_isLight(product.intensity)) {
        penalize('not_light_for_gym', 0.24);
      }
      if (!_isDayFriendly(product.time)) {
        penalize('night_for_gym', 0.26);
      }
      if (_isStrong(product.intensity)) {
        penalize('too_strong_for_gym', 0.34);
      }
      if (!_hasFreshCleanSignal(productText)) {
        penalize('missing_clean_fresh_gym_signal', 0.16);
      }
    } else if (useCase == 'office') {
      if (!_isDayFriendly(product.time)) {
        penalize('night_for_office', 0.22);
      }
      if (_isStrong(product.intensity)) {
        penalize('too_loud_for_office', 0.20);
      }
      if (_isDatePartyOccasion(product.occasion, normalizedTags)) {
        penalize('party_for_office', 0.22);
      }
      if (!_hasFreshCleanSignal(productText) &&
          !_isModerate(product.intensity)) {
        penalize('weak_office_clean_moderate_fit', 0.12);
      }
    } else if (_isPremiumWithoutBudget(product, context)) {
      penalize('premium_without_budget_caveat', 0.08);
    }

    return _RawSuitability(
      score: score.clamp(0.0, 1.0),
      reasons: reasons.toList(growable: false),
      severeReasons: severe,
    );
  }

  void _applyGenericPreferenceScoring({
    required ProductModel product,
    required SuitabilityContext context,
    required String productText,
    required Set<String> normalizedTags,
    required void Function(String code, double amount, {bool hardBlock})
    penalize,
  }) {
    final preferences = context.preferences;
    final preferredGender = _normalize(preferences.gender ?? '');
    if (preferredGender.isNotEmpty &&
        preferredGender != 'unisex' &&
        !_isGenderCompatible(product.gender, preferredGender)) {
      penalize('gender_mismatch', 0.45);
    }

    final requestedIntensity = _normalize(preferences.intensity ?? '');
    if (requestedIntensity.isNotEmpty) {
      final productIntensity = _normalize(product.intensity);
      if (requestedIntensity == 'light') {
        if (productIntensity == 'medium') {
          penalize('medium_for_light_request', 0.14);
        } else if (productIntensity == 'strong') {
          penalize('strong_for_light_request', 0.34);
        }
        if (!_isDayFriendly(product.time)) {
          penalize('night_for_light_request', 0.22);
        }
        if (_isDatePartyOccasion(product.occasion, normalizedTags)) {
          penalize('date_party_for_light_request', 0.16);
        }
        if (_hasHeavyWarmSignal(productText)) {
          penalize('heavy_warm_for_light_request', 0.12);
        }
      } else if (requestedIntensity == 'medium') {
        if (productIntensity == 'strong') {
          penalize('strong_for_medium_request', 0.18);
        }
      } else if (requestedIntensity == 'strong' &&
          productIntensity == 'light') {
        penalize('light_for_strong_request', 0.18);
      }
    }

    final requestedTime = _normalize(preferences.time ?? '');
    if (requestedTime.isNotEmpty &&
        !_timeMatches(product.time, requestedTime)) {
      penalize('time_mismatch', 0.18);
    }

    final requestedSeason = _normalize(preferences.season ?? '');
    if (requestedSeason.isNotEmpty &&
        !_seasonMatches(product.season, requestedSeason)) {
      penalize('season_mismatch', 0.14);
    } else if (requestedSeason.isEmpty &&
        _isWinter(product.season) &&
        requestedIntensity == 'light') {
      penalize('winter_without_request_for_light', 0.10);
    }

    final requestedOccasion = _normalize(preferences.occasion ?? '');
    if (requestedOccasion.isNotEmpty &&
        !_occasionMatches(
          product.occasion,
          requestedOccasion,
          normalizedTags,
        )) {
      penalize('occasion_mismatch', 0.12);
    }

    final preferredTerms = {
      ...preferences.preferredNotes.map(_normalize),
      ...preferences.preferredTopNotes.map(_normalize),
      ...preferences.preferredMiddleNotes.map(_normalize),
      ...preferences.preferredBaseNotes.map(_normalize),
      ...preferences.tags.map(_normalize),
    }..removeWhere((term) => term.isEmpty);
    if (preferredTerms.isNotEmpty &&
        !preferredTerms.any((term) => productText.contains(term))) {
      penalize('missing_preferred_facet_overlap', 0.22);
    }
  }

  SuitabilityPolicyResult _finalize(
    ProductModel product,
    _RawSuitability raw,
    SuitabilityContext context,
  ) {
    final shouldBlock = raw.hasHardBlock;
    final caveat =
        raw.reasons.contains('premium_without_budget_caveat') ||
            raw.reasons.contains('premium_without_budget')
        ? 'premium_without_budget'
        : null;
    final staffScore = _staffTasteScorer.score(
      product: product,
      preferences: context.preferences,
    );
    final staffBoost =
        AIChatExperimentConfig.staffTasteScoringEnabled && !staffScore.isNeutral
        ? staffScore.score * AIChatExperimentConfig.staffTasteWeight
        : 0.0;
    final finalScore = (raw.score + staffBoost).clamp(0.0, 1.0);
    return SuitabilityPolicyResult(
      productId: product.id,
      suitabilityScore: finalScore,
      suitabilityReasons: raw.reasons,
      blockedBySuitability: shouldBlock,
      caveat: caveat,
      staffTasteScore: staffScore.score,
      staffTasteReasons: staffScore.reasonCodes,
      staffDataCoverage: product.staffDataCoverage,
      staffIntelligenceStatus: product.staffIntelligenceStatus,
      reviewNeeded: product.reviewNeeded,
      staffTaxonomyVersion: product.staffTaxonomyVersion,
    );
  }

  void _applyHardSafetyScoring({
    required ProductModel product,
    required SuitabilityContext context,
    required String productText,
    required void Function(String code, double amount, {bool hardBlock})
    penalize,
  }) {
    if (!product.isActive || product.stock <= 0) {
      penalize('inactive_or_out_of_stock', 1.0, hardBlock: true);
    }

    final blockedTerms = {
      ...context.preferences.excludedNotes.map(_normalize),
      ...context.preferences.medicalExcludedNotes.map(_normalize),
    }..removeWhere((term) => term.isEmpty);
    for (final term in blockedTerms) {
      if (productText.contains(term)) {
        penalize(
          context.preferences.medicalExcludedNotes
                  .map(_normalize)
                  .contains(term)
              ? 'medical_excluded_note'
              : 'excluded_note',
          1.0,
          hardBlock: true,
        );
        break;
      }
    }
  }

  RecommendedProduct _withSuitability(
    RecommendedProduct recommendation,
    SuitabilityPolicyResult result,
  ) {
    return RecommendedProduct(
      product: recommendation.product,
      matchScore: (recommendation.matchScore * result.suitabilityScore).clamp(
        0.0,
        1.0,
      ),
      matchLabel: recommendation.matchLabel,
      matchReason: recommendation.matchReason.trim(),
      budgetStatus: recommendation.budgetStatus,
      exactBudget: recommendation.exactBudget,
      candidateSource: recommendation.candidateSource,
    );
  }

  String? _resolveUseCase(SuitabilityContext context) {
    final explicit = _normalize(context.detectedUseCase ?? '');
    if (explicit == 'university' ||
        explicit == 'gym' ||
        explicit == 'office' ||
        explicit == 'daily_fresh') {
      return explicit;
    }

    final preferences = context.preferences;
    final signals = {
      _normalize(preferences.occasion ?? ''),
      _normalize(preferences.time ?? ''),
      _normalize(preferences.intensity ?? ''),
      ...preferences.tags.map(_normalize),
      ...preferences.preferredNotes.map(_normalize),
    }..removeWhere((item) => item.isEmpty);

    if (signals.contains('university') || signals.contains('campus')) {
      return 'university';
    }
    if (signals.contains('gym') || signals.contains('workout')) {
      return 'gym';
    }
    if (signals.contains('office') || signals.contains('work')) {
      return 'office';
    }
    final daily = signals.contains('daily') || signals.contains('everyday');
    final fresh =
        signals.contains('fresh') ||
        signals.contains('clean') ||
        signals.contains('citrus') ||
        signals.contains('aquatic');
    if (daily && fresh) return 'daily_fresh';
    return null;
  }

  bool _isPremiumWithoutBudget(
    ProductModel product,
    SuitabilityContext context,
  ) {
    return !context.hasExplicitBudget &&
        context.preferences.maxBudget == null &&
        product.effectivePrice >= premiumWithoutBudgetPrice;
  }

  bool _isGenderCompatible(String productGender, String preferredGender) {
    final normalizedProductGender = _normalize(productGender);
    return normalizedProductGender.isEmpty ||
        normalizedProductGender == 'unisex' ||
        normalizedProductGender == preferredGender;
  }

  bool _isDayFriendly(String value) {
    final normalized = _normalize(value);
    return normalized.isEmpty ||
        normalized == 'day' ||
        normalized == 'all_day' ||
        normalized == 'all day';
  }

  bool _isWinter(String value) => _normalize(value) == 'winter';
  bool _isStrong(String value) => _normalize(value) == 'strong';
  bool _isLight(String value) => _normalize(value) == 'light';
  bool _isModerate(String value) => _normalize(value) == 'medium';

  bool _timeMatches(String productTime, String requestedTime) {
    final normalizedProductTime = _normalize(productTime);
    return normalizedProductTime.isEmpty ||
        normalizedProductTime == requestedTime ||
        normalizedProductTime == 'all_day' ||
        requestedTime == 'all_day';
  }

  bool _seasonMatches(String productSeason, String requestedSeason) {
    final normalizedProductSeason = _normalize(productSeason);
    return normalizedProductSeason.isEmpty ||
        normalizedProductSeason == requestedSeason ||
        normalizedProductSeason == 'all_seasons' ||
        normalizedProductSeason == 'all_season';
  }

  bool _occasionMatches(
    String productOccasion,
    String requestedOccasion,
    Set<String> tags,
  ) {
    final normalizedProductOccasion = _normalize(productOccasion);
    return normalizedProductOccasion.isEmpty ||
        normalizedProductOccasion == requestedOccasion ||
        tags.contains(requestedOccasion);
  }

  bool _requestedWinter(SessionPreferences preferences) {
    return _normalize(preferences.season ?? '') == 'winter';
  }

  bool _isPracticalOccasion(String occasion, Set<String> tags) {
    final normalized = _normalize(occasion);
    return normalized == 'daily' ||
        normalized == 'office' ||
        normalized == 'university' ||
        tags.contains('daily') ||
        tags.contains('office') ||
        tags.contains('university') ||
        tags.contains('campus');
  }

  bool _isDatePartyOccasion(String occasion, Set<String> tags) {
    final normalized = _normalize(occasion);
    return normalized == 'date' ||
        normalized == 'party' ||
        normalized == 'night_out' ||
        tags.contains('date') ||
        tags.contains('party') ||
        tags.contains('night');
  }

  bool _hasFreshCleanSignal(String productText) {
    return productText.contains('fresh') ||
        productText.contains('clean') ||
        productText.contains('citrus') ||
        productText.contains('aquatic') ||
        productText.contains('musk') ||
        productText.contains('green') ||
        productText.contains('soap');
  }

  bool _hasHeavyWarmSignal(String productText) {
    return productText.contains('vanilla') ||
        productText.contains('amber') ||
        productText.contains('oud') ||
        productText.contains('smoke') ||
        productText.contains('tobacco') ||
        productText.contains('leather') ||
        productText.contains('warm') ||
        productText.contains('sweet');
  }

  Set<String> _normalizedList(Iterable<String> values) {
    return values.map(_normalize).where((item) => item.isNotEmpty).toSet();
  }

  String _normalizedText(Iterable<String> values) {
    return values.map(_normalize).where((item) => item.isNotEmpty).join(' ');
  }

  String _normalize(String value) {
    return CatalogFacetIndex.normalizeText(value).replaceAll(' ', '_');
  }
}

class _RawSuitability {
  final double score;
  final List<String> reasons;
  final Set<String> severeReasons;

  const _RawSuitability({
    required this.score,
    required this.reasons,
    required this.severeReasons,
  });

  bool get hasHardBlock => severeReasons.isNotEmpty;
}
