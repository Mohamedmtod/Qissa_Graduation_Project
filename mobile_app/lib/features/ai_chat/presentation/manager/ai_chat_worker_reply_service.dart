import 'dart:async';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_reply_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_slot_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

typedef MissingFoundationalSlotsPredicate =
    bool Function(
      SessionPreferences preferences, {
      required bool hasRecommendationContext,
    });

class AIChatWorkerReplyService {
  static const int _workerHardTimeoutSeconds = int.fromEnvironment(
    'AI_CHAT_WORKER_TIMEOUT_SECONDS',
    defaultValue: 35,
  );
  static const Duration workerHardTimeout = Duration(
    seconds: _workerHardTimeoutSeconds,
  );

  final AIChatRepo aiChatRepo;
  final MissingFoundationalSlotsPredicate hasMissingFoundationalDiscoverySlots;
  final Duration workerTimeout;

  const AIChatWorkerReplyService({
    required this.aiChatRepo,
    required this.hasMissingFoundationalDiscoverySlots,
    this.workerTimeout = workerHardTimeout,
  });

  Future<AIChatWorkerReplyContext> fetchAndNormalize({
    required AIChatTurnContext incoming,
    required AIChatDiscoveryContext discovery,
    required AIChatRecommendationContext recommendationContext,
    required SessionPreferences currentPreferences,
    required String? lastAskQuestion,
    required List<AIChatMessage> currentMessages,
  }) async {
    AIChatReply? reply;
    String? failureReasonCode;
    final effectiveLastAskQuestion =
        lastAskQuestion ?? _lastAssistantQuestionFrom(currentMessages);
    final compactContext = AIChatExperimentConfig.sendCompactContext
        ? AIChatCompactConversationContext.fromMessages(
            messages: currentMessages,
            lastAssistantQuestion: effectiveLastAskQuestion,
            lastAskSlot: inferAskedSlot(effectiveLastAskQuestion ?? ''),
            hasAvailabilityContext:
                incoming.shouldContinueAvailabilityClarification,
            recommendationMemory: incoming.effectiveRecommendationMemory,
            currentPreferences: currentPreferences,
          )
        : null;
    try {
      final request = compactContext == null
          ? aiChatRepo.fetchAIRecommendation(
              currentMessage: incoming.trimmed,
              preferences: discovery.localPreferences,
              candidates: recommendationContext.candidatesList,
              responseLanguage: incoming.responseLanguage,
              requestId: incoming.requestId,
            )
          : aiChatRepo.fetchAIRecommendationWithContext(
              currentMessage: incoming.trimmed,
              preferences: discovery.localPreferences,
              candidates: recommendationContext.candidatesList,
              localRecommendations: recommendationContext.localCandidatesRefs,
              compactContext: compactContext,
              responseLanguage: incoming.responseLanguage,
              requestId: incoming.requestId,
            );
      reply = await request.timeout(workerTimeout);
    } on TimeoutException {
      failureReasonCode = 'worker_timeout';
      unawaited(
        aiChatRepo.logAIChatEvent(
          eventType: 'ai_worker_hard_timeout',
          sessionId: incoming.activeSessionId,
          metadata: {
            'requestId': incoming.requestId,
            'timeoutMs': workerTimeout.inMilliseconds,
            'candidateCount': recommendationContext.candidatesList.length,
          },
        ),
      );
      reply = null;
    }
    failureReasonCode ??= reply == null
        ? aiChatRepo.lastWorkerFailureReasonCode ?? 'worker_empty_reply'
        : null;
    var responseSource = 'ai_worker';

    if (reply != null &&
        discovery.isFollowUpOrCompare &&
        recommendationContext.localFallbackAnswer != null &&
        (reply.isRecommend || reply.isAnswer)) {
      reply = AIChatReply.answer(
        answer: recommendationContext.localFallbackAnswer!,
        updatedPreferences: currentPreferences,
      );
      responseSource = 'forced_answer';
    }

    if (reply != null) {
      reply = mergeReplyPreferences(
        reply,
        basePreferences: discovery.localPreferences,
      );
      reply = _preserveLocalNoteConstraintPatch(
        reply,
        currentPreferences: currentPreferences,
        localPreferences: discovery.localPreferences,
      );
    }

    if (reply != null && reply.isAsk) {
      var normalizedAsk = normalizeAskReply(
        reply,
        message: incoming.trimmed,
        localCandidates: recommendationContext.localCandidatesRefs,
        language: incoming.responseLanguage,
        hasRecommendationContext: discovery.effectiveHasRecommendationContext,
        lastAskQuestion: lastAskQuestion,
        hasMissingFoundationalDiscoverySlots:
            hasMissingFoundationalDiscoverySlots,
      );

      if (normalizedAsk.isAsk &&
          recommendationContext.localCandidatesRefs.isEmpty &&
          recommendationContext.candidatesList.isNotEmpty) {
        final refreshedExactCandidates =
            LocalCandidateFilter.getTopRecommendations(
              catalog: recommendationContext.candidatesList,
              preferences: reply.updatedPreferences,
            );
        final refreshedUpsellCandidates =
            recommendationContext.budgetPolicy == AIChatBudgetPolicy.flexible
            ? LocalCandidateFilter.getTopUpsellRecommendations(
                catalog: recommendationContext.candidatesList,
                preferences: reply.updatedPreferences,
              )
            : const <RecommendedProduct>[];
        final refreshedCandidates = [
          ...refreshedExactCandidates,
          ...refreshedUpsellCandidates.where(
            (upsell) => !refreshedExactCandidates.any(
              (exact) => exact.product.id == upsell.product.id,
            ),
          ),
        ];

        if (refreshedCandidates.isNotEmpty) {
          normalizedAsk = normalizeAskReply(
            reply,
            message: incoming.trimmed,
            localCandidates: refreshedCandidates,
            language: incoming.responseLanguage,
            hasRecommendationContext:
                discovery.effectiveHasRecommendationContext,
            lastAskQuestion: lastAskQuestion,
            hasMissingFoundationalDiscoverySlots:
                hasMissingFoundationalDiscoverySlots,
          );
        }
      }

      if (!normalizedAsk.isAsk) {
        responseSource = 'ask_override';
        reply = normalizedAsk;
      } else if (normalizedAsk.question != reply.question &&
          !_shouldPreserveWorkerAsk(incoming.trimmed)) {
        responseSource = 'ask_retarget';
        reply = normalizedAsk;
      } else if (_shouldRecoverFoundationalAskWithCandidateList(
        normalizedAsk,
        recommendationContext.candidatesList,
        discovery.effectiveHasRecommendationContext,
      )) {
        responseSource = 'ask_override';
        reply = AIChatReply.recommend(
          productIds: recommendationContext.candidatesList
              .take(3)
              .map((product) => product.id)
              .toList(growable: false),
          matchReasons: const <String, String>{},
          updatedPreferences: normalizedAsk.updatedPreferences,
          requestId: normalizedAsk.requestId,
          promptVersion: normalizedAsk.promptVersion,
          provider: normalizedAsk.provider,
          modelId: normalizedAsk.modelId,
        );
      }
    }

    if (_shouldRewriteSimilarityNoMatch(incoming.trimmed, reply)) {
      responseSource = responseSource.contains('ai_worker')
          ? 'ai_worker_similarity_not_found_rewrite'
          : responseSource;
      reply = AIChatReply.answer(
        answer: incoming.responseLanguage == AIChatLanguage.arabic
            ? '\u0627\u0644\u0627\u0633\u0645 \u062f\u0647 \u0645\u0634 \u0639\u0646\u062f\u064a\u060c \u0648\u0645\u0634 \u0647\u062e\u0645\u0646 \u0648\u0635\u0641\u0647. \u0627\u0648\u0635\u0641 \u0644\u064a \u0627\u0644\u0637\u0627\u0628\u0639 \u0627\u0644\u0644\u064a \u0642\u0627\u0635\u062f\u0647 \u0648\u0623\u062f\u0648\u0631 \u0644\u0643 \u0639\u0644\u0649 \u0628\u062f\u064a\u0644 \u0645\u0646\u0627\u0633\u0628.'
            : 'That name is not in my catalog, and I will not guess its profile. Describe the style you mean and I can look for a suitable alternative.',
        updatedPreferences:
            reply?.updatedPreferences ?? discovery.localPreferences,
        requestId: reply?.requestId,
        promptVersion: reply?.promptVersion,
        provider: reply?.provider,
        modelId: reply?.modelId,
        preferencePatch: reply?.preferencePatch,
      );
    }

    unawaited(
      aiChatRepo.saveAIChatDebugLog(
        phase: 'worker_reply_received',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        language: incoming.responseLanguage.code,
        messageText: incoming.trimmed,
        detectedIntent: incoming.intent.name,
        responseSource: responseSource,
        workerReplySummary: {
          'isNull': reply == null,
          'type': reply == null
              ? 'null'
              : (reply.isAsk
                    ? 'ask'
                    : (reply.isAnswer
                          ? 'answer'
                          : (reply.isToolCall ? 'tool_call' : 'recommend'))),
          'toolRouterEnabled': AIChatExperimentConfig.toolRouterV1,
          if (reply?.isToolCall == true)
            'toolCallName': reply?.toolCall?.name.name,
          if (reply?.isToolCall == true)
            'toolCallValid': reply?.toolCall != null,
          'productIds': reply?.productIds ?? const <String>[],
          'provider': reply?.provider,
          'modelId': reply?.modelId,
          'promptVersion': reply?.promptVersion,
          'requestId': reply?.requestId,
          'candidateCount': recommendationContext.candidatesList.length,
          'candidateCountSentToWorker':
              recommendationContext.candidatesList.length,
          'workerRawProductIds': reply?.productIds ?? const <String>[],
          'workerRawRecommendationCount': reply?.productIds.length ?? 0,
          'safeCandidateCount':
              recommendationContext.localCandidatesRefs.length,
          'localCandidateCount':
              recommendationContext.localCandidatesRefs.length,
          ...?failureReasonCode == null
              ? null
              : {'failureReasonCode': failureReasonCode},
        },
      ),
    );

    return AIChatWorkerReplyContext(
      reply: reply,
      responseSource: responseSource,
      failureReasonCode: failureReasonCode,
    );
  }

