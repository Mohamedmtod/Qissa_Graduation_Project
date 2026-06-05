import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAIChatRepo extends Mock implements AIChatRepo {}

class _MockUserTasteRepo extends Mock implements UserTasteRepo {}

ProductModel _product({
  required String id,
  required String name,
  required String brand,
  required double price,
  required String gender,
  required String season,
  required String occasion,
  required String time,
  required String intensity,
  required List<String> notes,
  required List<String> tags,
  List<String>? topNotes,
  List<String>? middleNotes,
  List<String>? baseNotes,
  int stock = 10,
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: [name.substring(0, 2).toLowerCase()],
    brand: brand,
    price: price,
    stock: stock,
    gender: gender,
    season: season,
    fragranceFamily: 'fresh',
    notes: notes,
    imageUrls: const ['https://placehold.co/300x300/png'],
    description: 'E2E smoke product',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: topNotes ?? notes.take(1).toList(),
    middleNotes: middleNotes ?? notes.skip(1).take(1).toList(),
    baseNotes: baseNotes ?? notes.skip(2).take(1).toList(),
    tags: tags,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
        id: 'fallback',
        displayName: 'Fallback',
        brand: 'Fallback',
        sourceUrl:
            'https://www.fragranticarabia.com/perfumes/Fallback/Fallback-1.html',
      ),
    );
  });

  testWidgets('opens AI chat, types, sends, and records E2E smoke logs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AIChatExperimentConfig.setTestOverrides(
      sendCompactContext: true,
      toolRouterV1: true,
      delegateMicroTurns: true,
      useCatalogSearchEngine: true,
      useSuitabilityPolicy: true,
    );
    addTearDown(AIChatExperimentConfig.resetTestOverrides);

    final repo = _MockAIChatRepo();
    final tasteRepo = _MockUserTasteRepo();
    final filteredLogs = <String>[];

    void logLine(String message) {
      final line = '[AIChatCubit] $message';
      filteredLogs.add(line);
      debugPrint(line, wrapWidth: 1024);
    }

    void publishFilteredLog() {
      binding.reportData = {'aiChatCubitFilteredLog': filteredLogs.join('\n')};
    }

    final catalog = [
      _product(
        id: 'floor',
        name: 'Budget Citrus',
        brand: 'Noura Atelier',
        price: 790,
        gender: 'men',
        season: 'summer',
        occasion: 'office',
        time: 'day',
        intensity: 'light',
        notes: const ['citrus', 'fruity', 'musk'],
        tags: const ['fresh', 'clean'],
      ),
      _product(
        id: 'light_blue',
        name: 'Light Blue',
        brand: 'Dolce & Gabbana',
        price: 3250,
        gender: 'unisex',
        season: 'summer',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'floral', 'fruity', 'woody'],
        tags: const ['fresh', 'clean', 'classic'],
      ),
      _product(
        id: 'acqua',
        name: 'Acqua di Gio',
        brand: 'Giorgio Armani',
        price: 3350,
        gender: 'unisex',
        season: 'summer',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'aquatic', 'fruity', 'woody'],
        tags: const ['fresh', 'clean', 'classic'],
      ),
      _product(
        id: 'si',
        name: 'Si',
        brand: 'Giorgio Armani',
        price: 3350,
        gender: 'unisex',
        season: 'autumn',
        occasion: 'daily',
        time: 'day',
        intensity: 'medium',
        notes: const ['rose', 'floral', 'fruity', 'vanilla', 'woody'],
        tags: const ['fresh', 'clean'],
      ),
      _product(
        id: 'goddess',
        name: 'Goddess',
        brand: 'Burberry',
        price: 3050,
        gender: 'unisex',
        season: 'autumn',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['fruity', 'vanilla', 'sweet'],
        tags: const ['fresh', 'clean'],
      ),
      _product(
        id: 'aqua_breeze',
        name: 'Aqua Breeze',
        brand: 'Scent Theory',
        price: 2500,
        gender: 'unisex',
        season: 'summer',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'aquatic', 'fruity', 'woody'],
        tags: const ['fresh', 'clean', 'classic'],
      ),
      _product(
        id: 'aqua_fresh',
        name: 'Aqua Fresh',
        brand: 'Maison Rayah',
        price: 3200,
        gender: 'unisex',
        season: 'summer',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'aquatic', 'fruity', 'woody', 'amber'],
        tags: const ['fresh', 'clean', 'classic'],
      ),
      _product(
        id: 'aventus',
        name: 'Aventus',
        brand: 'Creed',
        price: 9900,
        gender: 'unisex',
        season: 'summer',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'musk', 'fruity', 'woody'],
        tags: const ['fresh', 'clean', 'classic'],
      ),
      _product(
        id: 'the_noir',
        name: 'The Noir 29',
        brand: 'Le Labo',
        price: 6750,
        gender: 'unisex',
        season: 'autumn',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'musk', 'fruity', 'woody'],
        tags: const ['fresh', 'clean'],
      ),
      _product(
        id: 'delina',
        name: 'Delina',
        brand: 'Parfums de Marly',
        price: 8050,
        gender: 'unisex',
        season: 'spring',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'musk', 'rose', 'fruity', 'woody'],
        tags: const ['fresh', 'clean'],
      ),
      _product(
        id: 'bright_crystal',
        name: 'Bright Crystal',
        brand: 'Versace',
        price: 2950,
        gender: 'unisex',
        season: 'spring',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['amber', 'musk', 'floral', 'aquatic'],
        tags: const ['fresh', 'clean'],
      ),
    ];

    when(() => repo.canPersistSession).thenReturn(false);
    when(() => repo.currentUserId).thenReturn(null);
    when(() => repo.lastWorkerFailureReasonCode).thenReturn(null);
    when(
      () => repo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => catalog);
    when(() => repo.setSessionId(any())).thenReturn(null);
    when(() => repo.invalidateCatalog()).thenReturn(null);
    when(() => repo.invalidateCatalogCache()).thenReturn(null);
    when(
      () => repo.fetchLatestRestorableSession(userId: any(named: 'userId')),
    ).thenThrow(TimeoutException('e2e smoke skips restore'));
    when(
      () => repo.fetchRestorableSessionById(
        sessionId: any(named: 'sessionId'),
        userId: any(named: 'userId'),
      ),
    ).thenThrow(TimeoutException('e2e smoke skips restore'));
    when(() => repo.fetchSessionMessages(any())).thenAnswer((_) async => []);
    when(
      () => repo.createSession(
        sessionId: any(named: 'sessionId'),
        language: any(named: 'language'),
        startedAt: any(named: 'startedAt'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.appendMessage(
        message: any(named: 'message'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.completeSession(
        sessionId: any(named: 'sessionId'),
        messageCount: any(named: 'messageCount'),
        finalRecommendationMessageId: any(
          named: 'finalRecommendationMessageId',
        ),
        endedAt: any(named: 'endedAt'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        metadata: any(named: 'metadata'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((invocation) async {
      logLine('event=${invocation.namedArguments[#eventType]}');
    });
    when(
      () => repo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        metadata: any(named: 'metadata'),
      ),
    ).thenAnswer((invocation) async {
      logLine('event=${invocation.namedArguments[#eventType]}');
    });
    when(
      () => repo.lookupPerfumeKnowledge(any()),
    ).thenAnswer((_) async => null);
    when(
      () => repo.fetchBusinessInfo(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => null);
    when(
      () => repo.fetchProductPublicStats(
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => const {});
    when(
      () => repo.fetchAIRecommendation(
        currentMessage: any(named: 'currentMessage'),
        preferences: any(named: 'preferences'),
        candidates: any(named: 'candidates'),
        localRecommendations: any(named: 'localRecommendations'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => repo.fetchAIRecommendationWithContext(
        currentMessage: any(named: 'currentMessage'),
        preferences: any(named: 'preferences'),
        candidates: any(named: 'candidates'),
        localRecommendations: any(named: 'localRecommendations'),
        compactContext: any(named: 'compactContext'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((invocation) async {
      final message = invocation.namedArguments[#currentMessage]
          .toString()
          .trim()
          .toLowerCase();
      final language =
          invocation.namedArguments[#responseLanguage] as AIChatLanguage;
      final prefs =
          invocation.namedArguments[#preferences] as SessionPreferences;
      if (message == 'how are you') {
        return AIChatReply.answer(
          answer:
              'I am doing well and ready to help you choose a perfume. Tell me the mood, occasion, or budget you want.',
          updatedPreferences: prefs,
          provider: 'e2e_worker',
          modelId: 'fixture',
          promptVersion: 'ui_e2e',
        );
      }
      if (message.contains('حلو') && !message.contains('مسكر')) {
        return AIChatReply.toolCall(
          toolCall: const AIChatToolCall(
            name: AIChatToolName.askClarification,
            arguments: {
              'question':
                  'تقصد ريحة حلوة بمعنى مسكرة/sweet، ولا جميلة ولطيفة عمومًا؟',
            },
            confidence: 0.94,
          ),
          updatedPreferences: prefs,
          provider: 'e2e_worker',
          modelId: 'fixture',
          promptVersion: 'ui_e2e',
        );
      }
      if (language.isArabic && message.contains('جميل')) {
        return AIChatReply.toolCall(
          toolCall: const AIChatToolCall(
            name: AIChatToolName.askClarification,
            arguments: {
              'question':
                  'تمام، تقصد طابع لطيف ومقبول. تفضله رجالي ولا حريمي ولا للجنسين؟',
              'preferencePatch': {
                'appendLists': {
                  'tags': ['clean', 'elegant'],
                },
              },
            },
            confidence: 0.9,
          ),
          updatedPreferences: prefs,
          provider: 'e2e_worker',
          modelId: 'fixture',
          promptVersion: 'ui_e2e',
        );
      }
      return null;
    });
    when(
      () => repo.fetchAIInterpretation(
        currentMessage: any(named: 'currentMessage'),
        currentPreferences: any(named: 'currentPreferences'),
        responseLanguage: any(named: 'responseLanguage'),
        hasRecommendationContext: any(named: 'hasRecommendationContext'),
        hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => repo.lookupExternalPerfumeKnowledge(
        query: any(named: 'query'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => repo.lookupExternalPerfumeKnowledgeResult(
        query: any(named: 'query'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => const ExternalPerfumeLookupResult.notFound());
    when(
      () => repo.resolveExternalPerfumeKnowledgeCandidate(
        candidate: any(named: 'candidate'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => null);
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
    ).thenAnswer((invocation) async {
      final phase = invocation.namedArguments[#phase];
      final source = invocation.namedArguments[#responseSource];
      final reason = invocation.namedArguments[#reasonCode];
      final summary = invocation.namedArguments[#candidateSummary];
      logLine(
        'phase=$phase source=$source reason=$reason summary=${summary ?? {}}',
      );
    });
    when(
      () => tasteRepo.recordEvent(
        eventType: any(named: 'eventType'),
        notes: any(named: 'notes'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});

    AIChatCubit createCubit() {
      return AIChatCubit(
        aiChatRepo: repo,
        userTasteRepo: tasteRepo,
        initialLanguage: AIChatLanguage.english,
        thinkingDelay: Duration.zero,
        cooldownDuration: Duration.zero,
      );
    }

    var cubit = createCubit();
    addTearDown(() async => cubit.close());

    Future<void> pumpChatApp() async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                BlocProvider.value(value: cubit, child: const AIChatPage()),
          ),
          GoRoute(
            path: '/product/:id',
            builder: (context, state) => Scaffold(
              body: Text('Product ${state.pathParameters['id'] ?? 'unknown'}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpChatApp();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();

    Future<void> waitForTurnToFinish(int expectedMessages) async {
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (cubit.state.messages.length >= expectedMessages &&
            cubit.state.status != AIChatStatus.loading) {
          return;
        }
      }
      fail(
        'Timed out waiting for AI chat turn to finish. '
        'messages=${cubit.state.messages.length}, '
        'expected=$expectedMessages, status=${cubit.state.status.name}',
      );
    }

    var scenarioNumber = 0;

    Future<void> startFreshBatch() async {
      await cubit.close();
      cubit = createCubit();
      await pumpChatApp();
    }

    Future<void> sendThroughUi(String message) async {
      scenarioNumber += 1;
      final initialMessages = cubit.state.messages.length;
      final expectedMessages = initialMessages + 2;
      final field = find.byKey(const ValueKey('ai_chat_message_input'));
      expect(field, findsOneWidget);
      await tester.ensureVisible(field);
      await tester.tap(field, warnIfMissed: false);
      tester.testTextInput.enterText(message);
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(const Duration(milliseconds: 300));
      if (cubit.state.messages.length == initialMessages) {
        final sendButton = find.byKey(const ValueKey('ai_chat_send_button'));
        expect(sendButton, findsOneWidget);
        await tester.tap(sendButton, warnIfMissed: false);
      }
      await waitForTurnToFinish(expectedMessages);

      final last = cubit.state.messages.last;
      logLine(
        'scenario=${scenarioNumber.toString().padLeft(2, '0')} '
        'message="$message" status=${cubit.state.status.name} '
        'lastType=${last.type.name} source=${last.responseSource} '
        'products=${last.recommendedProducts.map((item) => item.product.id).toList()} '
        'content="${last.content.replaceAll(RegExp(r'\s+'), ' ')}"',
      );
      publishFilteredLog();
    }

    await sendThroughUi('how are you');
    expect(cubit.state.status, AIChatStatus.answer);
    expect(
      cubit.state.messages.last.responseSource,
      anyOf('ai_worker', 'social_micro_turn_worker', 'local_social_micro_turn'),
    );
    expect(cubit.state.messages.last.content, contains('ready to help'));

    await startFreshBatch();

    await sendThroughUi('رشحلي ريحة حلوة');
    expect(cubit.state.status, AIChatStatus.ask);
    expect(
      cubit.state.messages.last.responseSource,
      anyOf(
        'tool_ask_clarification',
        'deterministic_gate_ambiguous_egyptian_sweet',
      ),
    );
    expect(cubit.state.messages.last.content, contains('مسكرة'));

    await sendThroughUi('جميلة ولطيفة');
    expect(cubit.state.status, AIChatStatus.ask);
    expect(cubit.state.messages.last.responseSource, 'tool_ask_clarification');
    expect(cubit.state.preferences.tags, contains('clean'));

    await startFreshBatch();

    await sendThroughUi('I want a light fruity perfume for men');
    expect(cubit.state.status, AIChatStatus.recommend);

    await sendThroughUi('make it suitable for university');
    expect(cubit.state.status, AIChatStatus.recommend);

    final rejectedIds = cubit.state.messages.last.recommendedProducts
        .map((item) => item.product.id)
        .toSet();
    await sendThroughUi("I don't like these");
    expect(
      cubit.state.messages.last.recommendedProducts
          .map((item) => item.product.id)
          .toSet()
          .intersection(rejectedIds),
      isEmpty,
    );

    await sendThroughUi('show me something cheaper');
    expect(cubit.state.status, AIChatStatus.recommend);

    await sendThroughUi('is the first one suitable for work?');
    expect(cubit.state.status, AIChatStatus.answer);

    await sendThroughUi('compare 1 and 2');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('which is cheapest among them?');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('which one is better for university?');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('recommend a fresh daily perfume');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('I want a light fresh office perfume');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await startFreshBatch();

    await sendThroughUi('I want citrus aquatic perfume');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('for office');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('for summer');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('men perfume under 4000');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('cheapest perfume');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('most expensive perfume you have');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('cheapest men summer perfume');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('I want a clean office perfume');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('I want a sweet fruity perfume');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('avoid vanilla');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await startFreshBatch();

    await sendThroughUi('I want vanilla perfume now');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('anything cheaper?');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('show me another option');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('is Light Blue suitable for work?');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await sendThroughUi('similar to Light Blue but cheaper');
    expect(cubit.state.status, isNot(AIChatStatus.loading));

    await startFreshBatch();

    await sendThroughUi('I want a men summer fresh perfume under 600');
    expect(cubit.state.status, AIChatStatus.noMatch);
    expect(
      cubit.state.recommendationMemory.lastNoMatchContext?.reason,
      'budget_no_match',
    );

    await sendThroughUi('ok show me it');
    expect(cubit.state.status, AIChatStatus.recommend);
    expect(
      cubit.state.messages.last.recommendedProducts.first.product.id,
      'floor',
    );

    await startFreshBatch();

    await sendThroughUi('is Acqua di Gio suitable for office?');
    expect(cubit.state.status, AIChatStatus.answer);
    expect(cubit.state.messages.last.content, contains('Acqua di Gio'));

    await sendThroughUi('similar but cheaper');
    expect(cubit.state.status, AIChatStatus.recommend);
    expect(
      cubit.state.messages.last.recommendedProducts.every(
        (item) => item.product.effectivePrice < 3350,
      ),
      isTrue,
    );

    await sendThroughUi('Do you have Light Blue?');
    expect(cubit.state.messages.last.content, contains('Light Blue'));

    publishFilteredLog();
    expect(filteredLogs, isNotEmpty);
    expect(scenarioNumber, 33);
  });
}
