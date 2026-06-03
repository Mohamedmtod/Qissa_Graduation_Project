import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_copy_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_slot_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

AIChatReply mergeReplyPreferences(
  AIChatReply reply, {
  required SessionPreferences basePreferences,
}) {
  final preferencePatch = reply.preferencePatch;
  final mergedPatchPreferences = basePreferences.mergePatch(
    reply.updatedPreferences,
  );
  final mergedPreferences = preferencePatch == null || preferencePatch.isEmpty
      ? mergedPatchPreferences
      : preferencePatch.applyTo(mergedPatchPreferences);
  if (mergedPreferences == reply.updatedPreferences) {
    return reply;
  }

  if (reply.isAnswer) {
    return AIChatReply.answer(
      answer: reply.answer ?? '',
      updatedPreferences: mergedPreferences,
      requestId: reply.requestId,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
    );
  }

  if (reply.isRecommend) {
    return AIChatReply.recommend(
      productIds: reply.productIds,
      matchReasons: reply.matchReasons,
      updatedPreferences: mergedPreferences,
      requestId: reply.requestId,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
    );
  }

  return AIChatReply.ask(
    question: reply.question ?? '',
    updatedPreferences: mergedPreferences,
    requestId: reply.requestId,
    promptVersion: reply.promptVersion,
    provider: reply.provider,
    modelId: reply.modelId,
  );
}

AIChatReply buildRecommendReplyFromLocalCandidates(
  List<RecommendedProduct> localCandidates, {
  required SessionPreferences updatedPreferences,
  String? requestId,
  String? promptVersion,
  String? provider,
  String? modelId,
}) {
  final best3 = localCandidates.take(3).toList();
  return AIChatReply.recommend(
    productIds: best3.map((r) => r.product.id).toList(),
    matchReasons: {for (final r in best3) r.product.id: r.matchReason},
    updatedPreferences: updatedPreferences,
    requestId: requestId,
    promptVersion: promptVersion ?? 'local_v1',
    provider: provider ?? 'local',
    modelId: modelId ?? 'local',
  );
}

bool _looksLikeExplicitCatalogQuery(String message) {
  final normalized = LocalIntentParser.normalizeInput(message);
  if (normalized.isEmpty) return false;

  if (LocalIntentParser.containsAny(
    normalized,
    LocalIntentParser.cheapKeywords,
  )) {
    return true;
  }

  if (LocalIntentParser.containsAny(
    normalized,
    AvailabilityIntentUtils.availabilityKeywords,
  )) {
    return true;
  }

  return normalized.contains('what do you have') ||
      normalized.contains('do you have') ||
      normalized.contains('what have you got') ||
      normalized.contains('what is available');
}

bool _looksLikeFoundationalAskQuestion(String question) {
  final inferredSlot = inferAskedSlot(question);
  if (inferredSlot == 'gender' || inferredSlot == 'season') {
    return true;
  }

  final normalized = LocalIntentParser.normalizeInput(question);
  if (normalized.isEmpty) return false;
  if ((normalized.contains('\u0631\u062c\u0627\u0644\u064a') &&
          normalized.contains('\u0646\u0633\u0627\u0626\u064a')) ||
      normalized.contains('\u0627\u0644\u0646\u0648\u0639') ||
      normalized.contains('\u0627\u0644\u062c\u0646\u0633')) {
    return true;
  }
  if ((normalized.contains('\u0635\u064a\u0641') &&
          normalized.contains('\u0634\u062a')) ||
      normalized.contains('\u0627\u0644\u0645\u0648\u0633\u0645')) {
    return true;
  }

  final looksLikeGenderAsk =
      (normalized.contains('men') && normalized.contains('women')) ||
      normalized.contains('gender') ||
      normalized.contains('رجالي') ||
      normalized.contains('نسائي');
  final looksLikeSeasonAsk =
      (normalized.contains('summer') && normalized.contains('winter')) ||
      normalized.contains('season') ||
      normalized.contains('صيف') ||
      normalized.contains('شت');

  return looksLikeGenderAsk || looksLikeSeasonAsk;
}

