import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AIChatTurnContext {
  final String trimmed;
  final String activeSessionId;
  final AIChatLanguage responseLanguage;
  final RecommendationMemory effectiveRecommendationMemory;
  final AIChatIntent intent;
  final bool shouldContinueAvailabilityClarification;
  final bool isGreetingOnly;
  final String requestId;
  final SessionPreferences interpretationPreferences;
  final String? interpretationReasonCode;
  final String? availabilityProductQuery;

  const AIChatTurnContext({
    required this.trimmed,
    required this.activeSessionId,
    required this.responseLanguage,
    required this.effectiveRecommendationMemory,
    required this.intent,
    required this.shouldContinueAvailabilityClarification,
    required this.isGreetingOnly,
    required this.requestId,
    this.interpretationPreferences = const SessionPreferences(),
    this.interpretationReasonCode,
    this.availabilityProductQuery,
  });

  AIChatTurnContext copyWith({
    AIChatIntent? intent,
    bool? isGreetingOnly,
    SessionPreferences? interpretationPreferences,
    String? interpretationReasonCode,
    String? availabilityProductQuery,
  }) {
    return AIChatTurnContext(
      trimmed: trimmed,
      activeSessionId: activeSessionId,
      responseLanguage: responseLanguage,
      effectiveRecommendationMemory: effectiveRecommendationMemory,
      intent: intent ?? this.intent,
      shouldContinueAvailabilityClarification:
          shouldContinueAvailabilityClarification,
      isGreetingOnly: isGreetingOnly ?? this.isGreetingOnly,
      requestId: requestId,
      interpretationPreferences:
          interpretationPreferences ?? this.interpretationPreferences,
      interpretationReasonCode:
          interpretationReasonCode ?? this.interpretationReasonCode,
      availabilityProductQuery:
          availabilityProductQuery ?? this.availabilityProductQuery,
    );
  }
}

class AIChatDiscoveryContext {
  final bool hasRecommendationContext;
  final bool effectiveHasRecommendationContext;
  final bool isFollowUpOrCompare;
  final bool shouldPruneBotHistory;
  final SessionPreferences localPreferences;
  final List<String> localMissingSlots;
  final bool localReadyForRecommendation;
  final String? readinessReason;
  final AIChatBudgetPolicy budgetPolicy;

  const AIChatDiscoveryContext({
    required this.hasRecommendationContext,
    required this.effectiveHasRecommendationContext,
    required this.isFollowUpOrCompare,
    required this.shouldPruneBotHistory,
    required this.localPreferences,
    required this.localMissingSlots,
    required this.localReadyForRecommendation,
    this.readinessReason,
    this.budgetPolicy = AIChatBudgetPolicy.flexible,
  });
}

class AIChatRecommendationContext {
  final List<RecommendedProduct> localCandidatesRefs;
  final List<ProductModel> candidatesList;
  final String? localFallbackAnswer;
  final String? focusProductId;
  final AIChatBudgetPolicy budgetPolicy;
  final SessionPreferences effectivePreferences;

  const AIChatRecommendationContext({
    required this.localCandidatesRefs,
    required this.candidatesList,
    required this.localFallbackAnswer,
    this.focusProductId,
    this.budgetPolicy = AIChatBudgetPolicy.flexible,
    this.effectivePreferences = const SessionPreferences(),
  });
}

class AIChatDecisionTrace {
  final String? detectedLanguage;
  final String? detectedIntent;
  final Map<String, dynamic>? preferencePatch;
  final String? availabilityRoute;
  final String? availabilityReasonCode;
  final bool? discoveryReady;
  final String? readinessReason;
  final String? budgetPolicy;
  final List<String> missingSlots;
  final String? candidateSource;
  final int localCandidateCount;
  final int workerCandidateCount;
  final String? noMatchReason;
  final String? workerAction;
  final String? finalGuardDecision;
  final String? interpretationIntent;
  final double? interpretationConfidence;
  final String? interpretationReasonCode;
  final String? interpretationProductQueryCandidate;
  final String? interpretationDecision;
  final Map<String, dynamic>? catalogSearchShadow;
  final bool? toolRouterEnabled;
  final String? toolCallName;
  final bool? toolCallValid;
  final String? toolExecutionSource;
  final bool? catalogSearchEngineEnabled;
  final bool? suitabilityPolicyEnabled;
  final String? routeAction;
  final bool? shouldRenderCards;
  final String? decisionOwner;
  final String? ownershipClass;
  final String? semanticIntent;
  final String? localSkippedReason;
  final String? clarificationType;
  final String? llmEscalationReason;
  final int? candidateCountBeforeGuard;
  final int? candidateCountAfterGuard;
  final List<String> finalProductIds;
  final List<String> blockedReasons;

