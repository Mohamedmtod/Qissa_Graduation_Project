import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

enum _FamilyBucket { aromatic, woody, amber, fresh, unknown }

enum _FamilyProximity { close, medium, distant, unknown }

class ScentProfileScorer {
  static const double scentGate = 0.40;

  // Scent score internal weights (sum = 1.0).
  static const double _generalNotesWeight = 0.25;
  static const double _topNotesWeight = 0.10;
  static const double _middleNotesWeight = 0.20;
  static const double _baseNotesWeight = 0.20;
  static const double _familyWeight = 0.15;
  static const double _tagsWeight = 0.07;
  static const double _intensityWeight = 0.03;

  static const Set<String> _scentSignalTags = {
    'fresh',
    'clean',
    'aquatic',
    'citrus',
    'aromatic',
    'spicy',
    'woody',
    'amber',
    'sweet',
    'gourmand',
    'floral',
    'musk',
    'powdery',
    'leather',
    'oud',
    'vanilla',
    'fruity',
    'pepper',
    'ambroxan',
    'smoky',
    'herbal',
    'green',
    'earthy',
  };

  static bool hasStrongPreferenceSignal(SessionPreferences preferences) {
    final hasPreferredNotes =
        preferences.preferredNotes.isNotEmpty ||
        preferences.preferredTopNotes.isNotEmpty ||
        preferences.preferredMiddleNotes.isNotEmpty ||
        preferences.preferredBaseNotes.isNotEmpty;
    if (hasPreferredNotes) return true;

    final familyHints = _extractPreferenceFamilyHints(preferences);
    if (familyHints.isNotEmpty) return true;

    final scentSignalTags = _extractScentSignalTags(preferences.tags);
    if (scentSignalTags.length >= 2) return true;

    // Intensity alone is not enough to claim a scent profile signal.
    if (preferences.intensity != null &&
        (hasPreferredNotes ||
            scentSignalTags.length >= 2 ||
            familyHints.isNotEmpty)) {
      return true;
    }

    return false;
  }

  static double scoreProductToProduct(
    ProductModel reference,
    ProductModel candidate,
  ) {
    final components = <_WeightedComponent>[
      _weightedComponent(
        weight: _generalNotesWeight,
        isActive: reference.notes.isNotEmpty,
        score: _setOverlapScore(reference.notes, candidate.notes),
      ),
      _weightedComponent(
        weight: _topNotesWeight,
        isActive: reference.topNotes.isNotEmpty,
        score: _setOverlapScore(reference.topNotes, candidate.topNotes),
      ),
      _weightedComponent(
        weight: _middleNotesWeight,
        isActive: reference.middleNotes.isNotEmpty,
        score: _setOverlapScore(reference.middleNotes, candidate.middleNotes),
      ),
      _weightedComponent(
        weight: _baseNotesWeight,
        isActive: reference.baseNotes.isNotEmpty,
        score: _setOverlapScore(reference.baseNotes, candidate.baseNotes),
      ),
      _weightedComponent(
        weight: _familyWeight,
        isActive: _normalize(reference.fragranceFamily).isNotEmpty,
        score: _familyProximityScore(
          reference.fragranceFamily,
          candidate.fragranceFamily,
        ),
      ),
      _weightedComponent(
        weight: _tagsWeight,
        isActive: reference.tags.isNotEmpty,
        score: _setOverlapScore(reference.tags, candidate.tags),
      ),
      _weightedComponent(
        weight: _intensityWeight,
        isActive: _normalize(reference.intensity).isNotEmpty,
        score: _intensitySimilarityScore(
          reference.intensity,
          candidate.intensity,
        ),
      ),
    ];

    return _normalizedWeightedScore(components);
  }

