import 'dart:async';
import 'dart:developer';
import 'package:uuid/uuid.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_feedback.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_analytics_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_analytics_tracker.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_answer_grounding_guard.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_business_info_responder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_copy_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_conversation_orchestrator.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_discovery_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_deterministic_gate.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_deterministic_commerce_router.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_debug_session_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_interceptor_copy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_interpretation_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_local_catalog_command_handler.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_modifier_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_no_match_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_preference_change_detector.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_product_context_signals.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_reply_handler.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_reply_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_runtime_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_session_actions.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_session_id_store.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_summary_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_stored_message_restorer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_turn_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_worker_reply_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_input_interceptor.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_feedback_helper.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_feedback_remote_sink.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_turn_decision_engine.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_tool_executor.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_tool_result_renderer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_worker_first_experiment.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_followup_detector.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_flow_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_hint_builders.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_lookup_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_message_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_reference_profile_registry.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_route_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_substitute_engine.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_session_persistence_helper.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/budget_amount_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_query_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_shadow_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/mentioned_product_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/reference_product_similarity_ranker.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/final_recommendation_guard.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_slot_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/suitability_policy_engine.dart';

import 'package:perfume_app/features/ai_chat/presentation/manager/product_followup_answer_builder.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';

part 'ai_chat_cubit_turn_flow.dart';
part 'ai_chat_cubit_availability_flow.dart';
part 'ai_chat_cubit_quality_guards.dart';
part 'ai_chat_cubit_context_followups.dart';
part 'ai_chat_cubit_recommendation_flow.dart';
part 'ai_chat_cubit_worker_flow.dart';

/// Manages the AI Chat flow, state persistence, and communication with [AIChatRepo].
///
/// This Cubit acts as the primary orchestrator for the AI recommendation system.
/// It maintains [AIChatState.preferences] as the **Source of Truth** for the entire session.
class AIChatCubit extends Cubit<AIChatState> {
  static const int maxUserMessageLength = 600;

  final AIChatRepo _aiChatRepo;
  final UserTasteRepo? _userTasteRepo;

  final Duration _thinkingDelay;
  final Duration _cooldownDuration;
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const int _maxRequestsPerWindow = 10;
  static const String _logName = 'AIChatCubit';
  static const String _loadingPhaseAnalyzing = 'analyzing';
  static const String _loadingPhaseCatalog = 'catalog';
  static const String _loadingPhaseFiltering = 'filtering';
  static const String _loadingPhaseWorker = 'worker';
  static const String _loadingPhaseFinalGuard = 'final_guard';

  final List<int> _requestTimestampsMs = <int>[];
  Timer? _cooldownTimer;
  String? _lastAskQuestion;
  String _sessionId = _newSessionId();
  String _chatDebugId = _newChatDebugId();
  String? _persistedSessionUserId;
  String? _observedAuthUserId;
  int _authTransitionVersion = 0;
  late final AIChatSessionPersistenceHelper _sessionPersistenceHelper;
  final AIChatSessionIdStore _sessionIdStore = const AIChatSessionIdStore();
  final AIChatStoredMessageRestorer _storedMessageRestorer =
      const AIChatStoredMessageRestorer();
  late final AIChatFeedbackHelper _feedbackHelper;
  late final AIChatTurnDebugRemoteSink _turnDebugRemoteSink;
  late final AIChatReplyHandler _replyHandler;
  late final AIChatAnalyticsTracker _analyticsTracker;
  late final AIChatSessionActions _sessionActions;
  final AIChatTurnService _turnService = const AIChatTurnService();
  final AIChatTurnDecisionEngine _turnDecisionEngine =
      const AIChatTurnDecisionEngine();
  final AIChatConversationOrchestrator _conversationOrchestrator =
      const AIChatConversationOrchestrator();
  final AIChatDeterministicGate _deterministicGate =
      const AIChatDeterministicGate();
  final AIChatDiscoveryService _discoveryService =
      const AIChatDiscoveryService();
  late final AIChatInterpretationService _interpretationService;
  final AIChatModifierService _modifierService = const AIChatModifierService();
  final AIChatDeterministicCommerceRouter _deterministicCommerceRouter =
      const AIChatDeterministicCommerceRouter();
  late final AIChatToolExecutor _toolExecutor;
  final AIChatToolResultRenderer _toolResultRenderer =
      const AIChatToolResultRenderer();
  final AIChatProductContextSignals _productContextSignals =
      const AIChatProductContextSignals();
  late final AIChatBusinessInfoResponder _businessInfoResponder;
  final AIChatDebugSessionBuilder _debugSessionBuilder =
      const AIChatDebugSessionBuilder();
  final Set<String> _remoteDebugTurnIdsSent = <String>{};
  String _lastTurnDebugSendStatus = 'not_started';
  String? _lastTurnDebugSendError;
  final AIChatRecommendationSelectionResolver _selectionResolver =
      const AIChatRecommendationSelectionResolver();
  final AIChatPreferenceChangeDetector _preferenceChangeDetector =
      const AIChatPreferenceChangeDetector();
  final AIChatRecommendationMemoryAnswerBuilder _memoryAnswerBuilder =
      const AIChatRecommendationMemoryAnswerBuilder();
  late final AIChatLocalCatalogCommandHandler _localCatalogCommandHandler;
  late final AIChatRecommendationResolver _recommendationResolver;
  late final AIChatWorkerFirstExperimentResolver _workerFirstExperimentResolver;
  late final AIChatWorkerReplyService _workerReplyService;
  final AvailabilityFlowService _availabilityFlowService =
      const AvailabilityFlowService();
  final AvailabilityRouteResolver _availabilityRouteResolver =
      const AvailabilityRouteResolver();
  final CatalogQueryService _catalogQueryService = const CatalogQueryService();
  final AIChatAnswerGroundingGuard _answerGroundingGuard =
      const AIChatAnswerGroundingGuard();

  /// Stores the preferences snapshot before a modifier chain starts.
  /// Used by revert requests to restore the pre-modifier state.
  SessionPreferences? _baselinePreferences;

  String _analyticsToolStatus(AIChatToolResultStatus status) {
    return switch (status) {
      AIChatToolResultStatus.success => 'success',
      AIChatToolResultStatus.needsClarification => 'needs_clarification',
      AIChatToolResultStatus.noResults => 'no_results',
      AIChatToolResultStatus.blockedByGuard => 'blocked_by_guard',
      AIChatToolResultStatus.validationFailed => 'validation_failed',
    };
  }

  void _recordDeterministicGateShadowDecision({
    required AIChatTurnContext incoming,
    required List<ProductModel> catalog,
    required AIChatTurnDecision oldDecision,
    required String oldSource,
  }) {
    if (!AIChatExperimentConfig.analyticsEventsEnabled ||
        !AIChatExperimentConfig.deterministicGateShadowEnabled) {
      return;
    }

    final decision = _deterministicGate.evaluate(
      message: incoming.trimmed,
      language: incoming.responseLanguage,
      catalog: catalog,
      memory: incoming.effectiveRecommendationMemory,
    );
    _analyticsTracker.record(
      eventType: 'local_gate_shadow_decision',
      requestId: incoming.requestId,
      sessionId: incoming.activeSessionId,
      language: incoming.responseLanguage,
      messageLength: incoming.trimmed.length,
      oldRoute: oldDecision.route.name,
      oldAction: oldDecision.action,
      oldSource: oldSource,
      shadowGateResult: decision.result.name,
      shadowGateRoute: decision.route,
      wouldSendToLlm: decision.wouldSendToLlm,
      shouldRenderCards: decision.shouldRenderCards,
      proofLevel: decision.proofLevel.name,
      shadowGateProofReasons: decision.proofReasons,
      ambiguityReasons: decision.ambiguityReasons,
    );
  }

