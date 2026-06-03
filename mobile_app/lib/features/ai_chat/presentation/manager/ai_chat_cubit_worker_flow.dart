part of 'ai_chat_cubit.dart';

extension AIChatCubitWorkerFlow on AIChatCubit {
  Future<AIChatWorkerReplyContext?> _handleWorkerFailureFallback(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery,
    AIChatRecommendationContext recommendationContext,
    List<ProductModel> catalog,
    AIChatWorkerReplyContext workerReply, {
    required bool pruneHistoricalBotMessages,
  }) async {
    if (workerReply.reply != null) {
      return workerReply;
    }

    final failureReasonCode =
        workerReply.failureReasonCode ?? 'worker_unavailable';
    _logDebug(
      'AI request failed, falling back locally | requestId=${incoming.requestId} | '
      'reasonCode=$failureReasonCode | '
      'hasLocalFallback=${recommendationContext.localFallbackAnswer != null} | '
      'isVague=${LocalIntentParser.isVague(incoming.trimmed)} | '
      'localReady=${discovery.localReadyForRecommendation} | localCandidates=${recommendationContext.localCandidatesRefs.length}',
    );
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'request_model_error',
        sessionId: incoming.activeSessionId,
        metadata: {
          'ai_mode': _currentAiModeTelemetryValue(),
          'issueCode': 'worker_unavailable',
          'reasonCode': failureReasonCode,
          'fallback_reason': 'local_fallback_used',
        },
      ),
    );
    final localFallbackCandidates = _safeLocalFallbackCandidates(
      discovery.localPreferences,
      recommendationContext.localCandidatesRefs,
    );

    if (_looksLikeUnverifiedExternalReference(incoming.trimmed)) {
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: buildAvailabilityExternalLookupFailedMessage(
            incoming.responseLanguage,
            _externalReferenceLabel(incoming.trimmed),
          ),
          updatedPreferences: discovery.localPreferences,
        ),
        language: incoming.responseLanguage,
        source: 'external_lookup_failed_no_profile',
        issueCode: 'external_lookup_failed',
        reasonCode: 'external_profile_unverified',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        workerFailureReason: failureReasonCode,
      );
      return null;
    }

    if (recommendationContext.localFallbackAnswer != null) {
      final groundTruthPreferences = state.preferences.mergePatch(
        discovery.localPreferences,
      );
      final fallbackReply = AIChatReply.answer(
        answer: recommendationContext.localFallbackAnswer!,
        updatedPreferences: groundTruthPreferences,
      );
      final localFacts = recommendationContext.candidatesList.isNotEmpty
          ? recommendationContext.candidatesList
          : recommendationContext.localCandidatesRefs
                .map((candidate) => candidate.product)
                .toList(growable: false);
      final groundingDecision = _answerGroundingGuard.validate(
        reply: fallbackReply,
        localFacts: localFacts,
        effectivePreferences: groundTruthPreferences,
      );
      if (!groundingDecision.isAllowed) {
        unawaited(
          _aiChatRepo.logAIChatEvent(
            eventType: 'answer_grounding_blocked',
            sessionId: incoming.activeSessionId,
            metadata: {
              'source': 'local_fallback',
              'issueCode': groundingDecision.reasonCode,
              'requestId': incoming.requestId,
            },
          ),
        );
      } else {
        _replyHandler.handleAnswerReply(
          fallbackReply,
          language: incoming.responseLanguage,
          source: 'local_fallback',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
          workerFailureReason: failureReasonCode,
        );
        return null;
      }
    }

    if (discovery.localReadyForRecommendation &&
        localFallbackCandidates.isNotEmpty) {
      return AIChatWorkerReplyContext(
        reply: buildRecommendReplyFromLocalCandidates(
          localFallbackCandidates,
          updatedPreferences: discovery.localPreferences,
        ),
        responseSource: 'local_fallback',
        failureReasonCode: failureReasonCode,
      );
    }

    if (LocalIntentParser.isVague(incoming.trimmed)) {
      final shouldClarifyPerfumeRequest =
          LocalIntentParser.looksLikePerfumeRequest(
            incoming.trimmed,
            currentPreferences: discovery.localPreferences,
          );
      if (shouldClarifyPerfumeRequest) {
        final nextMissingSlot = nextUsefulAskSlot(
          discovery.localPreferences,
          discovery.localMissingSlots,
        );
        if (nextMissingSlot == null) {
          if (localFallbackCandidates.isNotEmpty) {
            return AIChatWorkerReplyContext(
              reply: buildRecommendReplyFromLocalCandidates(
                localFallbackCandidates,
                updatedPreferences: discovery.localPreferences,
              ),
              responseSource: 'local_fallback',
              failureReasonCode: failureReasonCode,
            );
          }
          final noMatchReason = _localNoMatchReason(discovery.localPreferences);
          _syncLastBudgetNoMatchContext(
            preferences: discovery.localPreferences,
            catalog: catalog,
            reasonCode: noMatchReason,
          );
          _replyHandler.replyWithFallback(
            buildNoMatchMessage(
              incoming.trimmed,
              discovery.localPreferences,
              catalog,
              incoming.responseLanguage,
              reasonCode: noMatchReason,
            ),
            language: incoming.responseLanguage,
            source: 'local_fallback',
            updatedPreferences: discovery.localPreferences,
            isNoMatch: true,
            issueCode: 'no_candidate_match',
            reasonCode: 'no_candidate_match',
            sessionId: incoming.activeSessionId,
            requestId: incoming.requestId,
            pruneHistoricalBotMessages: pruneHistoricalBotMessages,
            workerFailureReason: failureReasonCode,
          );
          return null;
        }
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question: buildQuestionForMissingSlot(
              nextMissingSlot,
              incoming.responseLanguage,
            ),
            updatedPreferences: discovery.localPreferences,
          ),
          language: incoming.responseLanguage,
          source: 'local_fallback',
          issueCode: 'needs_clarification',
          reasonCode: 'vague_perfume_request',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
          workerFailureReason: failureReasonCode,
        );
        return null;
      }

      _replyHandler.replyWithFallback(
        buildVagueInputFallbackText(incoming.responseLanguage),
        language: incoming.responseLanguage,
        source: 'local_fallback',
        issueCode: 'vague_input',
        reasonCode: 'vague_input',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        workerFailureReason: failureReasonCode,
      );
      return null;
    }

    if (!discovery.localReadyForRecommendation) {
      final nextMissingSlot = nextUsefulAskSlot(
        discovery.localPreferences,
        discovery.localMissingSlots,
      );
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: buildQuestionForMissingSlot(
            nextMissingSlot,
            incoming.responseLanguage,
          ),
          updatedPreferences: discovery.localPreferences,
        ),
        language: incoming.responseLanguage,
        source: 'local_fallback',
        issueCode: 'insufficient_criteria',
        reasonCode: 'insufficient_criteria',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        workerFailureReason: failureReasonCode,
      );
      return null;
    }

    if (localFallbackCandidates.isEmpty) {
      final noMatchReason = _localNoMatchReason(discovery.localPreferences);
      _syncLastBudgetNoMatchContext(
        preferences: discovery.localPreferences,
        catalog: catalog,
        reasonCode: noMatchReason,
      );
      _replyHandler.replyWithFallback(
        buildNoMatchMessage(
          incoming.trimmed,
          discovery.localPreferences,
          catalog,
          incoming.responseLanguage,
          reasonCode: noMatchReason,
        ),
        language: incoming.responseLanguage,
        source: 'local_fallback',
        updatedPreferences: discovery.localPreferences,
        isNoMatch: true,
        issueCode: 'no_candidate_match',
        reasonCode: 'no_candidate_match',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        workerFailureReason: failureReasonCode,
      );
      return null;
    }

    return AIChatWorkerReplyContext(
      reply: buildRecommendReplyFromLocalCandidates(
        localFallbackCandidates,
        updatedPreferences: discovery.localPreferences,
      ),
      responseSource: 'local_fallback',
      failureReasonCode: failureReasonCode,
    );
  }

  List<RecommendedProduct> _safeLocalFallbackCandidates(
    SessionPreferences preferences,
    List<RecommendedProduct> candidates,
  ) {
    if (candidates.isEmpty) return candidates;
    if (!_requiresStrictCampusFallback(preferences)) return candidates;

    final safe = candidates
        .where((candidate) {
          final product = candidate.product;
          final time = product.time.trim().toLowerCase();
          final intensity = product.intensity.trim().toLowerCase();
          final occasion = product.occasion.trim().toLowerCase();
          final season = product.season.trim().toLowerCase();
          final gender = product.gender.trim().toLowerCase();
          final requestedGender = preferences.gender?.trim().toLowerCase();
          final searchable = [
            product.fragranceFamily,
            product.description,
            ...product.notes,
            ...product.topNotes,
            ...product.middleNotes,
            ...product.baseNotes,
            ...product.tags,
          ].join(' ').toLowerCase();

          final genderOk =
              requestedGender == null ||
              requestedGender == 'unisex' ||
              gender.isEmpty ||
              gender == requestedGender ||
              gender == 'unisex';
          final timeOk =
              time == 'day' || time == 'all_day' || time == 'all day';
          final intensityOk =
              intensity == 'light' ||
              intensity == 'soft' ||
              intensity == 'medium' ||
              intensity.isEmpty;
          final occasionOk =
              occasion == 'university' ||
              occasion == 'office' ||
              occasion == 'daily' ||
              occasion == 'casual' ||
              occasion.isEmpty;
          final scentOk =
              searchable.contains('fresh') ||
              searchable.contains('clean') ||
              searchable.contains('citrus') ||
              searchable.contains('musk') ||
              searchable.contains('aquatic');
          final avoidsCampusMismatch = time != 'night' && season != 'winter';

          return genderOk &&
              timeOk &&
              intensityOk &&
              occasionOk &&
              scentOk &&
              avoidsCampusMismatch;
        })
        .toList(growable: false);

    return safe;
  }

  bool _looksLikeUnverifiedExternalReference(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    return normalized.contains('something like') ||
        normalized.contains('similar to') ||
        normalized.contains('like a perfume') ||
        normalized.contains('like fragrance') ||
        normalized.contains('scent profile') ||
        normalized.contains('شبه عطر') ||
        normalized.contains('شبه برفان') ||
        normalized.contains('زي عطر') ||
        normalized.contains('زى عطر');
  }

  String _externalReferenceLabel(String message) {
    var value = message.trim();
    final replacements = <String>[
      'Something like',
      'something like',
      'Similar to',
      'similar to',
      'like a perfume called',
      'like a fragrance called',
      'called',
    ];
    for (final phrase in replacements) {
      value = value.replaceFirst(phrase, '').trim();
    }
    return value.isEmpty ? message.trim() : value;
  }

  bool _requiresStrictCampusFallback(SessionPreferences preferences) {
    final occasion = preferences.occasion?.trim().toLowerCase();
    final time = preferences.time?.trim().toLowerCase();
    final intensity = preferences.intensity?.trim().toLowerCase();
    final tags = preferences.tags.map((tag) => tag.toLowerCase()).toSet();

    final campusContext =
        occasion == 'university' ||
        tags.contains('university') ||
        tags.contains('campus');
    final lightContext =
        intensity == 'light' ||
        tags.contains('fresh') ||
        tags.contains('clean') ||
        time == 'all_day' ||
        time == 'all day' ||
        time == 'day';
    return campusContext && lightContext;
  }

  Future<void> _renderFinalReply(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery,
    AIChatRecommendationContext recommendationContext,
    AIChatWorkerReplyContext workerReply,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final reply = workerReply.reply!;
    final responseSource = workerReply.responseSource;
    final workerFailureReason = workerReply.failureReasonCode;
    final effectivePruneHistoricalBotMessages = pruneHistoricalBotMessages;
    final requestedProductLimit =
        AIChatLocalCatalogCommandHandler.requestedPickLimit(
          LocalIntentParser.normalizeInput(incoming.trimmed),
        );
    List<RecommendedProduct> applyRequestedProductLimit(
      List<RecommendedProduct> products,
    ) {
      if (products.length <= requestedProductLimit) return products;
      return products.take(requestedProductLimit).toList(growable: false);
    }

    _logDebug(
      'Rendering final reply | requestId=${incoming.requestId} | source=$responseSource | '
      'type=${reply.isAsk
          ? "ask"
          : reply.isAnswer
          ? "answer"
          : reply.isToolCall
          ? "tool_call"
          : "recommend"}',
    );

    if (reply.isToolCall) {
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'semantic_router_tool_call_received',
          sessionId: incoming.activeSessionId,
          metadata: {
            'ai_mode': _currentAiModeTelemetryValue(),
            'requestId': incoming.requestId,
            'source': responseSource,
            'toolRouterEnabled': AIChatExperimentConfig.toolRouterV1,
            'toolCallName': reply.toolCall?.name.name,
            'toolConfidence': reply.toolCall?.confidence,
            'candidateCount': recommendationContext.candidatesList.length,
            'visibleProductCount': incoming
                .effectiveRecommendationMemory
                .lastRecommendedProducts
                .length,
            'hasFocusedProduct':
                incoming.effectiveRecommendationMemory.lastFocusedProductId !=
                null,
            'hasLastNoMatch':
                incoming.effectiveRecommendationMemory.lastNoMatchContext !=
                null,
          },
        ),
      );
      if (!AIChatExperimentConfig.toolRouterV1) {
        unawaited(
          _aiChatRepo.logAIChatEvent(
            eventType: 'semantic_tool_rejected',
            sessionId: incoming.activeSessionId,
            metadata: {
              'ai_mode': _currentAiModeTelemetryValue(),
              'requestId': incoming.requestId,
              'toolCallName': reply.toolCall?.name.name,
              'reasonCode': 'tool_router_disabled',
            },
          ),
        );
        _replyHandler.replyWithFallback(
          buildNoMatchMessage(
            incoming.trimmed,
            recommendationContext.effectivePreferences,
            catalog,
            incoming.responseLanguage,
            reasonCode: 'tool_router_disabled',
          ),
          language: incoming.responseLanguage,
          source: '${responseSource}_tool_router_disabled',
          updatedPreferences: recommendationContext.effectivePreferences,
          isNoMatch: true,
          issueCode: 'tool_router_disabled',
          reasonCode: 'tool_router_disabled',
          sessionId: incoming.activeSessionId,
          requestId: incoming.requestId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }
      final toolRecommendationMemory =
          incoming.effectiveRecommendationMemory.lastExternalProfile == null &&
              state.recommendationMemory.lastExternalProfile != null
          ? state.recommendationMemory
          : incoming.effectiveRecommendationMemory;
      final toolPreferences =
          reply.toolCall?.name ==
                  AIChatToolName.similarCheaperToExternalProfile &&
              !BudgetAmountParser.containsBudgetNumber(incoming.trimmed)
          ? state.preferences
          : recommendationContext.effectivePreferences;
      final toolResult = await _toolExecutor.execute(
        reply: reply,
        catalog: catalog,
        currentPreferences: toolPreferences,
        language: incoming.responseLanguage,
        recommendationMemory: toolRecommendationMemory,
      );
      if (toolResult.updatedRecommendationMemory != null) {
        _applyToolRecommendationMemory(toolResult.updatedRecommendationMemory!);
      }
      _logDebug(
        'Tool execution result | requestId=${incoming.requestId} | '
        '${toolResult.toTraceJson()}',
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'semantic_tool_execution_result',
          sessionId: incoming.activeSessionId,
          metadata: {
            'ai_mode': _currentAiModeTelemetryValue(),
            'requestId': incoming.requestId,
            'toolCallName': reply.toolCall?.name.name,
            'toolStatus': toolResult.status.name,
            'toolAction': toolResult.action.name,
            'renderIntent': toolResult.renderIntent.name,
            'shouldRenderCards': toolResult.shouldRenderCards,
            'productCount': toolResult.productIds.length,
            'recommendationCount': toolResult.recommendations.length,
            'source': toolResult.source,
            if (toolResult.issueCode != null) 'issueCode': toolResult.issueCode,
            if (toolResult.reasonCode != null)
              'reasonCode': toolResult.reasonCode,
            if (toolResult.traceReason != null)
              'traceReason': toolResult.traceReason,
            if (toolResult.referenceQuery != null)
              'referenceQuery': toolResult.referenceQuery,
            if (toolResult.referenceStatus != null)
              'referenceStatus': toolResult.referenceStatus,
            if (toolResult.referenceSource != null)
              'referenceSource': toolResult.referenceSource,
            if (toolResult.selectedOptionIndex != null)
              'selectedOptionIndex': toolResult.selectedOptionIndex,
            if (toolResult.externalProfileId != null)
              'externalProfileId': toolResult.externalProfileId,
            if (toolResult.externalProfileConfidence != null)
              'externalProfileConfidence': toolResult.externalProfileConfidence,
            if (toolResult.cacheStatus != null)
              'cacheStatus': toolResult.cacheStatus,
          },
        ),
      );
      if (!toolResult.handled || toolResult.reply == null) {
        _analyticsTracker.record(
          eventType: 'tool_executed',
          requestId: incoming.requestId,
          sessionId: incoming.activeSessionId,
          language: incoming.responseLanguage,
          messageLength: incoming.trimmed.length,
          route: 'semantic_tool',
          action: toolResult.action.name,
          source: toolResult.source,
          toolName: reply.toolCall?.name.name ?? toolResult.tool,
          toolStatus: _analyticsToolStatus(toolResult.status),
          renderIntent: toolResult.renderIntent.name,
          workerUsed: true,
          productCount: toolResult.productIds.length,
          finalProductIds: toolResult.productIds,
          failureReason: toolResult.reasonCode ?? 'tool_execution_failed',
        );
        unawaited(
          _aiChatRepo.logAIChatEvent(
            eventType: 'semantic_tool_rejected',
            sessionId: incoming.activeSessionId,
            metadata: {
              'ai_mode': _currentAiModeTelemetryValue(),
              'requestId': incoming.requestId,
              'toolCallName': reply.toolCall?.name.name,
              'toolStatus': toolResult.status.name,
              'reasonCode': toolResult.reasonCode ?? 'tool_execution_failed',
            },
          ),
        );
        _replyHandler.replyWithFallback(
          buildNoMatchMessage(
            incoming.trimmed,
            recommendationContext.effectivePreferences,
            catalog,
            incoming.responseLanguage,
            reasonCode: toolResult.reasonCode ?? 'tool_execution_failed',
          ),
          language: incoming.responseLanguage,
          source: '${responseSource}_tool_execution_failed',
          updatedPreferences: recommendationContext.effectivePreferences,
          isNoMatch: true,
          issueCode: toolResult.issueCode ?? 'tool_execution_failed',
          reasonCode: toolResult.reasonCode ?? 'tool_execution_failed',
          sessionId: incoming.activeSessionId,
          requestId: incoming.requestId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }
      if (toolResult.reply!.isAnswer) {
        _analyticsTracker.record(
          eventType: 'tool_executed',
          requestId: incoming.requestId,
          sessionId: incoming.activeSessionId,
          language: incoming.responseLanguage,
          messageLength: incoming.trimmed.length,
          route: 'semantic_tool',
          action: toolResult.action.name,
          source: toolResult.source,
          toolName: reply.toolCall?.name.name ?? toolResult.tool,
          toolStatus: _analyticsToolStatus(toolResult.status),
          renderIntent: toolResult.renderIntent.name,
          workerUsed: true,
          productCount: toolResult.productIds.length,
          finalProductIds: toolResult.productIds,
        );
        _replyHandler.handleAnswerReply(
          toolResult.reply!,
          language: incoming.responseLanguage,
          source: toolResult.source,
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }
      if (toolResult.reply!.isAsk) {
        _analyticsTracker.record(
          eventType: 'tool_executed',
          requestId: incoming.requestId,
          sessionId: incoming.activeSessionId,
          language: incoming.responseLanguage,
          messageLength: incoming.trimmed.length,
          route: 'semantic_tool',
          action: toolResult.action.name,
          source: toolResult.source,
          toolName: reply.toolCall?.name.name ?? toolResult.tool,
          toolStatus: _analyticsToolStatus(toolResult.status),
          renderIntent: toolResult.renderIntent.name,
          workerUsed: true,
          productCount: toolResult.productIds.length,
          finalProductIds: toolResult.productIds,
          clarificationType: toolResult.reasonCode,
        );
        _replyHandler.handleAskReply(
          toolResult.reply!,
          language: incoming.responseLanguage,
          source: toolResult.source,
          issueCode: toolResult.issueCode,
          reasonCode: toolResult.reasonCode,
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }
      final guardResult = FinalRecommendationGuard(translate: _t).guard(
        reply: toolResult.reply!,
        catalog: catalog,
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: toolResult.recommendations,
          candidatesList: toolResult.recommendations
              .map((item) => item.product)
              .toList(growable: false),
          localFallbackAnswer: null,
          budgetPolicy: recommendationContext.budgetPolicy,
          effectivePreferences: toolResult.preferences,
        ),
        language: incoming.responseLanguage,
        responseSource: toolResult.source,
      );
      _logDecisionTrace(
        incoming,
        AIChatDecisionTrace(
          toolRouterEnabled: AIChatExperimentConfig.toolRouterV1,
          toolCallName: reply.toolCall?.name.name,
          toolCallValid: reply.toolCall != null,
          toolExecutionSource: toolResult.source,
          catalogSearchEngineEnabled:
              AIChatExperimentConfig.useCatalogSearchEngine,
          suitabilityPolicyEnabled: AIChatExperimentConfig.useSuitabilityPolicy,
          candidateCountBeforeGuard: toolResult.recommendations.length,
          candidateCountAfterGuard: guardResult.safeProducts.isNotEmpty
              ? guardResult.safeProducts.length
              : guardResult.localRecoveryProducts.length,
          finalGuardDecision: guardResult.shouldNoMatch
              ? 'no_match'
              : guardResult.safeProducts.isNotEmpty
              ? 'safe_products'
              : 'local_recovery',
          blockedReasons: [
            if (guardResult.issueCode != null) guardResult.issueCode!,
            if (guardResult.reasonCode != null) guardResult.reasonCode!,
          ],
        ),
        phase: 'tool_call_guarded',
      );
      final products = applyRequestedProductLimit(
        _applySuitabilityPolicyToRecommendations(
          guardResult.safeProducts.isNotEmpty
              ? guardResult.safeProducts
              : guardResult.localRecoveryProducts,
          preferences: toolResult.preferences,
          hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(
            incoming.trimmed,
          ),
          sourcePath: toolResult.source,
        ),
      );
      _logDecisionTrace(
        incoming,
        AIChatDecisionTrace(
          toolRouterEnabled: AIChatExperimentConfig.toolRouterV1,
          toolCallName: reply.toolCall?.name.name,
          toolCallValid: reply.toolCall != null,
          toolExecutionSource: toolResult.source,
          catalogSearchEngineEnabled:
              AIChatExperimentConfig.useCatalogSearchEngine,
          suitabilityPolicyEnabled: AIChatExperimentConfig.useSuitabilityPolicy,
          candidateCountBeforeGuard: toolResult.recommendations.length,
          candidateCountAfterGuard: products.length,
          finalGuardDecision: products.isEmpty ? 'no_match' : 'render',
          finalProductIds: products
              .map((item) => item.product.id)
              .toList(growable: false),
          blockedReasons: [
            if (guardResult.issueCode != null) guardResult.issueCode!,
            if (guardResult.reasonCode != null) guardResult.reasonCode!,
            if (products.isEmpty) 'empty_after_guard_or_suitability',
          ],
        ),
        phase: 'tool_call_final',
      );
      _analyticsTracker.record(
        eventType: 'tool_executed',
        requestId: incoming.requestId,
        sessionId: incoming.activeSessionId,
        language: incoming.responseLanguage,
        messageLength: incoming.trimmed.length,
        route: 'semantic_tool',
        action: toolResult.action.name,
        source: toolResult.source,
        toolName: reply.toolCall?.name.name ?? toolResult.tool,
        toolStatus: _analyticsToolStatus(toolResult.status),
        renderIntent: toolResult.renderIntent.name,
        workerUsed: true,
        productCount: products.length,
        finalProductIds: products
            .map((item) => item.product.id)
            .toList(growable: false),
        guardBlockedCount: (toolResult.recommendations.length - products.length)
            .clamp(0, 999)
            .toInt(),
        failureReason: products.isEmpty
            ? guardResult.reasonCode ?? 'empty_after_guard_or_suitability'
            : null,
      );
      if (products.isEmpty) {
        _replyHandler.replyWithFallback(
          buildNoMatchMessage(
            incoming.trimmed,
            toolResult.preferences,
            catalog,
            incoming.responseLanguage,
            reasonCode: guardResult.reasonCode,
          ),
          language: incoming.responseLanguage,
          source: '${toolResult.source}_no_match',
          updatedPreferences: toolResult.preferences,
          isNoMatch: true,
          issueCode: guardResult.issueCode ?? 'no_candidate_match',
          reasonCode: guardResult.reasonCode ?? 'no_candidate_match',
          sessionId: incoming.activeSessionId,
          requestId: incoming.requestId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }
      _replyHandler.handleRecommendationReply(
        toolResult.reply!,
        products,
        language: incoming.responseLanguage,
        source: toolResult.source,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
        workerFailureReason: workerFailureReason,
      );
      return;
    }

    _logDebug(
      'Rendering non-tool reply | requestId=${incoming.requestId} | source=$responseSource | '
      'type=${reply.isAsk
          ? "ask"
          : reply.isAnswer
          ? "answer"
          : "recommend"}',
    );

    if (reply.isAnswer) {
      var answerReply = reply;
      var answerResponseSource = responseSource;
      if (_shouldBlockWorkerMojibake(
        text: answerReply.answer ?? '',
        language: incoming.responseLanguage,
        responseSource: responseSource,
      )) {
        answerReply = AIChatReply.answer(
          answer: _safeWorkerTextFallback(incoming.responseLanguage),
          updatedPreferences: answerReply.updatedPreferences,
          requestId: answerReply.requestId,
          promptVersion: answerReply.promptVersion,
          provider: answerReply.provider,
          modelId: answerReply.modelId,
          preferencePatch: answerReply.preferencePatch,
        );
        answerResponseSource = 'ai_worker_mojibake_blocked';
      }
      final groundTruthPreferences = state.preferences
          .mergePatch(discovery.localPreferences)
          .mergePatch(answerReply.updatedPreferences);
      final noSafeRecovery = _tryHumanNoSafeRecovery(
        incoming: incoming,
        discovery: discovery,
        recommendationContext: recommendationContext,
        reply: answerReply,
        catalog: catalog,
        responseSource: answerResponseSource,
        workerFailureReason: workerFailureReason,
        pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
        applyRequestedProductLimit: applyRequestedProductLimit,
      );
      if (noSafeRecovery) return;

      final askedSlot = inferAskedSlot(answerReply.answer ?? '');
      final stateAlreadyHasSlot =
          askedSlot != null &&
          isSlotAlreadyFilled(state.preferences, askedSlot);
      if (stateAlreadyHasSlot) {
        final exactCandidates = LocalCandidateFilter.getTopRecommendations(
          catalog: catalog,
          preferences: groundTruthPreferences,
        );
        final upsellCandidates =
            recommendationContext.budgetPolicy == AIChatBudgetPolicy.flexible
            ? LocalCandidateFilter.getTopUpsellRecommendations(
                catalog: catalog,
                preferences: groundTruthPreferences,
              )
            : const <RecommendedProduct>[];
        final recoveryProducts = [
          ...exactCandidates,
          ...upsellCandidates.where(
            (upsell) => !exactCandidates.any(
              (exact) => exact.product.id == upsell.product.id,
            ),
          ),
        ];

        if (recoveryProducts.isNotEmpty) {
          final limitedRecoveryProducts = applyRequestedProductLimit(
            recoveryProducts,
          );
          _replyHandler.handleRecommendationReply(
            buildRecommendReplyFromLocalCandidates(
              limitedRecoveryProducts,
              updatedPreferences: groundTruthPreferences,
              requestId: answerReply.requestId,
              promptVersion: answerReply.promptVersion,
              provider: answerReply.provider,
              modelId: answerReply.modelId,
            ),
            limitedRecoveryProducts,
            language: incoming.responseLanguage,
            source: '${answerResponseSource}_answer_filled_slot_recovery',
            sessionId: incoming.activeSessionId,
            pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
            workerFailureReason: workerFailureReason,
          );
          return;
        }

        final noMatchReason = AIChatRecommendationResolver.localNoMatchReason(
          groundTruthPreferences,
        );
        _syncLastBudgetNoMatchContext(
          preferences: groundTruthPreferences,
          catalog: catalog,
          reasonCode: noMatchReason,
        );
        _replyHandler.replyWithFallback(
          buildNoMatchMessage(
            incoming.trimmed,
            groundTruthPreferences,
            catalog,
            incoming.responseLanguage,
            reasonCode: noMatchReason,
          ),
          language: incoming.responseLanguage,
          source: '${answerResponseSource}_answer_filled_slot_no_match',
          updatedPreferences: groundTruthPreferences,
          isNoMatch: true,
          issueCode: 'filled_slot_no_candidate',
          reasonCode: noMatchReason,
          sessionId: incoming.activeSessionId,
          requestId: incoming.requestId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }

      if (answerResponseSource != 'forced_answer') {
        final localFacts = recommendationContext.candidatesList.isNotEmpty
            ? recommendationContext.candidatesList
            : recommendationContext.localCandidatesRefs
                  .map((candidate) => candidate.product)
                  .toList(growable: false);
        final groundingDecision = _answerGroundingGuard.validate(
          reply: answerReply,
          localFacts: localFacts,
          effectivePreferences: groundTruthPreferences,
        );
        if (!groundingDecision.isAllowed) {
          unawaited(
            _aiChatRepo.logAIChatEvent(
              eventType: 'answer_grounding_blocked',
              sessionId: incoming.activeSessionId,
              metadata: {
                'source': answerResponseSource,
                'issueCode': groundingDecision.reasonCode,
                'requestId': incoming.requestId,
              },
            ),
          );

          final localFallbackAnswer = recommendationContext.localFallbackAnswer;
          if (localFallbackAnswer != null) {
            _replyHandler.handleAnswerReply(
              AIChatReply.answer(
                answer: localFallbackAnswer,
                updatedPreferences: groundTruthPreferences,
                requestId: answerReply.requestId,
                promptVersion: answerReply.promptVersion,
                provider: answerReply.provider,
                modelId: answerReply.modelId,
              ),
              language: incoming.responseLanguage,
              source: '${answerResponseSource}_grounded_recovery',
              sessionId: incoming.activeSessionId,
              pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
              workerFailureReason: workerFailureReason,
            );
            return;
          }

          _replyHandler.handleAskReply(
            AIChatReply.ask(
              question: _t(
                incoming.responseLanguage,
                ar: 'أقدر أجاوب بدقة من المنتجات الظاهرة. تقصد أي منتج تحديدًا؟',
                en: 'I can answer accurately from the products shown. Which product do you mean?',
              ),
              updatedPreferences: answerReply.updatedPreferences,
              requestId: answerReply.requestId,
              promptVersion: answerReply.promptVersion,
              provider: answerReply.provider,
              modelId: answerReply.modelId,
            ),
            language: incoming.responseLanguage,
            source: '${answerResponseSource}_grounding_blocked',
            issueCode: groundingDecision.reasonCode,
            reasonCode: groundingDecision.reasonCode,
            sessionId: incoming.activeSessionId,
            pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
            workerFailureReason: workerFailureReason,
          );
          return;
        }
      }

      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: answerReply.answer ?? '',
          updatedPreferences: groundTruthPreferences,
          requestId: answerReply.requestId,
          promptVersion: answerReply.promptVersion,
          provider: answerReply.provider,
          modelId: answerReply.modelId,
          preferencePatch: answerReply.preferencePatch,
        ),
        language: incoming.responseLanguage,
        source: answerResponseSource,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
        workerFailureReason: workerFailureReason,
      );
      return;
    }

    if (reply.isAsk) {
      // Hard guard: never show an ask about an already-filled slot.
      // state.preferences is the ground-truth accumulated preferences from
      // the cubit. If the Worker asks about a slot that is already known in
      // state.preferences, we MUST convert it to either a recommendation or
      // a no-match; never let the redundant ask reach the user.
      final askedSlot = inferAskedSlot(reply.question ?? '');
      final stateAlreadyHasSlot =
          askedSlot != null &&
          isSlotAlreadyFilled(state.preferences, askedSlot);

      _logDebug(
        'Ask guard check | askedSlot=$askedSlot | '
        'stateAlreadyHasSlot=$stateAlreadyHasSlot | '
        'stateGender=${state.preferences.gender} | '
        'stateSeason=${state.preferences.season} | '
        'stateBudget=${state.preferences.maxBudget} | '
        'replyGender=${reply.updatedPreferences.gender} | '
        'localCandidatesCount=${recommendationContext.localCandidatesRefs.length} | '
        'requestId=${incoming.requestId}',
      );

      // Step 1: standard ask recovery (existing logic).
      final askRecoveryProducts = _buildAskRecoveryProducts(
        reply.updatedPreferences,
        recommendationContext,
        discovery.effectiveHasRecommendationContext,
      );
      if (askRecoveryProducts.isNotEmpty) {
        final limitedAskRecoveryProducts = applyRequestedProductLimit(
          askRecoveryProducts,
        );
        _logPostLlmRecommendationRoute(
          incoming,
          responseSource: responseSource,
          finalGuardDecision: 'ask_recovery',
          productIds: limitedAskRecoveryProducts
              .map((item) => item.product.id)
              .toList(growable: false),
        );
        _replyHandler.handleRecommendationReply(
          buildRecommendReplyFromLocalCandidates(
            limitedAskRecoveryProducts,
            updatedPreferences: reply.updatedPreferences,
            requestId: reply.requestId,
            promptVersion: reply.promptVersion,
            provider: reply.provider,
            modelId: reply.modelId,
          ),
          limitedAskRecoveryProducts,
          language: incoming.responseLanguage,
          source: '${responseSource}_ask_recovery',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }

      // Step 2: if the ask targets an already-filled slot, use ground-truth
      // preferences from state (not reply) to find candidates.
      if (stateAlreadyHasSlot) {
        final groundTruthPreferences = state.preferences.mergePatch(
          reply.updatedPreferences,
        );
        // Try with full catalog (not just pre-filtered candidates).
        final safetyNetProducts = LocalCandidateFilter.getTopRecommendations(
          catalog: catalog,
          preferences: groundTruthPreferences,
        );
        if (safetyNetProducts.isNotEmpty) {
          final limitedSafetyNetProducts = applyRequestedProductLimit(
            safetyNetProducts,
          );
          _logDebug(
            'Hard guard: recovery with ground-truth prefs | '
            'askedSlot=$askedSlot | '
            'candidateCount=${limitedSafetyNetProducts.length} | '
            'requestId=${incoming.requestId}',
          );
          _logPostLlmRecommendationRoute(
            incoming,
            responseSource: responseSource,
            finalGuardDecision: 'filled_slot_recovery',
            productIds: limitedSafetyNetProducts
                .map((item) => item.product.id)
                .toList(growable: false),
          );
          _replyHandler.handleRecommendationReply(
            buildRecommendReplyFromLocalCandidates(
              limitedSafetyNetProducts,
              updatedPreferences: groundTruthPreferences,
              requestId: reply.requestId,
              promptVersion: reply.promptVersion,
              provider: reply.provider,
              modelId: reply.modelId,
            ),
            limitedSafetyNetProducts,
            language: incoming.responseLanguage,
            source: '${responseSource}_filled_slot_recovery',
            sessionId: incoming.activeSessionId,
            pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
            workerFailureReason: workerFailureReason,
          );
          return;
        }

        // Step 3: still no candidates; show no-match instead of the
        // redundant ask. This is better UX than re-asking a known slot.
        final noMatchReason = AIChatRecommendationResolver.localNoMatchReason(
          groundTruthPreferences,
        );
        _syncLastBudgetNoMatchContext(
          preferences: groundTruthPreferences,
          catalog: catalog,
          reasonCode: noMatchReason,
        );
        _logDebug(
          'Hard guard: no candidates for filled slot, showing no-match | '
          'askedSlot=$askedSlot | noMatchReason=$noMatchReason | '
          'requestId=${incoming.requestId}',
        );
        _replyHandler.replyWithFallback(
          buildNoMatchMessage(
            incoming.trimmed,
            groundTruthPreferences,
            catalog,
            incoming.responseLanguage,
            reasonCode: noMatchReason,
          ),
          language: incoming.responseLanguage,
          source: '${responseSource}_filled_slot_no_match',
          updatedPreferences: groundTruthPreferences,
          isNoMatch: true,
          issueCode: 'filled_slot_no_candidate',
          reasonCode: noMatchReason,
          sessionId: incoming.activeSessionId,
          requestId: incoming.requestId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }

      // Step 4: ask is about an unfilled slot; allow it through.
      if (looksLikeGenericPreferenceAsk(reply.question ?? '')) {
        final effectivePreferences = state.preferences
            .mergePatch(discovery.localPreferences)
            .mergePatch(reply.updatedPreferences);
        final canRecommendFromEffectivePreferences =
            effectivePreferences.canRecommendInitial ||
            effectivePreferences.canRecommendPracticalInitial ||
            effectivePreferences.canRefineExistingRecommendation(
              hasRecommendationContext:
                  discovery.effectiveHasRecommendationContext,
            );
        if (canRecommendFromEffectivePreferences) {
          final genericAskRecoveryProducts =
              LocalCandidateFilter.getTopRecommendations(
                catalog: catalog,
                preferences: effectivePreferences,
              );
          if (genericAskRecoveryProducts.isNotEmpty) {
            final limitedGenericAskRecoveryProducts =
                applyRequestedProductLimit(genericAskRecoveryProducts);
            _logPostLlmRecommendationRoute(
              incoming,
              responseSource: responseSource,
              finalGuardDecision: 'generic_ask_recovery',
              productIds: limitedGenericAskRecoveryProducts
                  .map((item) => item.product.id)
                  .toList(growable: false),
            );
            _replyHandler.handleRecommendationReply(
              buildRecommendReplyFromLocalCandidates(
                limitedGenericAskRecoveryProducts,
                updatedPreferences: effectivePreferences,
                requestId: reply.requestId,
                promptVersion: reply.promptVersion,
                provider: reply.provider,
                modelId: reply.modelId,
              ),
              limitedGenericAskRecoveryProducts,
              language: incoming.responseLanguage,
              source: '${responseSource}_generic_ask_recovery',
              sessionId: incoming.activeSessionId,
              pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
              workerFailureReason: workerFailureReason,
            );
            return;
          }
        }

        final missingSlots = effectivePreferences.missingSlotsForNextQuestion(
          hasRecommendationContext: discovery.effectiveHasRecommendationContext,
        );
        final retargetSlot = nextUsefulAskSlot(
          effectivePreferences,
          missingSlots,
        );
        if (retargetSlot != null) {
          _replyHandler.handleAskReply(
            AIChatReply.ask(
              question: buildQuestionForMissingSlot(
                retargetSlot,
                incoming.responseLanguage,
              ),
              updatedPreferences: effectivePreferences,
              requestId: reply.requestId,
              promptVersion: reply.promptVersion,
              provider: reply.provider,
              modelId: reply.modelId,
            ),
            language: incoming.responseLanguage,
            source: '${responseSource}_targeted_ask',
            sessionId: incoming.activeSessionId,
            pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
            workerFailureReason: workerFailureReason,
          );
          return;
        }
      }

      var finalAskReply = reply;
      var finalAskSource = responseSource;
      if (_shouldBlockWorkerMojibake(
        text: reply.question ?? '',
        language: incoming.responseLanguage,
        responseSource: responseSource,
      )) {
        final effectivePreferences = state.preferences
            .mergePatch(discovery.localPreferences)
            .mergePatch(reply.updatedPreferences);
        finalAskReply = AIChatReply.ask(
          question: _humanClarificationQuestion(
            effectivePreferences,
            incoming.responseLanguage,
            hasRecommendationContext:
                discovery.effectiveHasRecommendationContext,
          ),
          updatedPreferences: effectivePreferences,
          requestId: reply.requestId,
          promptVersion: reply.promptVersion,
          provider: reply.provider,
          modelId: reply.modelId,
          preferencePatch: reply.preferencePatch,
        );
        finalAskSource = 'ai_worker_mojibake_blocked';
      }

      _replyHandler.handleAskReply(
        finalAskReply,
        language: incoming.responseLanguage,
        source: finalAskSource,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
        workerFailureReason: workerFailureReason,
      );
      return;
    }

    _logDebug(
      'AI reply details | requestId=${incoming.requestId} | action=${reply.isAsk ? "ASK" : "RECOMMEND"} | '
      'productIds=${reply.productIds} | matchReasons=${reply.matchReasons} | '
      'updatedPrefs=${reply.updatedPreferences.toJson()}',
    );

    final guardResult =
        FinalRecommendationGuard(
          translate: _t,
          logEvent: (eventType, metadata) {
            return _aiChatRepo.logAIChatEvent(
              eventType: eventType,
              sessionId: incoming.activeSessionId,
              metadata: {...metadata, 'requestId': incoming.requestId},
            );
          },
        ).guard(
          reply: reply,
          catalog: catalog,
          recommendationContext: recommendationContext,
          language: incoming.responseLanguage,
          responseSource: responseSource,
        );
    final recommendedProducts = applyRequestedProductLimit(
      _applySuitabilityPolicyToRecommendations(
        guardResult.safeProducts,
        preferences: recommendationContext.effectivePreferences.mergePatch(
          reply.updatedPreferences,
        ),
        hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(
          incoming.trimmed,
        ),
        sourcePath: responseSource,
      ),
    );

    _logDebug(
      'Final recommended products count | requestId=${incoming.requestId} | '
      'workerRawProductIds=${reply.productIds} | '
      'postGuardProductIds=${recommendedProducts.map((item) => item.product.id).toList()} | '
      'localRecoveryProductIds=${guardResult.localRecoveryProducts.map((item) => item.product.id).toList()} | '
      'safeCandidateCount=${recommendationContext.localCandidatesRefs.length} | '
      'count=${recommendedProducts.length}',
    );
    if (recommendedProducts.isEmpty) {
      final localFallbackProducts = applyRequestedProductLimit(
        _applySuitabilityPolicyToRecommendations(
          guardResult.localRecoveryProducts,
          preferences: recommendationContext.effectivePreferences.mergePatch(
            reply.updatedPreferences,
          ),
          hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(
            incoming.trimmed,
          ),
          sourcePath: '${responseSource}_local_recovery',
        ),
      );
      if (localFallbackProducts.isNotEmpty) {
        _replyHandler.handleRecommendationReply(
          buildRecommendReplyFromLocalCandidates(
            localFallbackProducts,
            updatedPreferences: reply.updatedPreferences,
            requestId: reply.requestId,
            promptVersion: reply.promptVersion,
            provider: reply.provider,
            modelId: reply.modelId,
          ),
          localFallbackProducts,
          language: incoming.responseLanguage,
          source: '${responseSource}_local_recovery',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
          workerFailureReason: workerFailureReason,
        );
        return;
      }

      final recovered = _renderHumanClarificationOrRecovery(
        incoming: incoming,
        discovery: discovery,
        recommendationContext: recommendationContext,
        catalog: catalog,
        preferences: reply.updatedPreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        responseSource: responseSource,
        workerFailureReason: workerFailureReason,
        pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
        applyRequestedProductLimit: applyRequestedProductLimit,
      );
      if (recovered) return;

      _replyHandler.replyWithFallback(
        buildNoMatchMessage(
          incoming.trimmed,
          reply.updatedPreferences,
          catalog,
          incoming.responseLanguage,
          reasonCode: _localNoMatchReason(reply.updatedPreferences),
        ),
        language: incoming.responseLanguage,
        source: responseSource,
        updatedPreferences: reply.updatedPreferences,
        isNoMatch: true,
        issueCode: 'no_candidate_match',
        reasonCode: 'no_candidate_match',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
        workerFailureReason: workerFailureReason,
      );
      return;
    }

    if (responseSource == 'ask_override') {
      _logPostLlmRecommendationRoute(
        incoming,
        responseSource: responseSource,
        finalGuardDecision: 'ask_override_recommend',
        productIds: recommendedProducts
            .map((item) => item.product.id)
            .toList(growable: false),
      );
    }

    _replyHandler.handleRecommendationReply(
      reply,
      recommendedProducts,
      language: incoming.responseLanguage,
      source: responseSource,
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: effectivePruneHistoricalBotMessages,
      workerFailureReason: workerFailureReason,
    );
  }

  bool _tryHumanNoSafeRecovery({
    required AIChatTurnContext incoming,
    required AIChatDiscoveryContext discovery,
    required AIChatRecommendationContext recommendationContext,
    required AIChatReply reply,
    required List<ProductModel> catalog,
    required String responseSource,
    required String? workerFailureReason,
    required bool pruneHistoricalBotMessages,
    required List<RecommendedProduct> Function(List<RecommendedProduct>)
    applyRequestedProductLimit,
  }) {
    if (!_looksLikeGenericNoSafeReply(reply.answer ?? '')) {
      return false;
    }
    final preferences = state.preferences
        .mergePatch(discovery.localPreferences)
        .mergePatch(reply.updatedPreferences);
    return _renderHumanClarificationOrRecovery(
      incoming: incoming,
      discovery: discovery,
      recommendationContext: recommendationContext,
      catalog: catalog,
      preferences: preferences,
      requestId: reply.requestId,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
      responseSource: responseSource,
      workerFailureReason: workerFailureReason,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      applyRequestedProductLimit: applyRequestedProductLimit,
    );
  }

  bool _renderHumanClarificationOrRecovery({
    required AIChatTurnContext incoming,
    required AIChatDiscoveryContext discovery,
    required AIChatRecommendationContext recommendationContext,
    required List<ProductModel> catalog,
    required SessionPreferences preferences,
    required String? requestId,
    required String? promptVersion,
    required String? provider,
    required String? modelId,
    required String responseSource,
    required String? workerFailureReason,
    required bool pruneHistoricalBotMessages,
    required List<RecommendedProduct> Function(List<RecommendedProduct>)
    applyRequestedProductLimit,
  }) {
    final contextualCandidates = _applySuitabilityPolicyToRecommendations(
      recommendationContext.localCandidatesRefs,
      preferences: preferences,
      hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(
        incoming.trimmed,
      ),
      sourcePath: '${responseSource}_human_recovery_context',
    );
    final exactCandidates = LocalCandidateFilter.getTopRecommendations(
      catalog: catalog,
      preferences: preferences,
    );
    final upsellCandidates =
        recommendationContext.budgetPolicy == AIChatBudgetPolicy.flexible
        ? LocalCandidateFilter.getTopUpsellRecommendations(
            catalog: catalog,
            preferences: preferences,
          )
        : const <RecommendedProduct>[];
    final fallbackSafeCandidates = [
      ...exactCandidates,
      ...upsellCandidates.where(
        (upsell) => !exactCandidates.any(
          (exact) => exact.product.id == upsell.product.id,
        ),
      ),
    ];
    final safeCandidates = contextualCandidates.isNotEmpty
        ? contextualCandidates
        : fallbackSafeCandidates;

    _logDebug(
      'Human clarification planner | requestId=${incoming.requestId} | '
      'safeCandidateCount=${safeCandidates.length} | '
      'contextualCandidateCount=${contextualCandidates.length} | '
      'fallbackCandidateCount=${fallbackSafeCandidates.length} | '
      'knownPrefsCount=${preferences.activeCriteriaCount} | '
      'workerRawSource=$responseSource',
    );

    if (safeCandidates.isNotEmpty && preferences.activeCriteriaCount >= 3) {
      final limitedProducts = applyRequestedProductLimit(safeCandidates);
      _replyHandler.handleRecommendationReply(
        buildRecommendReplyFromLocalCandidates(
          limitedProducts,
          updatedPreferences: preferences,
          requestId: requestId,
          promptVersion: promptVersion,
          provider: provider,
          modelId: modelId,
        ),
        limitedProducts,
        language: incoming.responseLanguage,
        source: 'ai_worker_safe_recovery',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        workerFailureReason: workerFailureReason,
      );
      return true;
    }

    if (safeCandidates.isNotEmpty && preferences.activeCriteriaCount < 3) {
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: _humanClarificationQuestion(
            preferences,
            incoming.responseLanguage,
            hasRecommendationContext:
                discovery.effectiveHasRecommendationContext,
          ),
          updatedPreferences: preferences,
          requestId: requestId,
          promptVersion: promptVersion,
          provider: provider,
          modelId: modelId,
        ),
        language: incoming.responseLanguage,
        source: '${responseSource}_human_clarification',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        workerFailureReason: workerFailureReason,
      );
      return true;
    }

    _replyHandler.replyWithFallback(
      _humanNoMatchText(incoming.responseLanguage),
      language: incoming.responseLanguage,
      source: '${responseSource}_human_no_match',
      updatedPreferences: preferences,
      isNoMatch: true,
      issueCode: 'no_candidate_match',
      reasonCode: AIChatRecommendationResolver.localNoMatchReason(preferences),
      sessionId: incoming.activeSessionId,
      requestId: incoming.requestId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      workerFailureReason: workerFailureReason,
    );
    return true;
  }

  bool _shouldBlockWorkerMojibake({
    required String text,
    required AIChatLanguage language,
    required String responseSource,
  }) {
    if (language != AIChatLanguage.arabic) return false;
    if (!responseSource.contains('ai_worker')) return false;
    return _looksLikeMojibake(text);
  }

  bool _looksLikeMojibake(String text) {
    const markers = [
      '\u0429',
      '\u00d0',
      '\u00d8',
      '\u00d9',
      '\u00c3',
      '\ufffd',
    ];
    return markers.any(text.contains) ||
        text.contains(String.fromCharCodes(const [63, 63, 63, 63]));
  }

  String _safeWorkerTextFallback(AIChatLanguage language) {
    return _t(
      language,
      ar: '\u062a\u0645\u0627\u0645\u060c \u0641\u0647\u0645\u062a \u0637\u0644\u0628\u0643. \u0647\u0631\u0627\u062c\u0639 \u0627\u0644\u062a\u0641\u0636\u064a\u0644\u0627\u062a \u0627\u0644\u062d\u0627\u0644\u064a\u0629 \u0648\u0623\u0631\u0634\u062d \u0644\u0643 \u0627\u062e\u062a\u064a\u0627\u0631\u064b\u0627 \u0622\u0645\u0646\u064b\u0627 \u0645\u0646 \u0627\u0644\u0643\u062a\u0627\u0644\u0648\u062c \u0627\u0644\u0645\u062a\u0627\u062d.',
      en: 'I understood your request. I will use the current preferences and suggest a safe option from the available catalog.',
    );
  }

  void _logPostLlmRecommendationRoute(
    AIChatTurnContext incoming, {
    required String responseSource,
    required String finalGuardDecision,
    required List<String> productIds,
  }) {
    _logDecisionTrace(
      incoming,
      AIChatDecisionTrace(
        availabilityRoute: 'recommendation_refinement',
        availabilityReasonCode: 'llm_result_validated_recommendation',
        routeAction: 'recommend',
        shouldRenderCards: true,
        decisionOwner: 'llm_router',
        finalGuardDecision: finalGuardDecision,
        finalProductIds: productIds,
        workerAction: responseSource,
      ),
      phase: 'llm_result_routed',
    );
  }

  bool _looksLikeGenericNoSafeReply(String text) {
    final normalized = LocalIntentParser.normalizeInput(text);
    if (normalized.isEmpty) return false;
    return normalized.contains('no safe recommendation') ||
        normalized.contains('cannot show a safe recommendation') ||
        normalized.contains('could not show a safe recommendation') ||
        normalized.contains('no current perfume matches') ||
        normalized.contains('current data') ||
        normalized.contains(
          '\u0644\u0627 \u0623\u0642\u062f\u0631 \u0623\u0639\u0631\u0636 \u062a\u0631\u0634\u064a\u062d \u0622\u0645\u0646',
        ) ||
        normalized.contains(
          '\u0644\u0627 \u0627\u0642\u062f\u0631 \u0627\u0639\u0631\u0636 \u062a\u0631\u0634\u064a\u062d \u0627\u0645\u0646',
        ) ||
        normalized.contains(
          '\u0645\u0634 \u0644\u0627\u0642\u064a \u062a\u0631\u0634\u064a\u062d \u0622\u0645\u0646',
        );
  }

  String _humanClarificationQuestion(
    SessionPreferences preferences,
    AIChatLanguage language, {
    required bool hasRecommendationContext,
  }) {
    final missingSlots = preferences.missingSlotsForNextQuestion(
      hasRecommendationContext: hasRecommendationContext,
    );
    if (preferences.gender == null && missingSlots.contains('gender')) {
      return _t(
        language,
        ar: '\u0623\u0643\u064a\u062f. \u062a\u062d\u0628\u0647 \u0631\u062c\u0627\u0644\u064a\u060c \u062d\u0631\u064a\u0645\u064a\u060c \u0648\u0644\u0627 \u064a\u0646\u0641\u0639 \u0644\u0644\u0627\u062a\u0646\u064a\u0646\u061f \u0648\u0631\u064a\u062d\u062a\u0647 \u062a\u0643\u0648\u0646 \u0647\u0627\u062f\u064a\u0629\u060c \u0648\u0633\u0637\u060c \u0648\u0644\u0627 \u0642\u0648\u064a\u0629\u061f',
        en: 'Sure. Should it be men, women, or unisex? And should the scent feel soft, balanced, or strong?',
      );
    }
    if (preferences.intensity == null &&
        missingSlots.contains('notesOrIntensity')) {
      return _t(
        language,
        ar: '\u062a\u062d\u0628 \u0631\u064a\u062d\u062a\u0647 \u0647\u0627\u062f\u064a\u0629\u060c \u0648\u0633\u0637\u060c \u0648\u0644\u0627 \u0642\u0648\u064a\u0629\u061f',
        en: 'Should the scent feel soft, balanced, or strong?',
      );
    }
    if (preferences.occasion == null && preferences.time == null) {
      return _t(
        language,
        ar: '\u062a\u062d\u0628\u0647 \u0644\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u064a\u0648\u0645\u064a \u0648\u0644\u0627 \u0644\u0644\u0645\u0646\u0627\u0633\u0628\u0627\u062a\u061f',
        en: 'Is it for daily use or for occasions?',
      );
    }
    if (preferences.season == null && missingSlots.contains('season')) {
      return _t(
        language,
        ar: '\u062a\u062d\u0628\u0647 \u0635\u064a\u0641\u064a\u060c \u0634\u062a\u0648\u064a\u060c \u0648\u0644\u0627 \u0644\u0643\u0644 \u0627\u0644\u0645\u0648\u0627\u0633\u0645\u061f',
        en: 'Should it be summer, winter, or all-season?',
      );
    }
    if (preferences.maxBudget == null && missingSlots.contains('maxBudget')) {
      return _t(
        language,
        ar: '\u062a\u062d\u0628 \u0623\u062d\u062f\u062f \u0627\u062e\u062a\u064a\u0627\u0631\u0627\u062a \u0641\u064a \u062d\u062f\u0648\u062f \u0643\u0627\u0645 \u062c\u0646\u064a\u0647\u061f',
        en: 'What budget range should I stay within?',
      );
    }
    return _t(
      language,
      ar: '\u062a\u062d\u0628 \u0623\u0628\u062f\u0623 \u0628\u0627\u062e\u062a\u064a\u0627\u0631 \u0645\u062a\u0648\u0627\u0632\u0646 \u064a\u0646\u0627\u0633\u0628 \u0623\u063a\u0644\u0628 \u0627\u0644\u0623\u0648\u0642\u0627\u062a\u061f',
      en: 'Should I start with a balanced option that works for most situations?',
    );
  }

  String _humanNoMatchText(AIChatLanguage language) {
    return _t(
      language,
      ar: '\u0645\u0634 \u0644\u0627\u0642\u064a \u0627\u062e\u062a\u064a\u0627\u0631 \u0622\u0645\u0646 \u0645\u0637\u0627\u0628\u0642 \u062a\u0645\u0627\u0645\u064b\u0627 \u0644\u0644\u062a\u0641\u0636\u064a\u0644\u0627\u062a \u0627\u0644\u062d\u0627\u0644\u064a\u0629. \u0645\u0645\u0643\u0646 \u0646\u0632\u0648\u062f \u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629 \u0634\u0648\u064a\u0629 \u0623\u0648 \u0646\u062e\u0641\u0641 \u0634\u0631\u0637 \u0645\u0646 \u0627\u0644\u0634\u0631\u0648\u0637\u061f',
      en: 'I cannot find a safe exact match for the current preferences. Can we raise the budget a little or relax one condition?',
    );
  }
}
