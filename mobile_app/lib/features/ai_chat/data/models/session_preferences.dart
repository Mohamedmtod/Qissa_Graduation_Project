import 'package:perfume_app/features/ai_chat/core/ai_normalizer.dart';

enum RankingStrategy { expensiveFirst, cheapestFirst }

/// Represents the user's accumulated preferences during an AI chat session.
///
/// This is the "memory" of the conversation — instead of replaying the full
/// chat history, the app maintains a compact preference snapshot that gets
/// updated after every message.
class SessionPreferences {
  final String? gender;
  final double? maxBudget;
  final String? season;
  final String? occasion;
  final String? time;
  final String? intensity;
  final RankingStrategy? rankingStrategy;

  final List<String> preferredNotes;
  final List<String> preferredTopNotes;
  final List<String> preferredMiddleNotes;
  final List<String> preferredBaseNotes;

  final List<String> excludedNotes;
  final List<String> medicalExcludedNotes;
  final List<String> tags;

  const SessionPreferences({
    this.gender,
    this.maxBudget,
    this.season,
    this.occasion,
    this.time,
    this.intensity,
    this.rankingStrategy,
    this.preferredNotes = const [],
    this.preferredTopNotes = const [],
    this.preferredMiddleNotes = const [],
    this.preferredBaseNotes = const [],
    this.excludedNotes = const [],
    this.medicalExcludedNotes = const [],
    this.tags = const [],
  });

  /// Returns a new [SessionPreferences] with all fields cleared.
  factory SessionPreferences.empty() => const SessionPreferences();

  /// Whether enough criteria are present to attempt a recommendation.
  bool get hasSufficientCriteria {
    return canRecommendInitial;
  }

  bool get hasAnyPreferredNote {
    return preferredNotes.isNotEmpty ||
        preferredTopNotes.isNotEmpty ||
        preferredMiddleNotes.isNotEmpty ||
        preferredBaseNotes.isNotEmpty;
  }

  bool get hasAnyNoteSignal {
    return hasAnyPreferredNote ||
        excludedNotes.isNotEmpty ||
        medicalExcludedNotes.isNotEmpty;
  }

  bool get hasAnyScalarSignal {
    return gender != null ||
        maxBudget != null ||
        season != null ||
        occasion != null ||
        time != null;
  }

  bool get shouldAskBudgetBeforeInitialRecommendation {
    return gender != null &&
        season != null &&
        maxBudget == null &&
        !tags.contains('open_budget') &&
        occasion == null &&
        time == null &&
        intensity == null &&
        tags.isEmpty &&
        !hasAnyNoteSignal;
  }

  /// Base readiness for first recommendation.
  ///
  /// Policy:
  /// - gender + season is enough for an initial recommendation.
  /// - any explicit note signal alone is enough for a note-led recommendation.
  /// - gender + budget is enough for a practical first pass.
  /// - occasion/time/tags + one supporting signal is enough for contextual asks.
  /// - (notes or exclusions or intensity) + any scalar signal is also enough.
  bool get canRecommendInitial {
    if (gender != null && season != null) {
      return true;
    }

    if (hasAnyNoteSignal) {
      return true;
    }

    if (gender != null && maxBudget != null) {
      return true;
    }

    final hasContextSignal =
        occasion != null || time != null || tags.isNotEmpty;
    final hasSupportingSignal =
        gender != null ||
        maxBudget != null ||
        season != null ||
        intensity != null ||
        hasAnyNoteSignal;
    if (hasContextSignal && hasSupportingSignal) {
      return true;
    }

    if (occasion != null && tags.isNotEmpty) {
      return true;
    }

    final hasRefinementSignal = hasAnyNoteSignal || intensity != null;
    if (hasRefinementSignal && hasAnyScalarSignal) {
      return true;
    }

    return false;
  }

  /// Narrow readiness path for practical shopping requests that have enough
  /// concrete context even when gender/season are not both known.
  bool get canRecommendPracticalInitial {
    if (shouldAskBudgetBeforeInitialRecommendation) {
      return false;
    }

    final hasAnchorSignal =
        maxBudget != null || gender != null || hasAnyPreferredNote;
    if (!hasAnchorSignal) {
      return false;
    }

    final hasPracticalContext =
        occasion != null ||
        time != null ||
        tags.isNotEmpty ||
        intensity != null ||
        hasAnyPreferredNote;
    if (!hasPracticalContext) {
      return false;
    }

    return canRecommendInitial;
  }