bool _looksLikeBudgetOrNotesAskQuestion(String question) {
  final inferredSlot = inferAskedSlot(question);
  if (inferredSlot == 'maxBudget' || inferredSlot == 'notesOrIntensity') {
    return true;
  }

  final normalized = LocalIntentParser.normalizeInput(question);
  if (normalized.isEmpty) return false;

  return normalized.contains('budget') ||
      normalized.contains('price') ||
      normalized.contains('notes') ||
      normalized.contains('note') ||
      normalized.contains('intensity') ||
      normalized.contains('ميزاني') ||
      normalized.contains('سعر') ||
      normalized.contains('نوت') ||
      normalized.contains('ريحة') ||
      normalized.contains('فوحان');
}

bool _hasRecommendationGradeCandidates(
  List<RecommendedProduct> localCandidates,
) {
  if (localCandidates.isEmpty) return false;
  return localCandidates.any(
    (candidate) =>
        candidate.product.stock > 0 &&
        candidate.matchScore >= 0.55 &&
        candidate.matchLabel.toLowerCase() != 'weak match' &&
        candidate.candidateSource != RecommendedCandidateSource.relaxed,
  );
}

bool _hasSafeFilteredCandidatesForRedundantAsk(
  List<RecommendedProduct> localCandidates,
) {
  if (localCandidates.isEmpty) return false;
  return localCandidates.any(
    (candidate) =>
        candidate.product.stock > 0 &&
        candidate.matchLabel.toLowerCase() != 'weak match' &&
        candidate.candidateSource != RecommendedCandidateSource.relaxed,
  );
}

bool _looksLikeGenericPreferenceAsk(String question) {
  final normalized = LocalIntentParser.normalizeInput(question);
  if (normalized.isEmpty) return false;
  return normalized.contains('one more preference') ||
      normalized.contains('share one more') ||
      normalized.contains('refine the recommendation') ||
      normalized.contains('تفضيل إضافي');
}

String? _nextUsefulAskSlot(
  SessionPreferences preferences,
  List<String> missingSlots,
) {
  for (final slot in missingSlots) {
    if (!isSlotAlreadyFilled(preferences, slot)) {
      return slot;
    }
  }
  if (preferences.gender == null) return 'gender';
  if (preferences.season == null) return 'season';
  if (preferences.maxBudget == null) return 'maxBudget';
  if (!preferences.hasAnyNoteSignal && preferences.tags.isEmpty) {
    return 'notesOrIntensity';
  }
  return null;
}