  AIChatReply _preserveLocalNoteConstraintPatch(
    AIChatReply reply, {
    required SessionPreferences currentPreferences,
    required SessionPreferences localPreferences,
  }) {
    if (!_hasLocalNoteConstraintDelta(currentPreferences, localPreferences)) {
      return reply;
    }

    final repairedPreferences = reply.updatedPreferences.copyWith(
      preferredNotes: localPreferences.preferredNotes,
      preferredTopNotes: localPreferences.preferredTopNotes,
      preferredMiddleNotes: localPreferences.preferredMiddleNotes,
      preferredBaseNotes: localPreferences.preferredBaseNotes,
      excludedNotes: localPreferences.excludedNotes,
      medicalExcludedNotes: localPreferences.medicalExcludedNotes,
    );

    if (repairedPreferences == reply.updatedPreferences) return reply;

    if (reply.isAsk) {
      return AIChatReply.ask(
        question: reply.question ?? '',
        updatedPreferences: repairedPreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      );
    }
    if (reply.isAnswer) {
      return AIChatReply.answer(
        answer: reply.answer ?? '',
        updatedPreferences: repairedPreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      );
    }
    return AIChatReply.recommend(
      productIds: reply.productIds,
      matchReasons: reply.matchReasons,
      updatedPreferences: repairedPreferences,
      requestId: reply.requestId,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
      preferencePatch: reply.preferencePatch,
    );
  }

