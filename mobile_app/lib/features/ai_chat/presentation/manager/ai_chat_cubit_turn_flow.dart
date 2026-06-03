part of 'ai_chat_cubit.dart';

extension AIChatCubitTurnFlow on AIChatCubit {
  Map<String, dynamic> _recommendationMemorySnapshot(
    RecommendationMemory memory,
  ) {
    return {
      'lastFocusedProductId': memory.lastFocusedProductId,
      'lastRecommendationBatchId': memory.lastRecommendationBatchId,
      'lastRecommendedProducts': memory.lastRecommendedProducts
          .map((item) => item.toJson())
          .toList(growable: false),
    };
  }

  bool _hasMissingFoundationalDiscoverySlots(
    SessionPreferences preferences, {
    required bool hasRecommendationContext,
  }) {
    if (hasRecommendationContext) return false;
    return preferences.gender == null || preferences.season == null;
  }

  bool _sameNormalizedStringSet(List<String> first, List<String> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;

    final firstSet = first.map((item) => item.trim().toLowerCase()).toSet();
    final secondSet = second.map((item) => item.trim().toLowerCase()).toSet();
    if (firstSet.length != secondSet.length) return false;
    return firstSet.containsAll(secondSet);
  }

  bool _hasNoteSignalDelta(
    SessionPreferences before,
    SessionPreferences after,
  ) {
    return !_sameNormalizedStringSet(
          before.preferredNotes,
          after.preferredNotes,
        ) ||
        !_sameNormalizedStringSet(
          before.preferredTopNotes,
          after.preferredTopNotes,
        ) ||
        !_sameNormalizedStringSet(
          before.preferredMiddleNotes,
          after.preferredMiddleNotes,
        ) ||
        !_sameNormalizedStringSet(
          before.preferredBaseNotes,
          after.preferredBaseNotes,
        ) ||
        !_sameNormalizedStringSet(before.excludedNotes, after.excludedNotes);
  }