AIChatReply normalizeAskReply(
  AIChatReply reply, {
  required String message,
  required List<RecommendedProduct> localCandidates,
  required AIChatLanguage language,
  required bool hasRecommendationContext,
  required String? lastAskQuestion,
  required bool Function(
    SessionPreferences preferences, {
    required bool hasRecommendationContext,
  })
  hasMissingFoundationalDiscoverySlots,
}) {
  if (!reply.isAsk) return reply;

  final effectivePreferences = reply.updatedPreferences;
  final missingSlots = effectivePreferences.missingSlotsForNextQuestion(
    hasRecommendationContext: hasRecommendationContext,
  );
  final askedSlot = inferAskedSlot(reply.question ?? '');
  final looksLikeFoundationalAsk = _looksLikeFoundationalAskQuestion(
    reply.question ?? '',
  );
  final looksLikeBudgetOrNotesAsk = _looksLikeBudgetOrNotesAskQuestion(
    reply.question ?? '',
  );
  final asksAlreadyFilledSlot =
      askedSlot != null && isSlotAlreadyFilled(effectivePreferences, askedSlot);
  final asksFoundationalSlotWithRecommendationContext =
      hasRecommendationContext &&
      (askedSlot == 'gender' ||
          askedSlot == 'season' ||
          looksLikeFoundationalAsk);
  final isDuplicateAsk =
      lastAskQuestion != null &&
      reply.question != null &&
      reply.question == lastAskQuestion;
  final hasMissingFoundationalSlots = hasMissingFoundationalDiscoverySlots(
    effectivePreferences,
    hasRecommendationContext: hasRecommendationContext,
  );
  final hasBlockingFoundationalSlots =
      hasMissingFoundationalSlots &&
      !effectivePreferences.canRecommendPracticalInitial;
  final isExplicitCatalogQuery = _looksLikeExplicitCatalogQuery(message);
  final messageIsVague = LocalIntentParser.isVague(message);
  final hasRecommendationGradeCandidates = _hasRecommendationGradeCandidates(
    localCandidates,
  );
  final hasSafeFilteredCandidatesForRedundantAsk =
      _hasSafeFilteredCandidatesForRedundantAsk(localCandidates);

  if (isExplicitCatalogQuery && localCandidates.isNotEmpty) {
    return buildRecommendReplyFromLocalCandidates(
      localCandidates,
      updatedPreferences: effectivePreferences,
      requestId: reply.requestId,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
    );
  }

  final readyForRecommendation =
      !effectivePreferences.shouldAskBudgetBeforeInitialRecommendation &&
      !hasBlockingFoundationalSlots &&
      (effectivePreferences.canRecommendInitial ||
          effectivePreferences.canRecommendPracticalInitial ||
          effectivePreferences.canRefineExistingRecommendation(
            hasRecommendationContext: hasRecommendationContext,
          ));

  if (hasBlockingFoundationalSlots) {
    final hasRichContextualSignals =
        effectivePreferences.occasion != null &&
        (effectivePreferences.time != null ||
            effectivePreferences.intensity != null ||
            effectivePreferences.tags.isNotEmpty);
    final hasSufficientLifestyleContext =
        hasRichContextualSignals &&
        effectivePreferences.activeCriteriaCount >= 2;
    final canTreatAsGenericFoundationalAsk =
        looksLikeFoundationalAsk ||
        (!looksLikeBudgetOrNotesAsk && missingSlots.isEmpty);
    if (canTreatAsGenericFoundationalAsk &&
        (!messageIsVague || hasSufficientLifestyleContext) &&
        hasRichContextualSignals &&
        effectivePreferences.canRecommendInitial &&
        hasRecommendationGradeCandidates) {
      return buildRecommendReplyFromLocalCandidates(
        localCandidates,
        updatedPreferences: effectivePreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
      );
    }

    final nextSlot = effectivePreferences.gender == null ? 'gender' : 'season';
    return AIChatReply.ask(
      question: buildQuestionForMissingSlot(nextSlot, language),
      updatedPreferences: effectivePreferences,
      requestId: reply.requestId,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
    );
  }

  final hasUsableRecommendationCandidates =
      hasRecommendationGradeCandidates ||
      hasSafeFilteredCandidatesForRedundantAsk;

  if (readyForRecommendation && hasUsableRecommendationCandidates) {
    if (isDuplicateAsk ||
        asksAlreadyFilledSlot ||
        asksFoundationalSlotWithRecommendationContext ||
        looksLikeFoundationalAsk ||
        askedSlot == 'gender' ||
        askedSlot == 'season' ||
        missingSlots.isEmpty) {
      return buildRecommendReplyFromLocalCandidates(
        localCandidates,
        updatedPreferences: effectivePreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
      );
    }
  }

  if (asksAlreadyFilledSlot || asksFoundationalSlotWithRecommendationContext) {
    if (asksAlreadyFilledSlot &&
        (hasRecommendationGradeCandidates ||
            hasSafeFilteredCandidatesForRedundantAsk)) {
      return buildRecommendReplyFromLocalCandidates(
        localCandidates,
        updatedPreferences: effectivePreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
      );
    }

    final canStayInRecommendationFlow =
        readyForRecommendation || effectivePreferences.canRecommendInitial;
    if (canStayInRecommendationFlow &&
        (hasRecommendationGradeCandidates ||
            (asksAlreadyFilledSlot &&
                hasSafeFilteredCandidatesForRedundantAsk))) {
      return buildRecommendReplyFromLocalCandidates(
        localCandidates,
        updatedPreferences: effectivePreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
      );
    }

    final nextSlot = missingSlots
        .where((slot) => !isSlotAlreadyFilled(effectivePreferences, slot))
        .firstOrNull;
    return AIChatReply.ask(
      question: buildQuestionForMissingSlot(nextSlot, language),
      updatedPreferences: effectivePreferences,
      requestId: reply.requestId,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
    );
  }

  if (!readyForRecommendation && missingSlots.isNotEmpty) {
    final nextSlot = missingSlots.first;
    if (askedSlot != nextSlot) {
      return AIChatReply.ask(
        question: buildQuestionForMissingSlot(nextSlot, language),
        updatedPreferences: effectivePreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
      );
    }
  }

  if (_looksLikeGenericPreferenceAsk(reply.question ?? '')) {
    final nextSlot = _nextUsefulAskSlot(effectivePreferences, missingSlots);
    if (nextSlot != null) {
      return AIChatReply.ask(
        question: buildQuestionForMissingSlot(nextSlot, language),
        updatedPreferences: effectivePreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
      );
    }
  }

  return reply;
}