  /// A recommendation context can be refined as long as we have at least one
  /// explicit user signal to apply as a patch to the existing state.
  bool canRefineExistingRecommendation({
    required bool hasRecommendationContext,
  }) {
    if (!hasRecommendationContext) return false;

    return hasAnyScalarSignal ||
        hasAnyNoteSignal ||
        intensity != null ||
        tags.isNotEmpty;
  }

  /// Returns missing slots in practical asking order.
  ///
  /// If recommendation criteria are already sufficient (or refinement context
  /// exists), this returns an empty list.
  List<String> missingSlotsForNextQuestion({
    bool hasRecommendationContext = false,
  }) {
    if (shouldAskBudgetBeforeInitialRecommendation) {
      return const <String>['maxBudget', 'notesOrIntensity'];
    }

    if (canRecommendInitial ||
        canRecommendPracticalInitial ||
        canRefineExistingRecommendation(
          hasRecommendationContext: hasRecommendationContext,
        )) {
      return const <String>[];
    }

    final missing = <String>[];

    if (gender == null) {
      missing.add('gender');
    }
    if (season == null) {
      missing.add('season');
    }
    if (maxBudget == null) {
      missing.add('maxBudget');
    }
    if (!hasAnyNoteSignal && intensity == null) {
      missing.add('notesOrIntensity');
    }

    return missing;
  }

  /// The number of active (non-null) criteria, used by the match score
  /// calculator to redistribute weights across available criteria only.
  int get activeCriteriaCount {
    int count = 0;
    if (maxBudget != null) count++;
    if (hasAnyPreferredNote) count++;
    if (gender != null) count++;
    if (season != null || occasion != null || time != null) count++;
    if (intensity != null) count++;
    if (tags.isNotEmpty) count++;
    return count;
  }

