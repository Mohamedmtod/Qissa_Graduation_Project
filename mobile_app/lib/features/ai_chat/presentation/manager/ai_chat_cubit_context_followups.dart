part of 'ai_chat_cubit.dart';

extension AIChatCubitContextFollowups on AIChatCubit {
  bool _handleRecommendationSelectionCommand(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    final refs = state.recommendationMemory.lastRecommendedProducts;
    if (refs.isEmpty) return false;

    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) return false;
    if (BudgetAmountParser.containsBudgetNumber(normalized)) return false;
    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return false;
    }
    final isCartSelection = _selectionResolver.looksLikeCartSelection(
      normalized,
    );
    final parsedPreferences = LocalIntentParser.parse(
      incoming.trimmed,
      state.preferences,
    );
    if (!isCartSelection &&
        _preferenceChangeDetector.hasPreferenceDelta(
          state.preferences,
          parsedPreferences,
        )) {
      return false;
    }

    final selection = _selectionResolver.resolve(
      normalized,
      refs,
      messages: state.messages,
    );
    if (selection == null) return false;

    if (selection.isAmbiguous) {
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: _memoryAnswerBuilder.buildAmbiguousSelectionAnswer(
            selection.matches,
            incoming.responseLanguage,
          ),
          updatedPreferences: state.preferences,
        ),
        language: incoming.responseLanguage,
        source: 'recommendation_selection_ambiguous',
        reasonCode: 'recommendation_selection_ambiguous',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final selected = selection.matches;
    if (selected.isEmpty) return false;
    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: _memoryAnswerBuilder.buildSelectionAnswer(
          selected,
          incoming.responseLanguage,
          wantsCart: isCartSelection,
        ),
        updatedPreferences: state.preferences,
        provider: 'local',
        modelId: 'recommendation_selection',
        promptVersion: 'recommendation_selection_v1',
      ),
      language: incoming.responseLanguage,
      source: 'recommendation_selection',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _handleFocusedProductContextQuestion(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (_selectionResolver.looksLikeCartSelection(normalized)) {
      return false;
    }
    if (!_productContextSignals.looksLikeContextSuitabilityQuestion(
      normalized,
    )) {
      return false;
    }
    if (!_productContextSignals.looksLikeExplicitProductContextQuestion(
      normalized,
    )) {
      return false;
    }
    final focusedId =
        incoming.effectiveRecommendationMemory.lastFocusedProductId;
    if (focusedId == null) return false;
    final product = catalog
        .where((item) => item.id == focusedId)
        .cast<ProductModel?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (product == null) return false;

    final answer = _buildCatalogProductContextSuitabilityAnswer(
      product,
      normalized,
      incoming.responseLanguage,
    );
    _syncRecommendationMemoryFocus(product.id);
    _logDecisionTrace(
      incoming,
      AIChatDecisionTrace(
        availabilityRoute: 'product_context_question',
        availabilityReasonCode: 'focused_product_context_suitability_answer',
        routeAction: 'answer_local',
        shouldRenderCards: false,
        decisionOwner: 'local_gate',
        finalGuardDecision: 'answer_route_cards_blocked',
        finalProductIds: [product.id],
      ),
      phase: 'route_decision',
    );
    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: answer,
        updatedPreferences: state.preferences,
        provider: 'local',
        modelId: 'focused_product_context_answer',
        promptVersion: 'focused_product_context_answer_v1',
      ),
      language: incoming.responseLanguage,
      source: 'focused_product_context_answer',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  Future<bool> _handleDeterministicCommerceToolFollowUp(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final memory =
        incoming.effectiveRecommendationMemory.lastExternalProfile == null &&
            state.recommendationMemory.lastExternalProfile != null
        ? state.recommendationMemory
        : incoming.effectiveRecommendationMemory;
    final route = _deterministicCommerceRouter.resolve(
      message: incoming.trimmed,
      memory: memory,
    );
    if (route == null) return false;

    final reply = AIChatReply.toolCall(
      toolCall: AIChatToolCall(
        name: route.toolName,
        arguments: route.arguments,
        confidence: 1,
      ),
      updatedPreferences: state.preferences,
      requestId: incoming.requestId,
      provider: 'local',
      modelId: 'deterministic_commerce_tool',
      promptVersion: 'deterministic_commerce_tool_v1',
    );
    final toolPreferences =
        (route.toolName == AIChatToolName.similarCheaper ||
                route.toolName == AIChatToolName.cheaperFollowup) &&
            !BudgetAmountParser.containsBudgetNumber(incoming.trimmed)
        ? state.preferences.copyWith(clearBudget: true)
        : state.preferences;
    final result = await _toolExecutor.execute(
      reply: reply,
      catalog: catalog,
      currentPreferences: toolPreferences,
      language: incoming.responseLanguage,
      recommendationMemory: memory,
    );
    if (result.updatedRecommendationMemory != null) {
      _applyToolRecommendationMemory(result.updatedRecommendationMemory!);
    }
    _logDecisionTrace(
      incoming,
      AIChatDecisionTrace(
        toolRouterEnabled: AIChatExperimentConfig.toolRouterV1,
        toolCallName: route.toolName.name,
        toolCallValid: result.handled,
        toolExecutionSource: result.source,
        routeAction: result.action.name,
        shouldRenderCards: result.shouldRenderCards,
        decisionOwner: 'local_gate',
        availabilityRoute: 'deterministic_commerce_tool',
        availabilityReasonCode: route.reasonCode,
        finalGuardDecision: result.status.name,
        finalProductIds: result.productIds,
      ),
      phase: 'deterministic_tool_executed',
    );
    _analyticsTracker.record(
      eventType: 'tool_executed',
      requestId: incoming.requestId,
      sessionId: incoming.activeSessionId,
      language: incoming.responseLanguage,
      messageLength: incoming.trimmed.length,
      route: 'deterministic_commerce_tool',
      action: result.action.name,
      source: result.source,
      toolName: route.toolName.name,
      toolStatus: _analyticsToolStatus(result.status),
      renderIntent: result.renderIntent.name,
      workerUsed: false,
      productCount: result.productIds.length,
      finalProductIds: result.productIds,
      clarificationType: result.reasonCode,
      failureReason: result.handled ? null : result.reasonCode,
    );
    return _toolResultRenderer.render(
      incoming: incoming,
      catalog: catalog,
      result: result,
      fallbackPreferences: state.preferences,
      replyHandler: _replyHandler,
      translate: _t,
      applySuitabilityPolicy: _applySuitabilityPolicyToRecommendations,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
  }

  bool _handleRecommendationMemoryQuestion(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    final refs = state.recommendationMemory.lastRecommendedProducts;
    if (refs.isEmpty) return false;

    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (_selectionResolver.looksLikeCartSelection(normalized)) {
      return false;
    }
    final pendingContextSelection = _tryResolvePendingProductContextSelection(
      normalized,
      refs,
    );
    if (pendingContextSelection != null) {
      final contextMessage =
          _lastUserMessageBeforeCurrent(incoming.trimmed) ?? _lastAskQuestion;
      final normalizedContext = LocalIntentParser.normalizeInput(
        contextMessage ?? '',
      );
      final responseLanguage = _productContextResponseLanguage(
        contextMessage: contextMessage,
        fallback: incoming.responseLanguage,
      );
      final answer = _buildContextSuitabilityAnswer(
        pendingContextSelection,
        normalizedContext,
        responseLanguage,
      );
      _syncRecommendationMemoryFocus(pendingContextSelection.productId);
      _logDecisionTrace(
        incoming,
        AIChatDecisionTrace(
          availabilityRoute: 'product_context_question',
          availabilityReasonCode: 'product_reference_clarification_answer',
          routeAction: 'answer_local',
          shouldRenderCards: false,
          decisionOwner: 'local_gate',
          finalGuardDecision: 'answer_route_cards_blocked',
          finalProductIds: [pendingContextSelection.productId],
        ),
        phase: 'route_decision',
      );
      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: answer,
          updatedPreferences: state.preferences,
          provider: 'local',
          modelId: 'product_context_clarification_answer',
          promptVersion: 'product_context_clarification_answer_v1',
        ),
        language: responseLanguage,
        source: 'product_context_clarification_answer',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final looksLikeSuitabilityFollowUp = _productContextSignals
        .looksLikeContextSuitabilityQuestion(normalized);
    final refinementConflict = _productContextSignals
        .classifyRecommendationRefinementConflict(normalized);
    if (refinementConflict != null) {
      _logDecisionTrace(
        incoming,
        AIChatDecisionTrace(
          availabilityRoute: refinementConflict == 'llm'
              ? 'llm'
              : 'recommendation_refinement',
          availabilityReasonCode: refinementConflict == 'llm'
              ? 'competing_routes_product_context_refinement'
              : 'recommendation_refinement_context_update',
          routeAction: refinementConflict == 'llm'
              ? 'send_to_llm'
              : 'recommend',
          shouldRenderCards: refinementConflict != 'llm',
          decisionOwner: 'local_gate',
          llmEscalationReason: refinementConflict == 'llm'
              ? 'natural_language_complexity'
              : null,
          finalGuardDecision: refinementConflict == 'llm'
              ? 'llm_escalation'
              : 'recommendation_refinement',
        ),
        phase: 'route_decision',
      );
      return false;
    }
    final parsedPreferences = LocalIntentParser.parse(
      incoming.trimmed,
      state.preferences,
    );
    if (_preferenceChangeDetector.hasPreferenceDelta(
          state.preferences,
          parsedPreferences,
        ) &&
        !looksLikeSuitabilityFollowUp) {
      return false;
    }
    final asksReason =
        normalized.contains('why') ||
        normalized.contains('\u0644\u064a\u0647') ||
        normalized.contains('\u0644\u0645\u0627\u0630\u0627') ||
        normalized.contains('reason');
    final asksNotes =
        normalized.contains('notes') ||
        normalized.contains('ingredients') ||
        normalized.contains('\u0645\u0643\u0648\u0646') ||
        normalized.contains('\u0646\u0648\u062a');
    final asksDetails =
        normalized.contains('tell me more') ||
        normalized.contains('details') ||
        normalized.contains('detail') ||
        normalized.contains('about ') ||
        normalized.contains('\u062a\u0641\u0627\u0635\u064a\u0644') ||
        normalized.contains('\u0627\u0634\u0631\u062d');
    final asksComparison =
        normalized.contains('compare') ||
        normalized.contains('heavier') ||
        normalized.contains('lighter') ||
        normalized.contains('\u0623\u062b\u0642\u0644') ||
        normalized.contains('\u0627\u062b\u0642\u0644') ||
        normalized.contains('\u0623\u062e\u0641') ||
        normalized.contains('\u0627\u062e\u0641') ||
        normalized.contains('\u0642\u0627\u0631\u0646');
    final asksCheapest =
        normalized.contains('cheapest') ||
        normalized.contains('lowest price') ||
        normalized.contains('lower price') ||
        normalized.contains('less expensive') ||
        normalized.contains('رخ') ||
        normalized.contains('\u0631\u062e\u0635') ||
        normalized.contains('\u0623\u0631\u062e\u0635') ||
        normalized.contains('\u0627\u0631\u062e\u0635');
    final asksContextSuitability = _productContextSignals
        .looksLikeContextSuitabilityQuestion(normalized);
    final contextLabel = _productContextSignals.extractContextLabel(normalized);
    final asksVisibleBestForContext =
        contextLabel != null &&
        refs.length > 1 &&
        (RegExp(
              r'\b(which|what|best|better|pick|choose)\b',
            ).hasMatch(normalized) ||
            normalized.contains('\u0623\u0641\u0636\u0644') ||
            normalized.contains('\u0627\u0641\u0636\u0644')) &&
        (RegExp(
              r'\b(them|these|those|among|between|options?|recommendations?|one|ones?)\b',
            ).hasMatch(normalized) ||
            normalized.contains('فيه') ||
            normalized.contains('\u0641\u064a\u0647\u0645') ||
            normalized.contains('\u062f\u0648\u0644'));
    if (!asksReason &&
        !asksNotes &&
        !asksDetails &&
        !asksComparison &&
        !asksCheapest &&
        !asksContextSuitability &&
        !asksVisibleBestForContext) {
      return false;
    }

    var selection = _selectionResolver.resolve(
      normalized,
      refs,
      messages: state.messages,
      allowNameOnly: asksContextSuitability,
    );
    if (selection == null && asksCheapest) {
      selection = AIChatRecommendationSelectionResult(matches: refs);
    }
    if (asksCheapest && selection != null && selection.matches.length < 2) {
      selection = AIChatRecommendationSelectionResult(matches: refs);
    }
    if (asksVisibleBestForContext) {
      selection = AIChatRecommendationSelectionResult(matches: refs);
    }
    if (selection == null && asksReason) {
      selection = AIChatRecommendationSelectionResult(
        matches: [_focusedOrFirstRecommendation(refs)],
      );
    }
    if (selection == null && asksNotes && refs.length == 1) {
      selection = AIChatRecommendationSelectionResult(matches: [refs.first]);
    }
    if (selection == null && asksDetails && refs.length == 1) {
      selection = AIChatRecommendationSelectionResult(matches: [refs.first]);
    }
    if (selection == null || selection.matches.isEmpty) {
      _logDecisionTrace(
        incoming,
        const AIChatDecisionTrace(
          availabilityRoute: 'product_context_question',
          availabilityReasonCode: 'ambiguous_product_reference',
          routeAction: 'ask_clarification',
          shouldRenderCards: false,
          decisionOwner: 'local_gate',
          clarificationType: 'product_reference',
          finalGuardDecision: 'answer_route_cards_blocked',
        ),
        phase: 'route_decision',
      );
      if (asksContextSuitability) {
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question: _memoryAnswerBuilder.buildAmbiguousSelectionAnswer(
              refs,
              incoming.responseLanguage,
            ),
            updatedPreferences: state.preferences,
          ),
          language: incoming.responseLanguage,
          source: 'product_context_question_clarification',
          reasonCode: 'ambiguous_product_reference',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return true;
      }
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: _t(
            incoming.responseLanguage,
            ar: '\u062a\u0642\u0635\u062f \u0623\u064a \u062a\u0631\u0634\u064a\u062d\u061f \u0627\u0628\u0639\u062a \u0645\u062b\u0644\u0627: \u0627\u0644\u0623\u0648\u0644\u060c \u0627\u0644\u062b\u0627\u0646\u064a\u060c \u0623\u0648 \u0627\u0644\u062b\u0627\u0644\u062b.',
            en: 'Which recommendation do you mean? Send for example: first, second, or third.',
          ),
          updatedPreferences: state.preferences,
        ),
        language: incoming.responseLanguage,
        source: 'recommendation_memory_clarification',
        reasonCode: 'recommendation_reference_missing',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }
    if (selection.isAmbiguous && asksContextSuitability) {
      _logDecisionTrace(
        incoming,
        const AIChatDecisionTrace(
          availabilityRoute: 'product_context_question',
          availabilityReasonCode: 'ambiguous_product_reference',
          routeAction: 'ask_clarification',
          shouldRenderCards: false,
          decisionOwner: 'local_gate',
          clarificationType: 'product_reference',
          finalGuardDecision: 'answer_route_cards_blocked',
        ),
        phase: 'route_decision',
      );
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: _memoryAnswerBuilder.buildAmbiguousSelectionAnswer(
            selection.matches,
            incoming.responseLanguage,
          ),
          updatedPreferences: state.preferences,
        ),
        language: incoming.responseLanguage,
        source: 'product_context_question_clarification',
        reasonCode: 'ambiguous_product_reference',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final answer = asksCheapest
        ? _memoryAnswerBuilder.buildCheapestAnswer(
            selection.matches,
            incoming.responseLanguage,
          )
        : asksVisibleBestForContext
        ? _memoryAnswerBuilder.buildBestForContextAnswer(
            selection.matches,
            contextLabel,
            incoming.responseLanguage,
          )
        : asksContextSuitability
        ? _buildContextSuitabilityAnswer(
            selection.matches.first,
            normalized,
            incoming.responseLanguage,
          )
        : asksComparison && selection.matches.length >= 2
        ? _memoryAnswerBuilder.buildComparisonAnswer(
            selection.matches.take(2).toList(growable: false),
            incoming.responseLanguage,
          )
        : _memoryAnswerBuilder.buildMemoryAnswer(
            selection.matches.first,
            incoming.responseLanguage,
            includeNotes: asksNotes,
            includeReason: asksReason,
          );
    final focusedProductId = asksVisibleBestForContext
        ? _memoryAnswerBuilder
              .selectBestForContext(selection.matches, contextLabel)
              .productId
        : selection.matches.first.productId;
    _syncRecommendationMemoryFocus(focusedProductId);
    _logDecisionTrace(
      incoming,
      AIChatDecisionTrace(
        availabilityRoute: asksContextSuitability
            ? 'product_context_question'
            : 'recommendation_memory_question',
        availabilityReasonCode: asksContextSuitability
            ? 'product_context_suitability_answer'
            : 'recommendation_memory_answer',
        routeAction: 'answer_local',
        shouldRenderCards: false,
        decisionOwner: 'local_gate',
        finalGuardDecision: 'answer_route_cards_blocked',
        finalProductIds: [focusedProductId],
      ),
      phase: 'route_decision',
    );
    final answerSource = asksCheapest || asksVisibleBestForContext
        ? 'visible_products_answer'
        : 'recommendation_memory_answer';
    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: answer,
        updatedPreferences: state.preferences,
        provider: 'local',
        modelId: answerSource,
        promptVersion: '${answerSource}_v1',
      ),
      language: incoming.responseLanguage,
      source: answerSource,
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  RecommendedProductRef? _tryResolvePendingProductContextSelection(
    String normalized,
    List<RecommendedProductRef> refs,
  ) {
    if (!_isPendingProductReferenceClarification()) return null;
    final shortExactSelection = _resolvePendingShortExactSelection(
      normalized,
      refs,
    );
    if (shortExactSelection != null) return shortExactSelection;

    final selection = _selectionResolver.resolve(
      normalized,
      refs,
      messages: state.messages,
      allowNameOnly: true,
    );
    if (selection == null || selection.matches.length != 1) return null;
    return selection.matches.single;
  }

  RecommendedProductRef? _resolvePendingShortExactSelection(
    String normalized,
    List<RecommendedProductRef> refs,
  ) {
    final clean = normalized.trim();
    if (clean.length > 2 || clean.isEmpty) return null;

    final matches = refs
        .where((ref) {
          final names = <String>{ref.name, '${ref.brand} ${ref.name}'}
              .map(LocalIntentParser.normalizeInput)
              .where((term) => term.isNotEmpty);
          return names.any((term) => term == clean);
        })
        .toList(growable: false);
    if (matches.length != 1) return null;
    return matches.single;
  }

  bool _isPendingProductReferenceClarification() {
    final lastAsk = (_lastAskQuestion ?? '').toLowerCase();
    if (lastAsk.contains('which product do you mean') ||
        lastAsk.contains('which recommendation do you mean') ||
        lastAsk.contains('\u062a\u0642\u0635\u062f')) {
      return true;
    }
    for (final message in state.messages.reversed) {
      if (message.isFromUser || message.isLoading) continue;
      final source = (message.responseSource ?? '').toLowerCase();
      final content = message.content.toLowerCase();
      return source.contains('product_context_question_clarification') ||
          source.contains('recommendation_memory_clarification') ||
          content.contains('which product do you mean') ||
          content.contains('which recommendation do you mean') ||
          content.contains('\u062a\u0642\u0635\u062f');
    }
    return false;
  }

  AIChatLanguage? _pendingProductReferenceClarificationLanguage() {
    final lastAsk = (_lastAskQuestion ?? '').toLowerCase();
    if (lastAsk.contains('which product do you mean') ||
        lastAsk.contains('which recommendation do you mean')) {
      return AIChatLanguage.english;
    }
    if (lastAsk.contains('\u062a\u0642\u0635\u062f')) {
      return AIChatLanguage.arabic;
    }
    for (final message in state.messages.reversed) {
      if (message.isFromUser || message.isLoading) continue;
      final source = (message.responseSource ?? '').toLowerCase();
      final content = message.content.toLowerCase();
      final isProductReferenceAsk =
          source.contains('product_context_question_clarification') ||
          source.contains('recommendation_memory_clarification') ||
          content.contains('which product do you mean') ||
          content.contains('which recommendation do you mean') ||
          content.contains('\u062a\u0642\u0635\u062f');
      if (!isProductReferenceAsk) return null;
      if (content.contains('which product do you mean') ||
          content.contains('which recommendation do you mean')) {
        return AIChatLanguage.english;
      }
      return AIChatLanguage.arabic;
    }
    return null;
  }

  AIChatLanguage _productContextResponseLanguage({
    required String? contextMessage,
    required AIChatLanguage fallback,
  }) {
    final pending = _pendingProductReferenceClarificationLanguage();
    if (pending == AIChatLanguage.english) return AIChatLanguage.english;
    final normalizedContext = LocalIntentParser.normalizeInput(
      contextMessage ?? '',
    );
    if (RegExp(r'[a-z]').hasMatch(normalizedContext) &&
        (normalizedContext.contains('work') ||
            normalizedContext.contains('office') ||
            normalizedContext.contains('gym') ||
            normalizedContext.contains('date') ||
            normalizedContext.contains('daily') ||
            normalizedContext.contains('university'))) {
      return AIChatLanguage.english;
    }
    return pending ?? fallback;
  }

  String? _lastUserMessageBeforeCurrent(String currentMessage) {
    var skippedCurrent = false;
    final normalizedCurrent = LocalIntentParser.normalizeInput(currentMessage);
    for (final message in state.messages.reversed) {
      if (!message.isFromUser) continue;
      final normalizedMessage = LocalIntentParser.normalizeInput(
        message.content,
      );
      if (!skippedCurrent && normalizedMessage == normalizedCurrent) {
        skippedCurrent = true;
        continue;
      }
      if (normalizedMessage.isNotEmpty) return message.content;
    }
    return null;
  }

  bool _handleCatalogProductContextQuestion(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (!_productContextSignals.looksLikeContextSuitabilityQuestion(
      normalized,
    )) {
      return false;
    }

    final matches = MentionedProductResolver.resolveMany(
      message: incoming.trimmed,
      catalog: catalog,
      limit: 4,
    );
    if (matches.isEmpty) return false;

    if (matches.length > 1) {
      _logDecisionTrace(
        incoming,
        const AIChatDecisionTrace(
          availabilityRoute: 'product_context_question',
          availabilityReasonCode: 'ambiguous_catalog_product_reference',
          routeAction: 'ask_clarification',
          shouldRenderCards: false,
          decisionOwner: 'local_gate',
          clarificationType: 'product_reference',
          finalGuardDecision: 'answer_route_cards_blocked',
        ),
        phase: 'route_decision',
      );
      final options = matches
          .take(3)
          .map((product) => product.name)
          .join(incoming.responseLanguage.isArabic ? ' \u0648' : ', ');
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: _t(
            incoming.responseLanguage,
            ar: '\u062a\u0642\u0635\u062f \u0623\u064a \u0639\u0637\u0631 \u0628\u0627\u0644\u0636\u0628\u0637\u061f $options',
            en: 'Which product do you mean? $options',
          ),
          updatedPreferences: state.preferences,
        ),
        language: incoming.responseLanguage,
        source: 'catalog_product_context_clarification',
        reasonCode: 'ambiguous_catalog_product_reference',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final product = matches.single;
    final answer = _buildCatalogProductContextSuitabilityAnswer(
      product,
      normalized,
      incoming.responseLanguage,
    );
    _syncRecommendationMemoryFocus(product.id);
    _logDecisionTrace(
      incoming,
      AIChatDecisionTrace(
        availabilityRoute: 'product_context_question',
        availabilityReasonCode: 'catalog_product_context_suitability_answer',
        routeAction: 'answer_local',
        shouldRenderCards: false,
        decisionOwner: 'local_gate',
        finalGuardDecision: 'answer_route_cards_blocked',
        finalProductIds: [product.id],
      ),
      phase: 'route_decision',
    );
    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: answer,
        updatedPreferences: state.preferences,
        provider: 'local',
        modelId: 'catalog_product_context_answer',
        promptVersion: 'catalog_product_context_answer_v1',
      ),
      language: incoming.responseLanguage,
      source: 'catalog_product_context_answer',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  void _syncRecommendationMemoryFocus(String productId) {
    _emitState(
      state.copyWith(
        recommendationMemory: state.recommendationMemory.copyWith(
          lastFocusedProductId: productId,
        ),
      ),
    );
  }
}