  bool _hasLocalNoteConstraintDelta(
    SessionPreferences currentPreferences,
    SessionPreferences localPreferences,
  ) {
    return !_sameNormalizedSet(
          currentPreferences.preferredNotes,
          localPreferences.preferredNotes,
        ) ||
        !_sameNormalizedSet(
          currentPreferences.preferredTopNotes,
          localPreferences.preferredTopNotes,
        ) ||
        !_sameNormalizedSet(
          currentPreferences.preferredMiddleNotes,
          localPreferences.preferredMiddleNotes,
        ) ||
        !_sameNormalizedSet(
          currentPreferences.preferredBaseNotes,
          localPreferences.preferredBaseNotes,
        ) ||
        !_sameNormalizedSet(
          currentPreferences.excludedNotes,
          localPreferences.excludedNotes,
        ) ||
        !_sameNormalizedSet(
          currentPreferences.medicalExcludedNotes,
          localPreferences.medicalExcludedNotes,
        );
  }

  bool _sameNormalizedSet(List<String> left, List<String> right) {
    return _normalizedSet(left).difference(_normalizedSet(right)).isEmpty &&
        _normalizedSet(right).difference(_normalizedSet(left)).isEmpty;
  }

  Set<String> _normalizedSet(List<String> values) {
    return values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  String? _lastAssistantQuestionFrom(List<AIChatMessage> messages) {
    for (final message in messages.reversed) {
      if (message.isLoading || message.isFromUser) continue;
      final text = message.content.trim();
      if (text.isEmpty) continue;
      if (message.isRecommendation || message.isAvailability) continue;
      return text;
    }
    return null;
  }

  bool _shouldPreserveWorkerAsk(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    return normalized.contains('same smell') ||
        normalized.contains('similar to') ||
        normalized.contains('smells like') ||
        normalized.contains('\u0634\u0628\u0647 \u0639\u0637\u0631') ||
        normalized.contains('\u0631\u064a\u062d\u0629 \u0634\u0628\u0647');
  }

  bool _shouldRewriteSimilarityNoMatch(String message, AIChatReply? reply) {
    if (!_shouldPreserveWorkerAsk(message) || reply == null) return false;
    final text = LocalIntentParser.normalizeInput(
      reply.answer ?? reply.question ?? '',
    );
    if (text.isEmpty) return false;
    return text.contains(
          '\u0644\u0627 \u0627\u0642\u062f\u0631 \u0627\u0639\u0631\u0636',
        ) ||
        text.contains(
          '\u062a\u0641\u0636\u0644 \u0639\u0637\u0631 \u0631\u062c\u0627\u0644\u064a',
        ) ||
        text.contains(
          '\u062a\u0641\u0636\u0644 \u0639\u0637\u0648\u0631 \u0631\u062c\u0627\u0644\u064a',
        ) ||
        (text.contains('\u0631\u062c\u0627\u0644') &&
            text.contains('\u0646\u0633\u0627')) ||
        (text.contains('\u0630\u0643\u0648\u0631') &&
            text.contains('\u0627\u0646\u062b')) ||
        text.contains('safe recommendation') ||
        text.contains('men or women') ||
        text.contains('male or female');
  }

  bool _shouldRecoverFoundationalAskWithCandidateList(
    AIChatReply askReply,
    List<ProductModel> candidates,
    bool hasRecommendationContext,
  ) {
    if (!askReply.isAsk || candidates.isEmpty) return false;
    final preferences = askReply.updatedPreferences;
    if (!preferences.canRecommendInitial &&
        !preferences.canRefineExistingRecommendation(
          hasRecommendationContext: hasRecommendationContext,
        )) {
      return false;
    }
    final question = LocalIntentParser.normalizeInput(askReply.question ?? '');
    final askedSlot = inferAskedSlot(question);
    if (askedSlot != null && isSlotAlreadyFilled(preferences, askedSlot)) {
      return true;
    }
    final asksGender =
        question.contains('men') && question.contains('women') ||
        question.contains('gender') ||
        question.contains('رجال') ||
        question.contains('\u0631\u062c\u0627\u0644') ||
        question.contains('\u0646\u0633\u0627');
    final asksSeason =
        question.contains('summer') && question.contains('winter') ||
        question.contains('season') ||
        question.contains('صيف') ||
        question.contains('شت') ||
        question.contains('\u0635\u064a\u0641') ||
        question.contains('\u0634\u062a');
    return (asksGender && preferences.gender != null) ||
        (asksSeason && preferences.season != null);
  }
}