  const AIChatDecisionTrace({
    this.detectedLanguage,
    this.detectedIntent,
    this.preferencePatch,
    this.availabilityRoute,
    this.availabilityReasonCode,
    this.discoveryReady,
    this.readinessReason,
    this.budgetPolicy,
    this.missingSlots = const <String>[],
    this.candidateSource,
    this.localCandidateCount = 0,
    this.workerCandidateCount = 0,
    this.noMatchReason,
    this.workerAction,
    this.finalGuardDecision,
    this.interpretationIntent,
    this.interpretationConfidence,
    this.interpretationReasonCode,
    this.interpretationProductQueryCandidate,
    this.interpretationDecision,
    this.catalogSearchShadow,
    this.toolRouterEnabled,
    this.toolCallName,
    this.toolCallValid,
    this.toolExecutionSource,
    this.catalogSearchEngineEnabled,
    this.suitabilityPolicyEnabled,
    this.routeAction,
    this.shouldRenderCards,
    this.decisionOwner,
    this.ownershipClass,
    this.semanticIntent,
    this.localSkippedReason,
    this.clarificationType,
    this.llmEscalationReason,
    this.candidateCountBeforeGuard,
    this.candidateCountAfterGuard,
    this.finalProductIds = const <String>[],
    this.blockedReasons = const <String>[],
  });

