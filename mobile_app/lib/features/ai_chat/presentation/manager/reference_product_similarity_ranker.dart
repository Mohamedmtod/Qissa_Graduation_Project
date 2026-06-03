import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/scent_profile_scorer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

enum ReferenceSimilarityMode { similar, similarCheaper }

class ReferenceProductSimilarityRanker {
  static const double scentGate = ScentProfileScorer.scentGate;

  // Final blended score weights.
  static const double _scentScoreWeight = 0.65;
  static const double _genderScoreWeight = 0.15;
  static const double _priceScoreWeight = 0.10;
  static const double _contextScoreWeight = 0.10;

  static const Set<String> _signatureScentTerms = {
    'aromatic',
    'fougere',
    'spicy',
    'woody',
    'amber',
    'citrus',
    'bergamot',
    'pepper',
    'lavender',
    'ambroxan',
    'fresh',
    'masculine',
  };

  static const Set<String> _distanceTerms = {
    'floral',
    'rose',
    'jasmine',
    'vanilla',
    'sweet',
    'gourmand',
    'fruity',
  };

  static List<RecommendedProduct> rank({
    required ProductModel referenceProduct,
    required List<ProductModel> catalog,
    required SessionPreferences sessionPreferences,
    required SessionPreferences effectivePreferences,
    required ReferenceSimilarityMode mode,
    int limit = 3,
    bool arabicReasons = false,
    bool enforceScentGate = true,
    bool filterDistractingCandidates = true,
  }) {
    final hasExplicitSessionGender = sessionPreferences.gender != null;
    final explicitSessionGender = sessionPreferences.gender;
    final referenceGender = _normalize(referenceProduct.gender);
    final effectiveGender = _normalize(
      effectivePreferences.gender ?? referenceGender,
    );

    final candidates = <_RankedCandidate>[];
    for (final product in catalog) {
      if (product.id == referenceProduct.id) continue;
      if (product.stock <= 0) continue;
      if (mode == ReferenceSimilarityMode.similarCheaper &&
          product.effectivePrice >= referenceProduct.effectivePrice) {
        continue;
      }
      if (_containsExcludedNotes(product, effectivePreferences.excludedNotes)) {
        continue;
      }
      if (hasExplicitSessionGender &&
          !_isGenderCompatibleAsHardFilter(
            explicitSessionGender!,
            product.gender,
          )) {
        continue;
      }
      if (!hasExplicitSessionGender &&
          mode == ReferenceSimilarityMode.similarCheaper &&
          !_isGenderCompatibleAsHardFilter(effectiveGender, product.gender)) {
        continue;
      }
      if (mode == ReferenceSimilarityMode.similarCheaper &&
          _isFeminineCandidateForMasculineReference(
            referenceProduct: referenceProduct,
            candidate: product,
            effectiveGender: effectiveGender,
          )) {
        continue;
      }
      if (filterDistractingCandidates &&
          mode == ReferenceSimilarityMode.similarCheaper &&
          _isDistractingReferenceCheaperCandidate(
            referenceProduct: referenceProduct,
            candidate: product,
            effectivePreferences: effectivePreferences,
          )) {
        continue;
      }

      final scentScore = ScentProfileScorer.scoreProductToProduct(
        referenceProduct,
        product,
      );
      if (enforceScentGate && scentScore < scentGate) continue;

      final genderScore = _genderScore(
        targetGender: hasExplicitSessionGender
            ? (explicitSessionGender ?? '')
            : effectiveGender,
        candidateGender: product.gender,
      );
      final priceScore = _priceScore(
        referencePrice: referenceProduct.effectivePrice,
        candidatePrice: product.effectivePrice,
        mode: mode,
        rankingStrategy: effectivePreferences.rankingStrategy,
      );
      final contextScore = _contextScore(
        referenceProduct: referenceProduct,
        effectivePreferences: effectivePreferences,
        candidate: product,
      );

      final sharedScentTerms = _sharedScentTerms(referenceProduct, product);
      final finalScore = mode == ReferenceSimilarityMode.similarCheaper
          ? _referenceCheaperScore(
              scentScore: scentScore,
              genderScore: genderScore,
              priceScore: priceScore,
              contextScore: contextScore,
              referenceProduct: referenceProduct,
              candidate: product,
              sharedScentTerms: sharedScentTerms,
              effectivePreferences: effectivePreferences,
            )
          : (scentScore * _scentScoreWeight) +
                (genderScore * _genderScoreWeight) +
                (priceScore * _priceScoreWeight) +
                (contextScore * _contextScoreWeight);
      candidates.add(
        _RankedCandidate(
          product: product,
          score: finalScore.clamp(0.0, 1.0),
          scentScore: scentScore,
          reason: _buildReason(
            mode,
            scentScore,
            referenceProduct: referenceProduct,
            candidate: product,
            sharedScentTerms: sharedScentTerms,
            preferences: effectivePreferences,
            arabic: arabicReasons,
          ),
        ),
      );
    }

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;

      final byScent = b.scentScore.compareTo(a.scentScore);
      if (byScent != 0) return byScent;

      final byPrice = _comparePriceByStrategy(
        a.product.effectivePrice,
        b.product.effectivePrice,
        effectivePreferences.rankingStrategy,
      );
      if (byPrice != 0) return byPrice;

      return a.product.name.compareTo(b.product.name);
    });

    return candidates
        .take(limit)
        .map(
          (item) => RecommendedProduct(
            product: item.product,
            matchScore: item.score,
            matchLabel: _matchLabel(item.score, arabic: arabicReasons),
            matchReason: item.reason,
          ),
        )
        .toList(growable: false);
  }

  static bool _containsExcludedNotes(
    ProductModel product,
    List<String> excludedNotes,
  ) {
    if (excludedNotes.isEmpty) return false;
    final haystack = [
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      product.fragranceFamily,
      product.description,
    ].map(_normalize).join(' ');

    for (final excluded in excludedNotes) {
      final normalizedExcluded = _normalize(excluded);
      if (normalizedExcluded.isEmpty) continue;
      if (haystack.contains(normalizedExcluded)) {
        return true;
      }
    }
    return false;
  }

  static bool _isGenderCompatibleAsHardFilter(
    String requestedGender,
    String candidateGender,
  ) {
    final requested = _normalize(requestedGender);
    final candidate = _normalize(candidateGender);
    if (requested.isEmpty || requested == 'unisex') return true;
    if (candidate.isEmpty) return true;
    if (candidate == requested) return true;
    return candidate == 'unisex';
  }

  static double _genderScore({
    required String targetGender,
    required String candidateGender,
  }) {
    final target = _normalize(targetGender);
    final candidate = _normalize(candidateGender);
    if (target.isEmpty || target == 'unisex') return 1.0;
    if (candidate == target) return 1.0;
    if (candidate == 'unisex') return 0.70;
    if (candidate.isEmpty) return 0.40;
    return 0.0;
  }

  static double _priceScore({
    required double referencePrice,
    required double candidatePrice,
    required ReferenceSimilarityMode mode,
    required RankingStrategy? rankingStrategy,
  }) {
    if (referencePrice <= 0) return 0.5;
    final ratio = (candidatePrice / referencePrice).clamp(0.0, 1.2);

    if (mode == ReferenceSimilarityMode.similarCheaper) {
      if (candidatePrice >= referencePrice) return 0.0;
      switch (rankingStrategy) {
        case RankingStrategy.expensiveFirst:
        case null:
          return ratio;
        case RankingStrategy.cheapestFirst:
          return (1.0 - ratio).clamp(0.0, 1.0);
      }
    }

    final distance = (1.0 - (ratio > 1.0 ? (2.0 - ratio) : ratio)).abs();
    return (1.0 - distance).clamp(0.0, 1.0);
  }

  static double _contextScore({
    required ProductModel referenceProduct,
    required SessionPreferences effectivePreferences,
    required ProductModel candidate,
  }) {
    final seasonTarget =
        effectivePreferences.season ?? _normalize(referenceProduct.season);
    final occasionTarget =
        effectivePreferences.occasion ?? _normalize(referenceProduct.occasion);
    final timeTarget =
        effectivePreferences.time ?? _normalize(referenceProduct.time);
    final intensityTarget =
        effectivePreferences.intensity ??
        _normalize(referenceProduct.intensity);

    final factors = <double>[];
    if (seasonTarget.isNotEmpty) {
      factors.add(
        _contextFieldScore(seasonTarget, _normalize(candidate.season)),
      );
    }
    if (occasionTarget.isNotEmpty) {
      factors.add(
        _contextFieldScore(occasionTarget, _normalize(candidate.occasion)),
      );
    }
    if (timeTarget.isNotEmpty) {
      factors.add(_timeScore(timeTarget, _normalize(candidate.time)));
    }
    if (intensityTarget.isNotEmpty) {
      factors.add(
        _intensityScore(intensityTarget, _normalize(candidate.intensity)),
      );
    }
    if (factors.isEmpty) return 0.5;

    final sum = factors.reduce((a, b) => a + b);
    return sum / factors.length;
  }

  static double _contextFieldScore(String target, String candidate) {
    if (candidate.isEmpty) return 0.4;
    if (target == candidate) return 1.0;
    if ((target == 'all_seasons' && candidate == 'all_seasons') ||
        (target == 'all_day' && candidate == 'all_day')) {
      return 1.0;
    }
    if (target == 'all_seasons' || candidate == 'all_seasons') return 0.8;
    return 0.0;
  }

  static double _timeScore(String target, String candidate) {
    if (candidate.isEmpty) return 0.4;
    if (target == candidate) return 1.0;
    if (target == 'all_day' && (candidate == 'day' || candidate == 'night')) {
      return 0.7;
    }
    if (candidate == 'all_day') return 0.8;
    return 0.0;
  }

  static double _intensityScore(String target, String candidate) {
    if (candidate.isEmpty) return 0.4;
    if (target == candidate) return 1.0;
    if ((target == 'medium' &&
            (candidate == 'light' || candidate == 'strong')) ||
        (candidate == 'medium' && (target == 'light' || target == 'strong'))) {
      return 0.5;
    }
    return 0.1;
  }

  static double _referenceCheaperScore({
    required double scentScore,
    required double genderScore,
    required double priceScore,
    required double contextScore,
    required ProductModel referenceProduct,
    required ProductModel candidate,
    required Set<String> sharedScentTerms,
    required SessionPreferences effectivePreferences,
  }) {
    final signatureOverlap = sharedScentTerms
        .where(_signatureScentTerms.contains)
        .length
        .clamp(0, 5);
    final signatureBonus = signatureOverlap * 0.035;
    final distancePenalty = _distancePenalty(
      referenceProduct: referenceProduct,
      candidate: candidate,
      effectivePreferences: effectivePreferences,
    );

    return (scentScore * 0.78) +
        (genderScore * 0.08) +
        (priceScore * 0.07) +
        (contextScore * 0.03) +
        signatureBonus -
        distancePenalty;
  }

  static double _distancePenalty({
    required ProductModel referenceProduct,
    required ProductModel candidate,
    required SessionPreferences effectivePreferences,
  }) {
    final requestedTerms = {
      ...effectivePreferences.preferredNotes.map(_normalize),
      ...effectivePreferences.preferredTopNotes.map(_normalize),
      ...effectivePreferences.preferredMiddleNotes.map(_normalize),
      ...effectivePreferences.preferredBaseNotes.map(_normalize),
      ...effectivePreferences.tags.map(_normalize),
    };
    final referenceTerms = _scentTerms(referenceProduct);
    final candidateTerms = _scentTerms(candidate);
    final unrequestedDistanceTerms = candidateTerms
        .where(_distanceTerms.contains)
        .where((term) => !referenceTerms.contains(term))
        .where((term) => !requestedTerms.contains(term))
        .length
        .clamp(0, 4);
    return unrequestedDistanceTerms * 0.035;
  }

  static bool _isDistractingReferenceCheaperCandidate({
    required ProductModel referenceProduct,
    required ProductModel candidate,
    required SessionPreferences effectivePreferences,
  }) {
    final requestedTerms = {
      ...effectivePreferences.preferredNotes.map(_normalize),
      ...effectivePreferences.preferredTopNotes.map(_normalize),
      ...effectivePreferences.preferredMiddleNotes.map(_normalize),
      ...effectivePreferences.preferredBaseNotes.map(_normalize),
      ...effectivePreferences.tags.map(_normalize),
    };
    final referenceTerms = _scentTerms(referenceProduct);
    final candidateTerms = _scentTerms(candidate);
    final unrequestedDistanceCount = candidateTerms
        .where(_distanceTerms.contains)
        .where((term) => !referenceTerms.contains(term))
        .where((term) => !requestedTerms.contains(term))
        .length;
    if (unrequestedDistanceCount < 2) return false;

    const masculineAromaticMarkers = {
      'aromatic',
      'fougere',
      'spicy',
      'pepper',
      'leather',
      'masculine',
    };
    final markerCount = candidateTerms
        .where(masculineAromaticMarkers.contains)
        .length;
    return markerCount < 2;
  }

  static bool _isFeminineCandidateForMasculineReference({
    required ProductModel referenceProduct,
    required ProductModel candidate,
    required String effectiveGender,
  }) {
    final referenceGender = _normalize(referenceProduct.gender);
    final targetGender = effectiveGender.isEmpty
        ? referenceGender
        : effectiveGender;
    if (targetGender != 'men') return false;

    final candidateGender = _normalize(candidate.gender);
    if (candidateGender == 'women') return true;
    if (candidateGender == 'men') return false;

    final searchableName = _normalize('${candidate.brand} ${candidate.name}');
    const feminineNameMarkers = {
      'miss',
      'girl',
      'lady',
      'her',
      'femme',
      'woman',
      'women',
      'female',
    };
    final hasFeminineNameMarker = feminineNameMarkers.any(
      (marker) => searchableName.split(RegExp(r'\s+')).contains(marker),
    );
    if (hasFeminineNameMarker) return true;

    final candidateTerms = _scentTerms(candidate);
    const feminineScentMarkers = {
      'floral',
      'rose',
      'jasmine',
      'romantic',
      'sweet',
      'gourmand',
      'fruity',
      'vanilla',
    };
    const masculineAromaticMarkers = {
      'aromatic',
      'fougere',
      'spicy',
      'pepper',
      'leather',
      'masculine',
      'cedar',
      'ambroxan',
    };
    final feminineMarkerCount = candidateTerms
        .where(feminineScentMarkers.contains)
        .length;
    if (feminineMarkerCount < 2) return false;

    final masculineMarkerCount = candidateTerms
        .where(masculineAromaticMarkers.contains)
        .length;
    return masculineMarkerCount < 2;
  }

  static String _buildReason(
    ReferenceSimilarityMode mode,
    double scentScore, {
    required ProductModel referenceProduct,
    required ProductModel candidate,
    required Set<String> sharedScentTerms,
    required SessionPreferences preferences,
    required bool arabic,
  }) {
    if (mode == ReferenceSimilarityMode.similarCheaper) {
      return _buildReferenceCheaperReason(
        referenceProduct: referenceProduct,
        candidate: candidate,
        sharedScentTerms: sharedScentTerms,
        scentScore: scentScore,
        preferences: preferences,
        arabic: arabic,
      );
    }

    if (scentScore < 0.55) {
      return 'Closest available alternative with partial profile overlap.';
    }
    return 'Alternative with a similar scent profile.';
  }

  static String _buildReferenceCheaperReason({
    required ProductModel referenceProduct,
    required ProductModel candidate,
    required Set<String> sharedScentTerms,
    required double scentScore,
    required SessionPreferences preferences,
    required bool arabic,
  }) {
    final shared = sharedScentTerms
        .where((term) => term.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
    final sharedText = arabic
        ? shared.map(_arabicScentTerm).join('، ')
        : shared.join(', ');
    final referenceName = referenceProduct.name;
    final difference = _differenceHint(
      referenceProduct: referenceProduct,
      candidate: candidate,
      arabic: arabic,
    );
    final rankingStrategy = preferences.rankingStrategy;

    if (rankingStrategy == RankingStrategy.expensiveFirst) {
      final premiumLead = arabic
          ? 'من أرقى وأفخم الخيارات المتاحة حالياً'
          : 'one of the most premium options currently available';
      final overlap = sharedText.isEmpty
          ? (arabic
                ? 'مع توافق عام في الطابع العطري'
                : 'with a general scent-profile overlap')
          : (arabic
                ? 'لأنه يشترك معه في $sharedText'
                : 'because it shares $sharedText');
      return arabic
          ? '$premiumLead ضمن البدائل الأقل من $referenceName $overlap$difference.'
          : '$premiumLead among the cheaper-than-$referenceName options $overlap$difference.';
    }
    if (rankingStrategy == RankingStrategy.cheapestFirst) {
      final valueLead = arabic
          ? 'من أوفر الخيارات المتاحة حالياً'
          : 'one of the most affordable options currently available';
      final overlap = sharedText.isEmpty
          ? (arabic
                ? 'مع توافق عام في الطابع العطري'
                : 'with a general scent-profile overlap')
          : (arabic
                ? 'لأنه يشترك معه في $sharedText'
                : 'because it shares $sharedText');
      return arabic
          ? '$valueLead ضمن البدائل الأقل من $referenceName $overlap$difference.'
          : '$valueLead among the cheaper-than-$referenceName options $overlap$difference.';
    }

    if (arabic) {
      final closeness = scentScore >= 0.55
          ? 'قريب منه في الرائحة'
          : 'أقرب بديل أرخص متاح';
      final overlap = sharedText.isEmpty
          ? 'مع وجود تشابه عام في الطابع العطري'
          : 'لأنه يشترك معه في $sharedText';
      return 'أرخص من $referenceName و$closeness $overlap$difference.';
    }

    final closeness = scentScore >= 0.55
        ? 'similar in scent'
        : 'the closest lower-priced available option';
    final overlap = sharedText.isEmpty
        ? 'with a general scent-profile overlap'
        : 'because it shares $sharedText';
    return 'Lower-priced than $referenceName and $closeness $overlap$difference.';
  }

  static String _differenceHint({
    required ProductModel referenceProduct,
    required ProductModel candidate,
    required bool arabic,
  }) {
    final referenceTerms = _scentTerms(referenceProduct);
    final candidateTerms = _scentTerms(candidate);
    final distance = candidateTerms
        .where(_distanceTerms.contains)
        .where((term) => !referenceTerms.contains(term))
        .take(2)
        .toList(growable: false);
    if (distance.isEmpty) return '';

    if (arabic) {
      return '، لكن طابعه ${distance.map(_arabicScentTerm).join(' و')} أكثر';
    }
    return ', but it leans more ${distance.join(' and ')}';
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

  static String _matchLabel(double score, {bool arabic = false}) {
    if (arabic) {
      if (score >= 0.80) return 'الأقرب في الرائحة';
      if (score >= 0.65) return 'تشابه قوي';
      return 'بديل قريب';
    }
    if (score >= 0.80) return 'Closest Match';
    if (score >= 0.65) return 'Strong Match';
    return 'Candidate Match';
  }

  static Set<String> _sharedScentTerms(
    ProductModel referenceProduct,
    ProductModel candidate,
  ) {
    final referenceTerms = _scentTerms(referenceProduct);
    final candidateTerms = _scentTerms(candidate);
    return referenceTerms.intersection(candidateTerms);
  }

  static Set<String> _scentTerms(ProductModel product) {
    return {
          ...product.notes,
          ...product.topNotes,
          ...product.middleNotes,
          ...product.baseNotes,
          product.fragranceFamily,
          ...product.tags,
        }
        .expand((value) => _normalize(value).split(RegExp(r'\s+')))
        .where((term) => term.trim().isNotEmpty)
        .toSet();
  }

  static String _arabicScentTerm(String term) {
    const map = {
      'aromatic': 'أروماتك',
      'fougere': 'فوجير',
      'spicy': 'توابل',
      'pepper': 'فلفل',
      'woody': 'خشبي',
      'cedar': 'خشب الأرز',
      'amber': 'عنبر',
      'citrus': 'حمضيات',
      'bergamot': 'برغموت',
      'lavender': 'لافندر',
      'ambroxan': 'أمبروكسان',
      'fresh': 'فريش',
      'masculine': 'رجالي',
      'musk': 'مسك',
      'vanilla': 'فانيليا',
      'sweet': 'حلو',
      'floral': 'زهري',
      'rose': 'ورد',
      'jasmine': 'ياسمين',
      'fruity': 'فاكهي',
    };
    return map[term] ?? term;
  }

  static String _normalize(String value) {
    return AIChatTextNormalizer.normalizeForParsing(value);
  }
}

class _RankedCandidate {
  final ProductModel product;
  final double score;
  final double scentScore;
  final String reason;

  const _RankedCandidate({
    required this.product,
    required this.score,
    required this.scentScore,
    required this.reason,
  });
}