  static double _preferenceToProductConflictPenalty(
    SessionPreferences preferences,
    ProductModel candidate,
  ) {
    final requestedAnchors = _preferenceScentAnchors(preferences);
    if (requestedAnchors.isEmpty) return 0.0;

    final candidateAnchors = _productScentAnchors(candidate);
    final requestsFresh =
        requestedAnchors.contains('fresh') ||
        requestedAnchors.contains('clean') ||
        requestedAnchors.contains('citrus') ||
        requestedAnchors.contains('aquatic');
    if (!requestsFresh) return 0.0;

    var penalty = 0.0;
    final heavySweetConflict =
        candidateAnchors.contains('gourmand') ||
        candidateAnchors.contains('sweet') ||
        candidateAnchors.contains('vanilla') ||
        candidateAnchors.contains('honey') ||
        candidateAnchors.contains('tobacco') ||
        candidateAnchors.contains('leather');
    final floralSweetConflict =
        candidateAnchors.contains('floral') &&
        (candidateAnchors.contains('sweet') ||
            candidateAnchors.contains('vanilla') ||
            candidateAnchors.contains('fruity'));

    if (heavySweetConflict) penalty += 0.18;
    if (floralSweetConflict) penalty += 0.10;

    final signatureRequests = requestedAnchors.intersection(const {
      'ambroxan',
      'pepper',
    });
    if (signatureRequests.isNotEmpty &&
        !signatureRequests.any(candidateAnchors.contains)) {
      penalty += 0.14;
    }

    if (preferences.intensity == 'strong' &&
        _normalize(candidate.intensity) == 'medium' &&
        heavySweetConflict) {
      penalty += 0.06;
    }

    return penalty.clamp(0.0, 0.35);
  }

  static double scorePreferenceToProduct(
    SessionPreferences preferences,
    ProductModel candidate,
  ) {
    final familyHints = _extractPreferenceFamilyHints(preferences);
    final scentTags = _extractScentSignalTags(preferences.tags);
    final candidateAllNotes = <String>[
      ...candidate.notes,
      ...candidate.topNotes,
      ...candidate.middleNotes,
      ...candidate.baseNotes,
      ...candidate.tags,
    ];

    final components = <_WeightedComponent>[
      _weightedComponent(
        weight: _generalNotesWeight,
        isActive: preferences.preferredNotes.isNotEmpty,
        score: _preferenceCoverageScore(
          preferences.preferredNotes,
          candidateAllNotes,
        ),
      ),
      _weightedComponent(
        weight: _topNotesWeight,
        isActive: preferences.preferredTopNotes.isNotEmpty,
        score: _preferenceCoverageScore(
          preferences.preferredTopNotes,
          candidate.topNotes,
        ),
      ),
      _weightedComponent(
        weight: _middleNotesWeight,
        isActive: preferences.preferredMiddleNotes.isNotEmpty,
        score: _preferenceCoverageScore(
          preferences.preferredMiddleNotes,
          candidate.middleNotes,
        ),
      ),
      _weightedComponent(
        weight: _baseNotesWeight,
        isActive: preferences.preferredBaseNotes.isNotEmpty,
        score: _preferenceCoverageScore(
          preferences.preferredBaseNotes,
          candidate.baseNotes,
        ),
      ),
      _weightedComponent(
        weight: _familyWeight,
        isActive: familyHints.isNotEmpty,
        score: _familyHintScore(familyHints, candidate.fragranceFamily),
      ),
      _weightedComponent(
        weight: _tagsWeight,
        isActive: scentTags.isNotEmpty,
        score: _preferenceCoverageScore(
          scentTags.toList(growable: false),
          candidate.tags,
        ),
      ),
      _weightedComponent(
        weight: _intensityWeight,
        isActive:
            preferences.intensity != null &&
            (preferences.preferredNotes.isNotEmpty ||
                preferences.preferredTopNotes.isNotEmpty ||
                preferences.preferredMiddleNotes.isNotEmpty ||
                preferences.preferredBaseNotes.isNotEmpty ||
                scentTags.isNotEmpty ||
                familyHints.isNotEmpty),
        score: _intensitySimilarityScore(
          preferences.intensity ?? '',
          candidate.intensity,
        ),
      ),
    ];

    final baseScore = _normalizedWeightedScore(components);
    final adjustedScore =
        baseScore - _preferenceToProductConflictPenalty(preferences, candidate);
    return adjustedScore.clamp(0.0, 1.0);
  }

  static double _normalizedWeightedScore(List<_WeightedComponent> components) {
    var totalWeightedScore = 0.0;
    var activeWeight = 0.0;
    for (final component in components) {
      if (!component.isActive) continue;
      activeWeight += component.weight;
      totalWeightedScore += component.weight * component.score;
    }

    if (activeWeight <= 0) {
      return 0.5;
    }
    return (totalWeightedScore / activeWeight).clamp(0.0, 1.0);
  }

  static _WeightedComponent _weightedComponent({
    required double weight,
    required bool isActive,
    required double score,
  }) {
    return _WeightedComponent(
      weight: weight,
      isActive: isActive,
      score: score.clamp(0.0, 1.0),
    );
  }