  AIChatDecisionTrace copyWith({
    String? detectedLanguage,
    String? detectedIntent,
    Map<String, dynamic>? preferencePatch,
    String? availabilityRoute,
    String? availabilityReasonCode,
    bool? discoveryReady,
    String? readinessReason,
    String? budgetPolicy,
    List<String>? missingSlots,
    String? candidateSource,
    int? localCandidateCount,
    int? workerCandidateCount,
    String? noMatchReason,
    String? workerAction,
    String? finalGuardDecision,
    String? interpretationIntent,
    double? interpretationConfidence,
    String? interpretationReasonCode,
    String? interpretationProductQueryCandidate,
    String? interpretationDecision,
    Map<String, dynamic>? catalogSearchShadow,
    bool? toolRouterEnabled,
    String? toolCallName,
    bool? toolCallValid,
    String? toolExecutionSource,
    bool? catalogSearchEngineEnabled,
    bool? suitabilityPolicyEnabled,
    String? routeAction,
    bool? shouldRenderCards,
    String? decisionOwner,
    String? ownershipClass,
    String? semanticIntent,
    String? localSkippedReason,
    String? clarificationType,
    String? llmEscalationReason,
    int? candidateCountBeforeGuard,
    int? candidateCountAfterGuard,
    List<String>? finalProductIds,
    List<String>? blockedReasons,
  }) {
    return AIChatDecisionTrace(
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      detectedIntent: detectedIntent ?? this.detectedIntent,
      preferencePatch: preferencePatch ?? this.preferencePatch,
      availabilityRoute: availabilityRoute ?? this.availabilityRoute,
      availabilityReasonCode:
          availabilityReasonCode ?? this.availabilityReasonCode,
      discoveryReady: discoveryReady ?? this.discoveryReady,
      readinessReason: readinessReason ?? this.readinessReason,
      budgetPolicy: budgetPolicy ?? this.budgetPolicy,
      missingSlots: missingSlots ?? this.missingSlots,
      candidateSource: candidateSource ?? this.candidateSource,
      localCandidateCount: localCandidateCount ?? this.localCandidateCount,
      workerCandidateCount: workerCandidateCount ?? this.workerCandidateCount,
      noMatchReason: noMatchReason ?? this.noMatchReason,
      workerAction: workerAction ?? this.workerAction,
      finalGuardDecision: finalGuardDecision ?? this.finalGuardDecision,
      interpretationIntent: interpretationIntent ?? this.interpretationIntent,
      interpretationConfidence:
          interpretationConfidence ?? this.interpretationConfidence,
      interpretationReasonCode:
          interpretationReasonCode ?? this.interpretationReasonCode,
      interpretationProductQueryCandidate:
          interpretationProductQueryCandidate ??
          this.interpretationProductQueryCandidate,
      interpretationDecision:
          interpretationDecision ?? this.interpretationDecision,
      catalogSearchShadow: catalogSearchShadow ?? this.catalogSearchShadow,
      toolRouterEnabled: toolRouterEnabled ?? this.toolRouterEnabled,
      toolCallName: toolCallName ?? this.toolCallName,
      toolCallValid: toolCallValid ?? this.toolCallValid,
      toolExecutionSource: toolExecutionSource ?? this.toolExecutionSource,
      catalogSearchEngineEnabled:
          catalogSearchEngineEnabled ?? this.catalogSearchEngineEnabled,
      suitabilityPolicyEnabled:
          suitabilityPolicyEnabled ?? this.suitabilityPolicyEnabled,
      routeAction: routeAction ?? this.routeAction,
      shouldRenderCards: shouldRenderCards ?? this.shouldRenderCards,
      decisionOwner: decisionOwner ?? this.decisionOwner,
      ownershipClass: ownershipClass ?? this.ownershipClass,
      semanticIntent: semanticIntent ?? this.semanticIntent,
      localSkippedReason: localSkippedReason ?? this.localSkippedReason,
      clarificationType: clarificationType ?? this.clarificationType,
      llmEscalationReason: llmEscalationReason ?? this.llmEscalationReason,
      candidateCountBeforeGuard:
          candidateCountBeforeGuard ?? this.candidateCountBeforeGuard,
      candidateCountAfterGuard:
          candidateCountAfterGuard ?? this.candidateCountAfterGuard,
      finalProductIds: finalProductIds ?? this.finalProductIds,
      blockedReasons: blockedReasons ?? this.blockedReasons,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (detectedLanguage != null) 'detectedLanguage': detectedLanguage,
      if (detectedIntent != null) 'detectedIntent': detectedIntent,
      if (preferencePatch != null) 'preferencePatch': preferencePatch,
      if (availabilityRoute != null) 'availabilityRoute': availabilityRoute,
      if (availabilityReasonCode != null)
        'availabilityReasonCode': availabilityReasonCode,
      if (discoveryReady != null) 'discoveryReady': discoveryReady,
      if (readinessReason != null) 'readinessReason': readinessReason,
      if (budgetPolicy != null) 'budgetPolicy': budgetPolicy,
      'missingSlots': missingSlots,
      if (candidateSource != null) 'candidateSource': candidateSource,
      'localCandidateCount': localCandidateCount,
      'workerCandidateCount': workerCandidateCount,
      if (noMatchReason != null) 'noMatchReason': noMatchReason,
      if (workerAction != null) 'workerAction': workerAction,
      if (finalGuardDecision != null) 'finalGuardDecision': finalGuardDecision,
      if (interpretationIntent != null)
        'interpretationIntent': interpretationIntent,
      if (interpretationConfidence != null)
        'interpretationConfidence': interpretationConfidence,
      if (interpretationReasonCode != null)
        'interpretationReasonCode': interpretationReasonCode,
      if (interpretationProductQueryCandidate != null)
        'interpretationProductQueryCandidate':
            interpretationProductQueryCandidate,
      if (interpretationDecision != null)
        'interpretationDecision': interpretationDecision,
      if (catalogSearchShadow != null)
        'catalogSearchShadow': catalogSearchShadow,
      if (toolRouterEnabled != null) 'toolRouterEnabled': toolRouterEnabled,
      if (toolCallName != null) 'toolCallName': toolCallName,
      if (toolCallValid != null) 'toolCallValid': toolCallValid,
      if (toolExecutionSource != null)
        'toolExecutionSource': toolExecutionSource,
      if (catalogSearchEngineEnabled != null)
        'catalogSearchEngineEnabled': catalogSearchEngineEnabled,
      if (suitabilityPolicyEnabled != null)
        'suitabilityPolicyEnabled': suitabilityPolicyEnabled,
      if (routeAction != null) 'action': routeAction,
      if (shouldRenderCards != null) 'shouldRenderCards': shouldRenderCards,
      if (decisionOwner != null) 'decisionOwner': decisionOwner,
      if (ownershipClass != null) 'ownershipClass': ownershipClass,
      if (semanticIntent != null) 'semanticIntent': semanticIntent,
      if (localSkippedReason != null)
        'localSkippedReason': localSkippedReason,
      if (clarificationType != null) 'clarificationType': clarificationType,
      if (llmEscalationReason != null)
        'llmEscalationReason': llmEscalationReason,
      if (candidateCountBeforeGuard != null)
        'candidateCountBeforeGuard': candidateCountBeforeGuard,
      if (candidateCountAfterGuard != null)
        'candidateCountAfterGuard': candidateCountAfterGuard,
      if (finalProductIds.isNotEmpty) 'finalProductIds': finalProductIds,
      if (blockedReasons.isNotEmpty) 'blockedReasons': blockedReasons,
    };
  }
}

