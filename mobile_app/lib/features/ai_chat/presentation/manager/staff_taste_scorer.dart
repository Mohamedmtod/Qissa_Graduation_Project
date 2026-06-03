import 'package:perfume_app/features/ai_chat/core/staff_taste_taxonomy.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class StaffTasteScoreResult {
  final double score;
  final bool isNeutral;
  final List<String> reasonCodes;
  final List<String> bestFor;
  final String? riskLabel;
  final List<String> watchOut;

  const StaffTasteScoreResult({
    required this.score,
    required this.isNeutral,
    this.reasonCodes = const <String>[],
    this.bestFor = const <String>[],
    this.riskLabel,
    this.watchOut = const <String>[],
  });

  static const neutral = StaffTasteScoreResult(score: 0, isNeutral: true);
}

class StaffTasteScorer {
  const StaffTasteScorer();

  StaffTasteScoreResult score({
    required ProductModel product,
    required SessionPreferences preferences,
    Iterable<String> detectedStaffTags = const <String>[],
  }) {
    if (!_isEligible(product)) {
      return StaffTasteScoreResult(
        score: 0,
        isNeutral: true,
        reasonCodes: [
          if (product.reviewNeeded) 'staff_review_needed',
          if (product.staffIntelligenceStatus == 'draft') 'staff_draft',
          if (_isGeneratedSeedData(product)) 'staff_generated_seed_data',
          if (product.staffDataCoverage < 1.0) 'staff_coverage_incomplete',
        ],
        bestFor: _deriveBestFor(product),
        riskLabel: _deriveRiskLabel(product),
        watchOut: _deriveWatchOut(product),
      );
    }

    final requested = _requestedTags(preferences, detectedStaffTags);
    if (requested.isEmpty) {
      return StaffTasteScoreResult(
        score: 0,
        isNeutral: true,
        reasonCodes: const ['staff_no_requested_tags'],
        bestFor: _deriveBestFor(product),
        riskLabel: _deriveRiskLabel(product),
        watchOut: _deriveWatchOut(product),
      );
    }

    var matchedWeight = 0.0;
    var possibleWeight = 0.0;
    final reasons = <String>[];
    for (final tag in requested) {
      possibleWeight += 3;
      final score = product.staffTagScores[tag] ?? 0;
      if (score > 0) {
        matchedWeight += score;
        reasons.add('staff_tag_matched:$tag');
      }
    }

    var normalized = possibleWeight == 0 ? 0.0 : matchedWeight / possibleWeight;
    normalized *= product.staffIntelligenceStatus == 'trusted' ? 1.0 : 0.6;
    normalized *= product.staffConfidence / 3.0;

    for (final warning in product.staffWarnings) {
      if (_warningConflictsWithRequest(warning, requested)) {
        normalized -= 0.12;
        reasons.add('staff_warning_penalty:$warning');
      }
    }

    final clamped = normalized.clamp(0.0, 1.0);
    return StaffTasteScoreResult(
      score: clamped,
      isNeutral: false,
      reasonCodes: reasons,
      bestFor: _deriveBestFor(product),
      riskLabel: _deriveRiskLabel(product),
      watchOut: _deriveWatchOut(product),
    );
  }

  bool _isEligible(ProductModel product) {
    if (product.reviewNeeded) return false;
    if (product.staffIntelligenceStatus == 'draft') return false;
    if (_isGeneratedSeedData(product)) return false;
    if (product.staffDataCoverage < 1.0) return false;
    return product.staffIntelligenceStatus == 'reviewed' ||
        product.staffIntelligenceStatus == 'trusted';
  }

  bool _isGeneratedSeedData(ProductModel product) {
    return product.staffUpdatedBy?.trim() == 'staff_taste_patch_tool';
  }

  Set<String> _requestedTags(
    SessionPreferences preferences,
    Iterable<String> detectedStaffTags,
  ) {
    final requested =
        <String>{
              ...preferences.tags,
              if (preferences.occasion != null) preferences.occasion!,
              ...detectedStaffTags,
            }
            .map((tag) => tag.trim())
            .where(StaffTasteTaxonomy.scoringTagIds.contains)
            .toSet();
    return requested;
  }

  List<String> _deriveBestFor(ProductModel product) {
    final candidates = product.staffTagScores.entries.where((entry) {
      final group = StaffTasteTaxonomy.groupFor(entry.key);
      return entry.value >= 2 &&
          (group == StaffTasteTagGroup.useCase ||
              group == StaffTasteTagGroup.vibe ||
              group == StaffTasteTagGroup.comfort);
    }).toList()..sort((a, b) => b.value.compareTo(a.value));
    return candidates.take(4).map((entry) => entry.key).toList();
  }

  String? _deriveRiskLabel(ProductModel product) {
    if ((product.staffTagScores['safe_blind_buy'] ?? 0) >= 2) {
      return 'safe_blind_buy';
    }
    if ((product.staffTagScores['polarizing'] ?? 0) >= 2) {
      return 'polarizing';
    }
    if ((product.staffTagScores['medium_risk'] ?? 0) >= 2) {
      return 'medium_risk';
    }
    return null;
  }

  List<String> _deriveWatchOut(ProductModel product) {
    return product.staffWarnings.take(3).toList(growable: false);
  }

  bool _warningConflictsWithRequest(String warning, Set<String> requested) {
    if (warning == 'too_sweet_for_some') {
      return requested.contains('safe_blind_buy') ||
          requested.contains('non_offensive') ||
          requested.contains('not_cloying');
    }
    if (warning == 'not_for_hot_weather') {
      return requested.contains('daily') || requested.contains('university');
    }
    if (warning == 'too_loud_for_sensitive_nose') {
      return requested.contains('soft_on_nose') ||
          requested.contains('not_headachey');
    }
    return false;
  }
}