  // ── Serialization ──────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'gender': gender,
      'maxBudget': maxBudget,
      'season': season,
      'occasion': occasion,
      'time': time,
      'intensity': intensity,
      'rankingStrategy': rankingStrategy?.name,
      'preferredNotes': preferredNotes,
      'preferredTopNotes': preferredTopNotes,
      'preferredMiddleNotes': preferredMiddleNotes,
      'preferredBaseNotes': preferredBaseNotes,
      'excludedNotes': excludedNotes,
      'medicalExcludedNotes': medicalExcludedNotes,
      'tags': tags,
    };
  }

  static double? _asNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized);
    }
    return null;
  }

  factory SessionPreferences.fromJson(Map<String, dynamic> json) {
    return SessionPreferences(
      gender: json['gender'] as String?,
      maxBudget: _asNullableDouble(json['maxBudget']),
      season: json['season'] as String?,
      occasion: json['occasion'] as String?,
      time: json['time'] as String?,
      intensity: json['intensity'] as String?,
      rankingStrategy: _asRankingStrategy(json['rankingStrategy']),
      preferredNotes: List<String>.from(json['preferredNotes'] ?? []),
      preferredTopNotes: List<String>.from(json['preferredTopNotes'] ?? []),
      preferredMiddleNotes: List<String>.from(
        json['preferredMiddleNotes'] ?? [],
      ),
      preferredBaseNotes: List<String>.from(json['preferredBaseNotes'] ?? []),
      excludedNotes: List<String>.from(json['excludedNotes'] ?? []),
      medicalExcludedNotes: List<String>.from(
        json['medicalExcludedNotes'] ?? [],
      ),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  // ── Copy / Merge ───────────────────────────────────────────────

  /// The official **Merge Policy** for session preferences:
  /// 1. **Persistence**: Values returned by the AI are patched onto existing state.
  /// 2. **Null Safety**: `null` values in a patch (from AI or local parser) do **not** clear existing values.
  /// 3. **Array Persistence**: Empty arrays in a patch do **not** clear existing lists.
  /// 4. **Reset Semantics**: Fields are only cleared if explicit reset flags are passed to [copyWith] or [reset] is called.
  /// 5. **Intent Isolation**: Intent-only messages (e.g. pure comparison or follow-up) should not inadvertently alter scalar preferences.

  SessionPreferences copyWith({
    String? gender,
    double? maxBudget,
    String? season,
    String? occasion,
    String? time,
    String? intensity,
    RankingStrategy? rankingStrategy,
    List<String>? preferredNotes,
    List<String>? preferredTopNotes,
    List<String>? preferredMiddleNotes,
    List<String>? preferredBaseNotes,
    List<String>? excludedNotes,
    List<String>? medicalExcludedNotes,
    List<String>? tags,
    // Use these to explicitly clear a nullable field:
    bool clearGender = false,
    bool clearBudget = false,
    bool clearSeason = false,
    bool clearOccasion = false,
    bool clearTime = false,
    bool clearIntensity = false,
    bool clearRankingStrategy = false,
  }) {
    return SessionPreferences(
      gender: clearGender ? null : (gender ?? this.gender),
      maxBudget: clearBudget ? null : (maxBudget ?? this.maxBudget),
      season: clearSeason ? null : (season ?? this.season),
      occasion: clearOccasion ? null : (occasion ?? this.occasion),
      time: clearTime ? null : (time ?? this.time),
      intensity: clearIntensity ? null : (intensity ?? this.intensity),
      rankingStrategy: clearRankingStrategy
          ? null
          : (rankingStrategy ?? this.rankingStrategy),
      preferredNotes: preferredNotes ?? this.preferredNotes,
      preferredTopNotes: preferredTopNotes ?? this.preferredTopNotes,
      preferredMiddleNotes: preferredMiddleNotes ?? this.preferredMiddleNotes,
      preferredBaseNotes: preferredBaseNotes ?? this.preferredBaseNotes,
      excludedNotes: excludedNotes ?? this.excludedNotes,
      medicalExcludedNotes: medicalExcludedNotes ?? this.medicalExcludedNotes,
      tags: tags ?? this.tags,
    ).sanitize();
  }

  /// Merges a partial preference patch onto the current session snapshot.
  ///
  /// The upstream model may return only the fields mentioned in the latest
  /// message. In that case, empty/null fields should not wipe out previously
  /// accumulated preferences.
  /// Merges a partial preference patch onto the current session snapshot.
  ///
  /// Following the **Merge Policy**:
  /// - Scalars only update if [patch] has a non-null value.
  /// - Lists only update if [patch] has a non-empty list.
  /// - Special case: If [patch] has [clearBudget] set (e.g. premium request), the budget is wiped.
  SessionPreferences mergePatch(
    SessionPreferences patch, {
    bool clearBudget = false,
  }) {
    final shouldClearBudget = clearBudget || patch.tags.contains('open_budget');
    return copyWith(
      gender: patch.gender ?? gender,
      maxBudget: (patch.maxBudget ?? maxBudget),
      clearBudget: shouldClearBudget,
      season: patch.season ?? season,
      occasion: patch.occasion ?? occasion,
      time: patch.time ?? time,
      intensity: patch.intensity ?? intensity,
      rankingStrategy: patch.rankingStrategy ?? rankingStrategy,
      preferredNotes: patch.preferredNotes.isNotEmpty
          ? patch.preferredNotes
          : preferredNotes,
      preferredTopNotes: patch.preferredTopNotes.isNotEmpty
          ? patch.preferredTopNotes
          : preferredTopNotes,
      preferredMiddleNotes: patch.preferredMiddleNotes.isNotEmpty
          ? patch.preferredMiddleNotes
          : preferredMiddleNotes,
      preferredBaseNotes: patch.preferredBaseNotes.isNotEmpty
          ? patch.preferredBaseNotes
          : preferredBaseNotes,
      excludedNotes: patch.excludedNotes.isNotEmpty
          ? patch.excludedNotes
          : excludedNotes,
      medicalExcludedNotes: patch.medicalExcludedNotes.isNotEmpty
          ? patch.medicalExcludedNotes
          : medicalExcludedNotes,
      tags: patch.tags.isNotEmpty ? patch.tags : tags,
    );
  }

  // ── Sanitize ───────────────────────────────────────────────────

  /// Returns a cleaned copy that enforces data integrity via AINormalizer:
  /// 1. Normalizes all scalar values mapping them to canonical forms.
  /// 2. Normalizes list values, removing duplicates and removing any note
  ///    that appears in the excluded list from the preferred lists (excluded wins).
  SessionPreferences sanitize() {
    final cleanGender = AINormalizer.normalizeGender(gender);
    final cleanSeason = AINormalizer.normalizeSeason(season);
    final cleanOccasion = AINormalizer.normalizeOccasion(occasion);
    final cleanTime = AINormalizer.normalizeTime(time);
    final cleanIntensity = AINormalizer.normalizeIntensity(intensity);

    final cleanTags = AINormalizer.normalizeTags(tags);
    final cleanMedicalExcluded = AINormalizer.normalizeNotes(
      medicalExcludedNotes,
    );
    final cleanExcluded = {
      ...AINormalizer.normalizeNotes(excludedNotes),
      ...cleanMedicalExcluded,
    }.toList();

    // Remove excluded notes from any preferred list
    final cleanGeneral = AINormalizer.normalizeNotes(
      preferredNotes,
    ).where((n) => !cleanExcluded.contains(n)).toList();

    final cleanTop = AINormalizer.normalizeNotes(
      preferredTopNotes,
    ).where((n) => !cleanExcluded.contains(n)).toList();

    final cleanMiddle = AINormalizer.normalizeNotes(
      preferredMiddleNotes,
    ).where((n) => !cleanExcluded.contains(n)).toList();

    final cleanBase = AINormalizer.normalizeNotes(
      preferredBaseNotes,
    ).where((n) => !cleanExcluded.contains(n)).toList();

    return SessionPreferences(
      gender: cleanGender,
      maxBudget: maxBudget,
      season: cleanSeason,
      occasion: cleanOccasion,
      time: cleanTime,
      intensity: cleanIntensity,
      preferredNotes: cleanGeneral,
      preferredTopNotes: cleanTop,
      preferredMiddleNotes: cleanMiddle,
      preferredBaseNotes: cleanBase,
      excludedNotes: cleanExcluded,
      medicalExcludedNotes: cleanMedicalExcluded,
      tags: cleanTags,
      rankingStrategy: rankingStrategy,
    );
  }

  // ── Reset ──────────────────────────────────────────────────────

  SessionPreferences reset() => SessionPreferences.empty();

  // ── Equality / Debug ───────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionPreferences) return false;
    return gender == other.gender &&
        maxBudget == other.maxBudget &&
        season == other.season &&
        occasion == other.occasion &&
        time == other.time &&
        intensity == other.intensity &&
        rankingStrategy == other.rankingStrategy &&
        _listEquals(preferredNotes, other.preferredNotes) &&
        _listEquals(preferredTopNotes, other.preferredTopNotes) &&
        _listEquals(preferredMiddleNotes, other.preferredMiddleNotes) &&
        _listEquals(preferredBaseNotes, other.preferredBaseNotes) &&
        _listEquals(excludedNotes, other.excludedNotes) &&
        _listEquals(medicalExcludedNotes, other.medicalExcludedNotes) &&
        _listEquals(tags, other.tags);
  }

  @override
  int get hashCode => Object.hash(
    gender,
    maxBudget,
    season,
    occasion,
    time,
    intensity,
    rankingStrategy,
    Object.hashAll(preferredNotes),
    Object.hashAll(preferredTopNotes),
    Object.hashAll(preferredMiddleNotes),
    Object.hashAll(preferredBaseNotes),
    Object.hashAll(excludedNotes),
    Object.hashAll(medicalExcludedNotes),
    Object.hashAll(tags),
  );

  @override
  String toString() {
    return 'SessionPreferences('
        'gender: $gender, maxBudget: $maxBudget, season: $season, '
        'occasion: $occasion, time: $time, intensity: $intensity, rankingStrategy: $rankingStrategy, '
        'notes: $preferredNotes, top: $preferredTopNotes, middle: $preferredMiddleNotes, base: $preferredBaseNotes, '
        'excluded: $excludedNotes, medicalExcluded: $medicalExcludedNotes, tags: $tags)';
  }

  static RankingStrategy? _asRankingStrategy(dynamic value) {
    if (value is RankingStrategy) return value;
    if (value is! String) return null;

    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    switch (normalized) {
      case 'expensivefirst':
      case 'mostexpensive':
      case 'highestprice':
      case 'premium':
      case 'luxury':
        return RankingStrategy.expensiveFirst;
      case 'cheapestfirst':
      case 'cheapest':
      case 'cheap':
      case 'lowerprice':
      case 'lowestprice':
      case 'moreaffordable':
      case 'mostaffordable':
      case 'economy':
      case 'economic':
      case 'economical':
        return RankingStrategy.cheapestFirst;
      case 'relevancefirst':
      case 'relevance':
      case 'default':
        return null;
    }
    return null;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
