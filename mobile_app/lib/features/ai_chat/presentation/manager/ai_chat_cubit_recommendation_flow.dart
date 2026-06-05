part of 'ai_chat_cubit.dart';

extension AIChatCubitRecommendationFlow on AIChatCubit {
  AIChatDiscoveryContext _resolveDiscoveryContext(AIChatTurnContext incoming) {
    final discovery = _discoveryService.resolve(
      incoming: incoming,
      currentPreferences: state.preferences,
      lastAskQuestion: _lastAskQuestion,
    );
    if (discovery.shouldClearBaselinePreferences) {
      _baselinePreferences = null;
    }

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'request_started',
        sessionId: incoming.activeSessionId,
        metadata: {
          'ai_mode': _currentAiModeTelemetryValue(),
          'detectedIntent': incoming.intent.name,
          'activeCriteriaCount':
              discovery.context.localPreferences.activeCriteriaCount,
          'hasSufficientCriteria':
              discovery.context.localReadyForRecommendation,
          'isFollowUpOrCompare': discovery.context.isFollowUpOrCompare,
          'isVague': discovery.isVague,
          'missingSlots': discovery.context.localMissingSlots,
          'requestId': incoming.requestId,
        },
      ),
    );

    return discovery.context;
  }

  bool _shouldUseWorkerFirstRecommendationFlow(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery,
  ) {
    if (discovery.isFollowUpOrCompare) return false;
    if (!discovery.localReadyForRecommendation) return false;
    if (AIChatExperimentConfig.catalogSearchShadow) return false;
    if (_looksLikeSensitiveSkinChoiceForWorkerFirst(incoming.trimmed)) {
      return false;
    }
    return incoming.intent == AIChatIntent.newRecommendation;
  }

  bool _looksLikeSensitiveSkinChoiceForWorkerFirst(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    final hasSensitiveSignal =
        normalized.contains('sensitive skin') ||
        (normalized.contains('\u0628\u0634\u0631') &&
            normalized.contains('\u062d\u0633\u0627\u0633'));
    if (!hasSensitiveSignal) return false;
    return normalized.contains('choose') ||
        normalized.contains('pick') ||
        normalized.contains('recommend') ||
        normalized.contains('\u0627\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0623\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0631\u0634\u062d');
  }

  void _logWorkerFirstExperimentUsage({
    required AIChatTurnContext incoming,
    required int candidateCountBeforeFilter,
    required int candidateCountAfterFilter,
    required bool workerCalled,
    String? fallbackReason,
  }) {
    final metadata = <String, dynamic>{
      'ai_mode': _currentAiModeTelemetryValue(),
      'requestId': incoming.requestId,
      'candidate_count_before_filter': candidateCountBeforeFilter,
      'candidate_count_after_filter': candidateCountAfterFilter,
      'worker_called': workerCalled,
    };
    if (fallbackReason != null) {
      metadata['fallback_reason'] = fallbackReason;
    }

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'ai_worker_first_path_used',
        sessionId: incoming.activeSessionId,
        metadata: metadata,
      ),
    );
  }

  Future<bool> _handleModifierPatchIfAny(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final modifierResolution = _modifierService.resolve(
      message: incoming.trimmed,
      currentPreferences: state.preferences,
      discovery: discovery,
      baselinePreferences: _baselinePreferences,
      hasNoteSignalDelta: _hasNoteSignalDelta(
        state.preferences,
        discovery.localPreferences,
      ),
    );
    if (!modifierResolution.shouldHandle) {
      return false;
    }

    final modifierPatch = modifierResolution.modifierPatch!;
    final modifiedPreferences = modifierResolution.modifiedPreferences!;
    _baselinePreferences = modifierResolution.updatedBaselinePreferences;

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'modifier_patch_applied',
        sessionId: incoming.activeSessionId,
        metadata: {
          'modifierType': modifierPatch.type.name,
          'activeCriteriaCount': modifiedPreferences.activeCriteriaCount,
          'requestId': incoming.requestId,
        },
      ),
    );

    final modifiedMissingSlots = modifiedPreferences
        .missingSlotsForNextQuestion(
          hasRecommendationContext: discovery.effectiveHasRecommendationContext,
        );
    final modifiedReadyForRecommendation =
        !modifiedPreferences.shouldAskBudgetBeforeInitialRecommendation &&
        !_hasMissingFoundationalDiscoverySlots(
          modifiedPreferences,
          hasRecommendationContext: discovery.effectiveHasRecommendationContext,
        ) &&
        (modifiedPreferences.canRecommendInitial ||
            modifiedPreferences.canRefineExistingRecommendation(
              hasRecommendationContext:
                  discovery.effectiveHasRecommendationContext,
            ));

    if (modifiedReadyForRecommendation) {
      final catalog = await _aiChatRepo.getCatalog();
      final modifierCandidates = LocalCandidateFilter.getTopRecommendations(
        catalog: catalog,
        preferences: modifiedPreferences,
      );
      final modifierUpsellCandidates =
          LocalCandidateFilter.getTopUpsellRecommendations(
            catalog: catalog,
            preferences: modifiedPreferences,
          );
      final allModifierCandidates = [
        ...modifierCandidates,
        ...modifierUpsellCandidates.where(
          (upsell) => !modifierCandidates.any(
            (exact) => exact.product.id == upsell.product.id,
          ),
        ),
      ];

      if (allModifierCandidates.isNotEmpty) {
        final reply = buildRecommendReplyFromLocalCandidates(
          allModifierCandidates,
          updatedPreferences: modifiedPreferences,
        );
        _replyHandler.handleRecommendationReply(
          reply,
          allModifierCandidates,
          language: incoming.responseLanguage,
          source: 'modifier_patch',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return true;
      }

      _syncLastBudgetNoMatchContext(
        preferences: modifiedPreferences,
        catalog: catalog,
        reasonCode: 'modifier_no_match',
      );
      _replyHandler.replyWithFallback(
        buildNoMatchMessage(
          incoming.trimmed,
          modifiedPreferences,
          catalog,
          incoming.responseLanguage,
          reasonCode: _localNoMatchReason(modifiedPreferences),
        ),
        language: incoming.responseLanguage,
        source: 'modifier_patch',
        updatedPreferences: modifiedPreferences,
        isNoMatch: true,
        issueCode: 'no_candidate_match',
        reasonCode: 'modifier_no_match',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final nextSlot = modifiedMissingSlots.isNotEmpty
        ? modifiedMissingSlots.first
        : null;
    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: buildQuestionForMissingSlot(
          nextSlot,
          incoming.responseLanguage,
        ),
        updatedPreferences: modifiedPreferences,
      ),
      language: incoming.responseLanguage,
      source: 'modifier_patch',
      issueCode: 'modifier_needs_more_info',
      reasonCode: 'modifier_missing_slots',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  List<RecommendedProduct> _buildAskRecoveryProducts(
    SessionPreferences preferences,
    AIChatRecommendationContext recommendationContext,
    bool hasRecommendationContext,
  ) {
    final canRecommend =
        preferences.canRecommendInitial ||
        preferences.canRefineExistingRecommendation(
          hasRecommendationContext: hasRecommendationContext,
        );
    if (!canRecommend ||
        _hasMissingFoundationalDiscoverySlots(
          preferences,
          hasRecommendationContext: hasRecommendationContext,
        )) {
      return const <RecommendedProduct>[];
    }

    if (recommendationContext.localCandidatesRefs.isNotEmpty) {
      return recommendationContext.localCandidatesRefs.take(3).toList();
    }

    return LocalCandidateFilter.getTopRecommendations(
      catalog: recommendationContext.candidatesList,
      preferences: preferences,
    ).take(3).toList();
  }

  String _localNoMatchReason(SessionPreferences preferences) {
    if (preferences.excludedNotes.isNotEmpty) {
      return 'excluded_note_no_match';
    }
    if (preferences.maxBudget != null) {
      return 'budget_no_match';
    }
    if (preferences.preferredNotes.length >= 2) {
      return 'strong_scent_no_match';
    }
    if (preferences.preferredNotes.isNotEmpty ||
        preferences.preferredTopNotes.isNotEmpty ||
        preferences.preferredMiddleNotes.isNotEmpty ||
        preferences.preferredBaseNotes.isNotEmpty) {
      return 'scent_no_match';
    }
    if (preferences.gender != null ||
        preferences.season != null ||
        preferences.time != null ||
        preferences.occasion != null ||
        preferences.intensity != null) {
      return 'context_no_match';
    }
    return 'local_candidate_no_match';
  }

  String get currentSessionId => _sessionId;
}