  static Set<String> _extractScentSignalTags(List<String> tags) {
    final normalized = tags.map(_normalize).where((item) => item.isNotEmpty);
    return normalized.where((tag) => _scentSignalTags.contains(tag)).toSet();
  }

  static Set<_FamilyBucket> _extractPreferenceFamilyHints(
    SessionPreferences preferences,
  ) {
    final inputs = <String>[
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
      ...preferences.tags,
    ];

    final buckets = <_FamilyBucket>{};
    for (final value in inputs) {
      final bucket = _familyBucket(value);
      if (bucket != _FamilyBucket.unknown) {
        buckets.add(bucket);
      }
    }
    return buckets;
  }

  static double _familyHintScore(
    Set<_FamilyBucket> targetBuckets,
    String candidateFamily,
  ) {
    if (targetBuckets.isEmpty) return 0.45;
    final candidateBucket = _familyBucket(candidateFamily);
    if (candidateBucket == _FamilyBucket.unknown) return 0.45;
    if (targetBuckets.contains(candidateBucket)) return 1.0;

    var mediumMatch = false;
    for (final target in targetBuckets) {
      final proximity = _familyBucketProximity(target, candidateBucket);
      if (proximity == _FamilyProximity.medium) {
        mediumMatch = true;
      } else if (proximity == _FamilyProximity.close) {
        return 1.0;
      }
    }
    if (mediumMatch) return 0.60;
    return 0.20;
  }

