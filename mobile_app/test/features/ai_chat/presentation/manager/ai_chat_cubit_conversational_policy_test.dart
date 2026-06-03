import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_interpretation_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'mock_catalog.dart';

class MockAIChatRepo2 extends Mock implements AIChatRepo {}

void main() {
  late MockAIChatRepo2 mockAIChatRepo;
  late AIChatCubit cubit;

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
    mockAIChatRepo = MockAIChatRepo2();
    when(
      () => mockAIChatRepo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => mockCatalog);
    when(
      () => mockAIChatRepo.lookupPerfumeKnowledge(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockAIChatRepo.lookupExternalPerfumeKnowledge(
        query: any(named: 'query'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
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
      () => mockAIChatRepo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        metadata: any(named: 'metadata'),
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

    cubit = AIChatCubit(
      aiChatRepo: mockAIChatRepo,
      thinkingDelay: Duration.zero,
      cooldownDuration: Duration.zero,
    );
  });

  tearDown(() {
    AIChatExperimentConfig.resetTestOverrides();
    cubit.close();
  });

  blocTest<AIChatCubit, AIChatState>(
    'social greeting delegates to worker when tool router context is enabled',
    build: () {
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: true,
        toolRouterV1: true,
      );
      when(
        () => mockAIChatRepo.fetchAIInterpretation(
          currentMessage: any(named: 'currentMessage'),
          currentPreferences: any(named: 'currentPreferences'),
          responseLanguage: any(named: 'responseLanguage'),
          hasRecommendationContext: any(named: 'hasRecommendationContext'),
          hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer(
        (_) async => const AIChatInterpretationResult(
          intent: 'greeting',
          confidence: 0.95,
          preferencePatch: SessionPreferences(),
          askSlot: null,
          productQueryCandidate: null,
          reasonCode: 'greeting',
        ),
      );
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
      ).thenAnswer(
        (_) async => AIChatReply.answer(
          answer: 'I am ready to help. Tell me what perfume mood you want.',
          updatedPreferences: const SessionPreferences(),
        ),
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage('how are you'),
    verify: (_) {
      verify(
        () => mockAIChatRepo.fetchAIRecommendationWithContext(
          currentMessage: 'how are you',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          localRecommendations: any(named: 'localRecommendations'),
          compactContext: any(named: 'compactContext'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
      expect(cubit.state.status, AIChatStatus.answer);
      expect(
        cubit.state.messages.last.responseSource,
        anyOf('ai_worker', 'social_micro_turn_worker'),
      );
      expect(cubit.state.messages.last.content, contains('ready to help'));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'social greeting delegates to worker even when compact context is disabled',
    build: () {
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: false,
        toolRouterV1: true,
      );
      when(
        () => mockAIChatRepo.fetchAIInterpretation(
          currentMessage: any(named: 'currentMessage'),
          currentPreferences: any(named: 'currentPreferences'),
          responseLanguage: any(named: 'responseLanguage'),
          hasRecommendationContext: any(named: 'hasRecommendationContext'),
          hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer(
        (_) async => const AIChatInterpretationResult(
          intent: 'greeting',
          confidence: 0.95,
          preferencePatch: SessionPreferences(),
          askSlot: null,
          productQueryCandidate: null,
          reasonCode: 'greeting',
        ),
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
        (_) async => AIChatReply.answer(
          answer: 'Doing well. Tell me what perfume style you want.',
          updatedPreferences: const SessionPreferences(),
        ),
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage('how are you'),
    verify: (_) {
      verify(
        () => mockAIChatRepo.fetchAIRecommendation(
          currentMessage: 'how are you',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
      expect(cubit.state.status, AIChatStatus.answer);
      expect(
        cubit.state.messages.last.responseSource,
        anyOf('ai_worker', 'social_micro_turn_worker'),
      );
      expect(cubit.state.messages.last.content, contains('Doing well'));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'short acknowledgement after social turn is not intercepted as gibberish',
    build: () {
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: false,
        toolRouterV1: true,
        llmLedRouterV2: true,
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
        (_) async => AIChatReply.ask(
          question:
              'Sure. Tell me the style, notes, occasion, or budget you want.',
          updatedPreferences: const SessionPreferences(),
        ),
      );
      return cubit;
    },
    act: (cubit) async {
      await cubit.sendMessage('hello');
      await cubit.sendMessage('yes');
    },
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.ask);
      final last = cubit.state.messages.last;
      expect(
        last.content.toLowerCase(),
        isNot(contains('could not understand')),
      );
      expect(last.responseSource, isNot('local_interceptor'));
      verify(
        () => mockAIChatRepo.fetchAIRecommendation(
          currentMessage: 'yes',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'fantasy request is intercepted locally without calling worker',
    build: () => cubit,
    act: (cubit) => cubit.sendMessage('عندكم عطر بريحة الشاورما والتوم؟'),
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
      expect(cubit.state.status, AIChatStatus.ask);
      expect(cubit.state.messages.last.content, contains('غير موجود'));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'contradictory request is intercepted locally without generic gender ask',
    build: () => cubit,
    act: (cubit) => cubit.sendMessage(
      'عايز عطر خفيف جدًا ومابيتشمش بس يكون قوي جدًا وبيملى المكان.',
    ),
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.ask);
      expect(cubit.state.messages.last.content, contains('تعارض'));
      expect(
        cubit.state.messages.last.content,
        isNot(contains('رجالي أم نسائي')),
      );
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'gibberish request is intercepted locally',
    build: () => cubit,
    act: (cubit) => cubit.sendMessage('asdfghjkl'),
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.ask);
      expect(
        cubit.state.messages.last.content.toLowerCase(),
        contains('understand'),
      );
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'persona-only statement updates preferences and does not call worker',
    build: () => cubit,
    act: (cubit) => cubit.sendMessage('I am a 28-year-old man.'),
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.ask);
      expect(cubit.state.preferences.gender, 'men');
      expect(cubit.state.preferences.maxBudget, isNull);
      expect(
        cubit.state.messages.last.content.toLowerCase(),
        contains('summer'),
      );
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

  blocTest<AIChatCubit, AIChatState>(
    'english invisible room-filling contradiction is not routed to gender ask',
    build: () => cubit,
    act: (cubit) => cubit.sendMessage(
      'extremely light invisible perfume that fills the whole room and lasts forever',
    ),
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
      expect(cubit.state.status, AIChatStatus.ask);
      final content = cubit.state.messages.last.content.toLowerCase();
      expect(
        content,
        anyOf(contains('contradiction'), contains('which matters more')),
      );
      expect(content, isNot(contains("men's or women's")));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'petrichor rain scent request is not routed as availability ambiguity',
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
          question:
              'Petrichor is very specific; I can look for the closest realistic fresh earthy direction.',
          updatedPreferences: const SessionPreferences(tags: ['fresh']),
        ),
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage(
      'Do you have something like petrichor, rain on soil, if possible?',
    ),
    verify: (_) {
      verify(
        () => mockAIChatRepo.fetchAIRecommendation(
          currentMessage: any(named: 'currentMessage'),
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
      final content = cubit.state.messages.last.content.toLowerCase();
      expect(content, isNot(contains('do you mean moonlit petals')));
      expect(content, isNot(contains('more than one perfume with that name')));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'office lifestyle can override generic worker ask into recommendation',
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
          question: 'هل تبحث عن عطر رجالي أم نسائي؟',
          updatedPreferences: const SessionPreferences(
            occasion: 'office',
            time: 'all_day',
            intensity: 'light',
            tags: ['clean', 'elegant'],
          ),
        ),
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage('عطر للـ Office استخدمه كل يوم.'),
    verify: (_) {
      verify(
        () => mockAIChatRepo.fetchAIRecommendation(
          currentMessage: any(named: 'currentMessage'),
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
      expect(
        cubit.state.status,
        AIChatStatus.recommend,
        reason:
            '${cubit.state.preferences} | ${cubit.state.messages.last.content}',
      );
      expect(cubit.state.messages.last.isRecommendation, isTrue);
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'Valentine romantic request returns recommendation cards',
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
          productIds: const ['p3'],
          matchReasons: const {'p3': 'Romantic sweet date profile.'},
          updatedPreferences: const SessionPreferences(
            maxBudget: 1400,
            occasion: 'date',
            tags: ['sweet', 'warm', 'romantic'],
          ),
        ),
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage(
      "Recommend a romantic perfume for Valentine's Day under 1400 EGP.",
    ),
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(cubit.state.messages.last.isRecommendation, isTrue);
      final content = cubit.state.messages.last.content.toLowerCase();
      expect(content, isNot(contains('{')));
      expect(content, isNot(contains('%')));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'five-turn persona accumulation ends in recommendation, not availability',
    build: () {
      final personaCatalog = [
        mockCatalog[1].copyWith(
          occasion: 'office',
          time: 'all_day',
          intensity: 'light',
          notes: const ['cedar', 'woody', 'smoky', 'amber'],
          baseNotes: const ['woody', 'smoky'],
          tags: const ['smoky', 'classic', 'elegant', 'warm'],
        ),
        mockCatalog[0],
        mockCatalog[2],
      ];
      when(
        () =>
            mockAIChatRepo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => personaCatalog);
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
          productIds: const ['p2'],
          matchReasons: const {
            'p2': 'Woody formal profile within your 1500 EGP budget.',
          },
          updatedPreferences: const SessionPreferences(
            gender: 'men',
            occasion: 'office',
            maxBudget: 1500,
            preferredNotes: ['woody'],
            tags: ['smoky', 'elegant', 'classic'],
          ),
        ),
      );
      return cubit;
    },
    act: (cubit) async {
      await cubit.sendMessage('I am a 28-year-old man.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('I work in finance.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('I prefer woody and smoky scents.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('My budget is 1500 EGP.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('Recommend the best match for me.');
    },
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(cubit.state.messages.last.isRecommendation, isTrue);
      expect(
        cubit.state.messages.last.content.toLowerCase(),
        isNot(contains('men\'s or women\'s')),
      );
      expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
      expect(
        cubit.state.messages.last.recommendedProducts.first.product.id,
        'p2',
      );
      verifyNever(() => mockAIChatRepo.lookupPerfumeKnowledge(any()));
      verifyNever(
        () => mockAIChatRepo.lookupExternalPerfumeKnowledge(
          query: any(named: 'query'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'memory continuation preserves prior preferences when worker asks filled gender',
    build: () {
      final personaCatalog = [
        mockCatalog[1].copyWith(
          id: 'office_cedar',
          price: 1375,
          occasion: 'office',
          time: 'all_day',
          intensity: 'light',
          notes: const ['cedar', 'woody', 'smoky'],
          baseNotes: const ['cedar', 'woody', 'smoky'],
          tags: const ['smoky', 'clean', 'elegant'],
        ),
        mockCatalog[2],
      ];
      when(
        () =>
            mockAIChatRepo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => personaCatalog);
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
    act: (cubit) async {
      await cubit.sendMessage('I am a 30-year-old man.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('I prefer cedar and smoky perfumes.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('Use it at work.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('Under 1600 EGP.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('Recommend one.');
    },
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(cubit.state.messages.last.isRecommendation, isTrue);
      expect(cubit.state.preferences.gender, 'men');
      expect(cubit.state.preferences.maxBudget, 1600);
      expect(
        cubit.state.messages.last.content.toLowerCase(),
        isNot(contains("men's or women's")),
      );
      expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'give me the best match is handled as local continuation',
    build: () {
      final professionalCatalog = [
        mockCatalog[1].copyWith(
          id: 'professional_amber',
          price: 1180,
          occasion: 'office',
          time: 'all_day',
          intensity: 'medium',
          notes: const ['woody', 'amber'],
          baseNotes: const ['woody', 'amber'],
          tags: const ['elegant', 'classic'],
        ),
        mockCatalog[2],
      ];
      when(
        () =>
            mockAIChatRepo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => professionalCatalog);
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
    act: (cubit) async {
      await cubit.sendMessage('I need something professional.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('For a man.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('I like woody and amber.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('Budget 1800 EGP.');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      await cubit.sendMessage('Give me the best match.');
    },
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(cubit.state.messages.last.isRecommendation, isTrue);
      expect(cubit.state.preferences.gender, 'men');
      expect(cubit.state.preferences.maxBudget, isNotNull);
      expect(
        cubit.state.messages.last.content.toLowerCase(),
        isNot(contains("men's or women's")),
      );
      expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
    },
  );
}