  Future<bool> _tryActivateDeterministicGate({
    required AIChatTurnContext incoming,
    required List<ProductModel> catalog,
    required bool pruneHistoricalBotMessages,
  }) async {
    if (!AIChatExperimentConfig.deterministicGateV1) return false;

    final decision = _deterministicGate.evaluate(
      message: incoming.trimmed,
      language: incoming.responseLanguage,
      catalog: catalog,
      memory: incoming.effectiveRecommendationMemory,
    );

    _logDecisionTrace(
      incoming,
      AIChatDecisionTrace(
        detectedLanguage: incoming.responseLanguage.code,
        detectedIntent: incoming.intent.name,
        availabilityRoute: decision.route,
        availabilityReasonCode: 'deterministic_gate_${decision.result.name}',
        routeAction: decision.wouldSendToLlm
            ? 'continue_semantic_path'
            : 'try_local_deterministic_handler',
        shouldRenderCards: decision.shouldRenderCards,
        decisionOwner: 'deterministic_gate_v1',
        clarificationType:
            decision.result == AIChatDeterministicGateResult.needsClarification
            ? decision.route
            : null,
        llmEscalationReason:
            decision.result == AIChatDeterministicGateResult.needsLlm
            ? 'insufficient_deterministic_proof'
            : null,
        finalGuardDecision: decision.isLocalSafe
            ? 'deterministic_gate_local_safe'
            : 'deterministic_gate_not_handled',
      ),
      phase: 'deterministic_gate_activation',
    );

    if (decision.result == AIChatDeterministicGateResult.needsLlm) {
      return false;
    }

    if (decision.result == AIChatDeterministicGateResult.blocked) {
      final blockedDecision = AIChatTurnDecision(
        route: AIChatTurnDecisionRoute.offTopic,
        confidence: AIChatTurnDecisionConfidence.high,
        reasonCode: decision.route,
        shouldAllowAvailability: false,
      );
      return _handleOffTopicRequest(
        incoming,
        blockedDecision,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
    }

    if (decision.result == AIChatDeterministicGateResult.needsClarification) {
      return _tryHandleDeterministicGateClarification(
        decision,
        incoming,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
    }

    if (!decision.isLocalSafe) return false;

    switch (decision.route) {
      case 'direct_catalog_query':
        return _handleDirectCatalogQuery(
          incoming,
          catalog,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
      case 'exact_catalog_availability':
        return _handleDirectAvailabilityQueryGuard(
          incoming,
          catalog,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
      case 'deterministic_visible_product_question':
        return _tryHandleVisibleProductsAnalyticalAnswer(
          incoming.trimmed,
          language: incoming.responseLanguage,
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
      case 'pending_clarification_selection':
        if (state.recommendationMemory.pendingPerfumeReferenceClarification !=
            null) {
          return _handlePerfumeReferenceSelectionCommand(
            incoming,
            catalog,
            pruneHistoricalBotMessages: pruneHistoricalBotMessages,
          );
        }
        return _handleRecommendationSelectionCommand(
          incoming,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
      default:
        return false;
    }
  }

  bool _tryHandleDeterministicGateClarification(
    AIChatDeterministicGateDecision decision,
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    switch (decision.route) {
      case 'ambiguous_egyptian_sweet':
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question: _t(
              incoming.responseLanguage,
              ar: '\u062a\u0642\u0635\u062f \u0631\u064a\u062d\u0629 \u0645\u0633\u0643\u0631\u0629 \u0648\u062d\u0644\u0648\u0629\u060c \u0648\u0644\u0627 \u0631\u064a\u062d\u0629 \u062c\u0645\u064a\u0644\u0629 \u0648\u0644\u0637\u064a\u0641\u0629 \u0639\u0645\u0648\u0645\u064b\u0627\u061f',
              en: 'Do you mean a sweet/sugary scent, or a generally nice and soft scent?',
            ),
            updatedPreferences: state.preferences,
          ),
          language: incoming.responseLanguage,
          source: 'deterministic_gate_ambiguous_egyptian_sweet',
          reasonCode: 'ambiguous_egyptian_sweet',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return true;
      case 'pending_clarification_selection':
        return _handleRecommendationSelectionCommand(
          incoming,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
      default:
        // Conservative PR13C rule: unknown or copy-less clarification routes
        // fall through to the current semantic path instead of creating a new
        // local ask.
        return false;
    }
  }

  Future<bool> _tryHandleExternalFamilyAmbiguityLookup(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) async {
    if (!AIChatExperimentConfig.deterministicGateV1) return false;
    final query = _extractSingleTokenExternalFamilyQuery(incoming.trimmed);
    if (query == null) return false;

    return _executeLocalPerfumeReferenceTool(
      incoming: incoming,
      catalog: catalog,
      toolName: AIChatToolName.lookupExternalPerfumeProfile,
      arguments: <String, dynamic>{'query': query},
      provider: 'local',
      modelId: 'external_family_ambiguity_v1',
      promptVersion: 'external_family_ambiguity_v1',
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
  }

  Future<bool> _handlePerfumeReferenceSelectionCommand(
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

    return _executeLocalPerfumeReferenceTool(
      incoming: incoming,
      catalog: catalog,
      toolName: AIChatToolName.selectPerfumeReferenceOption,
      arguments: <String, dynamic>{'selection': incoming.trimmed},
      provider: 'local',
      modelId: 'external_reference_selection_v1',
      promptVersion: 'external_reference_selection_v1',
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
  }

  Future<bool> _executeLocalPerfumeReferenceTool({
    required AIChatTurnContext incoming,
    required List<ProductModel> catalog,
    required AIChatToolName toolName,
    required Map<String, dynamic> arguments,
    required String provider,
    required String modelId,
    required String promptVersion,
    required bool pruneHistoricalBotMessages,
  }) async {
    final reply = AIChatReply.toolCall(
      toolCall: AIChatToolCall(
        name: toolName,
        arguments: arguments,
        confidence: 1,
      ),
      updatedPreferences: state.preferences,
      requestId: incoming.requestId,
      provider: provider,
      modelId: modelId,
      promptVersion: promptVersion,
    );
    final result = await _toolExecutor.execute(
      reply: reply,
      catalog: catalog,
      currentPreferences: state.preferences,
      language: incoming.responseLanguage,
      recommendationMemory: state.recommendationMemory,
    );
    if (result.updatedRecommendationMemory != null) {
      _applyToolRecommendationMemory(result.updatedRecommendationMemory!);
    }
    _analyticsTracker.record(
      eventType: 'tool_executed',
      requestId: incoming.requestId,
      sessionId: incoming.activeSessionId,
      language: incoming.responseLanguage,
      messageLength: incoming.trimmed.length,
      route: 'external_reference_local_tool',
      action: result.action.name,
      source: result.source,
      toolName: toolName.name,
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

  String? _extractSingleTokenExternalFamilyQuery(String message) {
    final normalized = AIChatTextNormalizer.normalizeForParsing(
      message,
    ).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    if (normalized.isEmpty) return null;

    String? query;
    final patterns = <RegExp>[
      RegExp(r'\b(?:something\s+like|similar\s+to|like)\s+(.+)$'),
      RegExp(r'\b(?:شبه|زي|زى)\s+(.+)$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        query = match.group(1);
        break;
      }
    }
    if (query == null) return null;
    query = query
        .replaceFirst(RegExp(r'\b(?:but\s+cheaper|cheaper)\b.*$'), '')
        .replaceFirst(RegExp(r'\b(?:ارخص|أرخص)\b.*$'), '')
        .replaceAll(RegExp(r'[?!.،,]+'), ' ')
        .trim();
    final tokens = query.split(RegExp(r'\s+')).where((item) => item.isNotEmpty);
    if (tokens.length != 1) return null;
    final token = tokens.single;
    const ambiguousFamilies = <String>{
      'sauvage',
      'blue',
      'bleu',
      'one',
      'code',
      'hero',
      'wanted',
      'libre',
      'chance',
    };
    return ambiguousFamilies.contains(token) ? token : null;
  }

  Future<bool> _tryHandleSocialMicroTurn(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final isSocialMicroTurn =
        incoming.isGreetingOnly || _looksLikeSocialMicroTurn(incoming.trimmed);
    if (!isSocialMicroTurn) return false;

    if (AIChatExperimentConfig.toolRouterV1) {
      final discovery = _resolveDiscoveryContext(incoming);
      final greetingContext = _buildMicroTurnRecommendationContext(
        catalog,
        discovery,
      );
      _setLoadingPhase(_loadingPhaseWorker);
      final workerReply = await _workerReplyService.fetchAndNormalize(
        incoming: incoming,
        discovery: discovery,
        recommendationContext: greetingContext,
        currentPreferences: state.preferences,
        lastAskQuestion: _lastAskQuestion,
        currentMessages: state.messages,
      );
      final reply = workerReply.reply;
      final answer = reply?.answer?.trim() ?? '';
      if (reply != null &&
          reply.isAnswer &&
          answer.isNotEmpty &&
          !_looksLikeNoMatchAnswerText(answer)) {
        _replyHandler.handleAnswerReply(
          _polishSocialMicroReply(reply),
          language: incoming.responseLanguage,
          source: 'social_micro_turn_worker',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return true;
      }
    }

    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: buildSocialGreetingFallbackText(incoming.responseLanguage),
        updatedPreferences: state.preferences,
      ),
      language: incoming.responseLanguage,
      source: 'local_social_greeting_fallback',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      workerFailureReason:
          _aiChatRepo.lastWorkerFailureReasonCode ?? 'worker_empty_reply',
    );
    return true;
  }

  AIChatCubit({
    required AIChatRepo aiChatRepo,
    UserTasteRepo? userTasteRepo,
    AIChatLanguage initialLanguage = AIChatLanguage.arabic,
    Duration thinkingDelay = const Duration(milliseconds: 800),
    Duration cooldownDuration = const Duration(seconds: 3),
    AIChatAnalyticsTracker? analyticsTracker,
  }) : _aiChatRepo = aiChatRepo,
       _userTasteRepo = userTasteRepo,
       _thinkingDelay = thinkingDelay,
       _cooldownDuration = cooldownDuration,
       super(AIChatState(language: initialLanguage)) {
    _analyticsTracker =
        analyticsTracker ??
        AIChatAnalyticsTracker.fromConfig(chatDebugId: _chatDebugId);
    _turnDebugRemoteSink =
        AIChatExperimentConfig.turnDebugRemoteEnabled &&
            AIChatExperimentConfig.debugCaptureMode != 'off'
        ? WorkerAIChatTurnDebugRemoteSink(aiChatRepo: _aiChatRepo)
        : const NoopAIChatTurnDebugRemoteSink();
    _analyticsTracker.onTurnTraceRecorded = _handleTurnTraceRecorded;
    _businessInfoResponder = AIChatBusinessInfoResponder(translate: _t);
    _toolExecutor = AIChatToolExecutor(
      lookupKnowledge: _aiChatRepo.lookupPerfumeKnowledge,
      lookupExternal: _aiChatRepo.lookupExternalPerfumeKnowledgeResult,
    );
    _localCatalogCommandHandler = AIChatLocalCatalogCommandHandler(
      translate: _t,
    );
    _sessionPersistenceHelper = AIChatSessionPersistenceHelper(
      aiChatRepo: _aiChatRepo,
      logName: _logName,
    );
    _recommendationResolver = AIChatRecommendationResolver(translate: _t);
    _workerFirstExperimentResolver =
        const AIChatWorkerFirstExperimentResolver();
    _interpretationService = AIChatInterpretationService(
      aiChatRepo: _aiChatRepo,
    );
    _workerReplyService = AIChatWorkerReplyService(
      aiChatRepo: _aiChatRepo,
      hasMissingFoundationalDiscoverySlots:
          _hasMissingFoundationalDiscoverySlots,
    );
    _feedbackHelper = AIChatFeedbackHelper(
      aiChatRepo: _aiChatRepo,
      analyticsTracker: _analyticsTracker,
      remoteSink: AIChatExperimentConfig.traceRemoteSinkEnabled
          ? WorkerAIChatFeedbackRemoteSink(aiChatRepo: _aiChatRepo)
          : const NoopAIChatFeedbackRemoteSink(),
      logName: _logName,
    );
    _replyHandler = AIChatReplyHandler(
      getState: () => state,
      emitState: emit,
      startCooldown: () {
        _cooldownTimer = startCooldownTimer(
          existingTimer: _cooldownTimer,
          cooldownDuration: _cooldownDuration,
          getState: () => state,
          emitState: emit,
          isClosed: () => isClosed,
        );
      },
      onAskQuestion: (question) {
        _lastAskQuestion = question;
      },
      sessionPersistenceHelper: _sessionPersistenceHelper,
      aiChatRepo: _aiChatRepo,
      analyticsTracker: _analyticsTracker,
      translate: _t,
    );
    _sessionActions = AIChatSessionActions(
      getState: () => state,
      emitState: emit,
      aiChatRepo: _aiChatRepo,
      feedbackHelper: _feedbackHelper,
      sessionPersistenceHelper: _sessionPersistenceHelper,
      userTasteRepo: _userTasteRepo,
      getSessionId: () => _sessionId,
      setSessionId: (sessionId) {
        _sessionId = sessionId;
        _chatDebugId = _newChatDebugId();
        _remoteDebugTurnIdsSent.clear();
        _lastTurnDebugSendStatus = 'not_started';
        _lastTurnDebugSendError = null;
      },
      cancelCooldown: () {
        _cooldownTimer?.cancel();
      },
      resetTransientConversationState: () {
        _requestTimestampsMs.clear();
        _lastAskQuestion = null;
        _baselinePreferences = null;
      },
      saveLastSessionId: _saveLastSessionId,
      clearLastSessionId: _clearLastSessionId,
      newSessionId: _newSessionId,
      translate: _t,
      logName: _logName,
    );
    _aiChatRepo.setSessionId(_sessionId);
    final initialUserId = _aiChatRepo.currentUserId;
    _observedAuthUserId = initialUserId?.trim().isEmpty == true
        ? null
        : initialUserId?.trim();
    if (initialUserId == null || initialUserId.isEmpty) {
      sendWelcomeMessage(getState: () => state, emitState: emit);
    } else {
      unawaited(_bootstrapSession(initialLanguage));
    }
  }

  @override
  Future<void> close() async {
    _cooldownTimer?.cancel();
    await _sessionPersistenceHelper.completeSessionById(_sessionId);
    return super.close();
  }

  String _t(AIChatLanguage language, {required String ar, required String en}) {
    return language.isArabic ? ar : en;
  }

  void _logDebug(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, name: _logName, error: error, stackTrace: stackTrace);
  }

  void _emitState(AIChatState nextState) {
    emit(nextState);
  }

  Future<void> handleAuthUserChanged(String? userId) async {
    final normalizedUserId = userId?.trim();
    final nextUserId = normalizedUserId == null || normalizedUserId.isEmpty
        ? null
        : normalizedUserId;
    if (nextUserId == _observedAuthUserId) return;

    final transitionVersion = ++_authTransitionVersion;
    _observedAuthUserId = nextUserId;
    _cooldownTimer?.cancel();
    _requestTimestampsMs.clear();
    _lastAskQuestion = null;
    _baselinePreferences = null;
    _persistedSessionUserId = null;

    _sessionId = _newSessionId();
    _chatDebugId = _newChatDebugId();
    _remoteDebugTurnIdsSent.clear();
    _lastTurnDebugSendStatus = 'not_started';
    _lastTurnDebugSendError = null;
    _aiChatRepo.setSessionId(_sessionId);
    _aiChatRepo.invalidateCatalogCache();

    final language = state.language;
    if (!isClosed) emit(AIChatState(language: language));

    if (nextUserId == null) {
      if (!isClosed && transitionVersion == _authTransitionVersion) {
        sendWelcomeMessage(getState: () => state, emitState: emit);
      }
      return;
    }

    await _bootstrapSession(language, authTransitionVersion: transitionVersion);
  }

  bool _isAuthTransitionCurrent(int? authTransitionVersion) {
    return authTransitionVersion == null ||
        authTransitionVersion == _authTransitionVersion;
  }

  Future<void> _bootstrapSession(
    AIChatLanguage initialLanguage, {
    int? authTransitionVersion,
  }) async {
    final restored = await _tryRestorePreviousSession(
      initialLanguage,
      authTransitionVersion: authTransitionVersion,
    );
    if (restored ||
        isClosed ||
        !_isAuthTransitionCurrent(authTransitionVersion)) {
      return;
    }

    sendWelcomeMessage(getState: () => state, emitState: emit);
    await _ensureSessionPersistenceForCurrentUser(
      authTransitionVersion: authTransitionVersion,
    );
  }

  Future<void> _ensureSessionPersistenceForCurrentUser({
    int? authTransitionVersion,
  }) async {
    final userId = _aiChatRepo.currentUserId;
    if (userId == null || userId.isEmpty) return;
    if (_persistedSessionUserId == userId) return;
    if (!_isAuthTransitionCurrent(authTransitionVersion)) return;

    final created = await _sessionPersistenceHelper.startSessionPersistence(
      sessionId: _sessionId,
      language: state.language,
      seedMessages: state.messages,
    );
    if (!created ||
        isClosed ||
        !_isAuthTransitionCurrent(authTransitionVersion)) {
      return;
    }

    _persistedSessionUserId = userId;
    await _saveLastSessionId(_sessionId);
  }

  Future<bool> _tryRestorePreviousSession(
    AIChatLanguage fallbackLanguage, {
    int? authTransitionVersion,
  }) async {
    final userId = _aiChatRepo.currentUserId;
    if (userId == null || userId.isEmpty) return false;

    try {
      final storedSessionId = await _sessionIdStore.load(userId: userId);
      var session = storedSessionId == null
          ? null
          : await _aiChatRepo.fetchRestorableSessionById(
              sessionId: storedSessionId,
              userId: userId,
            );
      session ??= await _aiChatRepo.fetchLatestRestorableSession(
        userId: userId,
      );
      if (session == null) return false;

      final storedMessages = await _aiChatRepo.fetchSessionMessages(session.id);
      final restoredMessages = await _restoreStoredMessages(storedMessages);
      if (restoredMessages.isEmpty) return false;
      if (isClosed || !_isAuthTransitionCurrent(authTransitionVersion)) {
        return true;
      }

      final restoredLanguage = _languageFromCode(session.language);
      _sessionId = session.id;
      _aiChatRepo.setSessionId(_sessionId);
      _aiChatRepo.invalidateCatalogCache();
      emit(AIChatState(language: restoredLanguage, messages: restoredMessages));
      final started = await _sessionPersistenceHelper.startSessionPersistence(
        sessionId: _sessionId,
        language: restoredLanguage,
        seedMessages: restoredMessages,
      );
      if (started) {
        _persistedSessionUserId = userId;
        await _sessionIdStore.save(_sessionId, userId: userId);
      }
      return true;
    } catch (error, stackTrace) {
      _logDebug(
        'Failed to restore previous AI chat session.',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed &&
          state.messages.isEmpty &&
          state.language != fallbackLanguage) {
        emit(state.copyWith(language: fallbackLanguage));
      }
      return false;
    }
  }

  Future<List<AIChatMessage>> _restoreStoredMessages(
    List<AIChatStoredMessage> storedMessages,
  ) async {
    return _storedMessageRestorer.restore(
      storedMessages,
      fetchProductsByIds: _aiChatRepo.fetchProductsByIds,
    );
  }

  AIChatLanguage _languageFromCode(String code) {
    return code.trim().toLowerCase() == 'en'
        ? AIChatLanguage.english
        : AIChatLanguage.arabic;
  }

  Future<void> _saveLastSessionId(String sessionId, {String? userId}) async {
    await _sessionIdStore.save(
      sessionId,
      userId: userId ?? _aiChatRepo.currentUserId,
    );
  }

  Future<void> _clearLastSessionId() async {
    await _sessionIdStore.clear(userId: _aiChatRepo.currentUserId);
  }

  void _setLoadingPhase(String phase) {
    if (isClosed || state.status != AIChatStatus.loading) return;
    if (state.loadingPhase == phase) return;
    emit(state.copyWith(loadingPhase: phase));
  }

  void _applyToolRecommendationMemory(RecommendationMemory memory) {
    if (isClosed) return;
    emit(state.copyWith(recommendationMemory: memory));
  }

  String _shortText(String value, {int maxLength = 180}) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= maxLength) return cleaned;
    return '${cleaned.substring(0, maxLength)}...';
  }

  String _currentAiModeTelemetryValue() {
    return AIChatExperimentConfig.aiModeTelemetryValue;
  }

  void syncLanguage(AIChatLanguage language) {
    if (state.language == language) return;
    emit(
      state.copyWith(
        language: language,
        messages: localizedOpeningMessages(state.messages, language),
      ),
    );
  }

  Future<void> sendMessage(String text) async {
    if (state.status == AIChatStatus.loading) {
      return;
    }
    if (state.isInCooldown &&
        !_canBypassCooldownForAvailabilityClarification(text)) {
      return;
    }

    final validatedIncoming = _validateIncomingMessage(text);
    if (validatedIncoming == null) return;
    var incoming = validatedIncoming;

    var fallbackPreferences = state.preferences;
    final shouldPruneActiveTurnMessages =
        _shouldPruneStaleRecommendationsForTurn(incoming);
    var shouldPruneBotHistory = false;

    _logDebug(
      'Outgoing user message | sessionId=${incoming.activeSessionId} | requestId=${incoming.requestId} | '
      'language=${incoming.responseLanguage.code} | intent=${incoming.intent.name} | '
      'len=${incoming.trimmed.length} | hasRecommendationContext=${incoming.effectiveRecommendationMemory.lastRecommendedProducts.isNotEmpty} | '
      'greetingOnly=${incoming.isGreetingOnly} | continueAvailabilityClarification=${incoming.shouldContinueAvailabilityClarification} | '
      'message="${_shortText(incoming.trimmed)}"',
    );

    await _ensureSessionPersistenceForCurrentUser();
    _prepareActiveTurn(
      incoming,
      pruneHistoricalBotMessages: shouldPruneActiveTurnMessages,
    );

    if (_handleConversationResetCommand(incoming)) {
      return;
    }

    await Future.delayed(_thinkingDelay);

    try {
      _setLoadingPhase(_loadingPhaseCatalog);
      final catalog = await _aiChatRepo.getCatalog();
      _logDebug(
        'Catalog loaded for requestId=${incoming.requestId} | catalogSize=${catalog.length} | '
        'currentPrefs=${state.preferences.toJson()}',
      );

      var turnDecision = _turnDecisionEngine.decide(
        incoming: incoming,
        state: state,
        catalog: catalog,
        shouldContinueAvailabilityClarification:
            _shouldContinueAvailabilityClarification,
      );
      var gateShadowRecorded = false;
      void recordGateShadow(String oldSource) {
        if (gateShadowRecorded) return;
        gateShadowRecorded = true;
        _recordDeterministicGateShadowDecision(
          incoming: incoming,
          catalog: catalog,
          oldDecision: turnDecision,
          oldSource: oldSource,
        );
      }

      _logDecisionTrace(
        incoming,
        AIChatDecisionTrace(
          detectedLanguage: incoming.responseLanguage.code,
          detectedIntent: incoming.intent.name,
          availabilityRoute: turnDecision.route.name,
          availabilityReasonCode: turnDecision.reasonCode,
          routeAction: turnDecision.action,
          shouldRenderCards: turnDecision.shouldRenderCards,
          decisionOwner: turnDecision.decisionOwner,
          ownershipClass: turnDecision.ownershipClass,
          semanticIntent: turnDecision.semanticIntent,
          localSkippedReason: turnDecision.localSkippedReason,
          clarificationType: turnDecision.clarificationType,
          llmEscalationReason: turnDecision.llmEscalationReason,
          finalGuardDecision: turnDecision.shouldAllowAvailability
              ? 'availability_allowed'
              : 'availability_blocked',
        ),
        phase: 'turn_decision',
      );

      if (await _tryActivateDeterministicGate(
        incoming: incoming,
        catalog: catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (await _tryHandleSocialMicroTurn(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        recordGateShadow('social_micro_turn_precheck');
        return;
      }

      if (await _tryHandleExternalFamilyAmbiguityLookup(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        recordGateShadow('external_family_ambiguity_precheck');
        return;
      }

      if (await _handleDirectCatalogQuery(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        recordGateShadow('direct_catalog_precheck');
        return;
      }

      _setLoadingPhase(_loadingPhaseAnalyzing);
      var oldSourceForGateShadow = 'turn_decision';
      final interpretation = await _interpretationService.interpretIfUseful(
        incoming: incoming,
        turnDecision: turnDecision,
        state: state,
        catalog: catalog,
      );
      if (interpretation != null) {
        incoming = interpretation.incoming;
        oldSourceForGateShadow = 'interpretation_applied';
        turnDecision = _turnDecisionEngine.decide(
          incoming: incoming,
          state: state,
          catalog: catalog,
          shouldContinueAvailabilityClarification:
              _shouldContinueAvailabilityClarification,
        );
        if (turnDecision.route == AIChatTurnDecisionRoute.clarify &&
            (interpretation.result.intent == 'recommendation' ||
                interpretation.result.intent == 'modifier' ||
                interpretation.result.intent == 'answer')) {
          turnDecision = AIChatTurnDecision(
            route: AIChatTurnDecisionRoute.recommendation,
            confidence: AIChatTurnDecisionConfidence.medium,
            reasonCode: 'interpretation_${interpretation.result.reasonCode}',
            shouldAllowAvailability: false,
          );
        }
        _logDecisionTrace(
          incoming,
          AIChatDecisionTrace(
            detectedLanguage: incoming.responseLanguage.code,
            detectedIntent: incoming.intent.name,
            availabilityRoute: turnDecision.route.name,
            availabilityReasonCode: turnDecision.reasonCode,
            routeAction: turnDecision.action,
            shouldRenderCards: turnDecision.shouldRenderCards,
            decisionOwner: turnDecision.decisionOwner,
            ownershipClass: turnDecision.ownershipClass,
            semanticIntent: turnDecision.semanticIntent,
            localSkippedReason: turnDecision.localSkippedReason,
            clarificationType: turnDecision.clarificationType,
            llmEscalationReason: turnDecision.llmEscalationReason,
            finalGuardDecision: turnDecision.shouldAllowAvailability
                ? 'availability_allowed'
                : 'availability_blocked',
            interpretationIntent: interpretation.result.intent,
            interpretationConfidence: interpretation.result.confidence,
            interpretationReasonCode: interpretation.result.reasonCode,
            interpretationProductQueryCandidate:
                interpretation.result.productQueryCandidate,
            interpretationDecision: 'accepted',
            preferencePatch: interpretation.result.preferencePatch.toJson(),
          ),
          phase: 'interpretation_applied',
        );
      }
      recordGateShadow(oldSourceForGateShadow);

      if (await _handleBusinessInfoCommand(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleOffTopicRequest(
        incoming,
        turnDecision,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleImpossiblePremiumBudgetGuard(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_tryHandleVisibleProductsAnalyticalAnswer(
        incoming.trimmed,
        language: incoming.responseLanguage,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (await _handleDirectCatalogQuery(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleFantasyNoteInterception(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (turnDecision.shouldAllowAvailability) {
        if (await _handleDirectAvailabilityQueryGuard(
          incoming,
          catalog,
          pruneHistoricalBotMessages: shouldPruneBotHistory,
        )) {
          return;
        }
      }

      if (await _handleLocalCatalogCommand(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleCatalogProductContextQuestion(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleFocusedProductContextQuestion(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleRecommendationMemoryQuestion(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (await _handleDeterministicCommerceToolFollowUp(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleRecommendationSelectionCommand(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleDirectExclusionOnlySafetyUpdate(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (await _tryHandleProductKnowledgeQuestion(
        message: incoming.trimmed,
        catalog: catalog,
        language: incoming.responseLanguage,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleBlockedAvailabilityQuestion(
        incoming,
        turnDecision,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleAdviceOnlyQuestion(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleContextualQualityAnswer(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleImpossiblePurchaseRequest(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (await _handleEarlyContextAnswers(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      final shouldDelegateMicroTurn = _shouldDelegateMicroTurnToWorker(
        incoming,
        turnDecision,
      );

      if (turnDecision.route == AIChatTurnDecisionRoute.clarify &&
          !shouldDelegateMicroTurn &&
          !AIChatExperimentConfig.toolRouterV1) {
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question: _t(
              incoming.responseLanguage,
              ar: 'تقصد تتأكد من توفر عطر معين، ولا تحب أرشح لك عطر من الكتالوج؟',
              en: 'Do you want me to check availability for a specific perfume, or suggest a perfume from the catalog?',
            ),
            updatedPreferences: state.preferences,
          ),
          language: incoming.responseLanguage,
          source: 'local_turn_decision_clarify',
          reasonCode: turnDecision.reasonCode,
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: shouldPruneBotHistory,
        );
        return;
      }

      if (await _handleEarlyContextAnswers(
        incoming,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (_handleEarlyInterception(
        incoming,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      if (turnDecision.shouldAllowAvailability) {
        if (await _handleAvailabilityBranches(
          incoming,
          pruneHistoricalBotMessages: shouldPruneBotHistory,
        )) {
          return;
        }
      }

      _setLoadingPhase(_loadingPhaseFiltering);
      final discovery = _resolveDiscoveryContext(incoming);
      shouldPruneBotHistory = discovery.shouldPruneBotHistory;
      fallbackPreferences = discovery.localPreferences;

      if (_handleExclusionOnlySafetyUpdate(
        incoming,
        discovery,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      )) {
        return;
      }

      final isSocialMicroTurn =
          incoming.isGreetingOnly ||
          _looksLikeSocialMicroTurn(incoming.trimmed);
      if (!discovery.isFollowUpOrCompare && isSocialMicroTurn) {
        if (AIChatExperimentConfig.toolRouterV1) {
          final greetingContext = _buildMicroTurnRecommendationContext(
            catalog,
            discovery,
          );
          _setLoadingPhase(_loadingPhaseWorker);
          final workerReply = await _workerReplyService.fetchAndNormalize(
            incoming: incoming,
            discovery: discovery,
            recommendationContext: greetingContext,
            currentPreferences: state.preferences,
            lastAskQuestion: _lastAskQuestion,
            currentMessages: state.messages,
          );
          if (workerReply.reply != null) {
            final microTurnReply = workerReply.reply!;
            final microTurnAnswer = microTurnReply.answer?.trim() ?? '';
            if (microTurnReply.isAnswer &&
                microTurnAnswer.isNotEmpty &&
                !_looksLikeNoMatchAnswerText(microTurnAnswer)) {
              _replyHandler.handleAnswerReply(
                _polishSocialMicroReply(microTurnReply),
                language: incoming.responseLanguage,
                source: 'social_micro_turn_worker',
                sessionId: incoming.activeSessionId,
                pruneHistoricalBotMessages: shouldPruneBotHistory,
              );
              return;
            }
          }
        }

        _replyHandler.handleAnswerReply(
          AIChatReply.answer(
            answer: buildSocialGreetingFallbackText(incoming.responseLanguage),
            updatedPreferences: state.preferences,
          ),
          language: incoming.responseLanguage,
          source: 'local_social_greeting_fallback',
          sessionId: incoming.activeSessionId,
          pruneHistoricalBotMessages: shouldPruneBotHistory,
          workerFailureReason:
              _aiChatRepo.lastWorkerFailureReasonCode ?? 'worker_empty_reply',
        );
        return;
      }

      if (!shouldDelegateMicroTurn &&
          await _handleModifierPatchIfAny(
            incoming,
            discovery,
            pruneHistoricalBotMessages: shouldPruneBotHistory,
          )) {
        return;
      }

      final useWorkerFirstRecommendationFlow =
          _shouldUseWorkerFirstRecommendationFlow(incoming, discovery);
      final recommendationResolution = useWorkerFirstRecommendationFlow
          ? _workerFirstExperimentResolver.resolve(
              incoming: incoming,
              discovery: discovery,
              catalog: catalog,
              currentPreferences: state.preferences,
            )
          : _recommendationResolver.resolve(
              incoming: incoming,
              discovery: discovery,
              catalog: catalog,
              currentPreferences: state.preferences,
            );
      _logDecisionTrace(
        incoming,
        recommendationResolution.trace,
        phase: useWorkerFirstRecommendationFlow
            ? 'recommendation_resolved_worker_first'
            : 'recommendation_resolved',
      );
      if (recommendationResolution.handledResult.handled &&
          !shouldDelegateMicroTurn) {
        if (useWorkerFirstRecommendationFlow) {
          _logWorkerFirstExperimentUsage(
            incoming: incoming,
            candidateCountBeforeFilter: catalog.length,
            candidateCountAfterFilter: 0,
            workerCalled: false,
            fallbackReason:
                recommendationResolution.handledResult.reasonCode ??
                recommendationResolution.handledResult.issueCode,
          );
        }
        await _renderHandledResult(
          recommendationResolution.handledResult,
          incoming,
          fallbackLanguage: incoming.responseLanguage,
          fallbackPruneHistoricalBotMessages: shouldPruneBotHistory,
        );
        return;
      }

      final recommendationContext =
          recommendationResolution.recommendationContext ??
          (shouldDelegateMicroTurn
              ? _buildMicroTurnRecommendationContext(catalog, discovery)
              : null);
      if (recommendationContext == null) {
        _logDebug(
          'No recommendation context resolved | requestId=${incoming.requestId} | intent=${incoming.intent.name}',
        );
        _replyHandler.replyWithFallback(
          _t(
            incoming.responseLanguage,
            ar: 'لم أقدر أجهز ترشيح موثوق من الطلب ده. جرّب طلب أبسط أو اذكر الميزانية والمناسبة.',
            en: 'I could not prepare a reliable recommendation from that request. Try a simpler request or include budget and occasion.',
          ),
          language: incoming.responseLanguage,
          source: 'recommendation_context_missing',
          updatedPreferences: fallbackPreferences,
          issueCode: 'recommendation_context_missing',
          reasonCode: 'recommendation_context_missing',
          sessionId: incoming.activeSessionId,
          requestId: incoming.requestId,
          pruneHistoricalBotMessages: shouldPruneBotHistory,
        );
        return;
      }
      _syncRecommendationFocus(incoming, recommendationContext);
      if (useWorkerFirstRecommendationFlow) {
        _logWorkerFirstExperimentUsage(
          incoming: incoming,
          candidateCountBeforeFilter: catalog.length,
          candidateCountAfterFilter:
              recommendationContext.candidatesList.length,
          workerCalled: true,
        );
      }

      _setLoadingPhase(_loadingPhaseWorker);
      final workerReply = await _workerReplyService.fetchAndNormalize(
        incoming: incoming,
        discovery: discovery,
        recommendationContext: recommendationContext,
        currentPreferences: state.preferences,
        lastAskQuestion: _lastAskQuestion,
        currentMessages: state.messages,
      );
      final effectiveWorkerReply = await _handleWorkerFailureFallback(
        incoming,
        discovery,
        recommendationContext,
        catalog,
        workerReply,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      );
      if (effectiveWorkerReply == null) {
        _logDebug(
          'Worker reply resolved to null after fallback handling | requestId=${incoming.requestId}',
        );
        return;
      }

      _setLoadingPhase(_loadingPhaseFinalGuard);
      await _renderFinalReply(
        incoming,
        discovery,
        recommendationContext,
        effectiveWorkerReply,
        catalog,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      );
    } catch (e, stackTrace) {
      _logDebug(
        'Unexpected AI chat error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _replyHandler.replyWithFallback(
        _t(
          incoming.responseLanguage,
          ar: 'حصل خطأ غير متوقع. حاول مرة أخرى بعد قليل.',
          en: 'An unexpected error happened. Please try again in a moment.',
        ),
        language: incoming.responseLanguage,
        source: 'exception',
        updatedPreferences: fallbackPreferences,
        issueCode: 'unexpected_exception',
        reasonCode: 'unexpected_exception',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: shouldPruneBotHistory,
      );
    }
  }

  bool _canBypassCooldownForAvailabilityClarification(String text) {
    if (text.trim().isEmpty) return false;
    return state.availabilityContext.availabilityStatus ==
            AvailabilityStatus.ambiguous &&
        state.availabilityContext.externalCandidates.isNotEmpty;
  }

  bool hasRecommendationInCurrentSession() {
    return state.messages.any((message) => message.isRecommendation);
  }

  bool _handleConversationResetCommand(AIChatTurnContext incoming) {
    if (!LocalIntentParser.shouldResetConversationContext(incoming.trimmed)) {
      return false;
    }

    _lastAskQuestion = null;
    _baselinePreferences = null;
    final resetPreferences = _preferencesFromResetCommand(incoming.trimmed);
    _emitState(
      state.copyWith(
        preferences: resetPreferences,
        recommendationMemory: const RecommendationMemory(),
        availabilityContext: const AvailabilityContext.empty(),
        notifiedProductIds: const <String>{},
      ),
    );
    if (resetPreferences.activeCriteriaCount > 0) {
      return false;
    }

    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: _t(
          incoming.responseLanguage,
          ar: 'تمام، مسحت التفضيلات السابقة. تحب عطر رجالي ولا نسائي ولا يونيسكس؟',
          en: 'I cleared the previous preferences. Do you want a men\'s, women\'s, or unisex perfume?',
        ),
        updatedPreferences: resetPreferences,
        provider: 'local',
        modelId: 'context_reset',
        promptVersion: 'context_reset_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_context_reset',
      issueCode: 'context_reset',
      reasonCode: 'start_over',
      sessionId: incoming.activeSessionId,
      availabilityContext: const AvailabilityContext.empty(),
      pruneHistoricalBotMessages: true,
    );
    return true;
  }

  AIChatReply _polishSocialMicroReply(AIChatReply reply) {
    final answer = reply.answer?.trim();
    if (answer == null || answer.isEmpty) return reply;
    final userTurnCount = state.messages
        .where((item) => item.isFromUser)
        .length;
    if (userTurnCount > 1) return reply;
    final polished = answer.replaceFirst(
      RegExp(r'^hello\s+again[!,.]?\s*', caseSensitive: false),
      'Hello! ',
    );
    if (polished == answer) return reply;
    return AIChatReply.answer(
      answer: polished.trim(),
      updatedPreferences: reply.updatedPreferences,
      requestId: reply.requestId,
      promptVersion: reply.promptVersion,
      provider: reply.provider,
      modelId: reply.modelId,
      preferencePatch: reply.preferencePatch,
    );
  }

  SessionPreferences _preferencesFromResetCommand(String message) {
    var preferences = LocalIntentParser.parse(
      message,
      SessionPreferences.empty(),
    );
    final normalized = LocalIntentParser.normalizeInput(message);
    final genderFromRecipient = _recipientGenderFromResetMessage(normalized);
    if (genderFromRecipient == null) {
      return preferences;
    }

    final tags = <String>{...preferences.tags, 'gift'}.toList();
    return preferences.copyWith(
      gender: genderFromRecipient,
      occasion: 'gift',
      tags: tags,
    );
  }

  String? _recipientGenderFromResetMessage(String normalized) {
    const womenRecipients = {
      '\u0648\u0627\u0644\u062f\u062a\u064a',
      '\u0648\u0627\u0644\u062f\u062a\u0649',
      '\u0627\u0645\u064a',
      '\u0623\u0645\u064a',
      '\u0645\u0627\u0645\u0627',
      '\u0627\u062e\u062a\u064a',
      '\u0623\u062e\u062a\u064a',
      '\u0645\u0631\u0627\u062a\u064a',
      '\u0632\u0648\u062c\u062a\u064a',
      '\u0628\u0646\u062a\u064a',
    };
    const menRecipients = {
      '\u0648\u0627\u0644\u062f\u064a',
      '\u0648\u0627\u0644\u062f\u0649',
      '\u0627\u0628\u0648\u064a\u0627',
      '\u0623\u0628\u0648\u064a\u0627',
      '\u0628\u0627\u0628\u0627',
      '\u0627\u062e\u0648\u064a\u0627',
      '\u0623\u062e\u0648\u064a\u0627',
      '\u062c\u0648\u0632\u064a',
      '\u0632\u0648\u062c\u064a',
      '\u0627\u0628\u0646\u064a',
    };

    if (womenRecipients.any(normalized.contains)) return 'women';
    if (menRecipients.any(normalized.contains)) return 'men';
    return null;
  }

  Future<bool> _handleBusinessInfoCommand(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (_businessInfoResponder.looksLikeBlockedFollowUp(normalized)) {
      return false;
    }
    final request = _businessInfoResponder.requestType(normalized);
    if (request == null) return false;

    final info = await _aiChatRepo.fetchBusinessInfo();
    final text = _businessInfoResponder.buildAnswer(
      info,
      request: request,
      language: incoming.responseLanguage,
    );
    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: text,
        updatedPreferences: state.preferences,
        provider: 'local',
        modelId: 'business_info',
        promptVersion: 'business_info_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_business_info',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  Future<bool> _handleDirectCatalogQuery(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final normalizedMessage = LocalIntentParser.normalizeInput(
      incoming.trimmed,
    );
    final asksAboutVisibleRecommendations =
        normalizedMessage.contains('among them') ||
        normalizedMessage.contains('between them') ||
        normalizedMessage.contains('of these') ||
        normalizedMessage.contains('from these') ||
        normalizedMessage.contains('من دول') ||
        normalizedMessage.contains('فيهم') ||
        normalizedMessage.contains('بينهم');
    if (asksAboutVisibleRecommendations &&
        (state.recommendationMemory.lastRecommendedProducts.isNotEmpty ||
            state.messages.any((message) => message.isRecommendation))) {
      return false;
    }

    final result = _catalogQueryService.resolve(
      message: incoming.trimmed,
      catalog: catalog,
      currentPreferences: state.preferences,
      language: incoming.responseLanguage,
    );
    if (result == null) return false;

    _logDecisionTrace(
      incoming,
      AIChatDecisionTrace(
        detectedLanguage: incoming.responseLanguage.code,
        detectedIntent: incoming.intent.name,
        availabilityRoute: 'catalog_query',
        availabilityReasonCode:
            'direct_catalog_query_${result.query.type.name}',
        routeAction: 'execute_tool',
        shouldRenderCards: result.hasRecommendations,
        decisionOwner: 'local_gate',
        finalGuardDecision: result.hasRecommendations
            ? 'catalog_query_cards_allowed'
            : 'catalog_query_answer_only',
        finalProductIds: result.recommendations
            .map((item) => item.product.id)
            .toList(growable: false),
      ),
      phase: 'route_decision',
    );

    _logDebug(
      'Direct catalog query handled | type=${result.query.type.name} | '
      'source=${result.responseSource} | count=${result.recommendations.length} | '
      'requestId=${incoming.requestId}',
    );

    if (!result.hasRecommendations) {
      _replyHandler.handleAnswerReply(
        result.reply,
        language: incoming.responseLanguage,
        source: result.responseSource,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final guardResult =
        FinalRecommendationGuard(
          translate: _t,
          logEvent: (eventType, metadata) {
            return _aiChatRepo.logAIChatEvent(
              eventType: eventType,
              sessionId: incoming.activeSessionId,
              metadata: {
                ...metadata,
                'requestId': incoming.requestId,
                'catalogQueryType': result.query.type.name,
              },
            );
          },
        ).guard(
          reply: result.reply,
          catalog: catalog,
          recommendationContext: AIChatRecommendationContext(
            localCandidatesRefs: result.recommendations,
            candidatesList: result.recommendations
                .map((item) => item.product)
                .toList(growable: false),
            localFallbackAnswer: null,
            effectivePreferences: result.effectivePreferences,
          ),
          language: incoming.responseLanguage,
          responseSource: result.responseSource,
        );

    final guardSafeProducts = guardResult.safeProducts.isNotEmpty
        ? guardResult.safeProducts
        : guardResult.localRecoveryProducts;
    final safeProducts = _applySuitabilityPolicyToRecommendations(
      guardSafeProducts,
      preferences: result.effectivePreferences,
      hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(
        incoming.trimmed,
      ),
      sourcePath: result.responseSource,
    );
    if (safeProducts.isEmpty) {
      _replyHandler.replyWithFallback(
        buildNoMatchMessage(
          incoming.trimmed,
          result.effectivePreferences,
          catalog,
          incoming.responseLanguage,
          reasonCode: guardResult.reasonCode ?? result.reasonCode,
        ),
        language: incoming.responseLanguage,
        source: result.responseSource,
        updatedPreferences: result.effectivePreferences,
        isNoMatch: true,
        issueCode:
            guardResult.issueCode ??
            result.issueCode ??
            'catalog_query_no_match',
        reasonCode: guardResult.reasonCode ?? result.reasonCode,
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    _replyHandler.handleRecommendationReply(
      result.reply,
      safeProducts,
      language: incoming.responseLanguage,
      source: result.responseSource,
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  List<RecommendedProduct> _applySuitabilityPolicyToRecommendations(
    List<RecommendedProduct> products, {
    required SessionPreferences preferences,
    required bool hasExplicitBudget,
    required String sourcePath,
  }) {
    if (!AIChatExperimentConfig.useSuitabilityPolicy || products.isEmpty) {
      return products;
    }
    return const SuitabilityPolicyEngine()
        .applyToRecommendations(
          products: products,
          context: SuitabilityContext(
            preferences: preferences,
            hasExplicitBudget: hasExplicitBudget,
            sourcePath: sourcePath,
          ),
        )
        .products;
  }

  Future<bool> _handleLocalCatalogCommand(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final result = await _localCatalogCommandHandler.resolve(
      message: incoming.trimmed,
      language: incoming.responseLanguage,
      catalog: catalog,
      preferences: state.preferences,
      recommendationMemory: state.recommendationMemory,
      fetchProductPublicStats: _aiChatRepo.fetchProductPublicStats,
    );
    if (result == null) return false;

    if (result.isAsk) {
      _replyHandler.handleAskReply(
        result.reply,
        language: incoming.responseLanguage,
        source: result.source,
        reasonCode: result.reasonCode,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    if (result.recommendations.isEmpty) {
      _replyHandler.handleAnswerReply(
        result.reply,
        language: incoming.responseLanguage,
        source: result.source,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    _replyHandler.handleRecommendationReply(
      result.reply,
      result.recommendations,
      language: incoming.responseLanguage,
      source: result.source,
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  void _syncLastBudgetNoMatchContext({
    required SessionPreferences preferences,
    required List<ProductModel> catalog,
    required String reasonCode,
  }) {
    if (!_isBudgetNoMatchReason(reasonCode) || preferences.maxBudget == null) {
      return;
    }
    final availableProducts = catalog.where(
      (product) => product.isActive && product.stock > 0,
    );
    if (availableProducts.isEmpty) return;

    final lowestPrice = availableProducts
        .map((product) => product.effectivePrice)
        .reduce((value, element) => value < element ? value : element);
    final lowestProductIds = availableProducts
        .where((product) => product.effectivePrice == lowestPrice)
        .map((product) => product.id)
        .take(3)
        .toList(growable: false);

    _emitState(
      state.copyWith(
        recommendationMemory: state.recommendationMemory.copyWith(
          lastNoMatchContext: LastNoMatchContext(
            reason: 'budget_no_match',
            requestedBudget: preferences.maxBudget,
            lowestAvailablePrice: lowestPrice,
            lowestAvailableProductIds: lowestProductIds,
          ),
        ),
      ),
    );
  }

  bool _isBudgetNoMatchReason(String reasonCode) {
    return reasonCode == 'budget_no_match' ||
        reasonCode == 'strict_budget_no_match' ||
        reasonCode == 'modifier_no_match' ||
        reasonCode == 'no_candidate_match';
  }

  RecommendedProductRef _focusedOrFirstRecommendation(
    List<RecommendedProductRef> refs,
  ) {
    final focusedId = state.recommendationMemory.lastFocusedProductId;
    if (focusedId == null) return refs.first;
    return refs.firstWhere(
      (ref) => ref.productId == focusedId,
      orElse: () => refs.first,
    );
  }

  bool _handleBlockedAvailabilityQuestion(
    AIChatTurnContext incoming,
    AIChatTurnDecision turnDecision, {
    required bool pruneHistoricalBotMessages,
  }) {
    if (!_looksLikeBlockedAvailabilityQuestion(incoming)) return false;
    if (turnDecision.shouldAllowAvailability) return false;
    if (turnDecision.route == AIChatTurnDecisionRoute.clarify) return false;

    final hasRecommendationContext =
        state.recommendationMemory.lastRecommendedProducts.isNotEmpty;
    final question = _t(
      incoming.responseLanguage,
      ar: hasRecommendationContext
          ? 'أي منتج من الترشيحات تحب أتأكد منه؟ اكتب اسمه أو رقمه، مثل: الأول أو Dior Sauvage.'
          : 'أي عطر تحب أتأكد منه؟ اكتب اسم العطر بوضوح وسأتحقق منه لك.',
      en: hasRecommendationContext
          ? 'Which recommended product do you want me to check? Send its name or number, like first or Dior Sauvage.'
          : 'Which perfume do you want me to check? Send the perfume name clearly and I will verify it.',
    );
    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: question,
        updatedPreferences: state.preferences,
      ),
      language: incoming.responseLanguage,
      source: 'blocked_availability_missing_product',
      reasonCode: 'availability_missing_product_anchor',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _looksLikeBlockedAvailabilityQuestion(AIChatTurnContext incoming) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) return false;

    final freshPreferences = LocalIntentParser.parse(
      incoming.trimmed,
      SessionPreferences.empty(),
    );
    final hasPreferenceSignal =
        freshPreferences.maxBudget != null ||
        freshPreferences.activeCriteriaCount > 0 ||
        freshPreferences.hasAnyNoteSignal ||
        freshPreferences.intensity != null ||
        freshPreferences.tags.isNotEmpty;
    if (hasPreferenceSignal) return false;

    final looksLikeAvailabilityOrPrice =
        RegExp(
          r'\b(available|availability|price|cost|how much)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u0645\u0648\u062c\u0648\u062f') ||
        normalized.contains('\u0645\u062a\u0648\u0641\u0631') ||
        normalized.contains('\u0633\u0639\u0631') ||
        normalized.contains('\u0628\u0643\u0627\u0645') ||
        normalized.contains('\u0628\u0643\u0645');
    if (incoming.intent == AIChatIntent.availabilityCheck) {
      return looksLikeAvailabilityOrPrice;
    }
    return looksLikeAvailabilityOrPrice;
  }

  String _buildContextSuitabilityAnswer(
    RecommendedProductRef ref,
    String normalizedMessage,
    AIChatLanguage language,
  ) {
    final context =
        _productContextSignals.extractContextLabel(normalizedMessage) ??
        'that context';
    final productText = [
      ref.season,
      ref.occasion,
      ref.intensity,
      ...ref.notes,
      ...ref.topNotes,
      ...ref.middleNotes,
      ...ref.baseNotes,
      ...ref.tags,
    ].map(LocalIntentParser.normalizeInput).join(' ');
    final positives = <String>[];
    final caveats = <String>[];

    if (context == 'office') {
      if (productText.contains('office') ||
          productText.contains('day') ||
          productText.contains('all day')) {
        positives.add('it has an office/day profile');
      }
      if (productText.contains('fresh') ||
          productText.contains('clean') ||
          productText.contains('citrus') ||
          productText.contains('musk')) {
        positives.add('the profile is clean or fresh');
      }
      if (productText.contains('night') || productText.contains('strong')) {
        caveats.add('it may feel a bit loud for quiet offices');
      }
    } else if (context == 'university') {
      if (productText.contains('day') ||
          productText.contains('daily') ||
          productText.contains('office')) {
        positives.add('it leans practical for daytime use');
      }
      if (productText.contains('fresh') ||
          productText.contains('clean') ||
          productText.contains('citrus')) {
        positives.add('it has a fresh/clean direction');
      }
      if (productText.contains('night') || productText.contains('strong')) {
        caveats.add('it may be heavier than ideal for university');
      }
    } else if (context == 'gym') {
      if (productText.contains('fresh') ||
          productText.contains('clean') ||
          productText.contains('citrus') ||
          productText.contains('aquatic')) {
        positives.add('it has a fresh/clean profile');
      }
      if (!productText.contains('light')) {
        caveats.add('it is not marked as light, so use it lightly');
      }
    } else if (context == 'date') {
      if (productText.contains('romantic') ||
          productText.contains('sweet') ||
          productText.contains('warm') ||
          productText.contains('date')) {
        positives.add('it has a warmer or more dressed-up profile');
      }
      if (productText.contains('office') || productText.contains('clean')) {
        caveats.add('it may feel cleaner than romantic');
      }
    } else {
      if (productText.contains('daily') ||
          productText.contains('day') ||
          productText.contains('fresh') ||
          productText.contains('clean')) {
        positives.add('it has an easy daily profile');
      }
    }

    final price = ref.price.toStringAsFixed(0);
    final fallbackProfile = ref.notes.take(2).join(', ');
    final positiveText = positives.isEmpty
        ? fallbackProfile.isEmpty
              ? 'it is available in the catalog'
              : 'it has catalog notes like $fallbackProfile'
        : positives.take(2).join(' and ');
    final caveatText = caveats.isEmpty ? '' : ' Caveat: ${caveats.first}.';

    if (language.isArabic) {
      final caveat = caveats.isEmpty
          ? ''
          : ' \u0645\u0644\u0627\u062d\u0638\u0629: ${caveats.first}.';
      return '${ref.name} \u064a\u0646\u0641\u0639 \u0644\u0640 $context \u0628\u0634\u0643\u0644 \u0645\u0639\u0642\u0648\u0644 \u0644\u0623\u0646 $positiveText. \u0634\u062f\u062a\u0647 ${ref.intensity} \u0648\u0633\u0639\u0631\u0647 $price \u062c\u0646\u064a\u0647.$caveat';
    }
    return '${ref.name} can work for $context because $positiveText. It is ${ref.intensity} intensity and costs $price EGP.$caveatText';
  }

  String _buildCatalogProductContextSuitabilityAnswer(
    ProductModel product,
    String normalizedMessage,
    AIChatLanguage language,
  ) {
    final ref = RecommendedProductRef(
      productId: product.id,
      name: product.name,
      brand: product.brand,
      displayIndex: 1,
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
    );
    return _buildContextSuitabilityAnswer(ref, normalizedMessage, language);
  }

  bool _shouldDelegateMicroTurnToWorker(
    AIChatTurnContext incoming,
    AIChatTurnDecision turnDecision,
  ) {
    if (!AIChatExperimentConfig.sendCompactContext) {
      return false;
    }

    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) return false;
    final isSemanticRouterFollowUp =
        AIChatExperimentConfig.toolRouterV1 &&
        _looksLikeSemanticRouterFollowUp(normalized, incoming);
    if (!AIChatExperimentConfig.delegateMicroTurns &&
        !isSemanticRouterFollowUp) {
      return false;
    }
    final tokenCount = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .length;
    final isShortConversationalReply =
        normalized.length <= 40 && tokenCount <= 4;
    if (!isShortConversationalReply && !isSemanticRouterFollowUp) return false;

    final hasPriorQuestion =
        _lastAskQuestion != null && _lastAskQuestion!.trim().isNotEmpty;
    final hasVisibleCards = incoming
        .effectiveRecommendationMemory
        .lastRecommendedProducts
        .isNotEmpty;
    final lastAskSlot = inferAskedSlot(_lastAskQuestion ?? '');
    if (!hasPriorQuestion && !hasVisibleCards && lastAskSlot == null) {
      return false;
    }

    if (turnDecision.shouldAllowAvailability ||
        turnDecision.route == AIChatTurnDecisionRoute.availability ||
        turnDecision.route == AIChatTurnDecisionRoute.availabilityFollowUp ||
        turnDecision.route == AIChatTurnDecisionRoute.offTopic) {
      return false;
    }
    if (_businessInfoResponder.requestType(normalized) != null) return false;
    if (_directSafetyExcludedNotes(incoming.trimmed).isNotEmpty) return false;
    if (normalized.contains('allergy') ||
        normalized.contains('allergic') ||
        normalized.contains('sensitive') ||
        normalized.contains('\u062d\u0633\u0627\u0633')) {
      return false;
    }
    if (LocalIntentParser.looksLikeOutOfDomainRequest(
      incoming.trimmed,
      currentPreferences: state.preferences,
    )) {
      return false;
    }

    return true;
  }

  bool _looksLikeSocialMicroTurn(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    return RegExp(
          r"\b(how are you|how r you|how are u|how r u|how is it going|what'?s up|whats up)\b",
        ).hasMatch(normalized) ||
        normalized.contains('\u0639\u0627\u0645\u0644 \u0627\u064a\u0647') ||
        normalized.contains(
          '\u0639\u0627\u0645\u0644\u0629 \u0627\u064a\u0647',
        ) ||
        normalized.contains('\u0627\u0632\u064a\u0643') ||
        normalized.contains('\u0627\u0632\u064a\u0643\u061f');
  }

  bool _looksLikeNoMatchAnswerText(String answer) {
    final normalized = answer.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.contains('safe in-stock catalog match') ||
        normalized.contains('in-stock catalog match') ||
        normalized.contains('catalog match for the current constraints') ||
        normalized.contains('no matching products') ||
        normalized.contains('no safe recommendation');
  }

  bool _looksLikeSemanticRouterFollowUp(
    String normalized,
    AIChatTurnContext incoming,
  ) {
    final hasVisibleCards = incoming
        .effectiveRecommendationMemory
        .lastRecommendedProducts
        .isNotEmpty;
    final hasFocusedProduct =
        incoming.effectiveRecommendationMemory.lastFocusedProductId != null;
    final hasBudgetNoMatch =
        incoming.effectiveRecommendationMemory.lastNoMatchContext?.reason ==
        'budget_no_match';
    if (!hasVisibleCards && !hasFocusedProduct && !hasBudgetNoMatch) {
      return false;
    }

    final acceptsBudgetFloor =
        hasBudgetNoMatch &&
        (RegExp(r'\b(ok|okay|yes|show|available|it)\b').hasMatch(normalized) ||
            normalized.contains('show me it') ||
            normalized.contains('show me the available one'));
    final rejectsVisible =
        RegExp(
          r"\b(i don'?t like|dont like|not these|change these|other options|different options)\b",
        ).hasMatch(normalized) ||
        normalized.contains('\u0645\u0634 \u0639\u0627\u062c\u0628') ||
        normalized.contains('\u063a\u064a\u0631\u0647\u0645');
    final cheaperFollowUp =
        RegExp(
          r'\b(similar but cheaper|something similar but cheaper|cheaper than it|anything cheaper|cheaper one|less expensive)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u0627\u0631\u062e\u0635') ||
        normalized.contains('\u0623\u0631\u062e\u0635');
    final refinementFollowUp =
        _productContextSignals.classifyRecommendationRefinementConflict(
              normalized,
            ) ==
            'llm' ||
        RegExp(
          r'\b(make|change|switch|turn)\b.*\b(suitable|university|office|work)\b',
        ).hasMatch(normalized);

    return acceptsBudgetFloor ||
        rejectsVisible ||
        cheaperFollowUp ||
        refinementFollowUp;
  }

  AIChatRecommendationContext _buildMicroTurnRecommendationContext(
    List<ProductModel> catalog,
    AIChatDiscoveryContext discovery,
  ) {
    final effectivePreferences = state.preferences.mergePatch(
      discovery.localPreferences,
    );
    final exactCandidates = LocalCandidateFilter.getTopRecommendations(
      catalog: catalog,
      preferences: effectivePreferences,
    );
    final upsellCandidates =
        discovery.budgetPolicy == AIChatBudgetPolicy.flexible
        ? LocalCandidateFilter.getTopUpsellRecommendations(
            catalog: catalog,
            preferences: effectivePreferences,
          )
        : const <RecommendedProduct>[];
    final localCandidates = [
      ...exactCandidates,
      ...upsellCandidates.where(
        (upsell) => !exactCandidates.any(
          (exact) => exact.product.id == upsell.product.id,
        ),
      ),
    ];
    final candidatesList = localCandidates.isNotEmpty
        ? localCandidates
              .take(15)
              .map((candidate) => candidate.product)
              .toList()
        : catalog
              .where((product) => product.isActive && product.stock > 0)
              .take(15)
              .toList(growable: false);

    return AIChatRecommendationContext(
      localCandidatesRefs: localCandidates,
      candidatesList: candidatesList,
      localFallbackAnswer: null,
      budgetPolicy: discovery.budgetPolicy,
      effectivePreferences: effectivePreferences,
    );
  }

  bool _shouldBlockHandledFilledSlotAsk(
    AIChatTurnContext incoming,
    AIChatHandledResult result,
  ) {
    if (LocalIntentParser.shouldResetConversationContext(incoming.trimmed)) {
      return false;
    }
    if (incoming.intent != AIChatIntent.newRecommendation) {
      return false;
    }
    if (incoming
        .effectiveRecommendationMemory
        .lastRecommendedProducts
        .isNotEmpty) {
      return true;
    }
    if (hasRecommendationInCurrentSession() &&
        LocalIntentParser.detectBudgetPolicy(incoming.trimmed) ==
            AIChatBudgetPolicy.strict) {
      return true;
    }
    if (state.preferences.activeCriteriaCount >= 3) {
      return true;
    }
    return AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      incoming.trimmed,
    );
  }

  bool _shouldPruneStaleRecommendationsForTurn(AIChatTurnContext incoming) {
    if (LocalIntentParser.shouldResetConversationContext(incoming.trimmed)) {
      return hasRecommendationInCurrentSession();
    }
    final parsedPreferences = LocalIntentParser.parse(
      incoming.trimmed,
      state.preferences,
    );
    final noteConstraintsChanged = _preferenceChangeDetector
        .hasNoteConstraintDelta(state.preferences, parsedPreferences);
    if (noteConstraintsChanged) return true;
    if (!hasRecommendationInCurrentSession()) return false;
    return LocalIntentParser.detectBudgetPolicy(incoming.trimmed) ==
        AIChatBudgetPolicy.strict;
  }

  bool _shouldBlockConstraintRefinementAsk(
    AIChatTurnContext incoming,
    String? askedSlot,
  ) {
    if (askedSlot == null) return false;
    if (!hasRecommendationInCurrentSession()) return false;
    if (LocalIntentParser.shouldResetConversationContext(incoming.trimmed)) {
      return false;
    }
    return LocalIntentParser.detectBudgetPolicy(incoming.trimmed) ==
        AIChatBudgetPolicy.strict;
  }

  Future<void> _renderHandledResult(
    AIChatHandledResult result,
    AIChatTurnContext incoming, {
    required AIChatLanguage fallbackLanguage,
    required bool fallbackPruneHistoricalBotMessages,
  }) async {
    final language = fallbackLanguage;
    final pruneHistoricalBotMessages =
        result.pruneHistoricalBotMessages || fallbackPruneHistoricalBotMessages;

    final reply = result.reply;
    if (reply != null &&
        reply.isRecommend &&
        result.recommendedProducts.isNotEmpty) {
      _replyHandler.handleRecommendationReply(
        reply,
        result.recommendedProducts,
        language: language,
        source: result.source ?? 'handled_result',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return;
    }

    if (reply != null && reply.isAsk) {
      final askedSlot = inferAskedSlot(reply.question ?? '');
      final resultPreferences = result.preferences;
      final alreadyFilled =
          askedSlot != null &&
          (isSlotAlreadyFilled(state.preferences, askedSlot) ||
              isSlotAlreadyFilled(reply.updatedPreferences, askedSlot) ||
              (resultPreferences != null &&
                  isSlotAlreadyFilled(resultPreferences, askedSlot)));

      _logDebug(
        'Handled ask guard check | askedSlot=$askedSlot | '
        'alreadyFilled=$alreadyFilled | source=${result.source} | '
        'stateGender=${state.preferences.gender} | '
        'stateSeason=${state.preferences.season} | '
        'stateBudget=${state.preferences.maxBudget} | '
        'replyGender=${reply.updatedPreferences.gender} | '
        'requestId=${incoming.requestId}',
      );

      final shouldBlockFilledSlotAsk =
          (alreadyFilled ||
              _shouldBlockConstraintRefinementAsk(incoming, askedSlot)) &&
          _shouldBlockHandledFilledSlotAsk(incoming, result);
      if (shouldBlockFilledSlotAsk) {
        final catalog = await _aiChatRepo.getCatalog();
        final groundTruthPreferences = state.preferences
            .mergePatch(resultPreferences ?? const SessionPreferences())
            .mergePatch(reply.updatedPreferences);
        final exactCandidates = LocalCandidateFilter.getTopRecommendations(
          catalog: catalog,
          preferences: groundTruthPreferences,
        );
        final upsellCandidates =
            LocalIntentParser.detectBudgetPolicy(incoming.trimmed) ==
                AIChatBudgetPolicy.flexible
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
          _logDebug(
            'Handled ask guard recovered recommendation | askedSlot=$askedSlot | '
            'candidateCount=${recoveryProducts.length} | requestId=${incoming.requestId}',
          );
          _replyHandler.handleRecommendationReply(
            buildRecommendReplyFromLocalCandidates(
              recoveryProducts,
              updatedPreferences: groundTruthPreferences,
              requestId: reply.requestId,
              promptVersion: reply.promptVersion,
              provider: reply.provider,
              modelId: reply.modelId,
            ),
            recoveryProducts,
            language: language,
            source: '${result.source ?? 'handled_result'}_filled_slot_recovery',
            sessionId: incoming.activeSessionId,
            pruneHistoricalBotMessages: pruneHistoricalBotMessages,
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
        _logDebug(
          'Handled ask guard blocked redundant ask with no candidates | '
          'askedSlot=$askedSlot | noMatchReason=$noMatchReason | '
          'requestId=${incoming.requestId}',
        );
        _replyHandler.replyWithFallback(
          buildNoMatchMessage(
            incoming.trimmed,
            groundTruthPreferences,
            catalog,
            language,
            reasonCode: noMatchReason,
          ),
          language: language,
          source: '${result.source ?? 'handled_result'}_filled_slot_no_match',
          updatedPreferences: groundTruthPreferences,
          isNoMatch: true,
          issueCode: 'filled_slot_no_candidate',
          reasonCode: noMatchReason,
          sessionId: incoming.activeSessionId,
          requestId: incoming.requestId,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return;
      }

      if (looksLikeGenericPreferenceAsk(reply.question ?? '')) {
        final effectivePreferences = state.preferences
            .mergePatch(resultPreferences ?? const SessionPreferences())
            .mergePatch(reply.updatedPreferences);
        final missingSlots = effectivePreferences.missingSlotsForNextQuestion(
          hasRecommendationContext: incoming
              .effectiveRecommendationMemory
              .lastRecommendedProducts
              .isNotEmpty,
        );
        final retargetSlot = nextUsefulAskSlot(
          effectivePreferences,
          missingSlots,
        );
        if (retargetSlot != null) {
          _replyHandler.handleAskReply(
            AIChatReply.ask(
              question: buildQuestionForMissingSlot(retargetSlot, language),
              updatedPreferences: effectivePreferences,
              requestId: reply.requestId,
              promptVersion: reply.promptVersion,
              provider: reply.provider,
              modelId: reply.modelId,
            ),
            language: language,
            source: '${result.source ?? 'handled_result'}_targeted_ask',
            issueCode: result.issueCode,
            reasonCode: result.reasonCode,
            sessionId: incoming.activeSessionId,
            availabilityContext: result.availabilityContext,
            pruneHistoricalBotMessages: pruneHistoricalBotMessages,
          );
          return;
        }
      }

      _replyHandler.handleAskReply(
        reply,
        language: language,
        source: result.source ?? 'handled_result',
        issueCode: result.issueCode,
        reasonCode: result.reasonCode,
        sessionId: incoming.activeSessionId,
        availabilityContext: result.availabilityContext,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return;
    }

    if (reply != null && reply.isAnswer) {
      _replyHandler.handleAnswerReply(
        reply,
        language: language,
        source: result.source ?? 'handled_result',
        sessionId: incoming.activeSessionId,
        availabilityContext: result.availabilityContext,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return;
    }

    final fallbackText = result.fallbackText;
    if (fallbackText != null) {
      if (result.isNoMatch &&
          result.preferences != null &&
          result.reasonCode != null) {
        final catalog = await _aiChatRepo.getCatalog();
        _syncLastBudgetNoMatchContext(
          preferences: result.preferences!,
          catalog: catalog,
          reasonCode: result.reasonCode!,
        );
      }
      _replyHandler.replyWithFallback(
        fallbackText,
        language: language,
        source: result.source ?? 'handled_result',
        updatedPreferences: result.preferences ?? state.preferences,
        isNoMatch: result.isNoMatch,
        issueCode: result.issueCode ?? 'handled_result',
        reasonCode: result.reasonCode,
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
    }
  }

  void _syncRecommendationFocus(
    AIChatTurnContext incoming,
    AIChatRecommendationContext recommendationContext,
  ) {
    final focusProductId = recommendationContext.focusProductId;
    if (focusProductId == null) return;
    _emitState(
      state.copyWith(
        recommendationMemory: state.recommendationMemory.copyWith(
          lastRecommendedProducts:
              incoming.effectiveRecommendationMemory.lastRecommendedProducts,
          lastRecommendationBatchId:
              incoming.effectiveRecommendationMemory.lastRecommendationBatchId,
          lastFocusedProductId: focusProductId,
        ),
      ),
    );
  }

  void _logDecisionTrace(
    AIChatTurnContext incoming,
    AIChatDecisionTrace trace, {
    required String phase,
  }) {
    final traceJson = {
      'normalizedMessage': LocalIntentParser.normalizeInput(incoming.trimmed),
      ...trace.toJson(),
    };
    _logDebug(
      'Decision trace | phase=$phase | requestId=${incoming.requestId} | $traceJson',
    );
    unawaited(
      _aiChatRepo.saveAIChatDebugLog(
        phase: phase,
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        language: incoming.responseLanguage.code,
        messageText: incoming.trimmed,
        detectedIntent: incoming.intent.name,
        responseSource: 'local_trace',
        preferencesSnapshot: state.preferences.toJson(),
        candidateSummary: traceJson,
      ),
    );
    final shadowTrace = trace.catalogSearchShadow;
    if (shadowTrace != null) {
      unawaited(
        const CatalogSearchShadowService().writeArtifact(
          requestId: incoming.requestId,
          trace: shadowTrace,
        ),
      );
    }
  }

  bool hasSessionFeedbackForSession(String sessionId) {
    return _feedbackHelper.hasSessionFeedbackForSession(sessionId);
  }

  Future<bool> hasPersistedSessionFeedbackForSession(String sessionId) async {
    return _feedbackHelper.hasPersistedSessionFeedbackForSession(sessionId);
  }

  Future<void> clearSession() async {
    return _sessionActions.clearSession();
  }

  Future<bool> submitSessionFeedback({
    required int rating,
    required bool isHelpful,
    String? comment,
  }) async {
    return _sessionActions.submitSessionFeedback(
      rating: rating,
      isHelpful: isHelpful,
      comment: comment,
    );
  }

  Future<bool> submitRecommendationFeedback({
    required String messageId,
    required bool isHelpful,
    String? note,
    String? requestId,
    AIChatFeedbackReason? reason,
  }) async {
    return _sessionActions.submitRecommendationFeedback(
      messageId: messageId,
      isHelpful: isHelpful,
      note: note,
      requestId: requestId,
      reason: reason,
    );
  }

  Map<String, Object?>? exportLatestFeedbackDebugSnapshotJson() {
    return _feedbackHelper.exportLatestDebugSnapshotJson();
  }

  Map<String, Object?> exportChatDebugSessionJson() {
    return _debugSessionBuilder
        .build(
          chatDebugId: _chatDebugId,
          messages: state.messages,
          traces: _analyticsTracker.recentTurnTraces,
        )
        .toJson();
  }

  String get chatDebugId => _chatDebugId;

  Map<String, Object?> get chatDebugStatus => <String, Object?>{
    'chatDebugId': _chatDebugId,
    'analyticsEventsEnabled': AIChatExperimentConfig.analyticsEventsEnabled,
    'turnDebugRemoteEnabled': AIChatExperimentConfig.turnDebugRemoteEnabled,
    'debugCaptureMode': AIChatExperimentConfig.debugCaptureMode,
    'traceCount': _analyticsTracker.recentTurnTraces.length,
    'lastTurnDebugSendStatus': _lastTurnDebugSendStatus,
    'lastTurnDebugSendError': _lastTurnDebugSendError,
  };

  static String _newSessionId() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  static String _newChatDebugId() {
    final compact = const Uuid().v4().replaceAll('-', '').substring(0, 10);
    return 'chat_dbg_$compact';
  }

  void _handleTurnTraceRecorded(AIChatTurnTrace trace) {
    if (!AIChatExperimentConfig.turnDebugRemoteEnabled) {
      _lastTurnDebugSendStatus = 'remote_disabled';
      return;
    }
    if (AIChatExperimentConfig.debugCaptureMode != 'all') {
      _lastTurnDebugSendStatus =
          'capture_${AIChatExperimentConfig.debugCaptureMode}';
      return;
    }
    if (trace.turnId.trim().isEmpty) {
      _lastTurnDebugSendStatus = 'missing_turn_id';
      return;
    }
    if (!_remoteDebugTurnIdsSent.add(trace.turnId)) {
      _lastTurnDebugSendStatus = 'duplicate_turn';
      return;
    }

    _lastTurnDebugSendStatus = 'queued';
    _lastTurnDebugSendError = null;
    unawaited(_sendTurnDebugAfterStateSettles(trace));
  }

  Future<void> _sendTurnDebugAfterStateSettles(
    AIChatTurnTrace trace, {
    int attempt = 0,
  }) async {
    // The trace can be recorded just before the bot message is emitted.
    // Give the Cubit state a short chance to include the visible reply.
    await Future<void>.delayed(Duration(milliseconds: attempt == 0 ? 80 : 200));

    final session = _debugSessionBuilder.build(
      chatDebugId: _chatDebugId,
      messages: state.messages,
      traces: _analyticsTracker.recentTurnTraces,
    );
    final turn = session.turns
        .where((item) => item.turnId == trace.turnId)
        .firstOrNull;
    if (turn == null) {
      if (attempt < 4) {
        return _sendTurnDebugAfterStateSettles(trace, attempt: attempt + 1);
      }
      _lastTurnDebugSendStatus = 'no_matching_turn';
      return;
    }

    _lastTurnDebugSendStatus = 'sending';
    try {
      final sent = await _turnDebugRemoteSink.sendTurnDebug(turn);
      _lastTurnDebugSendStatus = sent ? 'success' : 'failed';
    } catch (error) {
      _lastTurnDebugSendStatus = 'failed';
      _lastTurnDebugSendError = error.toString();
    }
  }

  Future<void> onNotifyMeRequested(String productId, String userId) async {
    return _sessionActions.onNotifyMeRequested(productId, userId);
  }

  Future<void> onRecommendedProductTapped(ProductModel product) async {
    return _sessionActions.onRecommendedProductTapped(product);
  }

  Future<void> onUpsellProductTapped(RecommendedProduct recommendation) async {
    return _sessionActions.onUpsellProductTapped(recommendation);
  }
}