  bool _tryHandleRecommendationContextAnswer(
    String message, {
    required List<ProductModel> catalog,
    required AIChatLanguage language,
    required String sessionId,
    required bool pruneHistoricalBotMessages,
  }) {
    final effectiveRecommendationMemory = _latestVisibleRecommendationMemory();
    if (effectiveRecommendationMemory.lastRecommendedProducts.isEmpty) {
      return false;
    }
    if (_tryHandleVisibleProductsAnalyticalAnswer(
      message,
      language: language,
      sessionId: sessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    )) {
      return true;
    }
    final parsedPreferences = LocalIntentParser.parse(
      message,
      state.preferences,
    );
    if (_preferenceChangeDetector.hasPreferenceDelta(
      state.preferences,
      parsedPreferences,
    )) {
      return false;
    }

    if (!looksLikeProductWhyFollowUp(message) &&
        !looksLikeProductDetailsFollowUp(message)) {
      return false;
    }

    final focusedProductId =
        effectiveRecommendationMemory.lastFocusedProductId ??
        effectiveRecommendationMemory.lastRecommendedProducts.first.productId;
    final focusedProduct = catalog
        .where((product) => product.id == focusedProductId)
        .firstOrNull;
    if (focusedProduct == null) return false;

    final answer = looksLikeProductWhyFollowUp(message)
        ? buildWhyProductFollowUpAnswer(focusedProduct, language)
        : buildProductDetailsFollowUpAnswer(focusedProduct, language);

    _emitState(
      state.copyWith(
        recommendationMemory: effectiveRecommendationMemory.copyWith(
          lastFocusedProductId: focusedProduct.id,
        ),
      ),
    );

    _replyHandler.handleAnswerReply(
      AIChatReply.answer(answer: answer, updatedPreferences: state.preferences),
      language: language,
      source: looksLikeProductWhyFollowUp(message)
          ? 'recommendation_product_why'
          : 'recommendation_product_details',
      sessionId: sessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _tryHandleVisibleProductsAnalyticalAnswer(
    String message, {
    required AIChatLanguage language,
    required String sessionId,
    required bool pruneHistoricalBotMessages,
  }) {
    final effectiveRecommendationMemory = _latestVisibleRecommendationMemory();
    final refs = effectiveRecommendationMemory.lastRecommendedProducts;
    if (refs.isEmpty) return false;

    final normalized = LocalIntentParser.normalizeInput(message);
    final contextLabel = _productContextSignals.extractContextLabel(normalized);
    final asksVisibleCheapest = _looksLikeVisibleCheapestQuestion(normalized);
    final asksVisibleBestForContext =
        contextLabel != null &&
        _looksLikeVisibleBestForContextQuestion(normalized);
    if (!asksVisibleCheapest && !asksVisibleBestForContext) return false;

    final answer = asksVisibleCheapest
        ? _memoryAnswerBuilder.buildCheapestAnswer(refs, language)
        : _memoryAnswerBuilder.buildBestForContextAnswer(
            refs,
            contextLabel!,
            language,
          );
    final focusedId = asksVisibleCheapest
        ? refs.reduce((a, b) => a.price <= b.price ? a : b).productId
        : _memoryAnswerBuilder
              .selectBestForContext(refs, contextLabel!)
              .productId;
    _emitState(
      state.copyWith(
        recommendationMemory: effectiveRecommendationMemory.copyWith(
          lastFocusedProductId: focusedId,
        ),
      ),
    );
    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: answer,
        updatedPreferences: state.preferences,
        provider: 'local',
        modelId: 'visible_products_answer',
        promptVersion: 'visible_products_answer_v1',
      ),
      language: language,
      source: 'visible_products_answer',
      sessionId: sessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _looksLikeVisibleCheapestQuestion(String normalized) {
    if (normalized.isEmpty) return false;
    final hasPriceSignal =
        normalized.contains('cheapest') ||
        normalized.contains('lowest price') ||
        normalized.contains('lower price') ||
        normalized.contains('less expensive') ||
        normalized.contains('رخ') ||
        normalized.contains('\u0631\u062e\u0635') ||
        normalized.contains('\u0623\u0631\u062e\u0635') ||
        normalized.contains('\u0627\u0631\u062e\u0635');
    if (!hasPriceSignal) return false;
    return _referencesVisibleOptions(normalized);
  }

  bool _looksLikeVisibleBestForContextQuestion(String normalized) {
    if (normalized.isEmpty) return false;
    final hasChoiceSignal =
        RegExp(
          r'\b(which|what|best|better|pick|choose)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u0623\u0646\u0647\u064a') ||
        normalized.contains('\u0627\u0646\u0647\u064a') ||
        normalized.contains('\u0623\u0641\u0636\u0644') ||
        normalized.contains('\u0627\u0641\u0636\u0644');
    if (!hasChoiceSignal) return false;
    return _referencesVisibleOptions(normalized);
  }

  bool _referencesVisibleOptions(String normalized) {
    return RegExp(
          r'\b(them|these|those|among|between|visible|options?|recommendations?|one|ones?)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u0641\u064a\u0647\u0645') ||
        normalized.contains('فيه') ||
        normalized.contains('هم') ||
        normalized.contains('\u0647\u0645') ||
        normalized.contains('\u0628\u064a\u0646\u0647\u0645') ||
        normalized.contains('\u062f\u0648\u0644') ||
        normalized.contains(
          '\u0627\u0644\u062a\u0631\u0634\u064a\u062d\u0627\u062a',
        ) ||
        normalized.contains(
          '\u0627\u0644\u0627\u062e\u062a\u064a\u0627\u0631\u0627\u062a',
        );
  }

  RecommendationMemory _latestVisibleRecommendationMemory() {
    return latestVisibleRecommendationMemory(
      state.messages,
      state.recommendationMemory,
    );
  }

  AIChatTurnContext? _validateIncomingMessage(String text) {
    final effectiveRecommendationMemory = _latestVisibleRecommendationMemory();
    final validation = _turnService.validateAndBuildContext(
      text: text,
      state: state,
      sessionId: _sessionId,
      effectiveRecommendationMemory: effectiveRecommendationMemory,
      requestTimestampsMs: _requestTimestampsMs,
      shouldContinueAvailabilityClarification:
          _shouldContinueAvailabilityClarification,
      maxUserMessageLength: AIChatCubit.maxUserMessageLength,
      maxRequestsPerWindow: AIChatCubit._maxRequestsPerWindow,
      rateLimitWindow: AIChatCubit._rateLimitWindow,
    );
    if (validation.accepted) return validation.context;
    if (validation.rejection == AIChatTurnRejection.emptyOrLoading) {
      return null;
    }

    if (validation.rejection == AIChatTurnRejection.tooLong) {
      _logDebug(
        'Rejected user message: too long | len=${validation.trimmed.length} | max=${AIChatCubit.maxUserMessageLength} | text="${_shortText(validation.trimmed)}"',
      );
      _emitState(
        state.copyWith(
          language: validation.responseLanguage,
          errorMessage: _t(
            validation.responseLanguage,
            ar: 'رسالتك طويلة جدًا. اختصرها إلى ${AIChatCubit.maxUserMessageLength} حرف أو أقل واحتفظ بالتفاصيل الأساسية فقط.',
            en: 'Your message is too long. Please shorten it to ${AIChatCubit.maxUserMessageLength} characters or less and keep only the key details.',
          ),
        ),
      );
      return null;
    }

    if (validation.rejection == AIChatTurnRejection.cooldown) {
      _logDebug(
        'Rejected user message: cooldown active | remaining=${state.cooldownSecondsRemaining}s | text="${_shortText(validation.trimmed)}"',
      );
      _emitState(
        state.copyWith(
          language: validation.responseLanguage,
          errorMessage: _t(
            validation.responseLanguage,
            ar: 'من فضلك انتظر ${state.cooldownSecondsRemaining} ثانية قبل إرسال رسالة أخرى.',
            en: 'Please wait ${state.cooldownSecondsRemaining} seconds before sending another message.',
          ),
        ),
      );
      return null;
    }

    if (validation.rejection == AIChatTurnRejection.rateLimit) {
      _logDebug(
        'Rejected user message: local rate limit exceeded | windowCount=${validation.rateLimitWindowCount} | text="${_shortText(validation.trimmed)}"',
      );
      _emitState(
        state.copyWith(
          language: validation.responseLanguage,
          errorMessage: _t(
            validation.responseLanguage,
            ar: 'وصلت للحد المؤقت للرسائل. حاول مرة أخرى بعد دقيقة.',
            en: 'You reached the temporary message limit. Please try again in a minute.',
          ),
        ),
      );
      return null;
    }

    return null;
  }

  void _prepareActiveTurn(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    final conversationPlan = _conversationOrchestrator.plan(
      message: incoming.trimmed,
      language: incoming.responseLanguage,
      preferences: state.preferences,
      memory: incoming.effectiveRecommendationMemory,
      hasRecommendationContext: incoming
          .effectiveRecommendationMemory
          .lastRecommendedProducts
          .isNotEmpty,
    );
    _logDebug(
      'Preparing active turn | sessionId=${incoming.activeSessionId} | requestId=${incoming.requestId} | '
      'status=${state.status.name} | messageCount=${state.messages.length} | '
      'prefs=${state.preferences.toJson()} | conversationIntent=${conversationPlan.intent.name} | '
      'cardPolicy=${conversationPlan.cardPolicy.name} | fallbackPlan=${conversationPlan.safeFallbackPlan}',
    );
    _analyticsTracker.beginTurn(
      requestId: incoming.requestId,
      sessionId: incoming.activeSessionId,
      language: incoming.responseLanguage,
      messageLength: incoming.trimmed.length,
    );
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'message_sent',
        sessionId: incoming.activeSessionId,
        metadata: {
          'ai_mode': _currentAiModeTelemetryValue(),
          'messageLength': incoming.trimmed.length,
          'activeCriteriaCount': state.preferences.activeCriteriaCount,
          'requestId': incoming.requestId,
        },
      ),
    );
    unawaited(
      _aiChatRepo.saveAIChatDebugLog(
        phase: 'turn_started',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        language: incoming.responseLanguage.code,
        messageText: incoming.trimmed,
        detectedIntent: incoming.intent.name,
        responseSource: 'incoming_turn',
        workerReplySummary: {
          'conversationIntent': conversationPlan.intent.name,
          'cardPolicy': conversationPlan.cardPolicy.name,
          'shouldPreferWorker': conversationPlan.shouldPreferWorker,
          'safeFallbackPlan': conversationPlan.safeFallbackPlan,
        },
        preferencesSnapshot: state.preferences.toJson(),
        availabilityContextSnapshot: {
          'lastQuery': state.availabilityContext.lastQuery,
          'matchedProductId': state.availabilityContext.matchedProductId,
          'matchedProductName': state.availabilityContext.matchedProductName,
          'availabilityStatus':
              state.availabilityContext.availabilityStatus.name,
          'referenceProfileKey': state.availabilityContext.referenceProfileKey,
          'candidateOptionIds': state.availabilityContext.candidateOptionIds,
          'externalCandidates': state.availabilityContext.externalCandidates
              .map((item) => item.toMap())
              .toList(growable: false),
          'source': state.availabilityContext.source,
        },
        recommendationMemorySnapshot: _recommendationMemorySnapshot(
          incoming.effectiveRecommendationMemory,
        ),
      ),
    );

    final userMessage = AIChatMessage.user(incoming.trimmed);
    final updatedMessages =
        pruneBotHistoryForFreshTurn(
            localizedOpeningMessages(
              List<AIChatMessage>.from(state.messages),
              incoming.responseLanguage,
            ),
            enabled: pruneHistoricalBotMessages,
          )
          ..add(userMessage)
          ..add(AIChatMessage.loading());

    _emitState(
      state.copyWith(
        status: AIChatStatus.loading,
        messages: updatedMessages,
        language: incoming.responseLanguage,
        errorMessage: null,
        loadingPhase: AIChatCubit._loadingPhaseAnalyzing,
        recommendationMemory: incoming.effectiveRecommendationMemory,
      ),
    );

    _sessionPersistenceHelper.enqueueMessagePersistence(
      message: userMessage,
      sessionId: incoming.activeSessionId,
    );
  }

