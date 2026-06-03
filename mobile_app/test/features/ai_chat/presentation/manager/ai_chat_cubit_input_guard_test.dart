import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';

import 'mock_catalog.dart';

class MockAIChatRepoGuard extends Mock implements AIChatRepo {}

void main() {
  late MockAIChatRepoGuard mockAIChatRepo;
  late AIChatCubit cubit;

  setUpAll(() {
    registerFallbackValue(const SessionPreferences());
    registerFallbackValue(AIChatLanguage.english);
  });

  setUp(() {
    mockAIChatRepo = MockAIChatRepoGuard();
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

    cubit = AIChatCubit(
      aiChatRepo: mockAIChatRepo,
      thinkingDelay: Duration.zero,
    );
  });

  tearDown(() {
    cubit.close();
  });

  blocTest<AIChatCubit, AIChatState>(
    'ignores whitespace-only messages',
    build: () => cubit,
    act: (cubit) => cubit.sendMessage('     '),
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
      expect(cubit.state.messages.length, 1);
    },
  );

  blocTest<AIChatCubit, AIChatState>(
    'blocks overlong messages before worker call',
    build: () => cubit,
    act: (cubit) =>
        cubit.sendMessage(List.filled(AIChatCubit.maxUserMessageLength + 1, 'a').join()),
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
      expect(cubit.state.status, isNot(AIChatStatus.loading));
      expect(cubit.state.errorMessage, isNotNull);
    },
  );
}
