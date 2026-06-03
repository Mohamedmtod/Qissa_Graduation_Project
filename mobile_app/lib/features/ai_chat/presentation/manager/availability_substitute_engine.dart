import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_reference_profile_registry.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/scent_profile_scorer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AvailabilitySubstituteSuggestion {
  final ProductModel product;
  final double score;
  final String reason;
  final bool hasMeaningfulOverlap;

  const AvailabilitySubstituteSuggestion({
    required this.product,
    required this.score,
    required this.reason,
    this.hasMeaningfulOverlap = false,
  });
}

class AvailabilitySubstituteEngineResult {
  final List<AvailabilitySubstituteSuggestion> suggestions;
  final bool meetsConfidenceThreshold;
  final double bestScore;

  const AvailabilitySubstituteEngineResult({
    required this.suggestions,
    required this.meetsConfidenceThreshold,
    required this.bestScore,
  });
}

class AvailabilitySubstituteEngine {
  static const double minimumConfidenceThreshold = 0.58;
  static const double minimumExplicitClosestFallbackThreshold = 0.05;

  static AvailabilitySubstituteEngineResult findSubstitutes({
    required AvailabilityContext context,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
  }) {
    final targetNotes = <String>{};
    final targetTags = <String>{};
    final targetTopNotes = <String>{};
    final targetMiddleNotes = <String>{};
    final targetBaseNotes = <String>{};
    String? targetIntensity;
    String? targetGender;
    String? targetSeason;
    String? targetOccasion;

    AvailabilityReferenceProfile? profile;
    if (context.referenceProfileKey != null) {
      for (final item in AvailabilityReferenceProfileRegistry.profiles) {
        if (item.key == context.referenceProfileKey) {
          profile = item;
          break;
        }
      }
    }

    if (profile != null) {
      targetNotes.addAll(profile.preferredNotes.map(_normalize));
      targetNotes.addAll(profile.accords.map(_normalize));
      targetTopNotes.addAll(profile.topNotes.map(_normalize));
      targetMiddleNotes.addAll(profile.middleNotes.map(_normalize));
      targetBaseNotes.addAll(profile.baseNotes.map(_normalize));
      targetTags.addAll(profile.tags.map(_normalize));
      targetTags.addAll(profile.accords.map(_normalize));
      targetIntensity = profile.intensityHint;
      targetGender = profile.genderHint;
      targetSeason = profile.seasonHint;
      targetOccasion = profile.occasionHint;
    }

    targetNotes.addAll(context.hints.preferredNotes.map(_normalize));
    targetTopNotes.addAll(context.hints.preferredTopNotes.map(_normalize));
    targetMiddleNotes.addAll(
      context.hints.preferredMiddleNotes.map(_normalize),
    );
    targetBaseNotes.addAll(context.hints.preferredBaseNotes.map(_normalize));
    targetTags.addAll(context.hints.tags.map(_normalize));
    targetIntensity ??= context.hints.intensity;
    targetGender ??= context.hints.gender;
    targetSeason ??= context.hints.season;
    targetOccasion ??= context.hints.occasion;

    targetNotes.addAll(currentPreferences.preferredNotes.map(_normalize));
    targetTopNotes.addAll(currentPreferences.preferredTopNotes.map(_normalize));
    targetMiddleNotes.addAll(
      currentPreferences.preferredMiddleNotes.map(_normalize),
    );
    targetBaseNotes.addAll(
      currentPreferences.preferredBaseNotes.map(_normalize),
    );
    targetTags.addAll(currentPreferences.tags.map(_normalize));
    targetIntensity ??= currentPreferences.intensity;
    targetGender ??= currentPreferences.gender;
    targetSeason ??= currentPreferences.season;
    targetOccasion ??= currentPreferences.occasion;

    final scored = <AvailabilitySubstituteSuggestion>[];
    for (final product in catalog) {
      if (product.stock <= 0) continue;
      if (context.matchedProductId != null &&
          product.id == context.matchedProductId) {
        continue;
      }

      final productNotes = product.notes.map(_normalize).toSet();
      final productTags = product.tags.map(_normalize).toSet();
      final productTopNotes = product.topNotes.map(_normalize).toSet();
      final productMiddleNotes = product.middleNotes.map(_normalize).toSet();
      final productBaseNotes = product.baseNotes.map(_normalize).toSet();

      final notesScore = _jaccard(targetNotes, productNotes);
      final topScore = _jaccard(targetTopNotes, productTopNotes);
      final middleScore = _jaccard(targetMiddleNotes, productMiddleNotes);
      final baseScore = _jaccard(targetBaseNotes, productBaseNotes);
      final tagsScore = _jaccard(targetTags, productTags);
      final hasMeaningfulOverlap =
          targetNotes.intersection(productNotes).isNotEmpty ||
          targetTopNotes.intersection(productTopNotes).isNotEmpty ||
          targetMiddleNotes.intersection(productMiddleNotes).isNotEmpty ||
          targetBaseNotes.intersection(productBaseNotes).isNotEmpty ||
          targetTags.intersection(productTags).isNotEmpty;
      final intensityScore = _scalarMatch(targetIntensity, product.intensity);
      final genderScore = _genderMatch(targetGender, product.gender);
      final seasonOccasionScore =
          (_scalarMatch(targetSeason, product.season) * 0.5) +
          (_scalarMatch(targetOccasion, product.occasion) * 0.5);

      final syntheticPreferences = SessionPreferences(
        gender: targetGender,
        season: targetSeason,
        occasion: targetOccasion,
        intensity: targetIntensity,
        preferredNotes: targetNotes.toList(),
        preferredTopNotes: targetTopNotes.toList(),
        preferredMiddleNotes: targetMiddleNotes.toList(),
        preferredBaseNotes: targetBaseNotes.toList(),
        tags: targetTags.toList(),
      ).sanitize();
      final scentScore = ScentProfileScorer.scorePreferenceToProduct(
        syntheticPreferences,
        product,
      );

      final total =
          (scentScore * 0.55) +
          (tagsScore * 0.20) +
          (intensityScore * 0.10) +
          (genderScore * 0.10) +
          (seasonOccasionScore * 0.05);

      final reasonParts = <String>[];
      if (notesScore >= 0.4 ||
          topScore >= 0.4 ||
          middleScore >= 0.4 ||
          baseScore >= 0.4) {
        reasonParts.add('notes');
      }
      if (tagsScore >= 0.4) reasonParts.add('style');
      if (scentScore >= 0.58 && !reasonParts.contains('notes')) {
        reasonParts.add('scent profile');
      }
      if (intensityScore >= 1) reasonParts.add('intensity');
      if (genderScore >= 1) reasonParts.add('gender');
      if (seasonOccasionScore >= 0.6) reasonParts.add('season/occasion');
      final reason = reasonParts.isEmpty
          ? 'closest available profile match'
          : 'matches ${reasonParts.take(2).join(' + ')}';

      scored.add(
        AvailabilitySubstituteSuggestion(
          product: product,
          score: total,
          reason: reason,
          hasMeaningfulOverlap: hasMeaningfulOverlap,
        ),
      );
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.product.effectivePrice.compareTo(b.product.effectivePrice);
    });

    final top = scored.take(3).toList(growable: false);
    final bestScore = top.isEmpty ? 0.0 : top.first.score;

    return AvailabilitySubstituteEngineResult(
      suggestions: top,
      meetsConfidenceThreshold: bestScore >= minimumConfidenceThreshold,
      bestScore: bestScore,
    );
  }

  static String _normalize(String value) {
    return AIChatTextNormalizer.normalizeForParsing(value);
  }

  static double _jaccard(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) return 0;
    final intersection = left.intersection(right).length;
    final union = left.union(right).length;
    if (union == 0) return 0;
    return intersection / union;
  }

  static double _scalarMatch(String? target, String candidate) {
    if (target == null || target.trim().isEmpty) return 0.5;
    final t = _normalize(target);
    final c = _normalize(candidate);
    if (t == c) return 1;
    if (t.isEmpty || c.isEmpty) return 0;
    return 0;
  }

  static double _genderMatch(String? target, String candidate) {
    if (target == null || target.trim().isEmpty) return 0.5;
    final t = _normalize(target);
    final c = _normalize(candidate);
    if (c == 'unisex') return 1;
    if (t == c) return 1;
    return 0;
  }
}
