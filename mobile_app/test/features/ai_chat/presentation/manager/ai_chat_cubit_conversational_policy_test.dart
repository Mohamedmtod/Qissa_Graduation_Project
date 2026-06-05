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
    'social micro-turn is handled locally when tool router context is enabled',
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
      verifyNever(
        () => mockAIChatRepo.fetchAIRecommendationWithContext(
          currentMessage: 'how are you',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          localRecommendations: any(named: 'localRecommendations'),
          compactContext: any(named: 'compactContext'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
      expect(cubit.state.status, AIChatStatus.answer);
      expect(
        cubit.state.messages.last.responseSource,
        'local_social_micro_turn',
      );
      expect(cubit.state.messages.last.content, contains('ready to help'));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'social micro-turn is handled locally when compact context is disabled',
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
      verifyNever(
        () => mockAIChatRepo.fetchAIRecommendation(
          currentMessage: 'how are you',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
      expect(cubit.state.status, AIChatStatus.answer);
      expect(
        cubit.state.messages.last.responseSource,
        'local_social_micro_turn',
      );
      expect(cubit.state.messages.last.content, contains('doing well'));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'arabic social micro-turn is handled locally without worker or gender ask',
    build: () {
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: true,
        toolRouterV1: true,
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage('كيف حالك'),
    verify: (_) {
      verifyNever(
        () => mockAIChatRepo.fetchAIRecommendationWithContext(
          currentMessage: 'كيف حالك',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          localRecommendations: any(named: 'localRecommendations'),
          compactContext: any(named: 'compactContext'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
      verifyNever(
        () => mockAIChatRepo.fetchAIRecommendation(
          currentMessage: 'كيف حالك',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
      expect(cubit.state.status, AIChatStatus.answer);
      final last = cubit.state.messages.last;
      expect(last.responseSource, 'local_social_micro_turn');
      expect(last.content, contains('أنا بخير'));
      expect(last.content, isNot(contains('رجالي ولا نسائي')));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'arabic social follow-up does not repeat the welcome fallback',
    build: () {
      AIChatExperimentConfig.setTestOverrides(toolRouterV1: false);
      return cubit;
    },
    act: (cubit) async {
      await cubit.sendMessage('اهلا');
      await cubit.sendMessage('ازيك عامل اي');
    },
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.answer);
      final last = cubit.state.messages.last;
      expect(last.responseSource, 'local_social_micro_turn');
      expect(last.content, contains('أنا بخير'));
      expect(last.content, isNot(contains('تفضيلاتك مثل النوع')));
      expect(last.content, isNot(contains('رجالي ولا نسائي')));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'repeated arabic greeting is handled locally without worker latency',
    build: () {
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: true,
        toolRouterV1: true,
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage(
      '\u0627\u0647\u0644\u0627 \u0627\u0647\u0644\u0627 \u0627\u0647\u0644\u0627',
    ),
    verify: (_) {
      verifyNever(
        () => mockAIChatRepo.fetchAIRecommendationWithContext(
          currentMessage:
              '\u0627\u0647\u0644\u0627 \u0627\u0647\u0644\u0627 \u0627\u0647\u0644\u0627',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          localRecommendations: any(named: 'localRecommendations'),
          compactContext: any(named: 'compactContext'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
      verifyNever(
        () => mockAIChatRepo.fetchAIRecommendation(
          currentMessage:
              '\u0627\u0647\u0644\u0627 \u0627\u0647\u0644\u0627 \u0627\u0647\u0644\u0627',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
      expect(cubit.state.status, AIChatStatus.answer);
      final last = cubit.state.messages.last;
      expect(last.responseSource, 'local_social_micro_turn');
      expect(
        last.content,
        contains('\u0623\u0646\u0627 \u0628\u062e\u064a\u0631'),
      );
      expect(
        last.content,
        isNot(
          contains(
            '\u0631\u062c\u0627\u0644\u064a \u0648\u0644\u0627 \u0646\u0633\u0627\u0626\u064a',
          ),
        ),
      );
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'short hey greeting is handled locally without worker latency',
    build: () {
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: true,
        toolRouterV1: true,
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage('hey'),
    verify: (_) {
      verifyNever(
        () => mockAIChatRepo.fetchAIRecommendationWithContext(
          currentMessage: 'hey',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          localRecommendations: any(named: 'localRecommendations'),
          compactContext: any(named: 'compactContext'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
      verifyNever(
        () => mockAIChatRepo.fetchAIRecommendation(
          currentMessage: 'hey',
          preferences: any(named: 'preferences'),
          candidates: any(named: 'candidates'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      );
      expect(cubit.state.status, AIChatStatus.answer);
      final last = cubit.state.messages.last;
      expect(last.responseSource, 'local_social_micro_turn');
      expect(last.content.toLowerCase(), contains('doing well'));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'short acknowledgement after social turn is not retargeted to gender',
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
      expect(cubit.state.status, AIChatStatus.answer);
      final last = cubit.state.messages.last;
      expect(
        last.content.toLowerCase(),
        isNot(contains('could not understand')),
      );
      expect(last.content.toLowerCase(), isNot(contains('men')));
      expect(last.content.toLowerCase(), isNot(contains('women')));
      expect(last.content, isNot(contains('رجالي ولا نسائي')));
      expect(last.responseSource, 'local_dialogue_no_perfume_intent');
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
    'generic worker ask after explicit perfume request may retarget',
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
          question: 'Tell me the style, notes, occasion, or budget you want.',
          updatedPreferences: const SessionPreferences(),
        ),
      );
      return cubit;
    },
    act: (cubit) => cubit.sendMessage('recommend me a perfume'),
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.ask);
      final last = cubit.state.messages.last;
      expect(
        last.responseSource,
        anyOf('ask_retarget', contains('targeted_ask')),
      );
      expect(last.responseSource, isNot('local_dialogue_no_perfume_intent'));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'short why after social turn is not retargeted to gender',
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
          question: "Do you prefer a men's or women's perfume?",
          updatedPreferences: const SessionPreferences(),
        ),
      );
      return cubit;
    },
    act: (cubit) async {
      await cubit.sendMessage('how are you');
      await cubit.sendMessage('why');
    },
    verify: (_) {
      expect(cubit.state.status, AIChatStatus.answer);
      final last = cubit.state.messages.last;
      expect(last.responseSource, 'local_dialogue_no_perfume_intent');
      expect(last.content.toLowerCase(), isNot(contains('men')));
      expect(last.content.toLowerCase(), isNot(contains('women')));
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'debug status reports remote sync only after a turn is stored',
    build: () {
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: false,
        toolRouterV1: true,
        analyticsEventsEnabled: true,
        turnDebugRemoteEnabled: true,
        debugCaptureMode: 'all',
      );
      when(
        () => mockAIChatRepo.sendAIChatTurnDebug(
          payload: any(named: 'payload'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((_) async => true);
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
          answer: 'Hello. Tell me what perfume style you want.',
          updatedPreferences: const SessionPreferences(),
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
          answer: 'Hello. Tell me what perfume style you want.',
          updatedPreferences: const SessionPreferences(),
        ),
      );
      return AIChatCubit(
        aiChatRepo: mockAIChatRepo,
        thinkingDelay: Duration.zero,
        cooldownDuration: Duration.zero,
      );
    },
    act: (cubit) async {
      expect(cubit.chatDebugStatus['remoteDebugSynced'], isFalse);
      await cubit.sendMessage('hello');
    },
    wait: const Duration(milliseconds: 1200),
    verify: (cubit) {
      expect(cubit.chatDebugStatus['lastTurnDebugSendStatus'], 'success');
      expect(cubit.chatDebugStatus['remoteDebugSynced'], isTrue);
      expect(cubit.chatDebugStatus['remoteDebugTurnSuccessCount'], 1);
      verify(
        () => mockAIChatRepo.sendAIChatTurnDebug(
          payload: any(named: 'payload'),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'debug status exposes turn debug send failure reason',
    build: () {
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: false,
        toolRouterV1: true,
        analyticsEventsEnabled: true,
        turnDebugRemoteEnabled: true,
        debugCaptureMode: 'all',
      );
      when(
        () => mockAIChatRepo.sendAIChatTurnDebug(
          payload: any(named: 'payload'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((_) async => false);
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
          answer: 'Hello. Tell me what perfume style you want.',
          updatedPreferences: const SessionPreferences(),
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
          answer: 'Hello. Tell me what perfume style you want.',
          updatedPreferences: const SessionPreferences(),
        ),
      );
      return AIChatCubit(
        aiChatRepo: mockAIChatRepo,
        thinkingDelay: Duration.zero,
        cooldownDuration: Duration.zero,
      );
    },
    act: (cubit) async => cubit.sendMessage('hello'),
    wait: const Duration(milliseconds: 1200),
    verify: (cubit) {
      expect(cubit.chatDebugStatus['lastTurnDebugSendStatus'], 'failed');
      expect(
        cubit.chatDebugStatus['lastTurnDebugSendError'],
        'turn_debug_send_returned_false',
      );
      expect(cubit.chatDebugStatus['remoteDebugSynced'], isFalse);
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