  static double _setOverlapScore(List<String> left, List<String> right) {
    final a = left.map(_normalize).where((item) => item.isNotEmpty).toSet();
    final b = right.map(_normalize).where((item) => item.isNotEmpty).toSet();
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  static double _preferenceCoverageScore(
    List<String> preferences,
    List<String> candidate,
  ) {
    final requested = preferences
        .map(_normalize)
        .where((item) => item.isNotEmpty)
        .toSet();
    if (requested.isEmpty) return 0.0;

    final offered = candidate.map(_normalize).where((item) => item.isNotEmpty);
    final offeredAnchors = <String>{};
    for (final item in offered) {
      offeredAnchors.add(item);
      offeredAnchors.addAll(_expandedEquivalentAnchors(item));
    }

    final matched = requested.where((item) {
      if (offeredAnchors.contains(item)) return true;
      final expandedRequest = _expandedEquivalentAnchors(item);
      return expandedRequest.any(offeredAnchors.contains);
    }).length;

    return (matched / requested.length).clamp(0.0, 1.0);
  }

  static Set<String> _expandedEquivalentAnchors(String value) {
    final normalized = _normalize(value);
    final anchors = <String>{};
    if (normalized.isEmpty) return anchors;
    if (normalized.contains('cedar') || normalized.contains('wood')) {
      anchors.addAll(const {'cedar', 'woody'});
    }
    if (normalized.contains('smok') || normalized.contains('tobacco')) {
      anchors.addAll(const {'smoky', 'tobacco', 'woody'});
    }
    if (normalized.contains('amber')) {
      anchors.addAll(const {'amber', 'warm'});
    }
    if (normalized.contains('ambrox')) {
      anchors.addAll(const {'ambroxan', 'amber', 'woody'});
    }
    if (normalized.contains('pepper') || normalized.contains('فلفل')) {
      anchors.addAll(const {'pepper', 'spicy'});
    }
    if (normalized.contains('musk')) {
      anchors.add('musk');
    }
    if (normalized.contains('aromatic')) {
      anchors.addAll(const {'aromatic', 'fresh'});
    }
    if (normalized.contains('vanilla')) {
      anchors.addAll(const {'vanilla', 'sweet', 'gourmand'});
    }
    if (normalized.contains('honey')) {
      anchors.addAll(const {'honey', 'sweet', 'gourmand'});
    }
    if (normalized.contains('floral') ||
        normalized.contains('rose') ||
        normalized.contains('jasmine')) {
      anchors.add('floral');
    }
    if (normalized.contains('fresh') ||
        normalized.contains('citrus') ||
        normalized.contains('bergamot') ||
        normalized.contains('lemon') ||
        normalized.contains('orange')) {
      anchors.addAll(const {'fresh', 'citrus'});
    }
    if (normalized.contains('gourmand')) {
      anchors.addAll(const {'gourmand', 'sweet'});
    }
    if (normalized.contains('leather')) {
      anchors.add('leather');
    }
    return anchors;
  }

  static Set<String> _preferenceScentAnchors(SessionPreferences preferences) {
    return _expandScentAnchors([
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
      ...preferences.tags,
      preferences.intensity ?? '',
    ]);
  }

  static Set<String> _productScentAnchors(ProductModel product) {
    return _expandScentAnchors([
      product.fragranceFamily,
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.tags,
    ]);
  }

  static Set<String> _expandScentAnchors(Iterable<String> values) {
    final anchors = <String>{};
    for (final raw in values) {
      final normalized = _normalize(raw);
      if (normalized.isEmpty) continue;
      anchors.add(normalized);
      anchors.addAll(_expandedEquivalentAnchors(normalized));
    }
    return anchors;
  }

  static double _familyProximityScore(
    String referenceFamily,
    String candidateFamily,
  ) {
    final proximity = _familyProximity(referenceFamily, candidateFamily);
    switch (proximity) {
      case _FamilyProximity.close:
        return 1.0;
      case _FamilyProximity.medium:
        return 0.60;
      case _FamilyProximity.distant:
        return 0.20;
      case _FamilyProximity.unknown:
        return 0.45;
    }
  }

  static _FamilyProximity _familyProximity(
    String referenceFamily,
    String candidateFamily,
  ) {
    final left = _familyBucket(referenceFamily);
    final right = _familyBucket(candidateFamily);
    return _familyBucketProximity(left, right);
  }

  static _FamilyProximity _familyBucketProximity(
    _FamilyBucket left,
    _FamilyBucket right,
  ) {
    if (left == _FamilyBucket.unknown || right == _FamilyBucket.unknown) {
      return _FamilyProximity.unknown;
    }
    if (left == right) return _FamilyProximity.close;

    final isMedium =
        (left == _FamilyBucket.aromatic && right == _FamilyBucket.woody) ||
        (left == _FamilyBucket.woody && right == _FamilyBucket.aromatic) ||
        (left == _FamilyBucket.aromatic && right == _FamilyBucket.fresh) ||
        (left == _FamilyBucket.fresh && right == _FamilyBucket.aromatic) ||
        (left == _FamilyBucket.woody && right == _FamilyBucket.fresh) ||
        (left == _FamilyBucket.fresh && right == _FamilyBucket.woody) ||
        (left == _FamilyBucket.woody && right == _FamilyBucket.amber) ||
        (left == _FamilyBucket.amber && right == _FamilyBucket.woody);

    if (isMedium) {
      return _FamilyProximity.medium;
    }
    return _FamilyProximity.distant;
  }

  static _FamilyBucket _familyBucket(String family) {
    final value = _normalize(family);
    if (value.isEmpty) return _FamilyBucket.unknown;

    final hasAromatic = value.contains('aromatic') || value.contains('fougere');
    final hasWoody =
        value.contains('woody') ||
        value.contains('wood') ||
        value.contains('cedar') ||
        value.contains('smok') ||
        value.contains('tobacco');
    final hasAmber =
        value.contains('amber') ||
        value.contains('oriental') ||
        value.contains('gourmand');
    final hasFresh =
        value.contains('fresh') ||
        value.contains('citrus') ||
        value.contains('aquatic');

    if (hasAromatic) return _FamilyBucket.aromatic;
    if (hasWoody) return _FamilyBucket.woody;
    if (hasAmber) return _FamilyBucket.amber;
    if (hasFresh) return _FamilyBucket.fresh;
    return _FamilyBucket.unknown;
  }

  static double _intensitySimilarityScore(
    String referenceIntensity,
    String candidateIntensity,
  ) {
    final left = _normalize(referenceIntensity);
    final right = _normalize(candidateIntensity);
    if (left.isEmpty || right.isEmpty) return 0.4;
    if (left == right) return 1.0;
    if ((left == 'medium' && (right == 'light' || right == 'strong')) ||
        (right == 'medium' && (left == 'light' || left == 'strong'))) {
      return 0.5;
    }
    return 0.1;
  }

  static String _normalize(String value) {
    return AIChatTextNormalizer.normalizeForParsing(value);
  }
}

class _WeightedComponent {
  final double weight;
  final bool isActive;
  final double score;

  const _WeightedComponent({
    required this.weight,
    required this.isActive,
    required this.score,
  });
}
