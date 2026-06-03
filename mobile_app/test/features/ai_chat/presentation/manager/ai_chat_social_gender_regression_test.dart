import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';

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
    registerFallbackValue(EventType.view);
  });

  setUp(() {
    AIChatExperimentConfig.setTestOverrides(
      sendCompactContext: false,
      toolRouterV1: true,
    );
    mockAIChatRepo = MockAIChatRepo();
    mockUserTasteRepo = MockUserTasteRepo();
    when(
      () => mockAIChatRepo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => mockCatalog);
    when(
      () => mockAIChatRepo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        metadata: any(named: 'metadata'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
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
    );
  });

  tearDown(() {
    AIChatExperimentConfig.resetTestOverrides();
    cubit.close();
  });

  group('Social Gender Inference - Cubit Regression', () {
    blocTest<AIChatCubit, AIChatState>(
      '1. inferred gender reaches the worker inside preferences',
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
            question: 'Any specific notes?',
            updatedPreferences: const SessionPreferences(gender: 'women'),
          ),
        );
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('عايز عطر لخطيبتي'),
      verify: (_) {
        verify(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: 'عايز عطر لخطيبتي',
            preferences: any(
              named: 'preferences',
              that: isA<SessionPreferences>().having(
                (p) => p.gender,
                'gender',
                'women',
              ),
            ),
            candidates: any(named: 'candidates'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).called(1);
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      '2. greeting-only delegates social reply to worker',
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
            answer: 'I am ready to help with perfumes.',
            updatedPreferences: const SessionPreferences(),
          ),
        );
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('اهلا'),
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
        expect(cubit.state.status, AIChatStatus.answer);
        expect(cubit.state.messages.last.content, contains('ready to help'));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      '2a. greeting-only ignores worker gender ask and uses social fallback',
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
            question: "Do you prefer a men's or women's perfume?",
            updatedPreferences: const SessionPreferences(),
          ),
        );
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('how are you'),
      verify: (_) {
        expect(cubit.state.status, AIChatStatus.answer);
        expect(
          cubit.state.messages.last.content.toLowerCase(),
          isNot(contains('men')),
        );
        expect(
          cubit.state.messages.last.content.toLowerCase(),
          isNot(contains('women')),
        );
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      '2a-hello. exact hello ignores worker no-match-like recommendation',
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
            answer:
                'I could not find a safe in-stock catalog match for the current constraints.',
            updatedPreferences: const SessionPreferences(),
          ),
        );
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('hello'),
      verify: (_) {
        expect(cubit.state.status, AIChatStatus.answer);
        final content = cubit.state.messages.last.content.toLowerCase();
        expect(content, contains('perfume'));
        expect(content, isNot(contains('safe in-stock')));
        expect(content, isNot(contains('catalog match')));
        expect(content, isNot(contains('constraints')));
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      '2b. ambiguous Egyptian sweet asks sweet-vs-beautiful before gender retarget when gate is on',
      build: () => cubit,
      act: (cubit) async {
        AIChatExperimentConfig.setTestOverrides(
          sendCompactContext: false,
          toolRouterV1: true,
          deterministicGateV1: true,
        );
        await cubit.sendMessage(
          '\u0631\u0634\u062d\u0644\u064a \u0631\u064a\u062d\u0629 \u062d\u0644\u0648\u0629',
        );
      },
      verify: (cubit) {
        expect(cubit.state.status, AIChatStatus.ask);
        final bot = cubit.state.messages.last;
        expect(bot.content, contains('\u0645\u0633\u0643\u0631\u0629'));
        expect(bot.content, contains('\u062c\u0645\u064a\u0644\u0629'));
        expect(bot.content, isNot(contains('\u0631\u062c\u0627\u0644\u064a')));
        expect(bot.content, isNot(contains('\u0646\u0633\u0627\u0626\u064a')));
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
      '3. mixed greeting + relationship does NOT enter local greeting path (calls worker)',
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
            question: 'Any specific notes?',
            updatedPreferences: const SessionPreferences(gender: 'women'),
          ),
        );
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('اهلا عايز عطر لخطيبتي'),
      verify: (_) {
        verify(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: 'اهلا عايز عطر لخطيبتي',
            preferences: any(
              named: 'preferences',
              that: isA<SessionPreferences>().having(
                (p) => p.gender,
                'gender',
                'women',
              ),
            ),
            candidates: any(named: 'candidates'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).called(1);
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      '4a. follow-up is unaffected by new relationship inference logic',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              displayIndex: 1,
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
        when(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.answer(
            answer: 'It lasts 8 hours.',
            updatedPreferences: cubit.state.preferences,
          ),
        );
        return cubit.sendMessage('tell me more about it');
      },
      verify: (cubit) {
        expect(cubit.state.status, AIChatStatus.answer);
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
      '4b. comparison is unaffected by new relationship inference logic',
      build: () => cubit,
      seed: () => AIChatState(
        status: AIChatStatus.recommend,
        recommendationMemory: RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'p1',
              name: 'P1',
              brand: 'B',
              displayIndex: 1,
              price: 1,
              stock: 1,
              season: 's',
              occasion: 'o',
              intensity: 'i',
              notes: [],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 1,
              matchReason: 'r',
            ),
            RecommendedProductRef(
              productId: 'p2',
              name: 'P2',
              brand: 'B',
              displayIndex: 2,
              price: 1,
              stock: 1,
              season: 's',
              occasion: 'o',
              intensity: 'i',
              notes: [],
              topNotes: [],
              middleNotes: [],
              baseNotes: [],
              tags: [],
              matchScore: 1,
              matchReason: 'r',
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
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatReply.answer(
            answer: 'Comparison results.',
            updatedPreferences: cubit.state.preferences,
          ),
        );
        return cubit.sendMessage('قارن بين 1 و 2');
      },
      verify: (cubit) {
        expect(cubit.state.status, AIChatStatus.answer);
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      '5. availability queries are unaffected (not sent to recommendation worker)',
      build: () => cubit,
      act: (cubit) => cubit.sendMessage('Dior موجوده؟'),
      verify: (_) {
        verifyNever(
          () => mockAIChatRepo.fetchAIRecommendation(
            currentMessage: any(named: 'currentMessage'),
            preferences: any(named: 'preferences'),
            candidates: any(named: 'candidates'),
            responseLanguage: any(named: 'responseLanguage'),
            requestId: any(named: 'requestId'),
          ),
        );
      },
    );
  });
}
