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
  catalogRanking,
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

    if (_looksLikeExternalReference(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.externalReference,
        localSkippedReason: 'external_reference_requires_semantic_anchor',
        llmRouteReason: 'external_reference_language',
      );
    }

    if (_looksLikeTrendPerfumeRequest(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.recommendationRefinement,
        localSkippedReason: 'trend_perfume_request_requires_recommendation',
        llmRouteReason: 'trend_recommendation_language',
      );
    }

    if (_looksLikeSoftNoteGapPerfumeRequest(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.noteSearch,
        localSkippedReason: 'soft_note_gap_request_requires_catalog_caveat',
        llmRouteReason: 'note_gap_recommendation_language',
      );
    }

    if (_looksLikeHotelOrAestheticPerfumeRequest(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.vibeSearch,
        localSkippedReason: 'vibe_request_requires_recommendation',
        llmRouteReason: 'vibe_recommendation_language',
      );
    }

    if (_looksLikeOccasionRecommendation(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.recommendationRefinement,
        localSkippedReason: 'occasion_request_requires_recommendation',
        llmRouteReason: 'occasion_recommendation_language',
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
        !_looksLikeBusinessInfo(normalized) &&
        !_looksLikeCatalogRanking(normalized) &&
        !_looksLikeKnownNotePreference(normalized) &&
        !_looksLikeNotePatch(normalized) &&
        !LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.localDeterministic,
        semanticIntent: AIChatSemanticIntent.productAvailability,
      );
    }

    if (_looksLikeBusinessInfo(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.localDeterministic,
        semanticIntent: AIChatSemanticIntent.businessInfo,
      );
    }

    if (_looksLikeSurprisePerfumeRequest(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.llmSemantic,
        semanticIntent: AIChatSemanticIntent.recommendationRefinement,
        localSkippedReason: 'surprise_perfume_request_requires_recommendation',
        llmRouteReason: 'surprise_recommendation_language',
      );
    }

    if (_looksLikeCatalogRanking(normalized)) {
      return const AIChatRouteOwnershipDecision(
        ownershipClass: AIChatRouteOwnershipClass.localDeterministic,
        semanticIntent: AIChatSemanticIntent.catalogRanking,
      );
    }

    if (LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized) ||
        _looksLikeKnownNotePreference(normalized) ||
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
    if (normalized.contains('\u0632\u064a \u0645\u062d\u0644') ||
        normalized.contains(
          '\u0632\u064a \u0631\u064a\u062d\u0629 \u0645\u062d\u0644',
        ) ||
        normalized.contains(
          '\u0632\u064a \u0631\u064a\u062d\u0629 \u0627\u0644\u0645\u062d\u0644',
        ) ||
        normalized.contains(
          '\u0632\u064a \u0631\u064a\u062d\u0629 \u0627\u0644\u0645\u062d\u0644\u0627\u062a',
        ) ||
        normalized.contains(
          '\u0632\u064a \u0631\u064a\u062d\u0647 \u0645\u062d\u0644',
        ) ||
        normalized.contains(
          '\u0632\u064a \u0631\u064a\u062d\u0647 \u0627\u0644\u0645\u062d\u0644',
        ) ||
        normalized.contains(
          '\u0632\u064a \u0631\u064a\u062d\u0647 \u0627\u0644\u0645\u062d\u0644\u0627\u062a',
        ) ||
        normalized.contains(
          '\u0634\u0628\u0647 \u0631\u064a\u062d\u0629 \u0645\u062d\u0644',
        ) ||
        normalized.contains(
          '\u0634\u0628\u0647 \u0631\u064a\u062d\u0629 \u0627\u0644\u0645\u062d\u0644',
        ) ||
        normalized.contains(
          '\u0634\u0628\u0647 \u0631\u064a\u062d\u0629 \u0627\u0644\u0645\u062d\u0644\u0627\u062a',
        ) ||
        normalized.contains(
          '\u0634\u0628\u0647 \u0631\u064a\u062d\u0647 \u0645\u062d\u0644',
        ) ||
        normalized.contains(
          '\u0634\u0628\u0647 \u0631\u064a\u062d\u0647 \u0627\u0644\u0645\u062d\u0644',
        ) ||
        normalized.contains(
          '\u0634\u0628\u0647 \u0631\u064a\u062d\u0647 \u0627\u0644\u0645\u062d\u0644\u0627\u062a',
        )) {
      return false;
    }
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
        normalized.contains('like baccarat rouge') ||
        normalized.contains('\u0634\u0628\u0647 ') ||
        normalized.contains('\u0632\u064a ') ||
        normalized.contains('\u0646\u0641\u0633 ');
  }

  bool _looksLikeBusinessInfo(String normalized) {
    return normalized.contains('payment') ||
        normalized.contains('pay online') ||
        normalized.contains('cash on delivery') ||
        normalized.contains('delivery') ||
        normalized.contains('shipping') ||
        normalized.contains('authentic') ||
        normalized.contains('original') ||
        normalized.contains('genuine') ||
        normalized.contains('return policy') ||
        normalized.contains('\u0627\u0644\u062f\u0641\u0639') ||
        normalized.contains('\u0627\u062f\u0641\u0639') ||
        normalized.contains('\u0623\u0648\u0646\u0644\u0627\u064a\u0646') ||
        normalized.contains('\u0627\u0648\u0646\u0644\u0627\u064a\u0646') ||
        normalized.contains(
          '\u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645',
        ) ||
        normalized.contains('\u0627\u0644\u062a\u0648\u0635\u064a\u0644') ||
        normalized.contains('\u0627\u0644\u0634\u062d\u0646') ||
        normalized.contains('\u0623\u0635\u0644\u064a') ||
        normalized.contains('\u0627\u0635\u0644\u064a') ||
        normalized.contains('\u0623\u0635\u0644\u064a\u0629') ||
        normalized.contains('\u0627\u0635\u0644\u064a\u0629') ||
        normalized.contains('\u0623\u0635\u0644\u064a\u064a\u0646') ||
        normalized.contains('\u0627\u0635\u0644\u064a\u064a\u0646') ||
        normalized.contains(
          '\u0627\u0644\u0627\u0633\u062a\u0631\u062c\u0627\u0639',
        );
  }

  bool _looksLikeCatalogRanking(String normalized) {
    return LocalIntentParser.looksLikeRankingRequest(normalized) ||
        normalized.contains('best seller') ||
        normalized.contains('best-selling') ||
        normalized.contains('most selling') ||
        normalized.contains('most popular') ||
        normalized.contains('longest lasting') ||
        normalized.contains('best longevity') ||
        normalized.contains('strongest projection') ||
        normalized.contains(
          '\u0623\u0643\u062a\u0631 \u0639\u0637\u0631 \u062b\u0627\u0628\u062a',
        ) ||
        normalized.contains(
          '\u0627\u0643\u062a\u0631 \u0639\u0637\u0631 \u062b\u0627\u0628\u062a',
        ) ||
        normalized.contains(
          '\u0623\u0643\u062b\u0631 \u0627\u0644\u0639\u0637\u0648\u0631 \u0645\u0628\u064a\u0639',
        ) ||
        normalized.contains(
          '\u0627\u0643\u062b\u0631 \u0627\u0644\u0639\u0637\u0648\u0631 \u0645\u0628\u064a\u0639',
        ) ||
        normalized.contains(
          '\u0623\u0643\u062b\u0631 \u0645\u0628\u064a\u0639',
        ) ||
        normalized.contains(
          '\u0627\u0643\u062b\u0631 \u0645\u0628\u064a\u0639',
        ) ||
        normalized.contains('\u0645\u0628\u064a\u0639') ||
        normalized.contains('\u0627\u0644\u062b\u0628\u0627\u062a') ||
        normalized.contains('\u062b\u0627\u0628\u062a') ||
        normalized.contains('\u0623\u062b\u0628\u062a') ||
        normalized.contains('\u0627\u062b\u0628\u062a') ||
        normalized.contains('\u0627\u0644\u0641\u0648\u062d\u0627\u0646');
  }

  bool _looksLikeSurprisePerfumeRequest(String normalized) {
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    if (!hasPerfumeProof) return false;
    return normalized.contains('surprise me') ||
        normalized.contains('\u0641\u0627\u062c') ||
        normalized.contains('\u0641\u0627\u062c\u0626\u0646\u064a') ||
        normalized.contains('\u0641\u0627\u062c\u064a\u0646\u064a');
  }

  bool _looksLikeTrendPerfumeRequest(String normalized) {
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    if (!hasPerfumeProof) return false;
    return normalized.contains('tiktok') ||
        normalized.contains('tik tok') ||
        normalized.contains('viral') ||
        normalized.contains('trend') ||
        normalized.contains('trending') ||
        normalized.contains('popular') ||
        normalized.contains('\u062a\u064a\u0643 \u062a\u0648\u0643') ||
        normalized.contains('\u062a\u064a\u0643\u062a\u0648\u0643') ||
        normalized.contains('\u062a\u0631\u064a\u0646\u062f') ||
        normalized.contains('\u0645\u0634\u0647\u0648\u0631');
  }

  bool _looksLikeSoftNoteGapPerfumeRequest(String normalized) {
    final hasPerfumeOrScentPreference =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631') ||
        normalized.contains('\u0628\u062d\u0628 \u0631\u064a\u062d\u0629') ||
        normalized.contains('\u0628\u062d\u0628 \u0631\u064a\u062d\u0647') ||
        normalized.contains('love the smell') ||
        normalized.contains('like the smell');
    if (!hasPerfumeOrScentPreference) return false;
    final hasScentPhrase =
        normalized.contains('scent') ||
        normalized.contains('smell') ||
        normalized.contains('note') ||
        normalized.contains('with ') ||
        normalized.contains('\u0631\u064a\u062d\u0629') ||
        normalized.contains('\u0631\u064a\u062d\u0647') ||
        normalized.contains('\u0631\u064a\u062d\u062a\u0647') ||
        normalized.contains('\u0641\u064a\u0647') ||
        normalized.contains('\u0646\u0648\u062a\u0629');
    if (!hasScentPhrase) return false;
    return normalized.contains('coffee') ||
        normalized.contains('tea') ||
        normalized.contains('coconut') ||
        normalized.contains('tobacco') ||
        normalized.contains('soapy') ||
        normalized.contains('soap') ||
        normalized.contains('\u0642\u0647\u0648\u0629') ||
        normalized.contains('\u0642\u0647\u0648\u0647') ||
        normalized.contains('\u0634\u0627\u064a') ||
        normalized.contains(
          '\u062c\u0648\u0632 \u0627\u0644\u0647\u0646\u062f',
        ) ||
        normalized.contains('\u062a\u0628\u063a') ||
        normalized.contains('\u0635\u0627\u0628\u0648\u0646') ||
        normalized.contains('\u0635\u0627\u0628\u0648\u0646\u0629');
  }

  bool _looksLikeHotelOrAestheticPerfumeRequest(String normalized) {
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    if (!hasPerfumeProof) return false;
    final hotelClean =
        (normalized.contains('hotel') ||
            normalized.contains('lobby') ||
            normalized.contains('\u0641\u0646\u062f\u0642') ||
            normalized.contains('\u0644\u0648\u0628\u064a')) &&
        (normalized.contains('clean') ||
            normalized.contains('fresh') ||
            normalized.contains('\u0646\u0638\u064a\u0641') ||
            normalized.contains('\u0646\u0636\u064a\u0641') ||
            normalized.contains('\u0645\u0646\u0639\u0634'));
    final aesthetic =
        normalized.contains('aesthetic') ||
        normalized.contains('creator') ||
        normalized.contains('content') ||
        normalized.contains('bottle') ||
        normalized.contains('\u0634\u0643\u0644\u0647') ||
        normalized.contains('\u0628\u0648\u062a\u0644') ||
        normalized.contains(
          '\u0635\u0627\u0646\u0639 \u0645\u062d\u062a\u0648\u0649',
        );
    final luxuryStore =
        normalized.contains('luxury store') ||
        normalized.contains('brand store') ||
        normalized.contains('designer store') ||
        normalized.contains(
          '\u0645\u062d\u0644 \u0628\u0631\u0627\u0646\u062f',
        ) ||
        normalized.contains(
          '\u0645\u062d\u0644 \u0628\u0631\u0627\u0646\u062f\u0627\u062a',
        ) ||
        normalized.contains(
          '\u0627\u0644\u0645\u062d\u0644\u0627\u062a \u0627\u0644\u0641\u062e\u0645\u0629',
        ) ||
        normalized.contains(
          '\u0627\u0644\u0645\u062d\u0644\u0627\u062a \u0627\u0644\u0641\u062e\u0645\u0647',
        ) ||
        normalized.contains(
          '\u0628\u0631\u0627\u0646\u062f\u0627\u062a \u0641\u062e\u0645\u0629',
        ) ||
        normalized.contains(
          '\u0628\u0631\u0627\u0646\u062f\u0627\u062a \u0641\u062e\u0645\u0647',
        );
    return hotelClean || aesthetic || luxuryStore;
  }

  bool _looksLikeOccasionRecommendation(String normalized) {
    final hasScentOrPerfumeRequest =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('scent') ||
        normalized.contains('smell') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631') ||
        normalized.contains('\u0631\u064a\u062d\u0629') ||
        normalized.contains('\u0631\u064a\u062d\u0647');
    final hasContextualUseCue =
        normalized.contains(
          '\u0623\u0633\u062a\u062e\u062f\u0645 \u0625\u064a\u0647',
        ) ||
        normalized.contains(
          '\u0627\u0633\u062a\u062e\u062f\u0645 \u0627\u064a\u0647',
        ) ||
        normalized.contains(
          '\u0623\u0633\u062a\u062e\u062f\u0645 \u0627\u064a\u0647',
        ) ||
        normalized.contains(
          '\u0645\u062d\u062a\u0627\u062c \u0639\u0637\u0631 \u0645\u0646\u0627\u0633\u0628',
        ) ||
        normalized.contains(
          '\u0623\u062e\u062a\u0627\u0631 \u0625\u064a\u0647',
        ) ||
        normalized.contains(
          '\u0627\u062e\u062a\u0627\u0631 \u0627\u064a\u0647',
        );
    if (!hasScentOrPerfumeRequest && !hasContextualUseCue) return false;
    return normalized.contains('interview') ||
        normalized.contains('meeting') ||
        normalized.contains('first day') ||
        normalized.contains('new job') ||
        normalized.contains('office') ||
        normalized.contains('client') ||
        normalized.contains('customer') ||
        normalized.contains('\u0627\u0646\u062a\u0631\u0641\u064a\u0648') ||
        normalized.contains('\u0645\u0642\u0627\u0628\u0644\u0629') ||
        normalized.contains('\u0639\u0645\u0644\u0627\u0621') ||
        normalized.contains('\u0627\u062c\u062a\u0645\u0627\u0639') ||
        normalized.contains(
          '\u0645\u0643\u0627\u0646 \u0645\u0641\u062a\u0648\u062d',
        ) ||
        normalized.contains(
          '\u0642\u0627\u0639\u0629 \u0645\u063a\u0644\u0642\u0629',
        ) ||
        normalized.contains(
          '\u0642\u0627\u0639\u0647 \u0645\u063a\u0644\u0642\u0647',
        ) ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628\u0629') ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628\u0647') ||
        normalized.contains('\u0634\u063a\u0644 \u062c\u062f\u064a\u062f') ||
        normalized.contains('\u0623\u0648\u0644 \u064a\u0648\u0645') ||
        normalized.contains('\u0627\u0648\u0644 \u064a\u0648\u0645');
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

  bool _looksLikeKnownNotePreference(String normalized) {
    final hasPreferenceCue =
        normalized.contains('love ') ||
        normalized.contains('like ') ||
        normalized.contains('prefer ') ||
        normalized.contains('with ') ||
        normalized.contains('\u0628\u062d\u0628') ||
        normalized.contains('\u062d\u0628') ||
        normalized.contains('\u0639\u0627\u064a\u0632') ||
        normalized.contains('\u0639\u0627\u0648\u0632') ||
        normalized.contains('\u0641\u064a\u0647') ||
        normalized.contains('\u0645\u0639');
    if (!hasPreferenceCue) return false;
    return normalized.contains('vanilla') ||
        normalized.contains('oud') ||
        normalized.contains('musk') ||
        normalized.contains('rose') ||
        normalized.contains('amber') ||
        normalized.contains('\u0641\u0627\u0646\u064a\u0644\u064a\u0627') ||
        normalized.contains('\u0639\u0648\u062f') ||
        normalized.contains('\u0645\u0633\u0643') ||
        normalized.contains('\u0648\u0631\u062f') ||
        normalized.contains('\u0639\u0646\u0628\u0631');
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
    if (normalized.contains('\u0644\u0644\u0646\u0648\u0645') ||
        normalized.contains(
          '\u0642\u0628\u0644 \u0627\u0644\u0646\u0648\u0645',
        ) ||
        normalized.contains(
          '\u064a\u0631\u064a\u062d \u0627\u0644\u0627\u0639\u0635\u0627\u0628',
        ) ||
        normalized.contains(
          '\u064a\u0631\u064a\u062d \u0627\u0644\u0623\u0639\u0635\u0627\u0628',
        )) {
      return true;
    }
    return normalized.contains('fresh') ||
        normalized.contains('soft') ||
        normalized.contains('elegant') ||
        normalized.contains('classy') ||
        normalized.contains('university') ||
        normalized.contains('office') ||
        normalized.contains('interview') ||
        normalized.contains('meeting') ||
        normalized.contains('not too strong') ||
        normalized.contains('\u0647\u0627\u062f\u064a') ||
        normalized.contains('\u0647\u0627\u062f\u064a\u0629') ||
        normalized.contains('\u0645\u0634 \u0642\u0648\u064a') ||
        normalized.contains('\u0645\u0634 \u0642\u0648\u064a\u0629') ||
        normalized.contains('\u0645\u0634 \u0633\u0648\u064a\u062a') ||
        normalized.contains('\u0645\u0634 \u0645\u0633\u0643\u0631') ||
        normalized.contains('\u0643\u0648\u064a\u0633\u0629') ||
        normalized.contains(
          '\u0633\u0639\u0631\u0647\u0627 \u0642\u0644\u064a\u0644',
        ) ||
        normalized.contains(
          '\u0628\u0634\u0631\u062a\u064a \u062d\u0633\u0627\u0633\u0629',
        ) ||
        normalized.contains('\u062d\u0633\u0627\u0633\u0629') ||
        normalized.contains('مش خانقة') ||
        normalized.contains('شيك') ||
        normalized.contains('\u0641\u062e\u0645') ||
        normalized.contains('\u0641\u062e\u0645\u0629') ||
        normalized.contains('\u0641\u062e\u0645\u0647') ||
        normalized.contains('\u0628\u0631\u0627\u0646\u062f') ||
        normalized.contains('\u0628\u0631\u0627\u0646\u062f\u0627\u062a') ||
        normalized.contains('لطيفة');
  }
}
