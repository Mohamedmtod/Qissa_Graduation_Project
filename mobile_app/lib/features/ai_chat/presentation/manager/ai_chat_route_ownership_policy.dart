import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

enum AIChatRouteOwnershipClass {
  localDeterministic,
  llmSemantic,
  dartGuard,
  copyEngine,
}

enum AIChatSemanticIntent {
  recommendationRefinement,
  noteSearch,
  vibeSearch,
  subjectiveVisibleQuestion,
  externalReference,
  productAvailability,
  businessInfo,
  social,
  clarification,
}

class AIChatRouteOwnershipDecision {
  const AIChatRouteOwnershipDecision({
    required this.ownershipClass,
    this.semanticIntent,
    this.localSkippedReason,
    this.llmRouteReason,
  });

  final AIChatRouteOwnershipClass ownershipClass;
  final AIChatSemanticIntent? semanticIntent;
  final String? localSkippedReason;
  final String? llmRouteReason;

  bool get isSemantic =>
      ownershipClass == AIChatRouteOwnershipClass.llmSemantic;
}

class AIChatRouteOwnershipPolicy {
  const AIChatRouteOwnershipPolicy();

  AIChatRouteOwnershipDecision classify(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.localDeterministic,
        semanticIntent: AIChatSemanticIntent.clarification,
      );
    }

    if (LocalIntentParser.isGreetingOnly(normalized) ||
        _looksLikeSocialTurn(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.social,
        localSkippedReason: 'social_turn_requires_conversation_owner',
        llmRouteReason: 'social_language',
      );
    }

    final availabilityProduct =
        AvailabilityIntentUtils.extractAvailabilityProductQuery(normalized);
    if (LocalIntentParser.containsAny(
          normalized,
          AvailabilityIntentUtils.availabilityKeywords,
        ) &&
        availabilityProduct != null &&
        !AvailabilityIntentUtils.isGenericAvailabilityCandidate(
          availabilityProduct,
        ) &&
        !LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.localDeterministic,
        semanticIntent: AIChatSemanticIntent.productAvailability,
      );
    }

    if (_looksLikeExternalReference(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.externalReference,
        localSkippedReason: 'external_reference_requires_semantic_anchor',
        llmRouteReason: 'external_reference_language',
      );
    }

    if (LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized) ||
        _looksLikeNotePatch(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.noteSearch,
        localSkippedReason: 'note_request_without_product_anchor',
        llmRouteReason: 'note_search_or_refinement',
      );
    }

    if (AvailabilityIntentUtils.looksLikeGenericRecommendationOrPreferenceCommand(
      normalized,
    )) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.recommendationRefinement,
        localSkippedReason: 'generic_recommendation_language',
        llmRouteReason: 'recommendation_command',
      );
    }

    if (_looksSubjectiveVisibleQuestion(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.subjectiveVisibleQuestion,
        localSkippedReason: 'subjective_visible_question',
        llmRouteReason: 'subjective_comparison',
      );
    }

    if (_looksLikeVibeOrRefinement(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.vibeSearch,
        localSkippedReason: 'natural_language_preference_or_refinement',
        llmRouteReason: 'vibe_or_refinement_language',
      );
    }

    return const AIChatRouteOwnershipDecision(
      ownershipClass: AIChatRouteOwnershipClass.localDeterministic,
    );
  }

  bool _looksLikeExternalReference(String normalized) {
    return normalized.contains('something like') ||
        normalized.contains('similar to') ||
        normalized.contains('inspired by') ||
        normalized.contains('alternative to') ||
        normalized.contains('dupe for') ||
        normalized.contains('clone of') ||
        normalized.contains('like dior') ||
        normalized.contains('like sauvage') ||
        normalized.contains('like bleu de chanel') ||
        normalized.contains('like aventus') ||
        normalized.contains('like baccarat rouge');
  }

  bool _looksLikeSocialTurn(String normalized) {
    final compact = normalized.replaceAll(RegExp(r'[^a-z\u0600-\u06ff ]'), ' ');
    return RegExp(
      r'(^|\s)(hello|hi|hey|how are you|thanks|thank you|اهلا|مرحبا|ازيك|عامل ايه)(\s|$)',
    ).hasMatch(compact);
  }

  bool _looksLikeNotePatch(String normalized) {
    final parsed = LocalIntentParser.parse(
      normalized,
      SessionPreferences.empty(),
    );
    if (!parsed.hasAnyNoteSignal) return false;
    return normalized.contains('with ') ||
        normalized.contains('note') ||
        normalized.contains('scent') ||
        normalized.contains('smell') ||
        normalized.contains('ريحة') ||
        normalized.contains('نوتة') ||
        normalized.contains('فيه');
  }

  bool _looksSubjectiveVisibleQuestion(String normalized) {
    return normalized.contains('which one is better') ||
        normalized.contains('which is better') ||
        normalized.contains('better for me') ||
        normalized.contains('suits me') ||
        normalized.contains('أنهي أحسن') ||
        normalized.contains('ايه الأحسن') ||
        normalized.contains('ايه الاحسن');
  }

  bool _looksLikeVibeOrRefinement(String normalized) {
    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return true;
    }
    final parsed = LocalIntentParser.parse(
      normalized,
      SessionPreferences.empty(),
    );
    if (parsed.activeCriteriaCount > 0 ||
        parsed.hasAnyNoteSignal ||
        parsed.tags.isNotEmpty ||
        parsed.intensity != null) {
      return true;
    }
    return normalized.contains('fresh') ||
        normalized.contains('soft') ||
        normalized.contains('elegant') ||
        normalized.contains('classy') ||
        normalized.contains('university') ||
        normalized.contains('office') ||
        normalized.contains('not too strong') ||
        normalized.contains('مش خانقة') ||
        normalized.contains('شيك') ||
        normalized.contains('لطيفة');
  }
}
