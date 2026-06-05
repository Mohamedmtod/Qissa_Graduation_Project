import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_worker_reply_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

import 'mock_catalog.dart';

class _MockAIChatRepo extends Mock implements AIChatRepo {}

void main() {
  late _MockAIChatRepo repo;

  setUpAll(() {
    registerFallbackValue(const SessionPreferences());
    registerFallbackValue(AIChatLanguage.english);
    registerFallbackValue(
      const AIChatCompactConversationContext(
        recentMessages: [],
        lastVisibleProductIds: [],
      ),
    );
  });

  setUp(() {
    AIChatExperimentConfig.setTestOverrides(sendCompactContext: false);
    repo = _MockAIChatRepo();
    when(
      () => repo.fetchAIRecommendation(
        currentMessage: any(named: 'currentMessage'),
        preferences: any(named: 'preferences'),
        candidates: any(named: 'candidates'),
        localRecommendations: any(named: 'localRecommendations'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return null;
    });
    when(
      () => repo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        metadata: any(named: 'metadata'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.saveAIChatDebugLog(
        phase: any(named: 'phase'),
        sessionId: any(named: 'sessionId'),
        requestId: any(named: 'requestId'),
        language: any(named: 'language'),
        messageText: any(named: 'messageText'),
        detectedIntent: any(named: 'detectedIntent'),
        responseSource: any(named: 'responseSource'),
        issueCode: any(named: 'issueCode'),
        reasonCode: any(named: 'reasonCode'),
        preferencesSnapshot: any(named: 'preferencesSnapshot'),
        availabilityContextSnapshot: any(named: 'availabilityContextSnapshot'),
        recommendationMemorySnapshot: any(
          named: 'recommendationMemorySnapshot',
        ),
        candidateSummary: any(named: 'candidateSummary'),
        recommendedProducts: any(named: 'recommendedProducts'),
        workerReplySummary: any(named: 'workerReplySummary'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(AIChatExperimentConfig.resetTestOverrides);

  test(
    'soft timeout returns bounded catalog recommendation from candidates',
    () async {
      final service = _service(repo);
      final result = await service.fetchAndNormalize(
        incoming: _incoming('I want a fresh daily perfume for men'),
        discovery: _discovery(),
        recommendationContext: _recommendationContext(),
        currentPreferences: const SessionPreferences(gender: 'men'),
        lastAskQuestion: null,
        currentMessages: const <AIChatMessage>[],
      );

      expect(result.appSoftTimeoutHit, isTrue);
      expect(result.fallbackFromCandidates, isTrue);
      expect(result.workerLateResultIgnored, isTrue);
      expect(result.latencyPolicyReason, 'safe_candidates_soft_timeout');
      expect(result.responseSource, 'local_candidate_soft_timeout');
      expect(result.reply?.isRecommend, isTrue);
      expect(result.reply?.productIds, ['p1', 'p2', 'p3']);
    },
  );

  test('broad choice help uses preemptive bounded candidate fallback', () async {
    final service = _service(repo);
    final result = await service.fetchAndNormalize(
      incoming: _incoming(
        'أنا مش عارف أختار عطر، ممكن تساعدني؟',
        language: AIChatLanguage.arabic,
      ),
      discovery: _discovery(),
      recommendationContext: _recommendationContext(),
      currentPreferences: const SessionPreferences(gender: 'men'),
      lastAskQuestion: null,
      currentMessages: const <AIChatMessage>[],
    );

    expect(result.appSoftTimeoutHit, isFalse);
    expect(result.fallbackFromCandidates, isTrue);
    expect(result.workerLateResultIgnored, isFalse);
    expect(result.latencyPolicyReason, 'safe_candidates_preemptive_fallback');
    expect(result.failureReasonCode, 'app_preemptive_candidate_fallback');
    expect(result.responseSource, 'local_candidate_preemptive_fallback');
    expect(result.reply?.isRecommend, isTrue);
    expect(result.reply?.productIds, ['p1', 'p2', 'p3']);
    verifyNever(
      () => repo.fetchAIRecommendation(
        currentMessage: any(named: 'currentMessage'),
        preferences: any(named: 'preferences'),
        candidates: any(named: 'candidates'),
        localRecommendations: any(named: 'localRecommendations'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    );
  });

  test('soft timeout is disabled for unresolved external similarity', () async {
    final service = _service(repo);
    final result = await service.fetchAndNormalize(
      incoming: _incoming('Something like Dior Sauvage'),
      discovery: _discovery(),
      recommendationContext: _recommendationContext(),
      currentPreferences: const SessionPreferences(gender: 'men'),
      lastAskQuestion: null,
      currentMessages: const <AIChatMessage>[],
    );

    expect(result.appSoftTimeoutHit, isFalse);
    expect(result.fallbackFromCandidates, isFalse);
    expect(result.reply, isNull);
    expect(result.failureReasonCode, 'worker_timeout');
  });

  test('soft timeout is disabled for answer-only size questions', () async {
    final service = _service(repo);
    final result = await service.fetchAndNormalize(
      incoming: _incoming('50ml or 100ml?'),
      discovery: _discovery(),
      recommendationContext: _recommendationContext(),
      currentPreferences: const SessionPreferences(gender: 'men'),
      lastAskQuestion: null,
      currentMessages: const <AIChatMessage>[],
    );

    expect(result.appSoftTimeoutHit, isFalse);
    expect(result.fallbackFromCandidates, isFalse);
    expect(result.reply, isNull);
    expect(result.failureReasonCode, 'worker_timeout');
  });

  test('soft timeout is disabled for Arabic mixed size questions', () async {
    final service = _service(repo);
    final result = await service.fetchAndNormalize(
      incoming: _incoming(
        'أجيب 50ml ولا 100ml؟',
        language: AIChatLanguage.arabic,
      ),
      discovery: _discovery(),
      recommendationContext: _recommendationContext(),
      currentPreferences: const SessionPreferences(gender: 'men'),
      lastAskQuestion: null,
      currentMessages: const <AIChatMessage>[],
    );

    expect(result.appSoftTimeoutHit, isFalse);
    expect(result.fallbackFromCandidates, isFalse);
    expect(result.reply, isNull);
    expect(result.failureReasonCode, 'worker_timeout');
  });
}

AIChatWorkerReplyService _service(_MockAIChatRepo repo) {
  return AIChatWorkerReplyService(
    aiChatRepo: repo,
    hasMissingFoundationalDiscoverySlots:
        (_, {required hasRecommendationContext}) => false,
    workerTimeout: const Duration(milliseconds: 20),
    appSoftTimeout: const Duration(milliseconds: 10),
  );
}

AIChatTurnContext _incoming(
  String text, {
  AIChatLanguage language = AIChatLanguage.english,
}) {
  return AIChatTurnContext(
    trimmed: text,
    activeSessionId: 'session-test',
    responseLanguage: language,
    effectiveRecommendationMemory: const RecommendationMemory(),
    intent: AIChatIntent.newRecommendation,
    shouldContinueAvailabilityClarification: false,
    isGreetingOnly: false,
    requestId: 'request-test',
  );
}

AIChatDiscoveryContext _discovery() {
  return const AIChatDiscoveryContext(
    hasRecommendationContext: true,
    effectiveHasRecommendationContext: true,
    isFollowUpOrCompare: false,
    shouldPruneBotHistory: false,
    localPreferences: SessionPreferences(gender: 'men'),
    localMissingSlots: <String>[],
    localReadyForRecommendation: true,
    budgetPolicy: AIChatBudgetPolicy.flexible,
  );
}

AIChatRecommendationContext _recommendationContext() {
  final candidates = mockCatalog
      .map(
        (product) => RecommendedProduct(
          product: product,
          matchScore: 0.9,
          matchLabel: 'Safe Match',
          matchReason: 'Closest safe catalog match.',
        ),
      )
      .toList(growable: false);
  return AIChatRecommendationContext(
    localCandidatesRefs: candidates,
    candidatesList: mockCatalog,
    localFallbackAnswer: null,
    budgetPolicy: AIChatBudgetPolicy.flexible,
    effectivePreferences: const SessionPreferences(gender: 'men'),
  );
}