  Future<bool> _handleEarlyContextAnswers(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) async {
    if (await _tryHandleAvailabilityContextAnswer(
      incoming.trimmed,
      catalog: catalog,
      language: incoming.responseLanguage,
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    )) {
      return true;
    }

    if (_tryHandleRecommendationContextAnswer(
      incoming.trimmed,
      catalog: catalog,
      language: incoming.responseLanguage,
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    )) {
      return true;
    }

    return false;
  }

  bool _handleFantasyNoteInterception(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    if (incoming.shouldContinueAvailabilityClarification ||
        incoming.isGreetingOnly) {
      return false;
    }

    final parsedForInterceptor = LocalIntentParser.parse(
      incoming.trimmed,
      state.preferences,
    );
    final intercepted = AIChatInputInterceptor.detect(
      incoming.trimmed,
      parsedForInterceptor,
    );
    if (intercepted?.kind != AIChatInterceptKind.fantasyNoteLike) {
      return false;
    }

    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: buildInterceptedClarificationMessage(
          intercepted!,
          incoming.responseLanguage,
        ),
        updatedPreferences: parsedForInterceptor,
      ),
      language: incoming.responseLanguage,
      source: 'local_interceptor',
      issueCode: intercepted.issueCode,
      reasonCode: intercepted.reasonCode,
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _handleEarlyInterception(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    final shouldRunEarlyInterceptor =
        incoming.intent != AIChatIntent.followUpProduct &&
        incoming.intent != AIChatIntent.compareProducts &&
        incoming.intent != AIChatIntent.summary &&
        !incoming.shouldContinueAvailabilityClarification &&
        !incoming.isGreetingOnly;

    if (shouldRunEarlyInterceptor) {
      final parsedForInterceptor = LocalIntentParser.parse(
        incoming.trimmed,
        state.preferences,
      );
      final hasRecommendationContext = incoming
          .effectiveRecommendationMemory
          .lastRecommendedProducts
          .isNotEmpty;
      if (_isPersonaOnlyMessageForLocalAsk(incoming, parsedForInterceptor)) {
        final missingSlots = parsedForInterceptor.missingSlotsForNextQuestion(
          hasRecommendationContext: hasRecommendationContext,
        );
        final nextSlot = missingSlots.isNotEmpty
            ? missingSlots.first
            : 'notesOrIntensity';
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question: buildQuestionForMissingSlot(
              nextSlot,
              incoming.responseLanguage,
            ),
            updatedPreferences: parsedForInterceptor,
          ),
          language: incoming.responseLanguage,
          source: 'persona_only_interceptor',
          issueCode: 'partial_persona_preferences',
          reasonCode: 'persona_only_local_ask',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return true;
      }

      var intercepted = AIChatInputInterceptor.detect(
        incoming.trimmed,
        parsedForInterceptor,
      );
      final hasMeaningfulExistingContext =
          state.preferences.activeCriteriaCount > 0 || hasRecommendationContext;
      if (intercepted?.kind == AIChatInterceptKind.gibberishLike &&
          hasMeaningfulExistingContext) {
        intercepted = null;
      }
      if (incoming.intent == AIChatIntent.availabilityCheck &&
          intercepted != null &&
          intercepted.kind != AIChatInterceptKind.fantasyNoteLike) {
        intercepted = null;
      }
      if (intercepted != null) {
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question: buildInterceptedClarificationMessage(
              intercepted,
              incoming.responseLanguage,
            ),
            updatedPreferences: parsedForInterceptor,
          ),
          language: incoming.responseLanguage,
          source: 'local_interceptor',
          issueCode: intercepted.issueCode,
          reasonCode: intercepted.reasonCode,
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return true;
      }
    }

    if (incoming.intent == AIChatIntent.summary) {
      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: buildPreferenceSummary(
            state.preferences,
            language: incoming.responseLanguage,
          ),
          updatedPreferences: state.preferences,
        ),
        language: incoming.responseLanguage,
        source: 'local_summary',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: true,
      );
      return true;
    }

    return false;
  }

  bool _isPersonaOnlyMessageForLocalAsk(
    AIChatTurnContext incoming,
    SessionPreferences parsedPreferences,
  ) {
    if (incoming.intent == AIChatIntent.availabilityCheck ||
        incoming.intent == AIChatIntent.followUpProduct ||
        incoming.intent == AIChatIntent.compareProducts ||
        incoming.intent == AIChatIntent.summary ||
        incoming.isGreetingOnly ||
        incoming.shouldContinueAvailabilityClarification) {
      return false;
    }

    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) return false;
    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return false;
    }
    if (LocalIntentParser.containsAny(
          normalized,
          AvailabilityIntentUtils.availabilityKeywords,
        ) ||
        normalized.contains('recommend') ||
        normalized.contains('suggest') ||
        normalized.contains('show me')) {
      return false;
    }
    if (!_looksLikeNarrowPersonaOnlyStatement(normalized)) {
      return false;
    }
    if (parsedPreferences.activeCriteriaCount > 1) return false;
    if (parsedPreferences.hasAnyNoteSignal) return false;
    if (parsedPreferences.maxBudget != null) return false;

    return true;
  }

  bool _looksLikeNarrowPersonaOnlyStatement(String normalized) {
    final agePattern = RegExp(
      r'\b\d{1,2}\s*(?:year old|years old|yr old|yrs old)\b',
    );
    final hyphenAgePattern = RegExp(r'\b\d{1,2}\s*-\s*year\s*-\s*old\b');
    final explicitPersonaGender = RegExp(
      r"\b(i am|im|i'm)\s+(?:a\s+)?(?:\d{1,2}\s*(?:-\s*)?year\s*(?:-\s*)?old\s+)?(?:man|male|woman|female)\b",
    );
    return agePattern.hasMatch(normalized) ||
        hyphenAgePattern.hasMatch(normalized) ||
        explicitPersonaGender.hasMatch(normalized) ||
        normalized.contains('i work') ||
        normalized.contains('i am working') ||
        normalized.contains("i'm working") ||
        normalized.contains('im working');
  }
}
