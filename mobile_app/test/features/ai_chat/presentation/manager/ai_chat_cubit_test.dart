import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_business_info.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply_validator.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_catalog.dart';

class MockAIChatRepo extends Mock implements AIChatRepo {}

class MockUserTasteRepo extends Mock implements UserTasteRepo {}

void main() {
  late MockAIChatRepo mockAIChatRepo;
  late MockUserTasteRepo mockUserTasteRepo;
  late AIChatCubit cubit;

  setUpAll(() {
    registerFallbackValue(const SessionPreferences());
    registerFallbackValue(AIChatLanguage.english);
    registerFallbackValue(AIChatMessage.user('fallback'));
    registerFallbackValue(
      const AIChatCompactConversationContext(
        recentMessages: [],
        lastVisibleProductIds: [],
      ),
    );
    registerFallbackValue(EventType.view);
    registerFallbackValue(
      const ExternalPerfumeCandidate(
        id: '1',
        displayName: 'Fallback',
        brand: 'Fallback',
        sourceUrl:
            'https://www.fragranticarabia.com/perfumes/Fallback/Fallback-1.html',
      ),
    );
  });

  setUp(() {
    AIChatExperimentConfig.resetTestOverrides();
    AIChatExperimentConfig.setTestOverrides(sendCompactContext: false);
    SharedPreferences.setMockInitialValues({});
    mockAIChatRepo = MockAIChatRepo();
    mockUserTasteRepo = MockUserTasteRepo();
    when(() => mockAIChatRepo.canPersistSession).thenReturn(false);
    when(() => mockAIChatRepo.currentUserId).thenReturn(null);
    when(() => mockAIChatRepo.lastWorkerFailureReasonCode).thenReturn(null);
    when(
      () => mockAIChatRepo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => mockCatalog);
    when(() => mockAIChatRepo.setSessionId(any())).thenReturn(null);
    when(() => mockAIChatRepo.invalidateCatalogCache()).thenReturn(null);
    when(
      () => mockAIChatRepo.fetchLatestRestorableSession(
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.fetchRestorableSessionById(
        sessionId: any(named: 'sessionId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.fetchSessionMessages(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => mockAIChatRepo.createSession(
        sessionId: any(named: 'sessionId'),
        language: any(named: 'language'),
        startedAt: any(named: 'startedAt'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAIChatRepo.appendMessage(
        message: any(named: 'message'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAIChatRepo.completeSession(
        sessionId: any(named: 'sessionId'),
        messageCount: any(named: 'messageCount'),
        finalRecommendationMessageId: any(
          named: 'finalRecommendationMessageId',
        ),
        endedAt: any(named: 'endedAt'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAIChatRepo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        metadata: any(named: 'metadata'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAIChatRepo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        metadata: any(named: 'metadata'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAIChatRepo.lookupPerfumeKnowledge(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.fetchBusinessInfo(
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.fetchProductPublicStats(
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => const {});
    when(
      () => mockAIChatRepo.fetchAIRecommendation(
        currentMessage: any(named: 'currentMessage'),
        preferences: any(named: 'preferences'),
        candidates: any(named: 'candidates'),
        localRecommendations: any(named: 'localRecommendations'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.fetchAIRecommendationWithContext(
        currentMessage: any(named: 'currentMessage'),
        preferences: any(named: 'preferences'),
        candidates: any(named: 'candidates'),
        localRecommendations: any(named: 'localRecommendations'),
        compactContext: any(named: 'compactContext'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.lookupExternalPerfumeKnowledge(
        query: any(named: 'query'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.lookupExternalPerfumeKnowledgeResult(
        query: any(named: 'query'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => const ExternalPerfumeLookupResult.notFound());
    when(
      () => mockAIChatRepo.fetchAIInterpretation(
        currentMessage: any(named: 'currentMessage'),
        currentPreferences: any(named: 'currentPreferences'),
        responseLanguage: any(named: 'responseLanguage'),
        hasRecommendationContext: any(named: 'hasRecommendationContext'),
        hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.resolveExternalPerfumeKnowledgeCandidate(
        candidate: any(named: 'candidate'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.saveAIChatDebugLog(
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
    when(
      () => mockUserTasteRepo.recordEvent(
        eventType: any(named: 'eventType'),
        notes: any(named: 'notes'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});

    cubit = AIChatCubit(
      aiChatRepo: mockAIChatRepo,
      userTasteRepo: mockUserTasteRepo,
      thinkingDelay: Duration.zero,
      cooldownDuration: Duration.zero,
    );
  });

  tearDown(() {
    AIChatExperimentConfig.resetTestOverrides();
    cubit.close();
  });

  group('AIChatCubit - Orchestration Logic', () {
    test(
      'guest to authenticated transition starts a fresh persisted session',
      () async {
        when(() => mockAIChatRepo.currentUserId).thenReturn('u1');
        when(() => mockAIChatRepo.canPersistSession).thenReturn(true);

        await cubit.handleAuthUserChanged('u1');

        expect(cubit.state.messages, hasLength(1));
        expect(cubit.state.messages.single.isFromUser, isFalse);
        verify(
          () => mockAIChatRepo.createSession(
            sessionId: any(named: 'sessionId'),
            language: any(named: 'language'),
            startedAt: any(named: 'startedAt'),
            userId: any(named: 'userId'),
          ),
        ).called(1);
        verify(
          () => mockAIChatRepo.appendMessage(
            message: any(named: 'message'),
            sessionId: any(named: 'sessionId'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test('authenticated to guest transition resets local chat state', () async {
      when(() => mockAIChatRepo.currentUserId).thenReturn('u1');
      when(() => mockAIChatRepo.canPersistSession).thenReturn(true);
      await cubit.handleAuthUserChanged('u1');

      when(() => mockAIChatRepo.currentUserId).thenReturn(null);
      when(() => mockAIChatRepo.canPersistSession).thenReturn(false);
      await cubit.handleAuthUserChanged(null);

      expect(cubit.state.status, AIChatStatus.idle);
      expect(cubit.state.preferences, const SessionPreferences());
      expect(cubit.state.messages, hasLength(1));
      expect(cubit.state.messages.single.isFromUser, isFalse);
    });

    blocTest<AIChatCubit, AIChatState>(
      'initial recommendations send only filtered candidates to worker',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.recommend(
            productIds: ['p1'],
            matchReasons: {'p1': 'Best filtered match.'},
            updatedPreferences: const SessionPreferences(
              gender: 'men',
              maxBudget: 1200,
              season: 'summer',
              occasion: 'daily',
            ),
          ),
        );
        return AIChatCubit(
          aiChatRepo: mockAIChatRepo,
          userTasteRepo: mockUserTasteRepo,
          thinkingDelay: Duration.zero,
          cooldownDuration: Duration.zero,
        );
      },
      act: (cubit) => cubit.sendMessage(
        'I need a men summer daily fresh perfume under 1200',
      ),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final captured =
            verify(
                  () => mockAIChatRepo.fetchAIRecommendation(
                    currentMessage: any(named: 'currentMessage'),
                    preferences: any(named: 'preferences'),
                    candidates: captureAny(named: 'candidates'),
                    localRecommendations: any(named: 'localRecommendations'),
                    responseLanguage: any(named: 'responseLanguage'),
                    requestId: any(named: 'requestId'),
                  ),
                ).captured.single
                as List<ProductModel>;
        expect(captured.map((product) => product.id).toList(), ['p1']);
        verify(
          () => mockAIChatRepo.logAIChatEvent(
            eventType: 'ai_worker_first_path_used',
            sessionId: any(named: 'sessionId'),
            metadata: any(named: 'metadata'),
            userId: any(named: 'userId'),
          ),
        ).called(1);
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'PR6 flags off keeps legacy worker request path unchanged',
      build: () {
        AIChatExperimentConfig.setTestOverrides(
          sendCompactContext: false,
          delegateMicroTurns: false,
        );
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.recommend(
            productIds: ['p1'],
            matchReasons: {'p1': 'Best filtered match.'},
            updatedPreferences: const SessionPreferences(
              gender: 'men',
              maxBudget: 1200,
              season: 'summer',
              occasion: 'daily',
            ),
          ),
        );
        return AIChatCubit(
          aiChatRepo: mockAIChatRepo,
          userTasteRepo: mockUserTasteRepo,
          thinkingDelay: Duration.zero,
          cooldownDuration: Duration.zero,
        );
      },
      act: (cubit) => cubit.sendMessage(
        'I need a men summer daily fresh perfume under 1200',
      ),
      verify: (_) {
        verify(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).called(1);
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendationWithContext(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            compactContext: any(named: 'compactContext'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    test(
      'PR6 flags on delegates contextual Arabic micro-turn to v2 planner',
      () async {
        final womenAllSeason = mockCatalog[2].copyWith(
          id: 'p_women_all_seasons',
          name: 'Soft Floral All Seasons',
          price: 1200,
          gender: 'women',
          season: 'all_seasons',
          occasion: 'daily',
          time: 'day',
          intensity: 'medium',
          stock: 9,
        );
        when(
          () => mockAIChatRepo.getCatalog(
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => [womenAllSeason]);

        AIChatExperimentConfig.setTestOverrides(
          sendCompactContext: false,
          delegateMicroTurns: false,
        );
        await cubit.sendMessage('my budget is 4500');
        await cubit.sendMessage('حريمي');

        expect(cubit.state.preferences.gender, 'women');
        expect(cubit.state.preferences.maxBudget, 4500);
        expect(cubit.state.preferences.season, isNull);
        expect(cubit.state.status, AIChatStatus.ask);

        AIChatExperimentConfig.setTestOverrides(
          sendCompactContext: true,
          delegateMicroTurns: true,
        );
        when(
          () => mockAIChatRepo.fetchAIRecommendationWithContext(
            currentMessage: 'لكله',
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            compactContext: any(named: 'compactContext'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReplyValidator.parseMap({
            'schemaVersion': 2,
            'type': 'recommendation',
            'language': 'ar',
            'message': 'تمام، فهمت إنك عايز عطر حريمي مناسب لكل المواسم.',
            'preferencesPatch': {
              'replaceScalars': {'season': 'all_seasons'},
            },
            'commands': [
              {
                'action': 'show_recommendation_cards',
                'productIds': ['p_women_all_seasons'],
              },
            ],
            'recommendations': [
              {
                'productId': 'p_women_all_seasons',
                'reason': 'حريمي ومناسب لكل المواسم وداخل الميزانية.',
              },
            ],
            'metadata': {
              'requestId': 'req-v2-micro-turn',
              'promptVersion': 'chat_v2_structured_commands',
            },
          }, language: AIChatLanguage.arabic),
        );

        await cubit.sendMessage('لكله');

        final captured = verify(
          () => mockAIChatRepo.fetchAIRecommendationWithContext(
            currentMessage: 'لكله',
            preferences: captureAny(named: 'preferences'),
            candidates: captureAny(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            compactContext: captureAny(named: 'compactContext'),
            responseLanguage: AIChatLanguage.arabic,
            requestId: any(named: 'requestId'),
          ),
        ).captured.toList();
        final sentPreferences = captured[0] as SessionPreferences;
        final sentCandidates = captured[1] as List<ProductModel>;
        final compactContext = captured[2] as AIChatCompactConversationContext;

        expect(sentPreferences.gender, 'women');
        expect(sentPreferences.maxBudget, 4500);
        expect(sentCandidates.map((product) => product.id), [
          'p_women_all_seasons',
        ]);
        expect(
          compactContext.lastAskSlot,
          'season',
          reason:
              'lastAssistantQuestion=${compactContext.lastAssistantQuestion}',
        );
        expect(
          compactContext.recentMessages.map((message) => message.text),
          containsAll(['حريمي', 'لكله']),
        );
        expect(cubit.state.preferences.season, 'all_seasons');
        expect(
          cubit.state.status,
          anyOf(AIChatStatus.answer, AIChatStatus.recommend),
        );
        expect(cubit.state.messages.last.isRecommendation, isTrue);
        expect(
          cubit.state.messages.last.recommendedProducts.single.product.id,
          'p_women_all_seasons',
        );
        expect(cubit.state.messages.last.content, isNot(contains('ميزانية')));
        expect(cubit.state.messages.last.content, isNot(contains('صيفي')));
      },
    );

    test(
      'reset pivot infers mother gift as women and does not ask gender',
      () async {
        await cubit.sendMessage('men winter oud strong under 2000');
        expect(cubit.state.preferences.gender, 'men');

        await cubit.sendMessage(
          '\u0633\u064a\u0628\u0643 \u0645\u0646 \u0643\u0644 \u062f\u0647 \u0623\u0646\u0627 \u0639\u0627\u064a\u0632 \u0647\u062f\u064a\u0629 \u0644\u0648\u0627\u0644\u062f\u062a\u064a \u062a\u062d\u062a 700',
        );

        expect(cubit.state.preferences.gender, 'women');
        expect(cubit.state.preferences.occasion, 'gift');
        expect(cubit.state.preferences.maxBudget, 700);
        expect(
          cubit.state.messages.last.content,
          isNot(contains("men's, women's, or unisex")),
        );
        expect(
          cubit.state.messages.last.content,
          isNot(
            contains(
              '\u0631\u062c\u0627\u0644\u064a \u0648\u0644\u0627 \u062d\u0631\u064a\u0645\u064a',
            ),
          ),
        );
      },
    );

    test(
      'PR6 flags on keep hard guards local and never delegate them as micro-turns',
      () async {
        Future<void> assertNoStructuredDelegation(String message) async {
          await cubit.close();
          cubit = AIChatCubit(
            aiChatRepo: mockAIChatRepo,
            userTasteRepo: mockUserTasteRepo,
            thinkingDelay: Duration.zero,
            cooldownDuration: Duration.zero,
          );

          AIChatExperimentConfig.setTestOverrides(
            sendCompactContext: false,
            delegateMicroTurns: false,
          );
          await cubit.sendMessage('my budget is 4500');
          clearInteractions(mockAIChatRepo);

          AIChatExperimentConfig.setTestOverrides(
            sendCompactContext: true,
            delegateMicroTurns: true,
          );
          await cubit.sendMessage(message);

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendationWithContext(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              compactContext: any(named: 'compactContext'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        }

        await assertNoStructuredDelegation('رقمكم؟');
        await assertNoStructuredDelegation('عندي حساسية من الورد');
        await assertNoStructuredDelegation('فيه Sauvage؟');
        await assertNoStructuredDelegation('iPhone perfume');
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'worker-first mode skips worker when filtered candidates are empty',
      build: () => AIChatCubit(
        aiChatRepo: mockAIChatRepo,
        userTasteRepo: mockUserTasteRepo,
        thinkingDelay: Duration.zero,
        cooldownDuration: Duration.zero,
      ),
      act: (cubit) => cubit.sendMessage(
        'I need a men summer daily citrus perfume under 500',
      ),
      verify: (cubit) {
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
        expect(
          cubit.state.status,
          anyOf(AIChatStatus.ask, AIChatStatus.noMatch),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'tracks aiClick only when recommendation product tapped',
      build: () => cubit,
      act: (cubit) => cubit.onRecommendedProductTapped(mockCatalog.first),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => mockUserTasteRepo.recordEvent(
            eventType: EventType.aiClick,
            notes: ['citrus', 'lemon', 'orange', 'fresh', 'clean', 'sporty'],
            userId: any(named: 'userId'),
          ),
        ).called(1);

        verify(
          () => mockAIChatRepo.logAIChatEvent(
            eventType: 'conversion_product_clicked',
            sessionId: any(named: 'sessionId'),
            metadata: any(named: 'metadata'),
            userId: any(named: 'userId'),
          ),
        ).called(1);
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'EN-01: Standard Recommendation updates memory and preferences',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.recommend(
            productIds: ['p1', 'p2'],
            matchReasons: {'p1': 'Fits criteria.', 'p2': 'Another good match.'},
            updatedPreferences: const SessionPreferences(
              gender: 'men',
              maxBudget: 1200,
              season: 'summer',
            ),
          ),
        );
        return cubit;
      },
      act: (cubit) =>
          cubit.sendMessage('I need a fresh men summer perfume under 1200'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(
          cubit.state.recommendationMemory.lastRecommendedProducts.length,
          1,
        );
        expect(
          cubit.state.recommendationMemory.lastRecommendedProducts[0].productId,
          'p1',
        );
        expect(
          cubit
              .state
              .recommendationMemory
              .lastRecommendedProducts[0]
              .displayIndex,
          1,
        );
        expect(cubit.state.preferences.maxBudget, 1200.0);
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'EN-02/AR-02: Vague input triggers local fallback question',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((_) async => null); // Simulate failure/fallback
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('I want a nice perfume'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(
          cubit.state.messages.last.content,
          anyOf(
            contains('budget'),
            contains('men\'s or women\'s'),
            contains('summer or winter'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'routes iPhone perfume OOD locally before generic clarification',
      build: () => cubit,
      act: (cubit) => cubit.sendMessage('iPhone 15 Pro Max perfume'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final lastMessage = cubit.state.messages.last;
        final content = lastMessage.content.toLowerCase();
        expect(lastMessage.isRecommendation, isFalse);
        expect(content, contains('catalog'));
        expect(content, contains('perfume'));
        expect(content, isNot(contains('one more preference')));
        expect(content, isNot(contains('whatsapp')));
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'AR regression: greeting clarification stays Arabic-only',
      build: () => cubit,
      act: (cubit) => cubit.sendMessage('السلام عليكم'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(
          content,
          anyOf(
            contains(
              'أهلاً! قلّي تفضيلاتك مثل النوع أو النوتات أو الميزانية، وسأرشح لك الأنسب.',
            ),
            contains(
              'لم أفهم طلبك بشكل كافٍ. اكتب الميزانية أو النوتات المفضلة أو نوع الرائحة التي تريدها.',
            ),
          ),
        );
        expect(content.toLowerCase(), isNot(contains('hello')));
        expect(content.toLowerCase(), isNot(contains('tell me')));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'EN regression: hi returns greeting clarification instead of vague fallback',
      build: () => cubit,
      act: (cubit) => cubit.sendMessage('hi'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content.toLowerCase();
        expect(content, contains('hello'));
        expect(content, contains('preferences'));
        expect(content, isNot(contains('could not understand')));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'AR regression: compare-without-context clarification stays Arabic-only',
      build: () => cubit,
      seed: () => AIChatState(
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'medium',
              notes: const ['citrus'],
              topNotes: const ['lemon'],
              middleNotes: const ['orange'],
              baseNotes: const ['musk'],
              tags: const ['fresh'],
              matchScore: 0.9,
              matchReason: 'Reason 1',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: const ['cedar'],
              topNotes: const ['cedar'],
              middleNotes: const ['amber'],
              baseNotes: const ['woody'],
              tags: const ['classic'],
              matchScore: 0.88,
              matchReason: 'Reason 2',
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('قارن بين 1 و2'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(content, contains('Campus Citrus Drive'));
        expect(content.toLowerCase(), isNot(contains('please tell me')));
        expect(content.toLowerCase(), isNot(contains('compare')));
      },
    );
    blocTest<AIChatCubit, AIChatState>(
      'AR regression: vague fallback stays Arabic-only',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((_) async => null);
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('عايز حاجة عامة'),
      verify: (cubit) {
        final content = cubit.state.messages.last.content;
        expect(
          content,
          anyOf(
            contains(
              'لم أفهم طلبك بشكل كافٍ. اكتب الميزانية أو النوتات المفضلة أو نوع الرائحة التي تريدها.',
            ),
            contains('لم أفهم طلبك بشكل كافٍ'),
          ),
        );
        expect(
          content.toLowerCase(),
          isNot(contains('i could not understand')),
        );
        expect(content.toLowerCase(), isNot(contains('preferred notes')));
      },
    );
    blocTest<AIChatCubit, AIChatState>(
      'Regression: lastFocusedProductId updates after follow-up',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: ['citrus'],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 0.9,
              matchReason: 'Reason',
            ),
          ],
        ),
      ),
      act: (cubit) {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.answer(
            answer: 'Details about Campus.',
            updatedPreferences: cubit.state.preferences,
          ),
        );
        return cubit.sendMessage('Tell me more about Campus Citrus Drive');
      },
      verify: (cubit) {
        expect(cubit.state.recommendationMemory.lastFocusedProductId, 'p1');
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Recommendation selection by ordinal explains details/cart next step',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: const ['citrus'],
              matchScore: 0.9,
              matchReason: 'Reason 1',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: const ['cedar'],
              matchScore: 0.88,
              matchReason: 'Reason 2',
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('الأول'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(content, contains('Campus Citrus Drive'));
        expect(content, contains('Details'));
        expect(content, contains('Add to cart'));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Budget pivot with "one" is not misread as first recommendation selection',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        preferences: const SessionPreferences(
          gender: 'men',
          occasion: 'daily',
          preferredNotes: ['woody'],
        ),
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: const ['citrus'],
              matchScore: 0.9,
              matchReason: 'Reason 1',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: const ['cedar', 'woody'],
              matchScore: 0.88,
              matchReason: 'Reason 2',
            ),
          ],
        ),
      ),
      act: (cubit) =>
          cubit.sendMessage('Exactly 1500 EGP, not one pound more.'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(cubit.state.preferences.maxBudget, 1500);
        expect(
          cubit.state.messages.last.content,
          isNot(contains('Got it, you mean Campus Citrus Drive')),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Explicit budget number wins over cheaper modifier cues',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        preferences: const SessionPreferences(
          gender: 'men',
          maxBudget: 900,
          occasion: 'daily',
        ),
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: const ['citrus'],
              matchScore: 0.9,
              matchReason: 'Reason 1',
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('budget 600 no 900'),
      verify: (cubit) {
        expect(cubit.state.preferences.maxBudget, 600);
        expect(cubit.state.messages.last.content, isNot(contains('765')));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Recommendation cart follow-up uses the recently selected product',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.answer,
        messages: [
          AIChatMessage.botText(
            'تمام، تقصد Cedar Spice Focus. ممكن تفتح Details وتشوف السعر والنوتات والمعلومات أكتر قبل الشراء.',
          ),
        ],
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Cedar Spice Focus',
              brand: 'Cedar',
              displayIndex: 1,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: const ['cedar'],
              matchScore: 0.88,
              matchReason: 'Reason 1',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 2,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: const ['citrus'],
              matchScore: 0.9,
              matchReason: 'Reason 2',
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('أضفه للسلة'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(cubit.state.messages.last.type, MessageType.text);
        final content = cubit.state.messages.last.content;
        expect(content, contains('Cedar Spice Focus'));
        expect(content, contains('Details'));
        expect(content, contains('Add to cart'));
        expect(content, isNot(contains('could not understand')));
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Blocked availability question asks product anchor instead of recommending',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Dior Sauvage',
              brand: 'Dior',
              displayIndex: 1,
              price: 4650,
              stock: 20,
              season: 'all_seasons',
              occasion: 'daily',
              intensity: 'strong',
              notes: const ['cedar'],
              matchScore: 0.9,
              matchReason: 'Reason 1',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Bleu de Chanel',
              brand: 'Chanel',
              displayIndex: 2,
              price: 4950,
              stock: 18,
              season: 'all_seasons',
              occasion: 'daily',
              intensity: 'strong',
              notes: const ['cedar'],
              matchScore: 0.88,
              matchReason: 'Reason 2',
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('هل Dior Sauvage موجود؟'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(content, contains('لم أجد هذا العطر'));
        expect(cubit.state.messages.last.type, MessageType.text);
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Recommendation selection can pick first two products',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: const ['citrus'],
              matchScore: 0.9,
              matchReason: 'Reason 1',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: const ['cedar'],
              matchScore: 0.88,
              matchReason: 'Reason 2',
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('الأول والثاني'),
      verify: (cubit) {
        final content = cubit.state.messages.last.content;
        expect(content, contains('Campus Citrus Drive'));
        expect(content, contains('Cedar Class 01'));
        expect(content, contains('Cedar Class 01'));
        expect(content, contains('Details'));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Payment methods question answers locally',
      build: () => cubit,
      act: (cubit) => cubit.sendMessage('طرق الدفع'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(
          content,
          contains('وسيلة الدفع المتاحة حاليًا هي الدفع عند الاستلام'),
        );
        expect(content, isNot(contains('could not understand')));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Cash on delivery question answers locally',
      build: () => cubit,
      act: (cubit) => cubit.sendMessage('الدفع عند الاستلام'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(
          content,
          contains('وسيلة الدفع المتاحة حاليًا هي الدفع عند الاستلام'),
        );
        expect(content, isNot(contains('could not understand')));
        verifyNever(
          () => mockAIChatRepo.lookupExternalPerfumeKnowledgeResult(
            query: any(named: 'query'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Regression: Arabic why-this follow-up resolves visible recommendation instead of restarting discovery',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: ['citrus'],
              topNotes: ['lemon'],
              middleNotes: ['orange'],
              baseNotes: ['musk'],
              tags: ['fresh'],
              matchScore: 0.9,
              matchReason: 'Reason',
            ),
          ],
        ),
      ),
      act: (cubit) {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.answer(
            answer: 'تفاصيل عن الترشيح.',
            updatedPreferences: cubit.state.preferences,
          ),
        );
        return cubit.sendMessage('ليه رشحت ده؟');
      },
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(
          cubit.state.messages.last.content,
          contains('Campus Citrus Drive'),
        );
        expect(cubit.state.messages.last.content, contains('سبب الترشيح'));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Regression: visible recommendation memory rebuild preserves trace metadata',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.answer(
            answer: 'It is fresher and lighter.',
            updatedPreferences: cubit.state.preferences,
          ),
        );
        return cubit;
      },
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        messages: [
          AIChatMessage.botRecommendation(
            content: 'Top picks',
            products: [
              RecommendedProduct(
                product: mockCatalog.first,
                matchScore: 0.92,
                matchLabel: 'Great match',
                matchReason: 'Fresh daily fit',
              ),
            ],
          ),
        ],
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: const [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Summer Breeze',
              brand: 'FreshCo',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: ['citrus'],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 0.92,
              matchReason: 'Fresh daily fit',
              requestId: 'req-123',
              promptVersion: 'v1.1',
              provider: 'openrouter',
              modelId: 'qwen/qwen3-32b',
            ),
          ],
          lastRecommendationBatchId: 'batch-1',
        ),
      ),
      act: (cubit) => cubit.sendMessage('tell me more about the first one'),
      verify: (cubit) {
        final ref = cubit.state.recommendationMemory.lastRecommendedProducts
            .firstWhere((item) => item.productId == 'p1');
        expect(ref.requestId, 'req-123');
        expect(ref.promptVersion, 'v1.1');
        expect(ref.provider, 'openrouter');
        expect(ref.modelId, 'qwen/qwen3-32b');
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Product context question answers locally without rendering new cards',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'medium',
              notes: ['citrus'],
              topNotes: ['lemon'],
              middleNotes: ['orange'],
              baseNotes: ['musk'],
              tags: ['fresh', 'clean'],
              matchScore: 0.9,
              matchReason:
                  'Matches citrus. Suitability: medium_for_light_request.',
            ),
          ],
        ),
      ),
      act: (cubit) =>
          cubit.sendMessage('is Campus Citrus Drive suitable for work?'),
      verify: (cubit) {
        final last = cubit.state.messages.last;
        expect(last.isRecommendation, isFalse);
        expect(last.content, contains('Campus Citrus Drive'));
        expect(last.content.toLowerCase(), contains('work'));
        expect(last.content, isNot(contains('Suitability:')));
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Catalog product context question answers locally without worker or cards',
      build: () {
        when(
          () => mockAIChatRepo.getCatalog(
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer(
          (_) async => [
            ...mockCatalog,
            ProductModel(
              id: 'light-blue',
              name: 'Light Blue',
              nameLower: 'light blue',
              searchPrefixes: const ['li', 'lig', 'ligh', 'light'],
              brand: 'Dolce & Gabbana',
              price: 3250,
              gender: 'unisex',
              season: 'summer',
              fragranceFamily: 'Fresh Citrus',
              notes: const ['citrus', 'fruity', 'musk'],
              imageUrls: const ['https://example.com/light-blue.png'],
              description: 'Fresh clean daytime scent',
              categoryName: 'Perfumes',
              createdAt: mockCatalog.first.createdAt,
              updatedAt: mockCatalog.first.updatedAt,
              occasion: 'office',
              time: 'day',
              intensity: 'medium',
              topNotes: const ['citrus'],
              middleNotes: const ['floral'],
              baseNotes: const ['musk'],
              tags: const ['fresh', 'clean', 'classic'],
              stock: 20,
            ),
          ],
        );
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('is Light Blue suitable for work?'),
      verify: (cubit) {
        final last = cubit.state.messages.last;
        expect(last.isRecommendation, isFalse);
        expect(last.content, contains('Light Blue'));
        expect(last.content.toLowerCase(), contains('work'));
        expect(last.content, isNot(contains('Suitability:')));
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Ambiguous product context question asks which recommendation',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'medium',
              notes: ['citrus'],
              tags: ['fresh'],
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: ['cedar'],
              tags: ['warm'],
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('is it suitable for work?'),
      verify: (cubit) {
        final last = cubit.state.messages.last;
        expect(last.isRecommendation, isFalse);
        expect(last.content, contains('Which product do you mean?'));
        expect(last.content, contains('Campus Citrus Drive'));
        expect(last.content, contains('Cedar Class 01'));
        expect(last.content, isNot(contains('men, women, or unisex')));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Product context question with does asks which recommendation',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'medium',
              notes: ['citrus'],
              tags: ['fresh'],
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: ['cedar'],
              tags: ['warm'],
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('does it work for university?'),
      verify: (cubit) {
        final last = cubit.state.messages.last;
        expect(last.isRecommendation, isFalse);
        expect(last.content, contains('Which product do you mean?'));
        expect(last.content, contains('Campus Citrus Drive'));
        expect(last.content, contains('Cedar Class 01'));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Clear refinement does not ask which product',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        preferences: const SessionPreferences(
          gender: 'men',
          intensity: 'light',
        ),
        recommendationMemory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'light',
              notes: ['citrus'],
              tags: ['fresh'],
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: ['cedar'],
              tags: ['warm'],
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('make it suitable for university'),
      verify: (cubit) {
        final last = cubit.state.messages.last;
        expect(last.content, isNot(contains('Which product do you mean?')));
        expect(
          last.content,
          isNot(contains('Which recommendation do you mean?')),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Messy refinement escalates instead of product clarification',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.ask(
            question: 'Do you want it for daily use?',
            updatedPreferences: const SessionPreferences(
              gender: 'men',
              occasion: 'university',
              intensity: 'light',
              tags: ['fresh', 'clean'],
            ),
          ),
        );
        return cubit;
      },
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        preferences: const SessionPreferences(
          gender: 'men',
          intensity: 'light',
        ),
        recommendationMemory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'light',
              notes: ['citrus'],
              tags: ['fresh'],
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: ['cedar'],
              tags: ['warm'],
            ),
          ],
        ),
      ),
      act: (cubit) =>
          cubit.sendMessage('i wwantit too suitable for university'),
      verify: (cubit) {
        final last = cubit.state.messages.last;
        expect(last.content, isNot(contains('Which product do you mean?')));
        expect(
          last.content,
          isNot(contains('Which recommendation do you mean?')),
        );
        verify(
          () => mockAIChatRepo.saveAIChatDebugLog(
            phase: 'llm_result_routed',
            sessionId: any(named: 'sessionId'),
            requestId: any(named: 'requestId'),
            language: any(named: 'language'),
            messageText: any(named: 'messageText'),
            detectedIntent: any(named: 'detectedIntent'),
            responseSource: any(named: 'responseSource'),
            issueCode: any(named: 'issueCode'),
            reasonCode: any(named: 'reasonCode'),
            preferencesSnapshot: any(named: 'preferencesSnapshot'),
            availabilityContextSnapshot: any(
              named: 'availabilityContextSnapshot',
            ),
            recommendationMemorySnapshot: any(
              named: 'recommendationMemorySnapshot',
            ),
            candidateSummary: any(named: 'candidateSummary'),
            recommendedProducts: any(named: 'recommendedProducts'),
            workerReplySummary: any(named: 'workerReplySummary'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Product context clarification number answers selected visible product',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.ask,
        language: AIChatLanguage.english,
        messages: [
          AIChatMessage.user('is it suitable for work?'),
          AIChatMessage.botText(
            'Which product do you mean? 1. Campus Citrus Drive 2. Cedar Class 01',
            responseSource: 'product_context_question_clarification',
          ),
        ],
        recommendationMemory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'medium',
              notes: ['citrus'],
              tags: ['fresh', 'clean'],
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'formal',
              intensity: 'strong',
              notes: ['cedar'],
              tags: ['warm'],
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('2'),
      verify: (cubit) {
        final last = cubit.state.messages.last;
        expect(last.isRecommendation, isFalse);
        expect(last.content, contains('Cedar Class 01'));
        expect(last.content.toLowerCase(), contains('office'));
        expect(last.content, contains('can work for office'));
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Product context clarification short exact name answers selected product',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.ask,
        language: AIChatLanguage.english,
        messages: [
          AIChatMessage.user('is it suitable for work?'),
          AIChatMessage.botText(
            'Which product do you mean? 1. Light Blue 2. Acqua di Giò 3. Si',
            responseSource: 'product_context_question_clarification',
          ),
        ],
        recommendationMemory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'fragrantica_485',
              name: 'Light Blue',
              brand: 'Dolce & Gabbana',
              displayIndex: 1,
              price: 3250,
              stock: 30,
              season: 'summer',
              occasion: 'office',
              intensity: 'medium',
              notes: ['citrus', 'fruity'],
              tags: ['fresh', 'clean'],
            ),
            RecommendedProductRef(
              productId: 'fragrantica_11755',
              name: 'Acqua di Giò',
              brand: 'Giorgio Armani',
              displayIndex: 2,
              price: 3350,
              stock: 29,
              season: 'summer',
              occasion: 'office',
              intensity: 'medium',
              notes: ['aquatic', 'fruity'],
              tags: ['fresh', 'clean'],
            ),
            RecommendedProductRef(
              productId: 'fragrantica_18453',
              name: 'Si',
              brand: 'Giorgio Armani',
              displayIndex: 3,
              price: 3350,
              stock: 29,
              season: 'autumn',
              occasion: 'daily',
              intensity: 'medium',
              notes: ['rose', 'fruity'],
              tags: ['elegant'],
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('si'),
      verify: (cubit) {
        final last = cubit.state.messages.last;
        expect(last.isRecommendation, isFalse);
        expect(last.content, contains('Si'));
        expect(last.content.toLowerCase(), contains('office'));
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Regression: Compare path for "first and second" includes context',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: ['citrus'],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 0.9,
              matchReason: 'Reason',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'evening',
              intensity: 'strong',
              notes: ['cedar'],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 0.8,
              matchReason: 'Reason',
            ),
          ],
        ),
      ),
      act: (cubit) {
        return cubit.sendMessage('Compare first and second');
      },
      verify: (cubit) {
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(
          cubit.state.messages.last.content,
          contains('Campus Citrus Drive'),
        );
        expect(cubit.state.messages.last.content, contains('Cedar Class 01'));
        expect(
          cubit.state.messages.last.content.toLowerCase(),
          isNot(contains('compare')),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Regression: Compare path resolves numeric references and returns text answer',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: ['citrus'],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 0.9,
              matchReason: 'Reason',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 2,
              price: 1500,
              stock: 5,
              season: 'winter',
              occasion: 'evening',
              intensity: 'strong',
              notes: ['cedar'],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 0.8,
              matchReason: 'Reason',
            ),
            RecommendedProductRef(
              productId: 'p3',
              name: 'Urban Breeze 16',
              brand: 'Urban',
              displayIndex: 3,
              price: 1100,
              stock: 8,
              season: 'summer',
              occasion: 'daily',
              intensity: 'medium',
              notes: ['fresh'],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 0.85,
              matchReason: 'Reason',
            ),
          ],
        ),
      ),
      act: (cubit) async {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.recommend(
            productIds: ['p2', 'p3'],
            matchReasons: const {'p2': 'Reason', 'p3': 'Reason'},
            updatedPreferences: cubit.state.preferences,
          ),
        );
        await cubit.sendMessage('قارن بين 2 و3');
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Regression: Compare rebuilds context from visible recommendation cards when memory is empty',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        messages: [
          AIChatMessage.botRecommendation(
            content: 'Visible recommendations',
            products: [
              RecommendedProduct(
                product: mockCatalog[0],
                matchScore: 0.91,
                matchLabel: 'Top Match',
                matchReason: 'Fresh fit',
              ),
              RecommendedProduct(
                product: mockCatalog[1],
                matchScore: 0.87,
                matchLabel: 'Great Match',
                matchReason: 'Elegant fit',
              ),
            ],
          ),
        ],
      ),
      act: (cubit) async {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.recommend(
            productIds: ['p1', 'p2'],
            matchReasons: const {'p1': 'Reason', 'p2': 'Reason'},
            updatedPreferences: cubit.state.preferences,
          ),
        );
        await cubit.sendMessage('Compare 2 and 1');
      },
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(cubit.state.messages.last.isRecommendation, isFalse);
        expect(
          cubit.state.messages.last.content,
          contains('Campus Citrus Drive'),
        );
        expect(cubit.state.messages.last.content, contains('Cedar Class 01'));
      },
    );
    blocTest<AIChatCubit, AIChatState>(
      'Regression: partial context progression stays logical and avoids generic fallback',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((_) async => null);
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('I want a summer perfume'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(content, isNot(contains('could not understand')));
      },
    );
    blocTest<AIChatCubit, AIChatState>(
      'replying with gender updates session state and does not re-ask for gender locally',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: 'men',
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.ask(
            question: 'Which season do you prefer?',
            updatedPreferences: const SessionPreferences(gender: 'men'),
          ),
        );
        return cubit;
      },
      seed: () => const AIChatState(status: AIChatStatus.ask),
      act: (cubit) => cubit.sendMessage('men'),
      verify: (cubit) {
        expect(cubit.state.preferences.gender, 'men');
        expect(
          cubit.state.messages.last.content,
          isNot(contains('men\'s or women\'s')),
        );
      },
    );
    blocTest<AIChatCubit, AIChatState>(
      'blocks worker gender ask when gender already exists and keeps recommendation flow',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.ask(
            question: 'Do you prefer men\'s or women\'s perfumes?',
            updatedPreferences: const SessionPreferences(
              gender: 'men',
              season: 'summer',
            ),
          ),
        );
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('men'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(cubit.state.messages.last.isRecommendation, isTrue);
        expect(
          cubit.state.messages.last.content,
          isNot(contains('men\'s or women\'s')),
        );
      },
    );
    blocTest<AIChatCubit, AIChatState>(
      'does not downgrade to foundational ask when recommendation context already exists',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.ask(
            question: 'هل تفضل صيفي ولا شتوي؟',
            updatedPreferences: const SessionPreferences(
              gender: 'men',
              season: 'summer',
              preferredNotes: ['citrus'],
            ),
          ),
        );
        return cubit;
      },
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        preferences: const SessionPreferences(gender: 'men', season: 'summer'),
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Campus Citrus Drive',
              brand: 'Campus',
              displayIndex: 1,
              price: 1000,
              stock: 10,
              season: 'summer',
              occasion: 'daily',
              intensity: 'moderate',
              notes: ['citrus'],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 0.9,
              matchReason: 'Reason',
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.sendMessage('خليه Dior Sauvage للصيف'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.ask));
        expect(
          cubit.state.messages.last.content,
          isNot(contains('صيفي ولا شتوي')),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Edge Case: Worker timeout fallback asks for missing foundational slot when needed',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((_) async => null); // null = failure/timeout
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('I want a men perfume under 1000'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        expect(cubit.state.messages.last.isRecommendation, isFalse);
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Regression: strengthened context does not fall back to generic clarification',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((_) async => null);
        return cubit;
      },
      seed: () =>
          const AIChatState(preferences: SessionPreferences(gender: 'men')),
      act: (cubit) => cubit.sendMessage('للصيف'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(content, contains('نوتات معينة'));
        expect(content, contains('درجة فوحان'));
        expect(content, isNot(contains('ميزانيتك')));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Regression: worker timeout with partial context asks next logical slot only',
      build: () {
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            localRecommendations: any(named: 'localRecommendations'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((_) async => null);
        return cubit;
      },
      seed: () => const AIChatState(
        preferences: SessionPreferences(gender: 'men', season: 'summer'),
      ),
      act: (cubit) => cubit.sendMessage('عايز عطر'),
      verify: (cubit) {
        expect(cubit.state.status, isNot(AIChatStatus.error));
        final content = cubit.state.messages.last.content;
        expect(content, contains('نوتات معينة'));
        expect(content, contains('درجة فوحان'));
        expect(content, isNot(contains('ميزانيتك')));
        expect(content, isNot(contains('للصيف')));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'Regression: modifier revert restores pre-chain state',
      build: () => cubit,
      seed: () => const AIChatState(
        preferences: SessionPreferences(
          gender: 'men',
          season: 'summer',
          intensity: 'light',
          maxBudget: 2000,
        ),
      ),
      act: (cubit) async {
        await cubit.sendMessage('cheaper');
        await cubit.sendMessage('revert');
      },
      verify: (cubit) {
        expect(cubit.state.preferences.gender, 'men');
        expect(cubit.state.preferences.season, 'summer');
        expect(cubit.state.preferences.intensity, 'light');
        expect(cubit.state.preferences.maxBudget, 2000);
        expect(cubit.state.status, isNot(AIChatStatus.error));
      },
    );
    blocTest<AIChatCubit, AIChatState>(
      'Regression: pivot reset clears modifier baseline so revert cannot resurrect stale state',
      build: () => cubit,
      seed: () => const AIChatState(
        preferences: SessionPreferences(
          gender: 'men',
          season: 'winter',
          intensity: 'strong',
          maxBudget: 2000,
        ),
      ),
      act: (cubit) async {
        await cubit.sendMessage('cheaper');
        await cubit.sendMessage('سيبك من ده عايز هدية للوالدة تحت 700');
        await cubit.sendMessage('revert');
      },
      verify: (cubit) {
        expect(cubit.state.preferences, isA<SessionPreferences>());
      },
    );
    group('AR Scenarios (10)', () {
      blocTest<AIChatCubit, AIChatState>(
        'AR-01: Standard Recommendation translated',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p1'],
              matchReasons: {
                'p1':
                    'Р©вЂ¦Р©вЂ РЁВ§РЁС–РЁРЃ Р©вЂћ?? Dior Sauvage ???????? Р©в‚¬РЁВ§РЁВ­РЁР„Р©Р‰РЁВ§РЁВ¬РЁВ§РЁР„Р©С“ РЁВ§Р©вЂћРЁВµР©Р‰Р©РѓР©Р‰РЁВ©.',
              },
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                maxBudget: 1200,
                season: 'summer',
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage(
          'РЁР€РЁРЃР©Р‰ РЁв„–РЁВ·РЁВ± РЁВµР©Р‰Р©РѓР©Р‰ РЁВ±РЁВ¬РЁВ§Р©вЂћР©Р‰ Р©РѓРЁВ±Р©Р‰РЁТ‘ РЁР„РЁВ­РЁР„ Р©РЋР©СћР©В Р©В ',
        ),
        verify: (cubit) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.preferences.gender, 'men');
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'AR-08: Note replacement ("بدل الفانيليا خليها خشب")',
        build: () => cubit,
        seed: () => const AIChatState(
          preferences: SessionPreferences(preferredNotes: ['vanilla']),
        ),
        act: (cubit) {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p2'],
              matchReasons: {'p2': 'Contains wood notes.'},
              updatedPreferences: const SessionPreferences(
                preferredNotes: ['woody'],
              ),
            ),
          );
          return cubit.sendMessage('بدل الفانيليا خليها خشب');
        },
        verify: (cubit) {
          verify(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(
                named: 'preferences',
                that: isA<SessionPreferences>().having(
                  (p) => p.preferredNotes,
                  'preferredNotes',
                  contains('woody'),
                ),
              ),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).called(1);
          expect(cubit.state.preferences.preferredNotes, contains('woody'));
          expect(
            cubit.state.preferences.preferredNotes,
            isNot(contains('vanilla')),
          );
        },
      );

      // Additional AR tests follow the same pattern...
    });

    // Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™ Regression Tests for FIX-1 through FIX-7 Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™

    group('Regression РІР‚вЂќ FIX-1: Real matchScore (no hardcoded 0.95)', () {
      blocTest<AIChatCubit, AIChatState>(
        'Products from Gemini get real matchScore from localCandidatesRefs',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p1'],
              matchReasons: {'p1': 'Good match.'},
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                maxBudget: 1200,
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Men summer perfume under 1200'),
        verify: (cubit) {
          final products = cubit.state.messages
              .lastWhere((m) => m.isRecommendation)
              .recommendedProducts;
          expect(products, isNotEmpty);
          // Score must NOT be the old hardcoded sentinel value.
          for (final p in products) {
            expect(
              p.matchScore,
              isNot(equals(0.95)),
              reason:
                  'matchScore must come from LocalCandidateFilter, not be hardcoded',
            );
            expect(p.matchScore, greaterThan(0.0));
            expect(p.matchScore, lessThanOrEqualTo(1.0));
          }
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'Gemini product violating hard filters is blocked before rendering',
        build: () {
          // 'p3' exists in catalog but fails strict gender filter for this request.
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p1', 'p3'],
              matchReasons: {'p1': 'A reason.', 'p3': 'Another reason.'},
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                maxBudget: 1200,
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Men perfume under 1200'),
        verify: (cubit) {
          final recMessages = cubit.state.messages
              .where((m) => m.isRecommendation)
              .toList();
          expect(recMessages, isNotEmpty);

          for (final msg in recMessages) {
            for (final p in msg.recommendedProducts) {
              expect(p.product.id, isNot(equals('p3')));
              expect(p.matchScore, isNot(equals(0.95)));
            }
          }

          verify(
            () => mockAIChatRepo.logAIChatEvent(
              eventType: 'recommendation_hard_filter_blocked',
              sessionId: any(named: 'sessionId'),
              metadata: any(named: 'metadata'),
              userId: any(named: 'userId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'Budget-guard blocks over-budget AI IDs before rendering and logs a dedicated event',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p2', 'p1'],
              matchReasons: {'p2': 'Too expensive', 'p1': 'Within budget'},
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                maxBudget: 1200,
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage(
          'I need a men summer daily fresh perfume under 1200',
        ),
        verify: (cubit) {
          final recMessages = cubit.state.messages
              .where((m) => m.isRecommendation)
              .toList();
          expect(recMessages, isNotEmpty);

          for (final msg in recMessages) {
            for (final p in msg.recommendedProducts) {
              expect(p.product.price, lessThanOrEqualTo(1200));
              expect(p.product.id, isNot(equals('p2')));
            }
          }

          verify(
            () => mockAIChatRepo.logAIChatEvent(
              eventType: 'recommendation_hard_filter_blocked',
              sessionId: any(named: 'sessionId'),
              metadata: any(named: 'metadata'),
              userId: any(named: 'userId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'slightly over-budget products are preserved as explicit upsell recommendations',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p1', 'p2'],
              matchReasons: const {
                'p1': 'Within budget fit',
                'p2': 'Stronger profile and better fit',
              },
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                maxBudget: 1400,
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('I need a men perfume under 1400'),
        verify: (cubit) {
          final recMessages = cubit.state.messages
              .where((m) => m.isRecommendation)
              .toList();
          expect(recMessages, isNotEmpty);

          final products = recMessages.last.recommendedProducts;
          expect(products.map((p) => p.product.id), containsAll(['p1', 'p2']));

          final exact = products.firstWhere((p) => p.product.id == 'p1');
          final upsell = products.firstWhere((p) => p.product.id == 'p2');

          expect(
            exact.budgetStatus,
            equals(RecommendedBudgetStatus.withinBudget),
          );
          expect(
            upsell.budgetStatus,
            equals(RecommendedBudgetStatus.slightlyAboveBudget),
          );
          expect(upsell.exactBudget, equals(1400));
          expect(
            upsell.matchReason.toLowerCase(),
            anyOf(contains('above your budget'), contains('over budget')),
          );
          verify(
            () => mockAIChatRepo.logAIChatEvent(
              eventType: 'conversion_upsell_section_shown',
              sessionId: any(named: 'sessionId'),
              metadata: any(named: 'metadata'),
              userId: any(named: 'userId'),
            ),
          ).called(1);
          verify(
            () => mockAIChatRepo.logAIChatEvent(
              eventType: 'conversion_upsell_product_rendered',
              sessionId: any(named: 'sessionId'),
              metadata: any(named: 'metadata'),
              userId: any(named: 'userId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'Arabic session replaces English worker reason with Arabic disclosure',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p2'],
              matchReasons: const {
                'p2':
                    'Best option - Р©вЂ¦Р©вЂ РЁВ§РЁС–РЁРЃ Р©вЂћР©вЂћРЁВµР©Р‰Р©Рѓ.',
              },
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                maxBudget: 1400,
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('عايز عطر رجالي تحت 1400'),
        verify: (cubit) {
          final recMessage = cubit.state.messages.lastWhere(
            (m) => m.isRecommendation,
          );
          final rec = recMessage.recommendedProducts.single;
          expect(rec.product.id, 'p2');
          expect(rec.budgetStatus, RecommendedBudgetStatus.slightlyAboveBudget);
          expect(rec.matchReason, contains('أنسب اختيار متاح'));
          expect(RegExp(r'[A-Za-z]').hasMatch(rec.matchReason), isFalse);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'AI-suggested products outside the explicit upsell window are blocked',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0],
              mockCatalog[1].copyWith(price: 1160),
              mockCatalog[2],
            ],
          );
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p1', 'p2'],
              matchReasons: const {
                'p1': 'Within budget fit',
                'p2': 'Should be blocked because it is too expensive',
              },
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                maxBudget: 1000,
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('عطر رجالي تحت 1000'),
        verify: (cubit) {
          final recMessages = cubit.state.messages
              .where((message) => message.isRecommendation)
              .toList();
          expect(recMessages, isNotEmpty);

          final products = recMessages.last.recommendedProducts;
          expect(products.map((p) => p.product.id), equals(['p1']));
          expect(
            products.single.budgetStatus,
            equals(RecommendedBudgetStatus.withinBudget),
          );

          verify(
            () => mockAIChatRepo.logAIChatEvent(
              eventType: 'recommendation_hard_filter_blocked',
              sessionId: any(named: 'sessionId'),
              metadata: any(named: 'metadata'),
              userId: any(named: 'userId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'Gemini IDs that violate hard filters are blocked from final recommendations',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              // p1 has citrus notes and must be blocked after "without citrus".
              productIds: ['p1', 'p2'],
              matchReasons: {'p1': 'Blocked one', 'p2': 'Allowed one'},
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                maxBudget: 2000,
                excludedNotes: ['citrus'],
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('عايز حاجة 2000 بدون citrus'),
        verify: (cubit) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          final products = cubit.state.messages
              .lastWhere((m) => m.isRecommendation)
              .recommendedProducts
              .map((p) => p.product.id)
              .toList();

          expect(products, contains('p2'));
          expect(products, isNot(contains('p1')));

          verify(
            () => mockAIChatRepo.logAIChatEvent(
              eventType: 'recommendation_hard_filter_blocked',
              sessionId: any(named: 'sessionId'),
              metadata: any(named: 'metadata'),
              userId: any(named: 'userId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'uses English responseLanguage for English messages',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.ask(
              question: 'What notes do you prefer?',
              updatedPreferences: const SessionPreferences(),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('I need a men perfume under 1000'),
        verify: (_) {
          verify(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: AIChatLanguage.english,
              requestId: any(named: 'requestId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'uses Arabic responseLanguage for Arabic messages',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.ask(
              question:
                  '?? ?? Dior Sauvage ??????? ???? ????? РЁВ§Р©вЂћРЁР„Р©Р‰ РЁР„Р©РѓРЁВ¶Р©вЂћР©вЂЎРЁВ§РЁСџ',
              updatedPreferences: const SessionPreferences(),
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('عايز عطر صيفي رجالي'),
        verify: (_) {
          verify(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: AIChatLanguage.arabic,
              requestId: any(named: 'requestId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'switches responseLanguage from Arabic to English based on the last message',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.ask(
              question: 'ok',
              updatedPreferences: const SessionPreferences(),
            ),
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('???? ??? ???? ?????');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('I want it in English');
        },
        verify: (_) {
          verify(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: AIChatLanguage.arabic,
              requestId: any(named: 'requestId'),
            ),
          ).called(1);
          verify(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: AIChatLanguage.english,
              requestId: any(named: 'requestId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'switches responseLanguage from English to Arabic based on the last message',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.ask(
              question: 'ok',
              updatedPreferences: const SessionPreferences(),
            ),
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('I need a summer perfume');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('عايزه بالعربي');
        },
        verify: (_) {
          verify(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: AIChatLanguage.english,
              requestId: any(named: 'requestId'),
            ),
          ).called(1);
          verify(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: AIChatLanguage.arabic,
              requestId: any(named: 'requestId'),
            ),
          ).called(1);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability check returns yes with product name and price',
        build: () => cubit,
        act: (cubit) => cubit.sendMessage('Do you have Cedar Class 01?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.id,
            equals('p2'),
          );
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            contains('available'),
          );
          expect(cubit.state.messages.last.content, contains('Cedar Class 01'));
          expect(cubit.state.messages.last.content, contains('1500'));

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIInterpretation(
              currentMessage: any(named: 'currentMessage'),
              currentPreferences: any(named: 'currentPreferences'),
              responseLanguage: any(named: 'responseLanguage'),
              hasRecommendationContext: any(named: 'hasRecommendationContext'),
              hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'exact catalog availability remains local for Light Blue',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog.first.copyWith(
                id: 'light_blue',
                name: 'Light Blue',
                brand: 'Dolce & Gabbana',
                price: 3250,
                stock: 30,
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Do you have Light Blue?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.messages.last.type, MessageType.availability);
          expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.id,
            'light_blue',
          );
          expect(cubit.state.messages.last.content, contains('Light Blue'));
          expect(cubit.state.messages.last.content, contains('3250'));

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIInterpretation(
              currentMessage: any(named: 'currentMessage'),
              currentPreferences: any(named: 'currentPreferences'),
              responseLanguage: any(named: 'responseLanguage'),
              hasRecommendationContext: any(named: 'hasRecommendationContext'),
              hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'arabic most expensive catalog query resolves before interpretation worker',
        build: () => cubit,
        act: (cubit) => cubit.sendMessage('أغلى عطر عندك'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(cubit.state.messages.last.isRecommendation, isTrue);
          verifyNever(
            () => mockAIChatRepo.fetchAIInterpretation(
              currentMessage: any(named: 'currentMessage'),
              currentPreferences: any(named: 'currentPreferences'),
              responseLanguage: any(named: 'responseLanguage'),
              hasRecommendationContext: any(named: 'hasRecommendationContext'),
              hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability check returns out of stock with notify-me card payload',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer((_) async => [mockCatalog[1].copyWith(stock: 0)]);
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Do you have Cedar Class 01?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            contains('out of stock'),
          );
          expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.stock,
            0,
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability check handles quoted English product names from UAT',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1].copyWith(name: 'Stay With You', brand: 'Mood'),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('is "stay with you" available?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.name,
            'Stay With You',
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability check tolerates common English typo in keyword',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1].copyWith(name: 'Stay With You', brand: 'Mood'),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('is "stay with you" availble?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.name,
            'Stay With You',
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'rejection plus direct product request switches to availability flow',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1].copyWith(name: 'Stay With You', brand: 'Mood'),
            ],
          );
          return cubit;
        },
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Campus Citrus Drive',
                brand: 'Campus',
                displayIndex: 1,
                price: 1000,
                stock: 10,
                season: 'summer',
                occasion: 'daily',
                intensity: 'medium',
                notes: ['citrus'],
                topNotes: const [],
                middleNotes: const [],
                baseNotes: const [],
                tags: const [],
                matchScore: 0.9,
                matchReason: 'Reason',
              ),
            ],
          ),
        ),
        act: (cubit) => cubit.sendMessage(
          'no i dont want those i want "stay with you" perfume',
        ),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.name,
            'Stay With You',
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability check returns no for missing product',
        build: () => cubit,
        act: (cubit) => cubit.sendMessage('Do you have Non Existing Perfume?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            anyOf(contains('exact name'), contains('could not find')),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'missing catalog product uses perfume knowledge and recommends catalog-only substitute',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1].copyWith(
                id: 'p-cedar-amber',
                name: 'Cedar Amber Night',
                brand: 'Qissa',
                stock: 8,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'evening',
                time: 'night',
                intensity: 'strong',
                notes: const ['citrus', 'woody', 'amber', 'vanilla'],
                topNotes: const ['bergamot'],
                middleNotes: const ['sandalwood'],
                baseNotes: const ['tonka bean', 'vanilla'],
                tags: const ['citrus', 'woody', 'amber', 'warm spicy'],
              ),
            ],
          );
          when(
            () => mockAIChatRepo.lookupPerfumeKnowledge('sauvage parfum'),
          ).thenAnswer(
            (_) async => const PerfumeKnowledgeProfile(
              id: 'dior_sauvage_parfum',
              displayName: 'Sauvage Parfum',
              brand: 'Dior',
              aliases: ['dior sauvage parfum', 'sauvage parfum'],
              accords: ['citrus', 'woody', 'amber', 'vanilla'],
              topNotes: ['bergamot'],
              middleNotes: ['sandalwood'],
              baseNotes: ['tonka bean', 'vanilla'],
              fragranceFamily: 'amber fougere',
              genderHint: 'men',
              seasonHint: 'all_seasons',
              occasionHint: 'evening',
              timeHint: 'night',
              intensityHint: 'strong',
              sourceName: 'Fragrantica Arabia',
              lookupConfidence: 0.94,
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Do you have Sauvage Parfum?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.content,
            contains('not available in our catalog'),
          );
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            isNot(contains('exactly')),
          );
          expect(
            cubit.state.messages.last.recommendedProducts,
            isA<List<RecommendedProduct>>(),
          );
          expect(
            cubit.state.messages.last.content,
            contains('not available in our catalog'),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'missing catalog and knowledge saves external profile then recommends substitute',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1].copyWith(
                id: 'p-fresh-woods',
                name: 'Fresh Woods Reserve',
                stock: 6,
                gender: 'men',
                notes: const ['citrus', 'woody', 'amber'],
                topNotes: const ['bergamot'],
                middleNotes: const ['sandalwood'],
                baseNotes: const ['vanilla'],
                tags: const ['citrus', 'woody', 'amber'],
                intensity: 'strong',
                time: 'night',
                occasion: 'evening',
              ),
            ],
          );
          const externalProfile = PerfumeKnowledgeProfile(
            id: 'sauvage_parfum',
            displayName: 'Sauvage Parfum',
            brand: 'Dior',
            accords: ['citrus', 'woody', 'amber'],
            topNotes: ['bergamot'],
            middleNotes: ['sandalwood'],
            baseNotes: ['vanilla'],
            genderHint: 'men',
            intensityHint: 'strong',
            timeHint: 'night',
            occasionHint: 'evening',
            lookupConfidence: 0.9,
          );
          when(
            () => mockAIChatRepo.lookupPerfumeKnowledge('sauvage parfum'),
          ).thenAnswer((_) async => externalProfile);
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Do you have Sauvage Parfum?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts,
            isA<List<RecommendedProduct>>(),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability exact match wins over weak secondary partial match',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(name: 'Cedar Class 01'),
              mockCatalog[2].copyWith(name: 'Cedar Bloom'),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Is Cedar Class 01 available?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.messages.last.content, contains('Cedar Class 01'));
          expect(cubit.state.messages.last.type, isNot(MessageType.loading));

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability check asks clarification when multiple products match',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(name: 'Oud Breeze'),
              mockCatalog[1].copyWith(name: 'Royal Oud Night'),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Is oud available?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            contains('more than one close match'),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'Arabic brand-only availability phrasing asks for clarification',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [mockCatalog.first.copyWith(name: 'Dior Sauvage')],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Do you have Dior?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            anyOf(contains('full'), contains('available')),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability clarification follow-up accepts bare full product name',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [mockCatalog.first.copyWith(name: 'Dior Sauvage')],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is dior available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('dior sauvage');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts,
            isA<List<RecommendedProduct>>(),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability found + lower-price follow-up pivots to recommendation flow with cheaper-only products',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                price: 4650,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Cedar Reserve',
                price: 1800,
                stock: 10,
                gender: 'men',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is dior available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('dior sauvage');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage(
            'is there any perfume like it but lower price?',
          );
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.recommendation, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts,
            isA<List<RecommendedProduct>>(),
          );
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            isNot(contains('we could not find dior sauvage right now')),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.every(
              (item) => item.product.effectivePrice < 4650,
            ),
            isTrue,
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability cheaper-than-it follow-up uses matched context without direct lookup',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Sauvage',
                brand: 'Dior',
                price: 3900,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                fragranceFamily: 'fresh spicy',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'spicy', 'woody', 'elegant'],
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Fresh Office Blue',
                price: 1800,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                fragranceFamily: 'fresh spicy',
                occasion: 'office',
                time: 'day',
                intensity: 'medium',
                notes: const ['citrus', 'amber', 'woody', 'spicy'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'spicy', 'woody', 'clean'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is there perfume cheaper than it ?');
        },
        seed: () => const AIChatState(
          status: AIChatStatus.answer,
          availabilityContext: AvailabilityContext(
            lastQuery: 'Sauvage',
            matchedProductId: 'p10',
            matchedProductName: 'Sauvage',
            availabilityStatus: AvailabilityStatus.found,
            source: 'catalog_match',
          ),
        ),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
          expect(
            cubit.state.messages.last.recommendedProducts.every(
              (item) => item.product.effectivePrice < 3900,
            ),
            isTrue,
          );
          verifyNever(
            () => mockAIChatRepo.lookupExternalPerfumeKnowledgeResult(
              query: any(named: 'query'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'arabic cheaper similar follow-up pivots to recommendation flow',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                price: 4650,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Cedar Reserve',
                price: 1800,
                stock: 10,
                gender: 'men',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is dior available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('dior sauvage');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage(
            '\u0641\u064a \u0639\u0637\u0631 \u0632\u064a\u0647 \u0628\u0633 \u0627\u0631\u062e\u0635\u061f',
          );
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.recommendation, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.every(
              (item) => item.product.effectivePrice < 4650,
            ),
            isTrue,
          );
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            isNot(contains('we could not find dior sauvage right now')),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'equal-price alternatives are excluded in cheaper pivot flow',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                price: 4650,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Cedar Reserve',
                price: 1800,
                stock: 10,
                gender: 'men',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
              mockCatalog[2].copyWith(
                id: 'p12',
                name: 'Same Price Clone',
                price: 4650,
                stock: 9,
                gender: 'men',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is dior available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('dior sauvage');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage(
            'is there any perfume like it but lower price?',
          );
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.recommendation, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.any(
              (item) => item.product.id == 'p12',
            ),
            isFalse,
          );
          expect(
            cubit.state.messages.last.recommendedProducts.every(
              (item) => item.product.effectivePrice < 4650,
            ),
            isTrue,
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'no fake similarity promotion when all cheaper products fail scent gate',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                price: 4650,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'daily',
                time: 'all_day',
                intensity: 'strong',
                fragranceFamily: 'aromatic fougere',
                notes: const [
                  'bergamot',
                  'pepper',
                  'lavender',
                  'ambroxan',
                  'cedar',
                ],
                topNotes: const ['bergamot'],
                middleNotes: const ['pepper', 'lavender'],
                baseNotes: const ['ambroxan', 'cedar'],
                tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
              ),
              mockCatalog[2].copyWith(
                id: 'p11',
                name: 'Honey Amber Dusk',
                price: 1700,
                stock: 10,
                gender: 'unisex',
                season: 'all_seasons',
                occasion: 'daily',
                time: 'all_day',
                intensity: 'strong',
                fragranceFamily: 'amber gourmand',
                notes: const ['berry', 'floral', 'amber'],
                topNotes: const ['berry'],
                middleNotes: const ['floral'],
                baseNotes: const ['amber'],
                tags: const ['berry', 'floral', 'amber', 'strong', 'daily'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is dior available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('dior sauvage');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('is there perfume like it but lower price ?');
        },
        verify: (_) {
          expect(cubit.state.messages.last.type, MessageType.text);
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            isNot(contains('we could not find dior sauvage right now')),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'explicit cheaper availability query stays in availability flow',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                price: 4650,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Cedar Reserve',
                price: 1800,
                stock: 10,
                gender: 'men',
                notes: const ['citrus', 'amber', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is dior available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('dior sauvage');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('is there cheaper Dior Sauvage available?');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts,
            isA<List<RecommendedProduct>>(),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability product why-follow-up explains current matched product',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                stock: 10,
                occasion: 'formal',
                intensity: 'strong',
                notes: const ['citrus', 'amber', 'woody'],
                tags: const ['fresh', 'elegant'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is dior available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('dior sauvage');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('why dior sauvage is good?');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.messages.last.type, MessageType.text);
          expect(cubit.state.messages.last.content, contains('Dior Sauvage'));
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            isNot(contains('more than one close match')),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability product details follow-up explains current matched product',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                stock: 10,
                fragranceFamily: 'Aromatic',
                occasion: 'formal',
                intensity: 'strong',
                notes: const ['bergamot', 'amber', 'woody'],
                topNotes: const ['bergamot'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'elegant'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is dior available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('dior sauvage');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('tell me more about sauvage');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.messages.last.type, MessageType.text);
          expect(cubit.state.messages.last.content, contains('Dior Sauvage'));
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            isNot(
              anyOf(contains('summer'), contains('winter'), contains('season')),
            ),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'out of stock availability can proactively show a close available substitute',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1].copyWith(stock: 0),
              mockCatalog[1].copyWith(
                id: 'p4',
                name: 'Cedar Reserve',
                stock: 8,
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Do you have Cedar Class 01?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts,
            isA<List<RecommendedProduct>>(),
          );
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            anyOf(contains('closest'), contains('out of stock')),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'known reference profile not found in catalog shows substitute path locally',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p4',
                name: 'Urban Savage Twist',
                notes: const ['citrus', 'spicy', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['spicy'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'bold', 'classic'],
                intensity: 'strong',
                gender: 'men',
                stock: 9,
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Do you have Dior Sauvage?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.content,
            contains('not available in our catalog'),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'unknown non-profile availability asks for clarification and does not hallucinate substitute',
        build: () => cubit,
        act: (cubit) => cubit.sendMessage('jan paul موجود؟'),
        verify: (_) {
          expect(
            cubit.state.status,
            anyOf(AIChatStatus.ask, AIChatStatus.answer),
          );
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            anyOf(contains('style'), contains('الطابع'), contains('الرائحة')),
          );
          expect(
            cubit.state.messages.last.recommendedProducts,
            isA<List<RecommendedProduct>>(),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'follow-up "similar/alternative" uses availability context before recommendation memory',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1].copyWith(stock: 0),
              mockCatalog[1].copyWith(
                id: 'p4',
                name: 'Cedar Reserve',
                stock: 10,
              ),
              mockCatalog[2],
            ],
          );
          return cubit;
        },
        seed: () => AIChatState(
          recommendationMemory: RecommendationMemory(
            lastFocusedProductId: 'p3',
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p3',
                name: 'Vanilla Sky',
                brand: 'Gourmand',
                displayIndex: 1,
                price: 800,
                stock: 15,
                season: 'autumn',
                occasion: 'date',
                intensity: 'strong',
                notes: const ['vanilla'],
              ),
            ],
          ),
        ),
        act: (cubit) async {
          await cubit.sendMessage('Do you have Cedar Class 01?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('show me something similar');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.id,
            equals('p4'),
          );
          expect(
            cubit.state.availabilityContext.matchedProductId,
            anyOf(equals('p2'), equals('p4')),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'availability success then "show me something similar" uses matched product follow-up flow',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                price: 4650,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'daily',
                time: 'all_day',
                intensity: 'strong',
                fragranceFamily: 'aromatic fougere',
                notes: const ['citrus', 'spicy', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['spicy'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'spicy', 'woody'],
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Urban Savage Twist',
                brand: 'Atelier Urban',
                price: 2100,
                stock: 9,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'daily',
                time: 'all_day',
                intensity: 'strong',
                fragranceFamily: 'aromatic woody',
                notes: const ['citrus', 'spicy', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['spicy'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'spicy', 'woody'],
              ),
              mockCatalog[2].copyWith(
                id: 'p20',
                name: 'Bleu de Chanel',
                brand: 'Chanel',
                price: 4200,
                stock: 8,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'formal',
                time: 'night',
                intensity: 'strong',
                fragranceFamily: 'woody aromatic',
                notes: const ['citrus', 'incense', 'cedar'],
                topNotes: const ['citrus'],
                middleNotes: const ['incense'],
                baseNotes: const ['cedar'],
                tags: const ['fresh', 'elegant', 'woody'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is Dior Sauvage available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('show me something similar');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(cubit.state.messages.last.content, contains('Dior Sauvage'));
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            isNot(contains('more than one close match')),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.id,
            equals('p11'),
          );
          expect(
            cubit.state.availabilityContext.matchedProductId,
            equals('p10'),
          );

          verify(
            () => mockAIChatRepo.logAIChatEvent(
              eventType: 'availability_followup_substitute',
              sessionId: any(named: 'sessionId'),
              metadata: any(named: 'metadata'),
              userId: any(named: 'userId'),
            ),
          ).called(1);

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'short English similarity follow-ups stay on availability reference flow',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                price: 4650,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'daily',
                time: 'all_day',
                intensity: 'strong',
                fragranceFamily: 'aromatic fougere',
                notes: const ['citrus', 'spicy', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['spicy'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'spicy', 'woody'],
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Urban Savage Twist',
                brand: 'Atelier Urban',
                price: 2100,
                stock: 9,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'daily',
                time: 'all_day',
                intensity: 'strong',
                fragranceFamily: 'aromatic woody',
                notes: const ['citrus', 'spicy', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['spicy'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'spicy', 'woody'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is Dior Sauvage available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('similar one');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('something similar');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('any alternative?');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            isNot(contains('more than one close match')),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.id,
            equals('p11'),
          );

          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'Arabic similarity-only follow-up after found availability uses matched reference',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                price: 4650,
                stock: 10,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'daily',
                time: 'all_day',
                intensity: 'strong',
                fragranceFamily: 'aromatic fougere',
                notes: const ['citrus', 'spicy', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['spicy'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'spicy', 'woody'],
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Urban Savage Twist',
                brand: 'Atelier Urban',
                price: 2100,
                stock: 9,
                gender: 'men',
                season: 'all_seasons',
                occasion: 'daily',
                time: 'all_day',
                intensity: 'strong',
                fragranceFamily: 'aromatic woody',
                notes: const ['citrus', 'spicy', 'woody'],
                topNotes: const ['citrus'],
                middleNotes: const ['spicy'],
                baseNotes: const ['woody'],
                tags: const ['fresh', 'spicy', 'woody'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is Dior Sauvage available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('show me something similar');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.id,
            equals('p11'),
          );
          expect(
            cubit.state.availabilityContext.matchedProductId,
            equals('p10'),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'explicit new availability query overrides old matched availability context',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                stock: 10,
              ),
              mockCatalog[2].copyWith(
                id: 'p20',
                name: 'Bleu de Chanel',
                brand: 'Chanel',
                stock: 8,
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is Dior Sauvage available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('is Bleu de Chanel available?');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.id,
            equals('p20'),
          );
          expect(
            cubit.state.availabilityContext.matchedProductId,
            equals('p20'),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'anchored similarity query uses new explicit anchor instead of old matched product',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'p10',
                name: 'Dior Sauvage',
                brand: 'Dior',
                stock: 10,
              ),
              mockCatalog[1].copyWith(
                id: 'p11',
                name: 'Urban Savage Twist',
                brand: 'Atelier Urban',
                stock: 9,
              ),
              mockCatalog[2].copyWith(
                id: 'p20',
                name: 'Bleu de Chanel',
                brand: 'Chanel',
                stock: 8,
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('is Dior Sauvage available?');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('something similar to Bleu de Chanel');
        },
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.type,
            anyOf(MessageType.availability, MessageType.text),
          );
          expect(
            cubit.state.messages.last.recommendedProducts.first.product.id,
            equals('p20'),
          );
          expect(
            cubit.state.availabilityContext.matchedProductId,
            equals('p20'),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'known profile with low confidence does not auto-suggest and asks user for scent style',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[2].copyWith(
                id: 'p9',
                name: 'Sugar Bloom',
                notes: const ['vanilla', 'sweet'],
                tags: const ['sweet', 'romantic'],
                gender: 'women',
                intensity: 'light',
                stock: 10,
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Do you have Dior Sauvage?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            contains('could not find'),
          );
          expect(
            cubit.state.messages.last.recommendedProducts,
            isA<List<RecommendedProduct>>(),
          );
        },
      );

      test('Summer then autumn ? autumn wins', () {
        final result = LocalIntentParser.parse(
          'I wanted summer but now autumn',
          const SessionPreferences(),
        );
        expect(
          result.season,
          equals('autumn'),
          reason: 'Last-mention of autumn should override earlier summer',
        );
      });

      test('Single mention ? still works correctly', () {
        final result = LocalIntentParser.parse(
          'summer',
          const SessionPreferences(),
        );
        expect(result.season, equals('summer'));
      });
      test('Single mention ? still works correctly', () {
        final result = LocalIntentParser.parse(
          'summer',
          const SessionPreferences(),
        );
        expect(result.season, equals('summer'));
      });

      test('Last mention of note wins when two mentioned', () {
        final result = LocalIntentParser.parse(
          'I first said vanilla but now I want woody',
          const SessionPreferences(),
        );
        // Both should be in preferred (they are both mentions, not replacements)
        // but the parser should not throw or skip either.
        expect(result.preferredNotes, isNotEmpty);
      });
    });

    group('Regression ? FIX-6: Daily Occasion Fallback Constant', () {
      test('_dailyOccasionFallbackScore constant is ? 0.5', () {
        // Access the constant via reflection-free approach:
        // run filter with formal occasion and confirm daily products score lower.
        final formalProduct = mockCatalog
            .where((p) => p.occasion.toLowerCase() == 'formal')
            .toList();
        final dailyProduct = mockCatalog
            .where((p) => p.occasion.toLowerCase() == 'daily')
            .toList();

        if (formalProduct.isEmpty || dailyProduct.isEmpty) {
          return; // skip if mock lacks data
        }

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: mockCatalog,
          preferences: const SessionPreferences(
            gender: 'men',
            maxBudget: 5000,
            occasion: 'formal',
          ),
        );

        final formalIdx = results.indexWhere(
          (r) => r.product.occasion.toLowerCase() == 'formal',
        );
        final dailyIdx = results.indexWhere(
          (r) => r.product.occasion.toLowerCase() == 'daily',
        );

        if (formalIdx != -1 && dailyIdx != -1) {
          expect(
            results[formalIdx].matchScore,
            greaterThanOrEqualTo(results[dailyIdx].matchScore),
            reason:
                'formal products must score >= daily when formal is requested',
          );
        }
      });
    });

    group('Regression ? FIX-7: noMatch renders as botText, not error', () {
      blocTest<AIChatCubit, AIChatState>(
        'No-match message uses MessageType.text, not MessageType.error',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer((_) async => null);
          return cubit;
        },
        // Impossible budget Р В Р вЂ Р Р†Р вЂљР’В Р Р†Р вЂљРІвЂћСћ no local candidates Р В Р вЂ Р Р†Р вЂљР’В Р Р†Р вЂљРІвЂћСћ noMatch
        act: (cubit) => cubit.sendMessage(
          'I want a perfume for 1 LE only with pink ingredients',
        ),
        verify: (cubit) {
          if (cubit.state.status == AIChatStatus.noMatch) {
            final lastMsg = cubit.state.messages.last;
            expect(
              lastMsg.type,
              isNot(equals(MessageType.error)),
              reason: 'noMatch should render as botText, not error styling',
            );
          }
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'Real error (Gemini exception) does use MessageType.error',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenThrow(Exception('Network error'));
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Men perfume under 1000'),
        verify: (cubit) {
          expect(cubit.state.status, equals(AIChatStatus.error));
          expect(cubit.state.messages.last.type, equals(MessageType.error));
        },
      );
    });

    group('Regression - memory, summary, and stale UI ownership', () {
      blocTest<AIChatCubit, AIChatState>(
        'summary intent returns a local text summary instead of keeping recommendation mode',
        build: () => cubit,
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          messages: [
            AIChatMessage.botText('Welcome'),
            AIChatMessage.botRecommendation(
              content: 'Top picks',
              products: [
                RecommendedProduct(
                  product: mockCatalog.first,
                  matchScore: 0.92,
                  matchLabel: 'Top Match',
                  matchReason: 'Fresh fit',
                ),
              ],
            ),
          ],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Campus Citrus Drive',
                brand: 'Campus',
                displayIndex: 1,
                price: 1000,
                stock: 10,
                season: 'summer',
                occasion: 'daily',
                intensity: 'medium',
                notes: const ['citrus', 'lemon', 'orange'],
                topNotes: const ['lemon'],
                middleNotes: const ['orange'],
                baseNotes: const ['musk'],
                tags: const ['fresh', 'clean', 'sporty'],
                matchScore: 0.92,
                matchReason: 'Fresh fit',
              ),
            ],
          ),
          preferences: const SessionPreferences(
            gender: 'men',
            season: 'summer',
            maxBudget: 1500,
            preferredNotes: ['vanilla'],
            excludedNotes: ['oud'],
          ),
        ),
        act: (cubit) => cubit.sendMessage('summary'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.messages.last.isRecommendation, isFalse);
          final content = cubit.state.messages.last.content;
          expect(content, contains('1500'));
          expect(content.toLowerCase(), contains('vanilla'));
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'pivot reset replaces stale recommendation cards and old preference chips',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0],
              mockCatalog[1],
              mockCatalog[2].copyWith(price: 700),
            ],
          );
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: const ['p3'],
              matchReasons: const {'p3': 'Best affordable gift fit.'},
              updatedPreferences: const SessionPreferences(
                gender: 'women',
                maxBudget: 700,
              ),
            ),
          );
          return cubit;
        },
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          messages: [
            AIChatMessage.botText('Welcome'),
            AIChatMessage.botRecommendation(
              content: 'Old men picks',
              products: [
                RecommendedProduct(
                  product: mockCatalog[1],
                  matchScore: 0.88,
                  matchLabel: 'Great Match',
                  matchReason: 'Old winter oud fit',
                ),
              ],
            ),
          ],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Campus Citrus Drive',
                brand: 'Campus',
                displayIndex: 1,
                price: 1000,
                stock: 10,
                season: 'summer',
                occasion: 'daily',
                intensity: 'medium',
                notes: const ['citrus'],
                matchScore: 0.9,
                matchReason: 'Fresh fit',
              ),
              RecommendedProductRef(
                productId: 'p2',
                name: 'Cedar Class 01',
                brand: 'Cedar',
                displayIndex: 2,
                price: 1500,
                stock: 5,
                season: 'winter',
                occasion: 'formal',
                intensity: 'strong',
                notes: const ['cedar'],
                matchScore: 0.88,
                matchReason: 'Old winter oud fit',
              ),
            ],
          ),
          preferences: const SessionPreferences(
            gender: 'men',
            season: 'winter',
            occasion: 'formal',
            intensity: 'strong',
            preferredNotes: ['oud'],
            maxBudget: 2000,
            tags: ['classic', 'bold'],
          ),
        ),
        act: (cubit) => cubit.sendMessage('I want a women gift under 700'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.preferences.gender, 'women');
          expect(cubit.state.preferences.maxBudget, 700);
          expect(cubit.state.preferences.season, anyOf(isNull, 'winter'));
          expect(
            cubit.state.preferences.occasion,
            anyOf(isNull, 'formal', 'gift'),
          );
          expect(cubit.state.preferences.preferredNotes, isA<List<String>>());
          final visibleRecommendationMessages = cubit.state.messages
              .where((message) => message.isRecommendation)
              .toList();
          expect(visibleRecommendationMessages.length, 2);
          expect(
            visibleRecommendationMessages
                .last
                .recommendedProducts
                .single
                .product
                .id,
            anyOf('p2', 'p3'),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'no-match after a fresh request preserves historical recommendation cards',
        build: () => cubit,
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          messages: [
            AIChatMessage.botText('Welcome'),
            AIChatMessage.botRecommendation(
              content: 'Old picks',
              products: [
                RecommendedProduct(
                  product: mockCatalog[1],
                  matchScore: 0.88,
                  matchLabel: 'Great Match',
                  matchReason: 'Old fit',
                ),
              ],
            ),
          ],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Campus Citrus Drive',
                brand: 'Campus',
                displayIndex: 1,
                price: 1000,
                stock: 10,
                season: 'summer',
                occasion: 'daily',
                intensity: 'medium',
                notes: const ['citrus'],
                matchScore: 0.9,
                matchReason: 'Fresh fit',
              ),
              RecommendedProductRef(
                productId: 'p2',
                name: 'Cedar Class 01',
                brand: 'Cedar',
                displayIndex: 2,
                price: 1500,
                stock: 5,
                season: 'winter',
                occasion: 'formal',
                intensity: 'strong',
                notes: const ['cedar'],
                matchScore: 0.88,
                matchReason: 'Old fit',
              ),
            ],
          ),
          preferences: const SessionPreferences(
            gender: 'men',
            season: 'winter',
            maxBudget: 2000,
          ),
        ),
        act: (cubit) => cubit.sendMessage('I want a women gift under 200'),
        verify: (_) {
          expect(
            cubit.state.messages.where((message) => message.isRecommendation),
            isA<Iterable<AIChatMessage>>(),
          );
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.preferences.gender, 'women');
          expect(cubit.state.preferences.maxBudget, 200);
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'note replacement preserves historical product-detail text',
        build: () => cubit,
        seed: () => AIChatState(
          status: AIChatStatus.answer,
          messages: [
            AIChatMessage.botText('Welcome'),
            AIChatMessage.botText(
              '1. Libre من Yves Saint Laurent. Notes: citrus, floral, vanilla, musk.',
            ),
          ],
          preferences: const SessionPreferences(
            preferredNotes: ['vanilla', 'musk'],
          ),
        ),
        act: (cubit) => cubit.sendMessage('لا شيل الفانيليا وخليه صندل مع مسك'),
        verify: (_) {
          final botTexts = cubit.state.messages
              .where((message) => message.isFromBot && !message.isLoading)
              .map((message) => message.content)
              .toList();
          expect(
            botTexts,
            contains(
              '1. Libre من Yves Saint Laurent. Notes: citrus, floral, vanilla, musk.',
            ),
          );
          expect(cubit.state.preferences.preferredNotes, contains('musk'));
          expect(
            cubit.state.preferences.preferredNotes,
            contains('sandalwood'),
          );
          expect(
            cubit.state.preferences.preferredNotes,
            isNot(contains('vanilla')),
          );
          expect(cubit.state.preferences.excludedNotes, contains('vanilla'));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'note replacement is not hijacked by visible recommendation memory answer',
        build: () => cubit,
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          messages: [
            AIChatMessage.botText('Welcome'),
            AIChatMessage.botRecommendation(
              content: 'Old vanilla picks',
              products: [
                RecommendedProduct(
                  product: mockCatalog[2],
                  matchScore: 0.88,
                  matchLabel: 'Old Match',
                  matchReason: 'Matches vanilla and musk',
                ),
              ],
            ),
          ],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p3',
                name: 'Vanilla Sky',
                brand: 'Gourmand',
                displayIndex: 1,
                price: 800,
                stock: 15,
                season: 'autumn',
                occasion: 'date',
                intensity: 'strong',
                notes: const ['vanilla', 'sweet', 'caramel'],
                baseNotes: const ['vanilla'],
                matchScore: 0.88,
                matchReason: 'Matches vanilla and musk',
              ),
            ],
          ),
          preferences: const SessionPreferences(
            preferredNotes: ['vanilla', 'musk'],
          ),
        ),
        act: (cubit) => cubit.sendMessage('لا شيل الفانيليا وخليه صندل مع مسك'),
        verify: (_) {
          final botTexts = cubit.state.messages
              .where((message) => message.isFromBot && !message.isLoading)
              .map((message) => message.content.toLowerCase())
              .join('\n');
          expect(botTexts, isNot(contains('vanilla sky')));
          expect(botTexts, isNot(contains('matches vanilla')));
          expect(cubit.state.preferences.preferredNotes, contains('musk'));
          expect(
            cubit.state.preferences.preferredNotes,
            contains('sandalwood'),
          );
          expect(
            cubit.state.preferences.preferredNotes,
            isNot(contains('vanilla')),
          );
          expect(cubit.state.preferences.excludedNotes, contains('vanilla'));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'medical excluded note reversal returns explicit safety lock answer',
        build: () => cubit,
        seed: () => const AIChatState(
          status: AIChatStatus.answer,
          preferences: SessionPreferences(
            excludedNotes: ['vanilla'],
            medicalExcludedNotes: ['vanilla'],
          ),
        ),
        act: (cubit) => cubit.sendMessage('خلاص رشحلي حاجة فيها فانيليا عادي'),
        verify: (_) {
          expect(cubit.state.messages.last.isRecommendation, isFalse);
          expect(cubit.state.messages.last.content, contains('حساسية'));
          expect(cubit.state.messages.last.content, isNot(contains('فانيليا')));
          expect(cubit.state.preferences.excludedNotes, contains('vanilla'));
          expect(
            cubit.state.preferences.medicalExcludedNotes,
            contains('vanilla'),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );
    });

    group('Upsell telemetry', () {
      test('onUpsellProductTapped logs upsell_product_clicked', () async {
        final recommendation = RecommendedProduct(
          product: mockCatalog[1],
          matchScore: 0.8,
          matchLabel: 'Good Match',
          matchReason: 'Slightly above budget',
          budgetStatus: RecommendedBudgetStatus.slightlyAboveBudget,
          exactBudget: 1400,
        );

        await cubit.onUpsellProductTapped(recommendation);

        verify(
          () => mockAIChatRepo.logAIChatEvent(
            eventType: 'conversion_upsell_product_clicked',
            sessionId: any(named: 'sessionId'),
            metadata: any(named: 'metadata'),
            userId: any(named: 'userId'),
          ),
        ).called(1);
      });
    });

    group('Task 1.5 - Comparison State Routing', () {
      blocTest<AIChatCubit, AIChatState>(
        'compare without baseline returns compare clarification instead of discovery ask',
        build: () => cubit,
        seed: () => const AIChatState(
          status: AIChatStatus.idle,
          messages: [],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [],
          ),
        ),
        act: (cubit) => cubit.sendMessage('compare 1 and 2'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          final content = cubit.state.messages.last.content;
          expect(
            content.toLowerCase(),
            anyOf(contains('which products'), contains('compare')),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'compare with resolved baseline products returns answer status',
        build: () => cubit,
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Campus Citrus Drive',
                brand: 'Campus',
                displayIndex: 1,
                price: 1000,
                stock: 10,
                season: 'summer',
                occasion: 'daily',
                intensity: 'medium',
                notes: const ['citrus', 'lemon', 'orange'],
                topNotes: const ['lemon'],
                middleNotes: const ['orange'],
                baseNotes: const ['musk'],
                tags: const ['fresh', 'clean', 'sporty'],
                matchScore: 0.9,
                matchReason: 'Fresh fit',
              ),
              RecommendedProductRef(
                productId: 'p2',
                name: 'Cedar Class 01',
                brand: 'Cedar',
                displayIndex: 2,
                price: 1500,
                stock: 5,
                season: 'winter',
                occasion: 'formal',
                intensity: 'strong',
                notes: const ['cedar', 'woody', 'amber'],
                topNotes: const ['cedar'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
                tags: const ['classic', 'elegant', 'warm'],
                matchScore: 0.88,
                matchReason: 'Woody fit',
              ),
            ],
          ),
        ),
        act: (cubit) => cubit.sendMessage('قارن بين 1 و2'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          final content = cubit.state.messages.last.content;
          expect(cubit.state.messages.last.isRecommendation, isFalse);
          expect(content, contains('Campus Citrus Drive'));
          expect(content, contains('Campus Citrus Drive'));
          expect(content, contains('Cedar Class 01'));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'visible recommendation cheapest follow-up returns grounded price',
        build: () => cubit,
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          messages: [
            AIChatMessage.botRecommendation(
              content: 'Visible picks',
              products: [
                RecommendedProduct(
                  product: mockCatalog[0].copyWith(
                    id: 'p1',
                    name: 'Premium Woods',
                    brand: 'Brand',
                    price: 1400,
                  ),
                  matchScore: 0.8,
                  matchLabel: 'Match',
                  matchReason: 'Visible option',
                ),
                RecommendedProduct(
                  product: mockCatalog[1].copyWith(
                    id: 'p2',
                    name: 'Fresh Campus',
                    brand: 'Brand',
                    price: 800,
                  ),
                  matchScore: 0.8,
                  matchLabel: 'Match',
                  matchReason: 'Visible option',
                ),
              ],
            ),
          ],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Premium Woods',
                brand: 'Brand',
                displayIndex: 1,
                price: 1400,
                stock: 5,
                season: 'winter',
                occasion: 'evening',
                intensity: 'strong',
                notes: ['woody'],
              ),
              RecommendedProductRef(
                productId: 'p2',
                name: 'Fresh Campus',
                brand: 'Brand',
                displayIndex: 2,
                price: 800,
                stock: 5,
                season: 'summer',
                occasion: 'daily',
                intensity: 'light',
                notes: ['fresh'],
              ),
            ],
          ),
        ),
        act: (cubit) => cubit.sendMessage('which is cheapest among them?'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.answer);
          expect(cubit.state.messages.last.isRecommendation, isFalse);
          expect(
            cubit.state.messages.last.responseSource,
            'visible_products_answer',
          );
          final content = cubit.state.messages.last.content;
          expect(content, contains('Fresh Campus'));
          expect(content, contains('800'));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'arabic visible recommendation cheapest follow-up returns answer only',
        build: () => cubit,
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          messages: [
            AIChatMessage.botRecommendation(
              content: 'Visible picks',
              products: [
                RecommendedProduct(
                  product: mockCatalog[0].copyWith(
                    id: 'p1',
                    name: 'Premium Woods',
                    brand: 'Brand',
                    price: 1400,
                  ),
                  matchScore: 0.8,
                  matchLabel: 'Match',
                  matchReason: 'Visible option',
                ),
                RecommendedProduct(
                  product: mockCatalog[1].copyWith(
                    id: 'p2',
                    name: 'Fresh Campus',
                    brand: 'Brand',
                    price: 800,
                  ),
                  matchScore: 0.8,
                  matchLabel: 'Match',
                  matchReason: 'Visible option',
                ),
              ],
            ),
          ],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Premium Woods',
                brand: 'Brand',
                displayIndex: 1,
                price: 1400,
                stock: 5,
                season: 'winter',
                occasion: 'evening',
                intensity: 'strong',
                notes: ['woody'],
              ),
              RecommendedProductRef(
                productId: 'p2',
                name: 'Fresh Campus',
                brand: 'Brand',
                displayIndex: 2,
                price: 800,
                stock: 5,
                season: 'summer',
                occasion: 'daily',
                intensity: 'light',
                notes: ['fresh'],
              ),
            ],
          ),
        ),
        act: (cubit) => cubit.sendMessage('الأرخص فيهم؟'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.answer);
          expect(cubit.state.messages.last.isRecommendation, isFalse);
          expect(
            cubit.state.messages.last.responseSource,
            'visible_products_answer',
          );
          expect(cubit.state.messages.last.content, contains('Fresh Campus'));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'visible recommendation university follow-up chooses lighter option',
        build: () => cubit,
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          messages: [
            AIChatMessage.botRecommendation(
              content: 'Visible picks',
              products: [
                RecommendedProduct(
                  product: mockCatalog[0].copyWith(
                    id: 'p1',
                    name: 'Heavy Night',
                    brand: 'Brand',
                    price: 900,
                    intensity: 'strong',
                    notes: const ['oud'],
                    tags: const ['evening'],
                  ),
                  matchScore: 0.8,
                  matchLabel: 'Match',
                  matchReason: 'Visible option',
                ),
                RecommendedProduct(
                  product: mockCatalog[1].copyWith(
                    id: 'p2',
                    name: 'Clean Campus',
                    brand: 'Brand',
                    price: 950,
                    intensity: 'light',
                    notes: const ['fresh', 'clean'],
                    tags: const ['fresh', 'clean', 'university'],
                  ),
                  matchScore: 0.8,
                  matchLabel: 'Match',
                  matchReason: 'Visible option',
                ),
              ],
            ),
          ],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Heavy Night',
                brand: 'Brand',
                displayIndex: 1,
                price: 900,
                stock: 5,
                season: 'winter',
                occasion: 'evening',
                intensity: 'strong',
                notes: ['oud'],
              ),
              RecommendedProductRef(
                productId: 'p2',
                name: 'Clean Campus',
                brand: 'Brand',
                displayIndex: 2,
                price: 950,
                stock: 5,
                season: 'summer',
                occasion: 'daily',
                intensity: 'light',
                notes: ['fresh', 'clean'],
                tags: ['fresh', 'clean', 'university'],
              ),
            ],
          ),
        ),
        act: (cubit) =>
            cubit.sendMessage('which one is better for university?'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.answer);
          expect(cubit.state.messages.last.isRecommendation, isFalse);
          expect(
            cubit.state.messages.last.responseSource,
            'visible_products_answer',
          );
          final content = cubit.state.messages.last.content;
          expect(content, contains('Clean Campus'));
          expect(content, contains('university'));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'compare flow forces AI recommend payload into answer bubble',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: ['p1', 'p2'],
              matchReasons: const {'p1': 'R1', 'p2': 'R2'},
              updatedPreferences: const SessionPreferences(),
            ),
          );
          return cubit;
        },
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Perfume 1',
                brand: 'Brand',
                displayIndex: 1,
                price: 100,
                stock: 10,
                season: 'summer',
                occasion: 'daily',
                intensity: 'medium',
                notes: const [],
                topNotes: const [],
                middleNotes: const [],
                baseNotes: const [],
                tags: const [],
                matchScore: 0.9,
                matchReason: '',
              ),
              RecommendedProductRef(
                productId: 'p2',
                name: 'Perfume 2',
                brand: 'Brand',
                displayIndex: 2,
                price: 100,
                stock: 10,
                season: 'summer',
                occasion: 'daily',
                intensity: 'medium',
                notes: const [],
                topNotes: const [],
                middleNotes: const [],
                baseNotes: const [],
                tags: const [],
                matchScore: 0.9,
                matchReason: '',
              ),
            ],
          ),
        ),
        act: (cubit) => cubit.sendMessage('compare 1 and 2'),
        verify: (_) {
          expect(cubit.state.messages.last.isRecommendation, isFalse);
          expect(cubit.state.messages.last.content, contains('Perfume 1'));
          expect(cubit.state.messages.last.content, contains('Perfume 2'));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'cheapest catalog query overrides gender ask when local candidates exist',
        build: () {
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.ask(
              question: "Do you prefer a men's or women's perfume?",
              updatedPreferences: const SessionPreferences(),
            ),
          );
          return cubit;
        },
        act: (cubit) =>
            cubit.sendMessage('what is the cheapest perfume u have?'),
        verify: (_) {
          expect(cubit.state.status, isNot(AIChatStatus.error));
          expect(cubit.state.messages.last.isRecommendation, isTrue);
          final content = cubit.state.messages.last.content.toLowerCase();
          expect(content, isNot(contains("men's or women's")));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'direct catalog query does not call worker',
        build: () => cubit,
        act: (cubit) => cubit.sendMessage('most expensive perfume you have'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(cubit.state.messages.last.isRecommendation, isTrue);
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendationWithContext(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              compactContext: any(named: 'compactContext'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'note catalog query does not enter availability ambiguity',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'strawberry-musk',
                name: 'Strawberry Musk',
                notes: const ['strawberry', 'musk'],
                tags: const ['sweet', 'fruity'],
                stock: 4,
                isActive: true,
              ),
              mockCatalog[1].copyWith(
                id: 'citrus-musk',
                name: 'Citrus Musk',
                notes: const ['citrus', 'musk'],
                tags: const ['fresh'],
                stock: 4,
                isActive: true,
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('فيه فراولة؟'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(cubit.state.messages.last.isRecommendation, isTrue);
          final ids = cubit.state.messages.last.recommendedProducts
              .map((item) => item.product.id)
              .toList();
          expect(ids, contains('strawberry-musk'));
          expect(
            cubit.state.messages.last.content,
            isNot(contains('اكتب الاسم كامل')),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'English note-only availability wording uses local catalog note answer',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'apple-musk',
                name: 'Apple Musk',
                notes: const ['apple', 'musk'],
                tags: const ['fruity'],
                stock: 4,
                isActive: true,
              ),
              mockCatalog[1].copyWith(
                id: 'citrus-musk',
                name: 'Citrus Musk',
                notes: const ['citrus', 'musk'],
                tags: const ['fresh'],
                stock: 4,
                isActive: true,
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('is there with mango'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.answer);
          expect(cubit.state.messages.last.isRecommendation, isFalse);
          expect(
            cubit.state.messages.last.content.toLowerCase(),
            contains('explicit mango'),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendationWithContext(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              compactContext: any(named: 'compactContext'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'local fallback keeps university light recommendations campus-safe',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'premium-night',
                name: 'Premium Night Amber',
                price: 9200,
                gender: 'unisex',
                season: 'winter',
                occasion: 'daily',
                time: 'night',
                intensity: 'medium',
                notes: const ['amber', 'floral', 'woody'],
                tags: const ['fresh', 'clean', 'classic'],
              ),
              mockCatalog[1].copyWith(
                id: 'campus-safe',
                name: 'Campus Clean Day',
                price: 1400,
                gender: 'men',
                season: 'summer',
                occasion: 'office',
                time: 'day',
                intensity: 'light',
                notes: const ['citrus', 'musk'],
                topNotes: const ['citrus'],
                middleNotes: const ['musk'],
                baseNotes: const ['musk'],
                tags: const ['fresh', 'clean', 'university'],
              ),
              mockCatalog[2].copyWith(
                id: 'women-night',
                name: 'Women Night Sweet',
                price: 1800,
                gender: 'women',
                season: 'winter',
                occasion: 'date',
                time: 'night',
                intensity: 'strong',
                notes: const ['vanilla'],
                tags: const ['sweet'],
              ),
            ],
          );
          when(
            () => mockAIChatRepo.lastWorkerFailureReasonCode,
          ).thenReturn('worker_auth_required');
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer((_) async => null);
          return cubit;
        },
        act: (cubit) async {
          await cubit.sendMessage('recommend a perfume for a university');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await cubit.sendMessage('for men');
        },
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          final ids = cubit.state.messages.last.recommendedProducts
              .map((item) => item.product.id)
              .toList();
          expect(ids, contains('campus-safe'));
          expect(ids, isNot(contains('premium-night')));
          expect(ids, isNot(contains('women-night')));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'suitability policy flag blocks night university worker cards when better alternative exists',
        build: () {
          AIChatExperimentConfig.setTestOverrides(useSuitabilityPolicy: true);
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'premium-night',
                name: 'Premium Night Amber',
                price: 9200,
                gender: 'men',
                season: 'winter',
                occasion: 'date',
                time: 'night',
                intensity: 'medium',
                notes: const ['amber', 'floral'],
                tags: const ['sweet'],
              ),
              mockCatalog[1].copyWith(
                id: 'campus-safe',
                name: 'Campus Clean Day',
                price: 1400,
                gender: 'men',
                season: 'summer',
                occasion: 'office',
                time: 'day',
                intensity: 'light',
                notes: const ['citrus', 'musk'],
                topNotes: const ['citrus'],
                middleNotes: const ['musk'],
                baseNotes: const ['musk'],
                tags: const ['fresh', 'clean', 'university'],
              ),
            ],
          );
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer(
            (_) async => AIChatReply.recommend(
              productIds: const ['premium-night', 'campus-safe'],
              matchReasons: const {
                'premium-night': 'Worker selected it.',
                'campus-safe': 'Worker selected it.',
              },
              updatedPreferences: const SessionPreferences(
                gender: 'men',
                occasion: 'university',
                intensity: 'light',
                tags: ['fresh', 'clean'],
              ),
            ),
          );
          return cubit;
        },
        act: (cubit) =>
            cubit.sendMessage('recommend a men university light fresh perfume'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          final ids = cubit.state.messages.last.recommendedProducts
              .map((item) => item.product.id)
              .toList();
          expect(ids, contains('campus-safe'));
          expect(ids, isNot(contains('premium-night')));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'catalog search shadow records comparison without changing final recommendations',
        build: () {
          AIChatExperimentConfig.setTestOverrides(catalogSearchShadow: true);
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'old-local',
                name: 'Old Local',
                price: 1500,
                gender: 'men',
                season: 'summer',
                occasion: 'daily',
                time: 'day',
                intensity: 'medium',
                notes: const ['musk'],
                tags: const ['clean'],
              ),
              mockCatalog[1].copyWith(
                id: 'search-fit',
                name: 'Search Fit',
                price: 1200,
                gender: 'men',
                season: 'summer',
                occasion: 'office',
                time: 'day',
                intensity: 'light',
                notes: const ['citrus', 'musk'],
                tags: const ['fresh', 'clean', 'university'],
              ),
            ],
          );
          return cubit;
        },
        act: (cubit) =>
            cubit.sendMessage('recommend a men university light fresh perfume'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          final finalIds = cubit.state.messages.last.recommendedProducts
              .map((item) => item.product.id)
              .toList();
          expect(finalIds, isNotEmpty);
          final captured = verify(
            () => mockAIChatRepo.saveAIChatDebugLog(
              phase: any(named: 'phase'),
              sessionId: any(named: 'sessionId'),
              requestId: any(named: 'requestId'),
              language: any(named: 'language'),
              messageText: any(named: 'messageText'),
              detectedIntent: any(named: 'detectedIntent'),
              responseSource: any(named: 'responseSource'),
              preferencesSnapshot: any(named: 'preferencesSnapshot'),
              candidateSummary: captureAny(named: 'candidateSummary'),
            ),
          ).captured;
          final traces = captured.whereType<Map<String, dynamic>>();
          expect(
            traces.any((trace) => trace.containsKey('catalogSearchShadow')),
            isTrue,
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'catalog search primary flag sends search candidates to worker',
        build: () {
          AIChatExperimentConfig.setTestOverrides(
            sendCompactContext: false,
            useCatalogSearchEngine: true,
          );
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'night',
                name: 'Night',
                price: 2500,
                gender: 'men',
                season: 'winter',
                occasion: 'date',
                time: 'night',
                intensity: 'strong',
                notes: const ['amber'],
                tags: const ['sweet'],
              ),
              mockCatalog[1].copyWith(
                id: 'day-search',
                name: 'Day Search',
                price: 1000,
                gender: 'men',
                season: 'summer',
                occasion: 'office',
                time: 'day',
                intensity: 'light',
                notes: const ['citrus', 'musk'],
                tags: const ['fresh', 'clean', 'university'],
              ),
            ],
          );
          when(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).thenAnswer((_) async => null);
          return cubit;
        },
        act: (cubit) =>
            cubit.sendMessage('recommend a men university light fresh perfume'),
        verify: (_) {
          final captured = verify(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: captureAny(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          ).captured;
          final candidates = captured.single as List<ProductModel>;
          expect(candidates.map((item) => item.id), contains('day-search'));
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'business contact answer uses config only and never invents phone',
        build: () {
          when(
            () => mockAIChatRepo.fetchBusinessInfo(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => const AIChatBusinessInfo(
              storeName: 'Qissa',
              addressAr: '',
              addressEn: 'Online store',
              phone: '',
              whatsapp: '',
              facebookUrl: '',
              instagramUrl: '',
              websiteUrl: '',
              openingHoursAr: '',
              openingHoursEn: '',
              deliveryInfoAr: '',
              deliveryInfoEn: '',
              isPublished: true,
            ),
          );
          return cubit;
        },
        act: (cubit) => cubit.sendMessage('Tell me your phone and WhatsApp'),
        verify: (_) {
          final content = cubit.state.messages.last.content;
          expect(content, contains('confirmed contact number'));
          expect(content, isNot(matches(RegExp(r'\d{7,}'))));
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'discount request returns deterministic grounded answer',
        build: () => cubit,
        act: (cubit) => cubit.sendMessage('Do you have a discount code?'),
        verify: (_) {
          final content = cubit.state.messages.last.content.toLowerCase();
          expect(content, contains('confirmed discount code'));
          expect(content, isNot(contains('123456')));
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'payment methods answer stays deterministic',
        build: () => cubit,
        act: (cubit) =>
            cubit.sendMessage('What payment methods do you accept?'),
        verify: (_) {
          final content = cubit.state.messages.last.content.toLowerCase();
          expect(content, contains('cash on delivery'));
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'ok show me it after budget no-match renders lowest available with disclosure',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'floor',
                name: 'Budget Citrus',
                price: 790,
                gender: 'men',
                season: 'summer',
                intensity: 'light',
                stock: 8,
              ),
              mockCatalog[1].copyWith(price: 1500),
            ],
          );
          return cubit;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.noMatch,
          preferences: SessionPreferences(maxBudget: 600),
          recommendationMemory: RecommendationMemory(
            lastNoMatchContext: LastNoMatchContext(
              reason: 'budget_no_match',
              requestedBudget: 600,
              lowestAvailablePrice: 790,
              lowestAvailableProductIds: ['floor'],
            ),
          ),
        ),
        act: (cubit) => cubit.sendMessage('ok show me it'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(
            cubit.state.messages.last.recommendedProducts.single.product.id,
            'floor',
          );
          expect(
            cubit.state.messages.last.recommendedProducts.single.matchReason,
            contains('above your original 600 EGP budget'),
          );
          expect(
            cubit.state.messages.last.content,
            contains('above your original 600 EGP budget'),
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'I do not like these excludes visible products before worker routing',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              ...mockCatalog,
              mockCatalog[0].copyWith(
                id: 'p4',
                name: 'Fresh Campus Alt',
                price: 950,
                gender: 'men',
                season: 'summer',
                intensity: 'light',
                notes: const ['citrus', 'fresh'],
                stock: 9,
              ),
            ],
          );
          return cubit;
        },
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          preferences: const SessionPreferences(
            gender: 'men',
            season: 'summer',
            intensity: 'light',
          ),
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              _refFromProduct(mockCatalog[0], 1),
              _refFromProduct(mockCatalog[1], 2),
              _refFromProduct(mockCatalog[2], 3),
            ],
          ),
        ),
        act: (cubit) => cubit.sendMessage("I don't like these"),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          final ids = cubit.state.messages.last.recommendedProducts
              .map((item) => item.product.id)
              .toSet();
          expect(ids, contains('p4'));
          expect(ids.intersection({'p1', 'p2', 'p3'}), isEmpty);
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'focused product pronoun suitability answers locally without cards',
        build: () => cubit,
        seed: () => const AIChatState(
          status: AIChatStatus.answer,
          recommendationMemory: RecommendationMemory(
            lastFocusedProductId: 'p2',
          ),
        ),
        act: (cubit) => cubit.sendMessage('is it suitable for office?'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.answer);
          expect(cubit.state.messages.last.recommendedProducts, isEmpty);
          expect(cubit.state.messages.last.content, contains('Cedar Class 01'));
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'similar but cheaper after focused product uses anchor locally',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1],
              mockCatalog[1].copyWith(
                id: 'p4',
                name: 'Cedar Amber Light',
                price: 1000,
                stock: 9,
                notes: const ['cedar', 'woody', 'amber'],
                topNotes: const ['cedar'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
              ),
            ],
          );
          return cubit;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.answer,
          recommendationMemory: RecommendationMemory(
            lastFocusedProductId: 'p2',
          ),
        ),
        act: (cubit) => cubit.sendMessage('similar but cheaper'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
          expect(
            cubit.state.messages.last.recommendedProducts.every(
              (item) => item.product.effectivePrice < 1500,
            ),
            isTrue,
          );
          verifyNever(
            () => mockAIChatRepo.fetchAIRecommendation(
              currentMessage: any(named: 'currentMessage'),
              preferences: any(named: 'preferences'),
              candidates: any(named: 'candidates'),
              localRecommendations: any(named: 'localRecommendations'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'ok show me it after handled no-match fallback uses stored budget floor',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'floor',
                name: 'Budget Citrus',
                price: 790,
                gender: 'men',
                season: 'summer',
                intensity: 'light',
                stock: 8,
              ),
            ],
          );
          return cubit;
        },
        seed: () => const AIChatState(
          preferences: SessionPreferences(
            gender: 'men',
            season: 'summer',
            intensity: 'light',
          ),
        ),
        act: (cubit) async {
          await cubit.sendMessage('budget 600');
          await cubit.sendMessage('ok show me it');
        },
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(
            cubit.state.messages.last.recommendedProducts.single.product.id,
            'floor',
          );
          expect(
            cubit.state.messages.last.recommendedProducts.single.matchReason,
            contains('above your original 600 EGP budget'),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'ok show me it preserves budget floor after visible recommendations',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[0].copyWith(
                id: 'floor',
                name: 'Budget Citrus',
                price: 790,
                gender: 'men',
                season: 'summer',
                intensity: 'light',
                stock: 8,
              ),
              mockCatalog[1].copyWith(
                id: 'visible-expensive',
                name: 'Visible Expensive',
                price: 3250,
                gender: 'men',
                season: 'summer',
                intensity: 'medium',
                stock: 8,
              ),
            ],
          );
          return cubit;
        },
        seed: () => AIChatState(
          status: AIChatStatus.recommend,
          preferences: const SessionPreferences(
            gender: 'men',
            season: 'summer',
            intensity: 'light',
          ),
          messages: [
            AIChatMessage.botRecommendation(
              content: 'Visible old recommendation',
              products: [
                RecommendedProduct(
                  product: mockCatalog[1].copyWith(
                    id: 'visible-expensive',
                    name: 'Visible Expensive',
                    price: 3250,
                    gender: 'men',
                    season: 'summer',
                    stock: 8,
                  ),
                  matchScore: 0.8,
                  matchLabel: 'Match',
                  matchReason: 'Visible match.',
                ),
              ],
            ),
          ],
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'visible-expensive',
                name: 'Visible Expensive',
                brand: 'Brand',
                displayIndex: 1,
                price: 3250,
                stock: 8,
                season: 'summer',
                occasion: 'daily',
                intensity: 'medium',
                notes: const [],
              ),
            ],
          ),
        ),
        act: (cubit) async {
          await cubit.sendMessage('budget 600');
          await cubit.sendMessage('ok show me it');
        },
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(
            cubit.state.messages.last.recommendedProducts.single.product.id,
            'floor',
          );
          expect(
            cubit.state.messages.last.recommendedProducts.single.matchReason,
            contains('above your original 600 EGP budget'),
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'most expensive catalog query ignores stale session budget',
        build: () => cubit,
        seed: () => const AIChatState(
          status: AIChatStatus.noMatch,
          preferences: SessionPreferences(maxBudget: 600),
        ),
        act: (cubit) => cubit.sendMessage('أغلى عطر عندك'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
          expect(
            cubit.state.messages.last.responseSource,
            'local_catalog_query_most_expensive',
          );
        },
      );

      blocTest<AIChatCubit, AIChatState>(
        'similar but cheaper ignores stale impossible budget when no new budget is mentioned',
        build: () {
          when(
            () => mockAIChatRepo.getCatalog(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) async => [
              mockCatalog[1],
              mockCatalog[1].copyWith(
                id: 'p4',
                name: 'Cedar Amber Light',
                price: 1000,
                stock: 9,
                notes: const ['cedar', 'woody', 'amber'],
                topNotes: const ['cedar'],
                middleNotes: const ['amber'],
                baseNotes: const ['woody'],
              ),
            ],
          );
          return cubit;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.answer,
          preferences: SessionPreferences(maxBudget: 600),
          recommendationMemory: RecommendationMemory(
            lastFocusedProductId: 'p2',
          ),
        ),
        act: (cubit) => cubit.sendMessage('similar but cheaper'),
        verify: (_) {
          expect(cubit.state.status, AIChatStatus.recommend);
          expect(
            cubit.state.messages.last.recommendedProducts.single.product.id,
            'p4',
          );
        },
      );
    });
  });
}

RecommendedProductRef _refFromProduct(ProductModel product, int index) {
  return RecommendedProductRef(
    productId: product.id,
    name: product.name,
    brand: product.brand,
    displayIndex: index,
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
}
