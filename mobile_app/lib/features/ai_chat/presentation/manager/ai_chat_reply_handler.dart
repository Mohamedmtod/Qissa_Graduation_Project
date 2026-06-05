import 'dart:async';
import 'dart:developer';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/core/staff_taste_taxonomy.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_conversation_orchestrator.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_analytics_tracker.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_copy_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_answer_grounding_guard.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_runtime_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_copy_engine.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_facts.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_quality_guard.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_session_persistence_helper.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_slot_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AIChatReplyHandler {
  final AIChatState Function() _getState;
  final void Function(AIChatState state) _emitState;
  final void Function() _startCooldown;
  final void Function(String? question) _onAskQuestion;
  final AIChatSessionPersistenceHelper _sessionPersistenceHelper;
  final AIChatRepo _aiChatRepo;
  final AIChatAnalyticsTracker _analyticsTracker;
  final AIChatAnswerGroundingGuard _answerGroundingGuard;
  final AIChatConversationOrchestrator _conversationOrchestrator =
      const AIChatConversationOrchestrator();
  final AIChatResponseCopyEngine _copyEngine = const AIChatResponseCopyEngine();
  final AIChatResponseQualityGuard _qualityGuard =
      const AIChatResponseQualityGuard();
  final String Function(
    AIChatLanguage language, {
    required String ar,
    required String en,
  })
  _translate;

  AIChatReplyHandler({
    required AIChatState Function() getState,
    required void Function(AIChatState state) emitState,
    required void Function() startCooldown,
    required void Function(String? question) onAskQuestion,
    required AIChatSessionPersistenceHelper sessionPersistenceHelper,
    required AIChatRepo aiChatRepo,
    AIChatAnalyticsTracker? analyticsTracker,
    required String Function(
      AIChatLanguage language, {
      required String ar,
      required String en,
    })
    translate,
  }) : _getState = getState,
       _emitState = emitState,
       _startCooldown = startCooldown,
       _onAskQuestion = onAskQuestion,
       _sessionPersistenceHelper = sessionPersistenceHelper,
       _aiChatRepo = aiChatRepo,
       _analyticsTracker =
           analyticsTracker ??
           AIChatAnalyticsTracker(
             enabled: false,
             sink: const NoopAIChatAnalyticsSink(),
           ),
       _answerGroundingGuard = const AIChatAnswerGroundingGuard(),
       _translate = translate;

  void _logDebug(String message, {Object? error, StackTrace? stackTrace}) {
    log(
      message,
      name: 'AIChatReplyHandler',
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _shortText(String value, {int maxLength = 160}) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= maxLength) return cleaned;
    return '${cleaned.substring(0, maxLength)}...';
  }

  String _listAsLog(List<String> values, {int maxItems = 20}) {
    if (values.isEmpty) return '[]';
    final trimmed = values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (trimmed.isEmpty) return '[]';

    final selected = trimmed.take(maxItems).map((item) => '"$item"').join(', ');
    final suffix = trimmed.length > maxItems
        ? ', ...(+${trimmed.length - maxItems} more)'
        : '';
    return '[$selected$suffix]';
  }

  Map<String, dynamic> _recommendedProductToDebugMap(
    RecommendedProduct recommendation,
  ) {
    final product = recommendation.product;
    return {
      'productId': product.id,
      'name': product.name,
      'brand': product.brand,
      'price': product.price,
      'salePrice': product.salePrice,
      'effectivePrice': product.effectivePrice,
      'stock': product.stock,
      'gender': product.gender,
      'fragranceFamily': product.fragranceFamily,
      'season': product.season,
      'occasion': product.occasion,
      'time': product.time,
      'intensity': product.intensity,
      'notes': product.notes,
      'topNotes': product.topNotes,
      'middleNotes': product.middleNotes,
      'baseNotes': product.baseNotes,
      'tags': product.tags,
      'matchScore': recommendation.matchScore,
      'matchLabel': recommendation.matchLabel,
      'matchReason': recommendation.matchReason,
      'budgetStatus': recommendation.budgetStatus.name,
      'exactBudget': recommendation.exactBudget,
    };
  }

  SessionPreferences _effectiveUpdatedPreferences(
    AIChatState currentState,
    SessionPreferences updatedPreferences, {
    bool pruneHistoricalBotMessages = false,
  }) {
    final base = pruneHistoricalBotMessages
        ? SessionPreferences.empty()
        : currentState.preferences;
    return base.mergePatch(updatedPreferences);
  }

  void handleAnswerReply(
    AIChatReply reply, {
    required AIChatLanguage language,
    required String source,
    required String sessionId,
    AvailabilityContext? availabilityContext,
    bool pruneHistoricalBotMessages = false,
    String? workerFailureReason,
    bool? retargetAllowed,
    String? retargetProofSource,
    String? retargetBlockedReason,
  }) {
    _removeLoadingMessage();
    _onAskQuestion(reply.question);
    final currentState = _getState();
    _logDebug(
      'Answer reply | sessionId=$sessionId | source=$source | requestId=${reply.requestId} | '
      'provider=${reply.provider} | modelId=${reply.modelId} | promptVersion=${reply.promptVersion} | '
      'answerLength=${reply.answer?.length ?? 0} | answer="${_shortText(reply.answer ?? '')}"',
    );

    final answerText = _qualityAdjustedAnswerText(
      reply: reply,
      source: source,
      language: language,
      currentState: currentState,
    );

    final botMessage = AIChatMessage.botText(
      answerText,
      responseSource: source,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
      workerFailureReason: workerFailureReason,
    );

    final effectivePreferences = _effectiveUpdatedPreferences(
      currentState,
      reply.updatedPreferences,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    final localFacts = _visibleRecommendationFacts(currentState);
    if (_shouldValidateAnswerGrounding(
      source: source,
      reply: reply,
      effectivePreferences: effectivePreferences,
      localFacts: localFacts,
    )) {
      final groundingDecision = _answerGroundingGuard.validate(
        reply: reply,
        localFacts: localFacts,
        effectivePreferences: effectivePreferences,
      );
      if (!groundingDecision.isAllowed) {
        replyWithFallback(
          _finalRenderGuardNoMatchText(language),
          language: language,
          source: source,
          sessionId: sessionId,
          requestId: reply.requestId,
          updatedPreferences: reply.updatedPreferences,
          isNoMatch: true,
          issueCode: 'answer_grounding_blocked',
          reasonCode: groundingDecision.reasonCode,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return;
      }
    }
    final messages = _messagesForNextBotReply(
      currentState.messages,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      effectivePreferences: effectivePreferences,
      source: source,
      sessionId: sessionId,
      requestId: reply.requestId,
    )..add(botMessage);

    _emitState(
      currentState.copyWith(
        status: AIChatStatus.answer,
        messages: messages,
        preferences: effectivePreferences,
        availabilityContext:
            availabilityContext ?? currentState.availabilityContext,
        language: language,
        errorMessage: null,
        clearLoadingPhase: true,
      ),
    );

    _startCooldown();
    _sessionPersistenceHelper.enqueueMessagePersistence(
      message: botMessage,
      sessionId: sessionId,
    );
    _analyticsTracker.record(
      eventType: 'turn_completed',
      requestId: reply.requestId,
      sessionId: sessionId,
      language: language,
      messageLength: 0,
      route: 'answer',
      action: 'answer',
      source: source,
      renderIntent: 'answer_only',
      workerUsed: source.contains('worker'),
      fallbackUsed: workerFailureReason != null,
      failureReason: workerFailureReason,
      retargetAllowed: retargetAllowed,
      retargetProofSource: retargetProofSource,
      retargetBlockedReason: retargetBlockedReason,
    );
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'recommendation_answer_shown',
        sessionId: sessionId,
        metadata: {
          'source': source,
          'answerLength': answerText.length,
          'requestId': reply.requestId,
          if (reply.promptVersion != null) 'promptVersion': reply.promptVersion,
          if (reply.provider != null) 'provider': reply.provider,
          if (reply.modelId != null) 'modelId': reply.modelId,
        },
      ),
    );
  }

  List<ProductModel> _visibleRecommendationFacts(AIChatState state) {
    final seen = <String>{};
    final products = <ProductModel>[];
    for (final message in state.messages) {
      for (final recommendation in message.recommendedProducts) {
        final product = recommendation.product;
        final id = product.id.trim();
        if (id.isEmpty || !seen.add(id)) continue;
        products.add(product);
      }
    }
    return products;
  }

  String _qualityAdjustedAnswerText({
    required AIChatReply reply,
    required String source,
    required AIChatLanguage language,
    required AIChatState currentState,
  }) {
    final rawText =
        reply.answer ??
        _translate(
          language,
          ar: '\u062a\u0641\u0636\u0644\u060c \u0647\u0630\u0647 \u0647\u064a \u0627\u0644\u0625\u062c\u0627\u0628\u0629 \u0627\u0644\u062a\u064a \u0637\u0644\u0628\u062a\u0647\u0627.',
          en: 'Here is the response you were looking for.',
        );
    final intent = _answerIntentFromState(source, currentState, language);
    final facts = AIChatResponseFacts.answer(
      source: source,
      answer: rawText,
      intent: intent,
      preferences: reply.updatedPreferences,
    );
    final factsDecision = _qualityGuard.validateFacts(facts);
    if (!factsDecision.isAllowed && intent == AIChatConversationIntent.social) {
      return _copyEngine.socialAnswer(language);
    }
    final decision = _qualityGuard.validateText(
      intent: intent,
      cardPolicy: AIChatCardPolicy.answerOnly,
      text: rawText,
    );
    if (decision.isAllowed) return rawText;
    if (intent == AIChatConversationIntent.social) {
      return _copyEngine.socialAnswer(language);
    }
    return rawText;
  }

  AIChatConversationIntent _answerIntentFromState(
    String source,
    AIChatState state,
    AIChatLanguage language,
  ) {
    final normalizedSource = source.toLowerCase();
    if (normalizedSource.contains('social')) {
      return AIChatConversationIntent.social;
    }
    if (normalizedSource.contains('business')) {
      return AIChatConversationIntent.businessInfo;
    }
    if (normalizedSource.contains('availability')) {
      return AIChatConversationIntent.availability;
    }
    final lastUserMessage = _lastUserMessageText(state);
    if (lastUserMessage == null) return AIChatConversationIntent.unknown;
    return _conversationOrchestrator
        .plan(
          message: lastUserMessage,
          language: language,
          preferences: state.preferences,
          memory: state.recommendationMemory,
          hasRecommendationContext:
              state.recommendationMemory.lastRecommendedProducts.isNotEmpty,
        )
        .intent;
  }

  String? _lastUserMessageText(AIChatState state) {
    for (final message in state.messages.reversed) {
      if (message.isFromUser) return message.content;
    }
    return null;
  }

  bool _shouldValidateAnswerGrounding({
    required String source,
    required AIChatReply reply,
    required SessionPreferences effectivePreferences,
    required List<ProductModel> localFacts,
  }) {
    final normalizedSource = source.toLowerCase();
    if (normalizedSource.contains('summary')) return false;
    if (normalizedSource.contains('social')) return false;
    if (normalizedSource == 'catalog_product_context_answer' ||
        normalizedSource == 'focused_product_context_answer') {
      return false;
    }
    if (reply.productIds.isNotEmpty) return true;
    if (localFacts.isNotEmpty) return true;
    if (effectivePreferences.excludedNotes.isNotEmpty ||
        effectivePreferences.medicalExcludedNotes.isNotEmpty) {
      return true;
    }
    return normalizedSource.contains('worker');
  }

  void handleAskReply(
    AIChatReply reply, {
    required AIChatLanguage language,
    required String source,
    String? issueCode,
    String? reasonCode,
    required String sessionId,
    AvailabilityContext? availabilityContext,
    bool pruneHistoricalBotMessages = false,
    String? workerFailureReason,
    bool? retargetAllowed,
    String? retargetProofSource,
    String? retargetBlockedReason,
  }) {
    _removeLoadingMessage();
    final currentState = _getState();
    final effectivePreferences = _effectiveUpdatedPreferences(
      currentState,
      reply.updatedPreferences,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    var questionText =
        reply.question ??
        _translate(
          language,
          ar: '\u0647\u0644 \u0644\u062f\u064a\u0643 \u0623\u064a \u062a\u0641\u0636\u064a\u0644\u0627\u062a \u0625\u0636\u0627\u0641\u064a\u0629 \u0623\u0636\u0639\u0647\u0627 \u0641\u064a \u0627\u0644\u0627\u0639\u062a\u0628\u0627\u0631\u061f',
          en: 'Do you have any extra preferences I should consider?',
        );
    final shouldRetargetAsk = !_isProductReferenceClarification(
      source: source,
      reasonCode: reasonCode,
    );
    if (shouldRetargetAsk && looksLikeGenericPreferenceAsk(questionText)) {
      final missingSlots = effectivePreferences.missingSlotsForNextQuestion(
        hasRecommendationContext: currentState
            .recommendationMemory
            .lastRecommendedProducts
            .isNotEmpty,
      );
      final retargetSlot = nextUsefulAskSlot(
        effectivePreferences,
        missingSlots,
      );
      if (retargetSlot != null) {
        questionText = buildContextualQuestionForMissingSlot(
          retargetSlot,
          language,
          effectivePreferences,
          hasRecommendationContext: currentState
              .recommendationMemory
              .lastRecommendedProducts
              .isNotEmpty,
        );
      }
    }
    final inferredAskedSlot = inferAskedSlot(questionText);
    if (shouldRetargetAsk && inferredAskedSlot != null) {
      questionText = buildContextualQuestionForMissingSlot(
        inferredAskedSlot,
        language,
        effectivePreferences,
        hasRecommendationContext: currentState
            .recommendationMemory
            .lastRecommendedProducts
            .isNotEmpty,
        fallbackQuestion: questionText,
      );
    }
    final askFacts = AIChatResponseFacts.ask(
      source: source,
      question: questionText,
      preferences: effectivePreferences,
      constraints: [?inferredAskedSlot],
    );
    final askQuality = _qualityGuard.validateFacts(askFacts);
    if (!askQuality.isAllowed || looksLikeGenericPreferenceAsk(questionText)) {
      questionText = _copyEngine.askQuestion(
        askFacts,
        language,
        llmQuestion: questionText,
      );
    }
    _logDebug(
      'Ask reply | sessionId=$sessionId | source=$source | issueCode=$issueCode | reasonCode=$reasonCode | '
      'requestId=${reply.requestId} | provider=${reply.provider} | modelId=${reply.modelId} | '
      'promptVersion=${reply.promptVersion} | question="${_shortText(questionText)}"',
    );

    final botMessage = AIChatMessage.botText(
      questionText,
      responseSource: source,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
      workerFailureReason: workerFailureReason,
    );

    final messages = _messagesForNextBotReply(
      currentState.messages,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      effectivePreferences: effectivePreferences,
      source: source,
      sessionId: sessionId,
      requestId: reply.requestId,
    )..add(botMessage);

    _emitState(
      currentState.copyWith(
        status: AIChatStatus.ask,
        messages: messages,
        preferences: effectivePreferences,
        availabilityContext:
            availabilityContext ?? currentState.availabilityContext,
        language: language,
        errorMessage: null,
        clearLoadingPhase: true,
        recommendationMemory: currentState.recommendationMemory.copyWith(
          pendingPerfumeReferenceClarification:
              _pendingPerfumeReferenceClarificationFromAvailability(
                availabilityContext,
              ),
          clearPendingPerfumeReferenceClarification:
              _pendingPerfumeReferenceClarificationFromAvailability(
                availabilityContext,
              ) ==
              null,
        ),
      ),
    );

    _startCooldown();
    _sessionPersistenceHelper.enqueueMessagePersistence(
      message: botMessage,
      sessionId: sessionId,
    );
    final clarificationType = reasonCode ?? issueCode ?? inferredAskedSlot;
    _analyticsTracker.record(
      eventType: 'clarification_asked',
      requestId: reply.requestId,
      sessionId: sessionId,
      language: language,
      messageLength: 0,
      route: 'ask',
      action: 'ask',
      source: source,
      renderIntent: 'no_cards',
      workerUsed: source.contains('worker') || source.contains('tool_'),
      fallbackUsed: workerFailureReason != null,
      clarificationType: clarificationType,
      failureReason: workerFailureReason,
      retargetAllowed: retargetAllowed,
      retargetProofSource: retargetProofSource,
      retargetBlockedReason: retargetBlockedReason,
    );
    _analyticsTracker.record(
      eventType: 'turn_completed',
      requestId: reply.requestId,
      sessionId: sessionId,
      language: language,
      messageLength: 0,
      route: 'ask',
      action: 'ask',
      source: source,
      renderIntent: 'no_cards',
      workerUsed: source.contains('worker') || source.contains('tool_'),
      fallbackUsed: workerFailureReason != null,
      clarificationType: clarificationType,
      failureReason: workerFailureReason,
      retargetAllowed: retargetAllowed,
      retargetProofSource: retargetProofSource,
      retargetBlockedReason: retargetBlockedReason,
    );
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'recommendation_clarifying_question_shown',
        sessionId: sessionId,
        metadata: {
          'source': source,
          'activeCriteriaCount': effectivePreferences.activeCriteriaCount,
          ...?issueCode == null ? null : {'issueCode': issueCode},
          ...?reasonCode == null ? null : {'reasonCode': reasonCode},
          'requestId': reply.requestId,
          if (reply.promptVersion != null) 'promptVersion': reply.promptVersion,
          if (reply.provider != null) 'provider': reply.provider,
          if (reply.modelId != null) 'modelId': reply.modelId,
        },
      ),
    );
  }

  bool _isProductReferenceClarification({
    required String source,
    String? reasonCode,
  }) {
    final normalizedSource = source.toLowerCase();
    final normalizedReason = (reasonCode ?? '').toLowerCase();
    return normalizedReason.contains('reference') ||
        normalizedSource.contains('product_context') ||
        normalizedSource.contains('recommendation_memory_clarification') ||
        normalizedSource.contains('catalog_product_context_clarification');
  }

  void handleAvailabilityCardReply(
    AIChatMessage message, {
    required AIChatLanguage language,
    required String source,
    required String sessionId,
    AvailabilityContext? availabilityContext,
  }) {
    _removeLoadingMessage();
    final currentState = _getState();
    _logDebug(
      'Availability card reply | sessionId=$sessionId | source=$source | '
      'contentLength=${message.content.length} | content="${_shortText(message.content)}"',
    );

    final renderedMessage = message.copyWith(responseSource: source);

    final messages = List<AIChatMessage>.from(currentState.messages)
      ..add(renderedMessage);

    _emitState(
      currentState.copyWith(
        status: AIChatStatus.answer,
        messages: messages,
        availabilityContext:
            availabilityContext ?? currentState.availabilityContext,
        language: language,
        errorMessage: null,
        clearLoadingPhase: true,
        recommendationMemory:
            availabilityContext?.availabilityStatus ==
                    AvailabilityStatus.found &&
                renderedMessage.recommendedProducts.isNotEmpty
            ? currentState.recommendationMemory.copyWith(
                lastRecommendedProducts: _buildRecommendationRefs(
                  renderedMessage.recommendedProducts,
                ),
                lastFocusedProductId:
                    renderedMessage.recommendedProducts.first.product.id,
                lastRecommendationBatchId: renderedMessage.id,
              )
            : currentState.recommendationMemory.copyWith(
                lastExternalProfile: _externalProfileRefFromAvailability(
                  availabilityContext,
                ),
                clearPendingPerfumeReferenceClarification: true,
              ),
      ),
    );

    _startCooldown();
    _sessionPersistenceHelper.enqueueMessagePersistence(
      message: renderedMessage,
      sessionId: sessionId,
    );
    _analyticsTracker.record(
      eventType: 'turn_completed',
      requestId: null,
      sessionId: sessionId,
      language: language,
      messageLength: 0,
      route: 'availability',
      action: 'answer',
      source: source,
      renderIntent: renderedMessage.recommendedProducts.isEmpty
          ? 'answer_only'
          : 'purchase_cta_card',
      workerUsed: false,
      fallbackUsed: false,
      productCount: renderedMessage.recommendedProducts.length,
      finalProductIds: renderedMessage.recommendedProducts
          .map((item) => item.product.id)
          .toList(growable: false),
    );
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_answer_shown',
        sessionId: sessionId,
        metadata: {
          'source': source,
          'answerLength': message.content.length,
          'messageType': 'availability_card',
        },
      ),
    );
  }

  void handleRecommendationReply(
    AIChatReply reply,
    List<RecommendedProduct> products, {
    required AIChatLanguage language,
    required String source,
    required String sessionId,
    bool pruneHistoricalBotMessages = false,
    String? workerFailureReason,
  }) {
    _removeLoadingMessage();
    final currentState = _getState();
    final effectivePreferences = _effectiveUpdatedPreferences(
      currentState,
      reply.updatedPreferences,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    final renderProducts = _filterRenderableRecommendationProducts(
      products,
      effectivePreferences,
      source: source,
      sessionId: sessionId,
      requestId: reply.requestId,
      language: language,
    );
    if (renderProducts.isEmpty) {
      replyWithFallback(
        _finalRenderGuardNoMatchText(language),
        language: language,
        source: source,
        sessionId: sessionId,
        requestId: reply.requestId,
        updatedPreferences: reply.updatedPreferences,
        isNoMatch: true,
        issueCode: 'no_candidate_match',
        reasonCode: 'final_render_guard_no_safe_products',
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return;
    }

    _logDebug(
      'Recommendation reply | sessionId=$sessionId | source=$source | requestId=${reply.requestId} | '
      'provider=${reply.provider} | modelId=${reply.modelId} | promptVersion=${reply.promptVersion} | '
      'productCount=${renderProducts.length} | productIds=${renderProducts.map((item) => item.product.id).toList()}',
    );
    for (final recommendation in renderProducts) {
      final product = recommendation.product;
      _logDebug(
        'Recommendation product specs | sessionId=$sessionId | source=$source | '
        'productId=${product.id} | name="${_shortText(product.name)}" | brand="${_shortText(product.brand)}" | '
        'price=${product.price} | salePrice=${product.salePrice} | effectivePrice=${product.effectivePrice} | '
        'stock=${product.stock} | gender=${product.gender} | family="${_shortText(product.fragranceFamily)}" | '
        'season=${product.season} | occasion=${product.occasion} | time=${product.time} | intensity=${product.intensity} | '
        'notes=${_listAsLog(product.notes)} | topNotes=${_listAsLog(product.topNotes)} | '
        'middleNotes=${_listAsLog(product.middleNotes)} | baseNotes=${_listAsLog(product.baseNotes)} | '
        'tags=${_listAsLog(product.tags)} | matchScore=${recommendation.matchScore} | '
        'matchLabel="${recommendation.matchLabel}" | matchReason="${_shortText(recommendation.matchReason)}"',
      );
    }

    final recommendationMessage = AIChatMessage.botRecommendation(
      content: _recommendationIntroContent(
        language: language,
        source: source,
        reply: reply,
        recommendations: renderProducts,
      ),
      products: renderProducts,
      responseSource: source,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
      workerFailureReason: workerFailureReason,
    );

    final messages = _messagesForNextBotReply(
      currentState.messages,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      effectivePreferences: effectivePreferences,
      source: source,
      sessionId: sessionId,
      requestId: reply.requestId,
    )..add(recommendationMessage);
    final shouldPreserveExternalProfile = source.toLowerCase().contains(
      'externalprofile',
    );
    final preservedExternalProfile = shouldPreserveExternalProfile
        ? currentState.recommendationMemory.lastExternalProfile ??
              _externalProfileRefFromAvailability(
                currentState.availabilityContext,
              )
        : currentState.recommendationMemory.lastExternalProfile;
    _emitState(
      currentState.copyWith(
        status: AIChatStatus.recommend,
        messages: messages,
        preferences: effectivePreferences,
        language: language,
        errorMessage: null,
        clearLoadingPhase: true,
        availabilityContext: const AvailabilityContext.empty(),
        recommendationMemory: currentState.recommendationMemory.copyWith(
          lastRecommendedProducts: _buildRecommendationRefs(
            renderProducts,
            reply: reply,
          ),
          lastRecommendationBatchId: DateTime.now().millisecondsSinceEpoch
              .toString(),
          clearLastNoMatchContext: true,
          lastExternalProfile: preservedExternalProfile,
        ),
      ),
    );

    _startCooldown();
    _sessionPersistenceHelper.enqueueMessagePersistence(
      message: recommendationMessage,
      sessionId: sessionId,
    );
    _analyticsTracker.record(
      eventType: 'turn_completed',
      requestId: reply.requestId,
      sessionId: sessionId,
      language: language,
      messageLength: 0,
      route: 'recommendation',
      action: 'recommend',
      source: source,
      renderIntent: _analyticsRenderIntentForRecommendation(source),
      workerUsed: source.contains('worker'),
      fallbackUsed: workerFailureReason != null || source.contains('fallback'),
      productCount: renderProducts.length,
      finalProductIds: renderProducts
          .map((item) => item.product.id)
          .toList(growable: false),
      failureReason: workerFailureReason,
    );
    unawaited(
      _aiChatRepo.saveAIChatDebugLog(
        phase: 'final_reply_rendered',
        sessionId: sessionId,
        requestId: reply.requestId,
        language: language.code,
        messageText: recommendationMessage.content,
        responseSource: source,
        candidateSummary: {
          'toolRouterEnabled': AIChatExperimentConfig.toolRouterV1,
          'catalogSearchEngineEnabled':
              AIChatExperimentConfig.useCatalogSearchEngine,
          'suitabilityPolicyEnabled':
              AIChatExperimentConfig.useSuitabilityPolicy,
          'candidateCountAfterGuard': renderProducts.length,
          'finalProductIds': renderProducts
              .map((item) => item.product.id)
              .toList(growable: false),
          if (reply.isToolCall) 'toolCallName': reply.toolCall?.name.name,
        },
        recommendedProducts: renderProducts
            .map(_recommendedProductToDebugMap)
            .toList(growable: false),
      ),
    );

    final upsellProducts = renderProducts
        .where(
          (product) =>
              product.budgetStatus ==
              RecommendedBudgetStatus.slightlyAboveBudget,
        )
        .toList();
    if (upsellProducts.isNotEmpty) {
      final exactBudget = upsellProducts.first.exactBudget;
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'conversion_upsell_section_shown',
          sessionId: sessionId,
          metadata: {
            'source': source,
            'count': upsellProducts.length,
            'productIds': upsellProducts
                .map((item) => item.product.id)
                .toList(),
            'exactBudget': exactBudget,
            'requestId': reply.requestId,
            if (reply.promptVersion != null)
              'promptVersion': reply.promptVersion,
            if (reply.provider != null) 'provider': reply.provider,
            if (reply.modelId != null) 'modelId': reply.modelId,
          },
        ),
      );
      for (final upsell in upsellProducts) {
        unawaited(
          _aiChatRepo.logAIChatEvent(
            eventType: 'conversion_upsell_product_rendered',
            sessionId: sessionId,
            metadata: {
              'source': source,
              'productId': upsell.product.id,
              'exactBudget': upsell.exactBudget,
              'productPrice': upsell.product.effectivePrice,
              'deltaAmount': upsell.overBudgetAmount,
              'deltaPercent': upsell.overBudgetPercent,
              'requestId': reply.requestId,
              if (reply.promptVersion != null)
                'promptVersion': reply.promptVersion,
              if (reply.provider != null) 'provider': reply.provider,
              if (reply.modelId != null) 'modelId': reply.modelId,
            },
          ),
        );
      }
    }

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'recommendation_shown',
        sessionId: sessionId,
        metadata: {
          'source': source,
          'productIds': renderProducts.map((item) => item.product.id).toList(),
          'count': renderProducts.length,
          'requestId': reply.requestId,
          if (reply.promptVersion != null) 'promptVersion': reply.promptVersion,
          if (reply.provider != null) 'provider': reply.provider,
          if (reply.modelId != null) 'modelId': reply.modelId,
        },
      ),
    );
  }

  String _analyticsRenderIntentForRecommendation(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('cheaper')) return 'similar_or_cheaper_results';
    if (normalized.contains('reject')) return 'rejection_recovery';
    if (normalized.contains('external')) return 'external_profile_results';
    if (normalized.contains('budget')) return 'budget_floor_or_filtered';
    if (normalized.contains('catalog_query')) return 'catalog_query_results';
    return 'recommendation_grid';
  }

  List<RecommendedProduct> _filterRenderableRecommendationProducts(
    List<RecommendedProduct> products,
    SessionPreferences effectivePreferences, {
    required String source,
    required String sessionId,
    required AIChatLanguage language,
    String? requestId,
  }) {
    final safeProducts = <RecommendedProduct>[];
    final seenProductIds = <String>{};

    for (final recommendation in products) {
      if (safeProducts.length >= 3) break;

      final product = recommendation.product;
      final id = product.id.trim();
      if (id.isEmpty) {
        _logRenderGuardBlock(
          reasonCode: 'catalog_id_missing',
          productId: product.id,
          source: source,
          sessionId: sessionId,
          requestId: requestId,
        );
        continue;
      }

      if (!seenProductIds.add(id)) {
        _logRenderGuardBlock(
          reasonCode: 'duplicate_cards_blocked',
          productId: id,
          source: source,
          sessionId: sessionId,
          requestId: requestId,
        );
        continue;
      }

      if (!product.isActive || product.stock <= 0) {
        _logRenderGuardBlock(
          reasonCode: 'inactive_or_out_of_stock',
          productId: id,
          source: source,
          sessionId: sessionId,
          requestId: requestId,
          metadata: {'stock': product.stock, 'isActive': product.isActive},
        );
        continue;
      }

      final budgetStatus = LocalCandidateFilter.budgetStatusForProduct(
        product,
        effectivePreferences,
      );
      final allowBudgetFloorException = source.contains(
        'showLowestAvailableAfterBudgetNoMatch',
      );
      final allowDirectCatalogQueryBudgetBypass =
          source.startsWith('local_catalog_query_') &&
          !source.contains('no_match') &&
          !source.contains('no_exact_facet');
      final allowReferenceToolBudgetBypass =
          (source.startsWith('tool_similarCheaper') ||
              source.startsWith('tool_cheaperFollowup')) &&
          !source.contains('explicit_budget');
      if (budgetStatus == null &&
          !allowBudgetFloorException &&
          !allowDirectCatalogQueryBudgetBypass &&
          !allowReferenceToolBudgetBypass) {
        _logRenderGuardBlock(
          reasonCode: 'budget_policy_block',
          productId: id,
          source: source,
          sessionId: sessionId,
          requestId: requestId,
          metadata: {
            'maxBudget': effectivePreferences.maxBudget,
            'productPrice': product.effectivePrice,
          },
        );
        continue;
      }

      final scentBlockReason = _renderExcludedScentBlockReason(
        product,
        effectivePreferences,
      );
      if (scentBlockReason != null) {
        _logRenderGuardBlock(
          reasonCode: scentBlockReason,
          productId: id,
          source: source,
          sessionId: sessionId,
          requestId: requestId,
          metadata: {'excludedNotes': effectivePreferences.excludedNotes},
        );
        continue;
      }

      safeProducts.add(
        RecommendedProduct(
          product: product,
          matchScore: recommendation.matchScore,
          matchLabel: recommendation.matchLabel,
          matchReason: _resolveRenderableMatchReason(
            recommendation: recommendation,
            preferences: effectivePreferences,
            language: language,
          ),
          budgetStatus:
              budgetStatus ?? RecommendedBudgetStatus.slightlyAboveBudget,
          exactBudget: effectivePreferences.maxBudget,
          candidateSource: recommendation.candidateSource,
        ),
      );
    }

    return safeProducts;
  }

  String _resolveRenderableMatchReason({
    required RecommendedProduct recommendation,
    required SessionPreferences preferences,
    required AIChatLanguage language,
  }) {
    final cleaned = _cleanUserFacingRecommendationReason(
      recommendation.matchReason,
    );
    if (!_isCatalogFacetReason(cleaned)) return cleaned;
    return _buildPersuasiveMatchReason(
      recommendation.product,
      preferences,
      language,
    );
  }

  String _cleanUserFacingRecommendationReason(String reason) {
    var cleaned = reason.trim();
    if (cleaned.isEmpty) return cleaned;
    cleaned = cleaned
        .replaceAll(
          RegExp(r'\s*Suitability:\s*[^.]+\.?', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b[a-z]+(?:_[a-z0-9]+){1,}\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+([.,;:!?])'), r'$1');
    return cleaned;
  }

  bool _isCatalogFacetReason(String reason) {
    final normalized = reason.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.startsWith('matched catalog facets:') ||
        normalized.startsWith('matched catalog facet:');
  }

  String _buildPersuasiveMatchReason(
    ProductModel product,
    SessionPreferences preferences,
    AIChatLanguage language,
  ) {
    final noteMatches = _matchedPreferenceNotes(
      product,
      preferences,
    ).take(2).toList(growable: false);
    final highlights = _productReasonHighlights(product, language);
    final family = product.fragranceFamily.trim();
    final contextMatches = <String>[
      if (preferences.occasion != null &&
          _normalizedReason(product.occasion) ==
              _normalizedReason(preferences.occasion!))
        _displayReasonValue(preferences.occasion!, language),
      if (preferences.season != null &&
          (_normalizedReason(product.season) ==
                  _normalizedReason(preferences.season!) ||
              _normalizedReason(product.season) == 'all seasons' ||
              _normalizedReason(product.season) == 'all_seasons'))
        _displayReasonValue(preferences.season!, language),
      if (preferences.time != null &&
          _normalizedReason(product.time) ==
              _normalizedReason(preferences.time!))
        _displayReasonValue(preferences.time!, language),
      if (preferences.intensity != null &&
          _normalizedReason(product.intensity) ==
              _normalizedReason(preferences.intensity!))
        _displayReasonValue(preferences.intensity!, language),
      if (preferences.gender != null &&
          _genderCompatible(preferences.gender!, product.gender))
        _displayReasonValue(preferences.gender!, language),
    ].take(3).toList(growable: false);
    final caveats = _matchReasonCaveats(
      product,
      preferences,
      language,
    ).take(2).toList(growable: false);
    final staffHighlights = _trustedStaffHighlights(product, language);
    final staffWarnings = _trustedStaffWarnings(product, language);
    final profilePieces = <String>[
      if (family.isNotEmpty) _displayReasonValue(family, language),
      if (noteMatches.isNotEmpty) ...noteMatches,
      if (noteMatches.isEmpty) ...highlights.take(2),
    ].where((item) => item.trim().isNotEmpty).take(3).toList(growable: false);
    final usePieces = <String>[
      ...contextMatches,
      ...staffHighlights.take(contextMatches.isEmpty ? 3 : 2),
    ].where((item) => item.trim().isNotEmpty).take(3).toList(growable: false);
    final price = product.effectivePrice.toStringAsFixed(0);
    final budgetPhrase =
        preferences.maxBudget != null &&
            product.effectivePrice <= preferences.maxBudget!
        ? (language.isArabic
              ? 'داخل ميزانيتك ${preferences.maxBudget!.toStringAsFixed(0)} جنيه'
              : 'inside your ${preferences.maxBudget!.toStringAsFixed(0)} EGP budget')
        : (language.isArabic ? 'بسعر $price جنيه' : 'priced at $price EGP');

    if (language.isArabic) {
      final scent = profilePieces.isEmpty
          ? 'طابعه قريب من طلبك الحالي'
          : 'طابعه ${profilePieces.join('\u060c ')}';
      final use = usePieces.isEmpty
          ? 'مناسب كبداية آمنة من الكتالوج'
          : 'يناسب ${usePieces.join('\u060c ')}';
      final watchOut = [
        ...caveats,
        ...staffWarnings,
      ].take(2).toList(growable: false);
      final watchOutText = watchOut.isEmpty
          ? ''
          : ' خليك عارف: ${watchOut.join('\u060c ')}.';
      return 'اختيار قوي لأن $scent، $use، و$budgetPhrase.$watchOutText';
    }

    final scent = profilePieces.isEmpty
        ? 'a profile close to your current request'
        : 'a ${profilePieces.join(', ')} profile';
    final use = usePieces.isEmpty
        ? 'a safe catalog starting point'
        : 'well for ${usePieces.join(', ')}';
    final watchOut = [
      ...caveats,
      ...staffWarnings,
    ].take(2).toList(growable: false);
    final watchOutText = watchOut.isEmpty
        ? ''
        : ' Watch out: ${watchOut.join(', ')}.';
    return 'Strong pick because it gives you $scent, works $use, and is $budgetPhrase.$watchOutText';
  }

  Iterable<String> _matchedPreferenceNotes(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    final requested = {
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
    }.map(_normalizedReason).where((item) => item.isNotEmpty).toSet();
    if (requested.isEmpty) return const <String>[];
    final productTerms = {
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      product.fragranceFamily,
      ...product.tags,
    }.map(_normalizedReason).where((item) => item.isNotEmpty).toSet();
    return requested.where(
      (note) => productTerms.any((term) => term == note || term.contains(note)),
    );
  }

  List<String> _trustedStaffHighlights(
    ProductModel product,
    AIChatLanguage language,
  ) {
    if (!_canUseStaffTasteClaims(product)) return const <String>[];
    final preferredGroups = <StaffTasteTagGroup>[
      StaffTasteTagGroup.useCase,
      StaffTasteTagGroup.vibe,
      StaffTasteTagGroup.comfort,
      StaffTasteTagGroup.risk,
    ];
    final result = <String>[];
    for (final group in preferredGroups) {
      final entries =
          product.staffTagScores.entries
              .where(
                (entry) =>
                    entry.value >= 2 &&
                    StaffTasteTaxonomy.groupFor(entry.key) == group,
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in entries) {
        final label = _staffTagLabel(entry.key, language);
        if (label != null && !result.contains(label)) result.add(label);
      }
    }
    return result.take(4).toList(growable: false);
  }

  List<String> _trustedStaffWarnings(
    ProductModel product,
    AIChatLanguage language,
  ) {
    if (!_canUseStaffTasteClaims(product)) return const <String>[];
    return product.staffWarnings
        .map((item) => _staffTagLabel(item, language))
        .whereType<String>()
        .take(2)
        .toList(growable: false);
  }

  bool _canUseStaffTasteClaims(ProductModel product) {
    return product.hasReviewedStaffData &&
        product.staffUpdatedBy != 'staff_taste_patch_tool';
  }

  String? _staffTagLabel(String tagId, AIChatLanguage language) {
    final definition = StaffTasteTaxonomy.byId[tagId];
    if (definition == null) return null;
    return language.isArabic
        ? definition.labelAr
        : definition.labelEn.toLowerCase();
  }

  List<String> _matchReasonCaveats(
    ProductModel product,
    SessionPreferences preferences,
    AIChatLanguage language,
  ) {
    final caveats = <String>[];
    if (preferences.intensity != null &&
        _normalizedReason(product.intensity) !=
            _normalizedReason(preferences.intensity!)) {
      caveats.add(
        language.isArabic
            ? _displayReasonValue(preferences.intensity!, language)
            : '${_displayReasonValue(preferences.intensity!, language)} intensity',
      );
    }
    if (preferences.occasion != null &&
        _normalizedReason(product.occasion) !=
            _normalizedReason(preferences.occasion!) &&
        _normalizedReason(product.occasion) != 'daily') {
      caveats.add(
        language.isArabic
            ? _displayReasonValue(preferences.occasion!, language)
            : '${_displayReasonValue(preferences.occasion!, language)} use',
      );
    }
    if (preferences.time != null &&
        _normalizedReason(product.time) !=
            _normalizedReason(preferences.time!) &&
        !(_normalizedReason(preferences.time!) == 'all day' &&
            _normalizedReason(product.time) == 'day')) {
      caveats.add(
        language.isArabic
            ? _displayReasonValue(preferences.time!, language)
            : '${_displayReasonValue(preferences.time!, language)} time',
      );
    }
    if (preferences.gender != null &&
        !_genderCompatible(preferences.gender!, product.gender)) {
      caveats.add(
        language.isArabic
            ? _displayReasonValue(preferences.gender!, language)
            : '${_displayReasonValue(preferences.gender!, language)} profile',
      );
    }
    return caveats;
  }

  List<String> _productReasonHighlights(
    ProductModel product,
    AIChatLanguage language,
  ) {
    final values = <String>[
      ...product.topNotes,
      if (product.topNotes.isEmpty) ...product.notes,
      ...product.middleNotes.take(1),
      ...product.baseNotes.take(1),
    ];
    final seen = <String>{};
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .where((item) => seen.add(_normalizedReason(item)))
        .map((item) => _displayReasonValue(item, language))
        .take(2)
        .toList(growable: false);
  }

  String _normalizedReason(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _genderCompatible(String requested, String actual) {
    final normalizedRequested = _normalizedReason(requested);
    final normalizedActual = _normalizedReason(actual);
    return normalizedRequested.isEmpty ||
        normalizedRequested == 'unisex' ||
        normalizedActual == normalizedRequested ||
        normalizedActual == 'unisex';
  }

  String _displayReasonValue(String value, AIChatLanguage language) {
    final normalized = _normalizedReason(value);
    if (!language.isArabic) return normalized;
    return switch (normalized) {
      'men' => '\u0631\u062c\u0627\u0644\u064a',
      'women' => '\u0646\u0633\u0627\u0626\u064a',
      'unisex' => '\u064a\u0648\u0646\u064a\u0633\u0643\u0633',
      'light' => '\u0647\u0627\u062f\u064a',
      'medium' => '\u0645\u062a\u0648\u0633\u0637',
      'strong' => '\u0642\u0648\u064a',
      'office' => '\u0627\u0644\u0634\u063a\u0644',
      'university' => '\u0627\u0644\u062c\u0627\u0645\u0639\u0629',
      'daily' => '\u0627\u0644\u064a\u0648\u0645\u064a',
      'day' => '\u0627\u0644\u0646\u0647\u0627\u0631',
      'night' => '\u0627\u0644\u0644\u064a\u0644',
      'all day' => '\u0637\u0648\u0627\u0644 \u0627\u0644\u064a\u0648\u0645',
      'summer' => '\u0627\u0644\u0635\u064a\u0641',
      'winter' => '\u0627\u0644\u0634\u062a\u0627\u0621',
      'spring' => '\u0627\u0644\u0631\u0628\u064a\u0639',
      'autumn' => '\u0627\u0644\u062e\u0631\u064a\u0641',
      'all seasons' => '\u0643\u0644 \u0627\u0644\u0641\u0635\u0648\u0644',
      'all_seasons' => '\u0643\u0644 \u0627\u0644\u0641\u0635\u0648\u0644',
      'fresh citrus' => '\u0641\u0631\u064a\u0634 \u062d\u0645\u0636\u064a',
      'fresh spicy' =>
        '\u0641\u0631\u064a\u0634 \u0633\u0628\u0627\u064a\u0633\u064a',
      _ => value,
    };
  }

  List<AIChatMessage> _messagesForNextBotReply(
    List<AIChatMessage> currentMessages, {
    required bool pruneHistoricalBotMessages,
    required SessionPreferences effectivePreferences,
    required String source,
    required String sessionId,
    String? requestId,
  }) {
    return pruneBotHistoryForFreshTurn(
      List<AIChatMessage>.from(currentMessages),
      enabled: pruneHistoricalBotMessages,
    );
  }

  PendingPerfumeReferenceClarification?
  _pendingPerfumeReferenceClarificationFromAvailability(
    AvailabilityContext? context,
  ) {
    if (context == null ||
        context.availabilityStatus != AvailabilityStatus.ambiguous ||
        context.externalCandidates.isEmpty) {
      return null;
    }
    return PendingPerfumeReferenceClarification(
      query: context.lastQuery,
      options: context.externalCandidates
          .take(5)
          .toList(growable: false)
          .asMap()
          .entries
          .map((entry) {
            final candidate = entry.value;
            return PerfumeReferenceOptionRef(
              index: entry.key + 1,
              name: candidate.displayName,
              brand: candidate.brand,
              source: 'externalLookup',
              externalProfileId: candidate.id.trim().isEmpty
                  ? null
                  : candidate.id,
              confidence: candidate.score,
            );
          })
          .toList(growable: false),
    );
  }

  ExternalProfileRef? _externalProfileRefFromAvailability(
    AvailabilityContext? context,
  ) {
    if (context == null ||
        context.availabilityStatus != AvailabilityStatus.notFoundKnownProfile ||
        context.referenceProfileKey == null) {
      return null;
    }
    final hints = context.hints;
    return ExternalProfileRef(
      id: context.referenceProfileKey!,
      name: context.lastQuery,
      notes: [
        ...hints.preferredNotes,
        ...hints.preferredTopNotes,
        ...hints.preferredMiddleNotes,
        ...hints.preferredBaseNotes,
      ].take(8).toList(growable: false),
      tags: hints.tags.take(8).toList(growable: false),
      source: context.source.trim().isEmpty
          ? 'perfume_knowledge'
          : context.source,
    );
  }

  String _recommendationIntroContent({
    required AIChatLanguage language,
    required String source,
    required AIChatReply reply,
    required List<RecommendedProduct> recommendations,
  }) {
    final disclosures = <String>[];
    if (source.contains('showLowestAvailableAfterBudgetNoMatch')) {
      final disclosure = recommendations
          .map((item) => item.matchReason.trim())
          .firstWhere((item) => item.isNotEmpty, orElse: () => '');
      if (disclosure.isNotEmpty) disclosures.add(disclosure);
    }

    final facts = AIChatResponseFacts.fromRecommendations(
      source: source,
      recommendations: recommendations,
      preferences: reply.updatedPreferences,
      disclosures: disclosures,
    );
    return _copyEngine.recommendationIntro(
      facts,
      language,
      llmIntro: reply.answer,
    );
  }

  String _finalRenderGuardNoMatchText(AIChatLanguage language) {
    return _translate(
      language,
      ar: '\u0644\u0645 \u0623\u062c\u062f \u0639\u0637\u0631\u0627 \u0645\u062a\u0627\u062d\u0627 \u064a\u0637\u0627\u0628\u0642 \u0627\u0644\u0642\u064a\u0648\u062f \u0627\u0644\u062d\u0627\u0644\u064a\u0629 \u0628\u0623\u0645\u0627\u0646.',
      en: 'I could not find an in-stock catalog match that safely respects your current constraints.',
    );
  }

  void replyWithFallback(
    String content, {
    required AIChatLanguage language,
    required String source,
    required String sessionId,
    String? requestId,
    SessionPreferences? updatedPreferences,
    bool isNoMatch = false,
    required String issueCode,
    String? reasonCode,
    bool pruneHistoricalBotMessages = false,
    String? workerFailureReason,
  }) {
    _removeLoadingMessage();
    final currentState = _getState();
    final effectivePreferences = updatedPreferences == null
        ? currentState.preferences
        : _effectiveUpdatedPreferences(
            currentState,
            updatedPreferences,
            pruneHistoricalBotMessages: pruneHistoricalBotMessages,
          );
    final fallbackFacts = isNoMatch
        ? AIChatResponseFacts.noMatch(
            source: source,
            answer: content,
            preferences: effectivePreferences,
            constraints: [?reasonCode, if (issueCode.isNotEmpty) issueCode],
          )
        : AIChatResponseFacts.answer(
            source: source,
            answer: content,
            intent: AIChatConversationIntent.unknown,
            cardPolicy: AIChatCardPolicy.noCards,
            preferences: effectivePreferences,
          );
    final finalContent = isNoMatch
        ? _copyEngine.noMatch(fallbackFacts, language, llmText: content)
        : content;
    _logDebug(
      'Fallback reply | sessionId=$sessionId | source=$source | isNoMatch=$isNoMatch | '
      'issueCode=$issueCode | reasonCode=$reasonCode | content="${_shortText(finalContent)}"',
    );

    final message = isNoMatch
        ? AIChatMessage.botText(
            finalContent,
            responseSource: source,
            workerFailureReason: workerFailureReason ?? reasonCode ?? issueCode,
          )
        : AIChatMessage.error(
            finalContent,
            responseSource: source,
            workerFailureReason: workerFailureReason ?? reasonCode ?? issueCode,
          );

    final newStatus = isNoMatch ? AIChatStatus.noMatch : AIChatStatus.error;
    final messages = _messagesForNextBotReply(
      currentState.messages,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      effectivePreferences: effectivePreferences,
      source: source,
      sessionId: sessionId,
      requestId: requestId,
    )..add(message);

    _emitState(
      currentState.copyWith(
        status: newStatus,
        messages: messages,
        preferences: effectivePreferences,
        language: language,
        errorMessage: null,
        clearLoadingPhase: true,
      ),
    );

    _startCooldown();
    _sessionPersistenceHelper.enqueueMessagePersistence(
      message: message,
      sessionId: sessionId,
    );
    final analyticsReason = workerFailureReason ?? reasonCode ?? issueCode;
    _analyticsTracker.record(
      eventType: isNoMatch ? 'no_match' : 'fallback_used',
      requestId: requestId,
      sessionId: sessionId,
      language: language,
      messageLength: 0,
      route: isNoMatch ? 'no_match' : 'fallback',
      action: isNoMatch ? 'no_match' : 'fallback',
      source: source,
      renderIntent: 'no_cards',
      workerUsed: source.contains('worker'),
      fallbackUsed: true,
      productCount: 0,
      noMatchReason: isNoMatch ? reasonCode ?? issueCode : null,
      failureReason: analyticsReason,
    );
    _analyticsTracker.record(
      eventType: 'turn_completed',
      requestId: requestId,
      sessionId: sessionId,
      language: language,
      messageLength: 0,
      route: isNoMatch ? 'no_match' : 'fallback',
      action: isNoMatch ? 'no_match' : 'fallback',
      source: source,
      renderIntent: 'no_cards',
      workerUsed: source.contains('worker'),
      fallbackUsed: true,
      productCount: 0,
      noMatchReason: isNoMatch ? reasonCode ?? issueCode : null,
      failureReason: analyticsReason,
    );
    unawaited(
      _aiChatRepo.saveAIChatDebugLog(
        phase: 'fallback_rendered',
        sessionId: sessionId,
        requestId: requestId,
        language: language.code,
        messageText: finalContent,
        responseSource: source,
        issueCode: issueCode,
        reasonCode: reasonCode,
        preferencesSnapshot: effectivePreferences.toJson(),
        candidateSummary: {
          'toolRouterEnabled': AIChatExperimentConfig.toolRouterV1,
          'catalogSearchEngineEnabled':
              AIChatExperimentConfig.useCatalogSearchEngine,
          'suitabilityPolicyEnabled':
              AIChatExperimentConfig.useSuitabilityPolicy,
          if (reasonCode != null) 'blockedReasons': [reasonCode],
          'finalProductIds': const <String>[],
        },
      ),
    );
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: isNoMatch
            ? 'recommendation_no_match_shown'
            : 'request_fallback_local',
        sessionId: sessionId,
        metadata: {
          'source': source,
          'issueCode': issueCode,
          'reasonCode': reasonCode ?? issueCode,
        },
      ),
    );
  }

  String? _renderExcludedScentBlockReason(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    if (preferences.excludedNotes.isEmpty) return null;

    final canonicalText = [
      ...product.notes,
      product.fragranceFamily,
    ].map(_normalizeGuardToken).join(' ');
    final fineText = [
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.tags,
      product.description,
      product.pyramidDescription ?? '',
    ].map(_normalizeGuardToken).join(' ');

    for (final excluded in preferences.excludedNotes) {
      for (final token in _expandedExcludedGuardTokens(excluded)) {
        if (_containsGuardToken(canonicalText, token)) {
          return 'excluded_note_violation';
        }
        if (_containsGuardToken(fineText, token)) {
          return 'fine_note_violation';
        }
      }
    }
    return null;
  }

  Set<String> _expandedExcludedGuardTokens(String value) {
    final normalized = _normalizeGuardToken(value);
    final tokens = <String>{normalized};
    if (normalized.contains('citrus') ||
        normalized.contains('lemon') ||
        normalized.contains('bergamot') ||
        normalized.contains('orange')) {
      tokens.addAll(const {'citrus', 'lemon', 'bergamot', 'orange'});
    }
    if (normalized.contains('rose')) {
      tokens.add('rose');
    }
    if (normalized.contains('jasmine')) {
      tokens.add('jasmine');
    }
    return tokens;
  }

  bool _containsGuardToken(String normalizedText, String token) {
    final normalizedToken = _normalizeGuardToken(token);
    if (normalizedText.isEmpty || normalizedToken.isEmpty) return false;

    final asciiToken = RegExp(r'^[a-z0-9 ]+$').hasMatch(normalizedToken);
    if (!asciiToken) return normalizedText.contains(normalizedToken);

    final escapedToken = RegExp.escape(normalizedToken);
    return RegExp(
      '(^|[^a-z0-9])$escapedToken([^a-z0-9]|\$)',
    ).hasMatch(normalizedText);
  }

  String _normalizeGuardToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  void _logRenderGuardBlock({
    required String reasonCode,
    required String productId,
    required String source,
    required String sessionId,
    String? requestId,
    Map<String, dynamic> metadata = const {},
  }) {
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'recommendation_hard_filter_blocked',
        sessionId: sessionId,
        metadata: {
          'source': source,
          'productId': productId,
          'issueCode': reasonCode,
          'reasonCode': reasonCode,
          ...?requestId == null ? null : {'requestId': requestId},
          ...metadata,
        },
      ),
    );
  }

  void _removeLoadingMessage() {
    final currentState = _getState();
    final messages = List<AIChatMessage>.from(currentState.messages)
      ..removeWhere((m) => m.isLoading);
    _emitState(currentState.copyWith(messages: messages));
  }

  List<RecommendedProductRef> _buildRecommendationRefs(
    List<RecommendedProduct> products, {
    AIChatReply? reply,
  }) {
    return products.asMap().entries.map((entry) {
      final product = entry.value.product;
      return RecommendedProductRef(
        productId: product.id,
        name: product.name,
        brand: product.brand,
        displayIndex: entry.key + 1,
        price: product.effectivePrice,
        stock: product.stock,
        season: product.season,
        occasion: product.occasion,
        intensity: product.intensity,
        notes: product.notes,
        topNotes: product.topNotes,
        middleNotes: product.middleNotes,
        baseNotes: product.baseNotes,
        tags: product.tags,
        matchScore: entry.value.matchScore,
        matchReason: entry.value.matchReason,
        requestId: reply?.requestId,
        promptVersion: reply?.promptVersion,
        provider: reply?.provider,
        modelId: reply?.modelId,
      );
    }).toList();
  }
}