enum AIChatTurnDecisionRoute {
  greeting,
  localCommand,
  modifier,
  recommendation,
  availability,
  availabilityFollowUp,
  clarify,
  offTopic,
}

enum AIChatTurnDecisionConfidence { high, medium, low }

class AIChatTurnDecision {
  final AIChatTurnDecisionRoute route;
  final AIChatTurnDecisionConfidence confidence;
  final String reasonCode;
  final String? productQuery;
  final bool shouldAllowAvailability;
  final String? action;
  final bool? shouldRenderCards;
  final String? decisionOwner;
  final String? ownershipClass;
  final String? semanticIntent;
  final String? localSkippedReason;
  final String? clarificationType;
  final String? llmEscalationReason;

  const AIChatTurnDecision({
    required this.route,
    required this.confidence,
    required this.reasonCode,
    this.productQuery,
    required this.shouldAllowAvailability,
    this.action,
    this.shouldRenderCards,
    this.decisionOwner,
    this.ownershipClass,
    this.semanticIntent,
    this.localSkippedReason,
    this.clarificationType,
    this.llmEscalationReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'route': route.name,
      'confidence': confidence.name,
      'reasonCode': reasonCode,
      'shouldAllowAvailability': shouldAllowAvailability,
      if (productQuery != null) 'productQuery': productQuery,
      if (action != null) 'action': action,
      if (shouldRenderCards != null) 'shouldRenderCards': shouldRenderCards,
      if (decisionOwner != null) 'decisionOwner': decisionOwner,
      if (ownershipClass != null) 'ownershipClass': ownershipClass,
      if (semanticIntent != null) 'semanticIntent': semanticIntent,
      if (localSkippedReason != null)
        'localSkippedReason': localSkippedReason,
      if (clarificationType != null) 'clarificationType': clarificationType,
      if (llmEscalationReason != null)
        'llmEscalationReason': llmEscalationReason,
    };
  }
}

class AIChatWorkerReplyContext {
  final AIChatReply? reply;
  final String responseSource;
  final String? failureReasonCode;

  const AIChatWorkerReplyContext({
    required this.reply,
    required this.responseSource,
    this.failureReasonCode,
  });
}

class FinalRecommendationGuardResult {
  final List<RecommendedProduct> safeProducts;
  final List<RecommendedProduct> localRecoveryProducts;
  final bool shouldNoMatch;
  final String? issueCode;
  final String? reasonCode;

  const FinalRecommendationGuardResult({
    this.safeProducts = const <RecommendedProduct>[],
    this.localRecoveryProducts = const <RecommendedProduct>[],
    this.shouldNoMatch = false,
    this.issueCode,
    this.reasonCode,
  });
}

class WorkerReplyServiceResult {
  final AIChatWorkerReplyContext? workerReply;
  final AIChatHandledResult handledResult;

  const WorkerReplyServiceResult({
    this.workerReply,
    this.handledResult = const AIChatHandledResult.notHandled(),
  });
}

class RecommendationResolverResult {
  final AIChatRecommendationContext? recommendationContext;
  final AIChatHandledResult handledResult;
  final AIChatDecisionTrace trace;

  const RecommendationResolverResult({
    this.recommendationContext,
    this.handledResult = const AIChatHandledResult.notHandled(),
    this.trace = const AIChatDecisionTrace(),
  });
}

class AIChatHandledResult {
  final bool handled;
  final AIChatReply? reply;
  final List<RecommendedProduct> recommendedProducts;
  final AIChatMessage? availabilityMessage;
  final AvailabilityContext? availabilityContext;
  final SessionPreferences? preferences;
  final String? source;
  final String? issueCode;
  final String? reasonCode;
  final bool pruneHistoricalBotMessages;
  final String? fallbackText;
  final bool isNoMatch;

  const AIChatHandledResult({
    required this.handled,
    this.reply,
    this.recommendedProducts = const <RecommendedProduct>[],
    this.availabilityMessage,
    this.availabilityContext,
    this.preferences,
    this.source,
    this.issueCode,
    this.reasonCode,
    this.pruneHistoricalBotMessages = false,
    this.fallbackText,
    this.isNoMatch = false,
  });

  const AIChatHandledResult.notHandled()
    : handled = false,
      reply = null,
      recommendedProducts = const <RecommendedProduct>[],
      availabilityMessage = null,
      availabilityContext = null,
      preferences = null,
      source = null,
      issueCode = null,
      reasonCode = null,
      pruneHistoricalBotMessages = false,
      fallbackText = null,
      isNoMatch = false;
}
