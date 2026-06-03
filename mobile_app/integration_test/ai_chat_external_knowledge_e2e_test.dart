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
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
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
  required List<String> notes,
  required List<String> tags,
  String gender = 'men',
  String season = 'summer',
  String occasion = 'office',
  String time = 'day',
  String intensity = 'medium',
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
    fragranceFamily: tags.contains('spicy') ? 'fresh spicy' : 'fresh',
    notes: notes,
    imageUrls: const ['https://placehold.co/300x300/png'],
    description: 'External knowledge E2E product',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: notes.take(1).toList(),
    middleNotes: notes.skip(1).take(1).toList(),
    baseNotes: notes.skip(2).take(2).toList(),
    tags: tags,
  );
}

PerfumeKnowledgeProfile _profile({
  required String id,
  required String displayName,
  required String brand,
  required List<String> accords,
  required List<String> notes,
  List<String> aliases = const [],
  String family = 'fresh spicy',
  double confidence = 0.92,
}) {
  return PerfumeKnowledgeProfile(
    id: id,
    displayName: displayName,
    brand: brand,
    aliases: aliases,
    searchKeys: [
      displayName.toLowerCase(),
      '$brand $displayName'.toLowerCase(),
    ],
    accords: accords,
    topNotes: notes.take(1).toList(),
    middleNotes: notes.skip(1).take(1).toList(),
    baseNotes: notes.skip(2).toList(),
    fragranceFamily: family,
    genderHint: 'men',
    occasionHint: 'office',
    timeHint: 'day',
    intensityHint: 'strong',
    sourceName: 'e2e_fixture',
    sourceUrl: 'https://example.test/perfumes/$id',
    extractionMethod: 'fixture',
    lookupConfidence: confidence,
    status: PerfumeKnowledgeStatus.approved,
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
        sourceUrl: 'https://example.test/fallback',
      ),
    );
  });

  tearDown(AIChatExperimentConfig.resetTestOverrides);

  testWidgets('external perfume knowledge stays grounded end to end', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AIChatExperimentConfig.setTestOverrides(
      sendCompactContext: true,
      useCatalogSearchEngine: true,
      useSuitabilityPolicy: true,
      toolRouterV1: true,
    );

    final repo = _MockAIChatRepo();
    final tasteRepo = _MockUserTasteRepo();
    final filteredLogs = <String>[];

    void logLine(String message) {
      final line = '[AIChatCubit] $message';
      filteredLogs.add(line);
      debugPrint(line, wrapWidth: 1024);
    }

    void publishFilteredLog() {
      binding.reportData = {
        'aiChatExternalKnowledgeFilteredLog': filteredLogs.join('\n'),
      };
    }

    final sauvage = _profile(
      id: 'dior_sauvage',
      displayName: 'Dior Sauvage',
      brand: 'Dior',
      accords: const ['fresh', 'spicy', 'woody', 'masculine'],
      notes: const ['bergamot', 'pepper', 'ambroxan', 'woody'],
      aliases: const ['sauvage', 'dior sauvage', 'سوفاج'],
    );
    final diorHomme = _profile(
      id: 'dior_homme',
      displayName: 'Dior Homme',
      brand: 'Dior',
      accords: const ['woody', 'powdery', 'iris'],
      notes: const ['iris', 'cacao', 'amber', 'woody'],
      family: 'woody floral',
    );
    final azzaro = _profile(
      id: 'azzaro_pour_homme',
      displayName: 'Azzaro Pour Homme',
      brand: 'Azzaro',
      accords: const ['aromatic', 'fougere', 'spicy'],
      notes: const ['lavender', 'anise', 'musk', 'woody'],
      aliases: const ['azzaro', 'azzaro pour homme'],
      family: 'aromatic fougere',
    );

    final catalog = [
      _product(
        id: 'pepper_woods',
        name: 'Pepper Woods',
        brand: 'Scent Theory',
        price: 2600,
        notes: const ['bergamot', 'pepper', 'ambroxan', 'woody'],
        tags: const ['fresh', 'spicy', 'masculine'],
      ),
      _product(
        id: 'aqua_spice',
        name: 'Aqua Spice',
        brand: 'Maison Rayah',
        price: 2900,
        notes: const ['citrus', 'pepper', 'aquatic', 'woody'],
        tags: const ['fresh', 'spicy', 'clean'],
      ),
      _product(
        id: 'lavender_fougere',
        name: 'Lavender Fougere',
        brand: 'Noura Atelier',
        price: 2100,
        notes: const ['lavender', 'anise', 'musk', 'woody'],
        tags: const ['aromatic', 'spicy', 'classic'],
      ),
      _product(
        id: 'light_blue',
        name: 'Light Blue',
        brand: 'Dolce & Gabbana',
        price: 3250,
        notes: const ['citrus', 'floral', 'fruity', 'woody'],
        tags: const ['fresh', 'clean', 'classic'],
        gender: 'unisex',
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
    ).thenThrow(TimeoutException('external e2e skips restore'));
    when(
      () => repo.fetchRestorableSessionById(
        sessionId: any(named: 'sessionId'),
        userId: any(named: 'userId'),
      ),
    ).thenThrow(TimeoutException('external e2e skips restore'));
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
    when(() => repo.lookupPerfumeKnowledge(any())).thenAnswer((
      invocation,
    ) async {
      final query = invocation.positionalArguments.first
          .toString()
          .toLowerCase();
      if (query.contains('sauvage') || query.contains('سوفاج')) return sauvage;
      if (query.contains('azzaro')) return azzaro;
      return null;
    });
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
          .toLowerCase();
      final preferences =
          invocation.namedArguments[#preferences] as SessionPreferences;
      final requestId = invocation.namedArguments[#requestId]?.toString();
      if (message.contains('cheaper than it') ||
          message.contains('sauvage but cheaper')) {
        return AIChatReply.toolCall(
          toolCall: const AIChatToolCall(
            name: AIChatToolName.similarCheaperToExternalProfile,
            arguments: {'externalProfileId': 'dior_sauvage'},
            confidence: 0.94,
          ),
          updatedPreferences: preferences,
          requestId: requestId,
          provider: 'e2e_worker_mock',
          modelId: 'tool_router_mock',
          promptVersion: 'external_knowledge_e2e',
        );
      }
      if (message.contains('something like dior sauvage')) {
        return AIChatReply.toolCall(
          toolCall: const AIChatToolCall(
            name: AIChatToolName.recommendSimilarToExternalProfile,
            arguments: {'externalProfileId': 'dior_sauvage'},
            confidence: 0.94,
          ),
          updatedPreferences: preferences,
          requestId: requestId,
          provider: 'e2e_worker_mock',
          modelId: 'tool_router_mock',
          promptVersion: 'external_knowledge_e2e',
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
    ).thenAnswer((invocation) async {
      final query = invocation.namedArguments[#query].toString().toLowerCase();
      if (query.contains('dior sauvage')) return sauvage;
      if (query.contains('azzaro')) return azzaro;
      return null;
    });
    when(
      () => repo.lookupExternalPerfumeKnowledgeResult(
        query: any(named: 'query'),
        responseLanguage: any(named: 'responseLanguage'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((invocation) async {
      final query = invocation.namedArguments[#query].toString().toLowerCase();
      if (query.trim() == 'dior' || query.contains('have dior')) {
        return ExternalPerfumeLookupResult.ambiguous([
          const ExternalPerfumeCandidate(
            id: 'dior_sauvage',
            displayName: 'Dior Sauvage',
            brand: 'Dior',
            sourceUrl: 'https://example.test/dior-sauvage',
            score: 0.91,
          ),
          const ExternalPerfumeCandidate(
            id: 'dior_homme',
            displayName: 'Dior Homme',
            brand: 'Dior',
            sourceUrl: 'https://example.test/dior-homme',
            score: 0.84,
          ),
        ]);
      }
      if (query.contains('sauvage') || query.contains('سوفاج')) {
        return ExternalPerfumeLookupResult.found(sauvage);
      }
      if (query.contains('azzaro')) {
        return ExternalPerfumeLookupResult.found(azzaro);
      }
      return const ExternalPerfumeLookupResult.notFound();
    });
    when(
      () => repo.resolveExternalPerfumeKnowledgeCandidate(
        candidate: any(named: 'candidate'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((invocation) async {
      final candidate =
          invocation.namedArguments[#candidate] as ExternalPerfumeCandidate;
      switch (candidate.id) {
        case 'dior_sauvage':
          return sauvage;
        case 'dior_homme':
          return diorHomme;
      }
      return null;
    });
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

    final cubit = AIChatCubit(
      aiChatRepo: repo,
      userTasteRepo: tasteRepo,
      initialLanguage: AIChatLanguage.english,
      thinkingDelay: Duration.zero,
      cooldownDuration: Duration.zero,
    );
    addTearDown(() async => cubit.close());

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
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();

    Future<void> waitForTurnToFinish(int expectedMessages) async {
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (cubit.state.messages.length >= expectedMessages &&
            cubit.state.status != AIChatStatus.loading) {
          return;
        }
      }
      fail(
        'Timed out waiting for AI chat turn. '
        'messages=${cubit.state.messages.length}, '
        'expected=$expectedMessages, status=${cubit.state.status.name}',
      );
    }

    var scenarioNumber = 0;
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

    bool lastProductsAreCatalogOnly() {
      return cubit.state.messages.last.recommendedProducts.every(
        (item) => item.product.id != 'dior_sauvage' && item.product.stock > 0,
      );
    }

    await sendThroughUi('Do you have Dior?');
    expect(cubit.state.status, AIChatStatus.ask);
    expect(cubit.state.messages.last.recommendedProducts, isEmpty);
    expect(cubit.state.messages.last.content, contains('Dior Sauvage'));
    expect(
      cubit.state.recommendationMemory.pendingPerfumeReferenceClarification,
      isNotNull,
    );

    await sendThroughUi('1');
    expect(cubit.state.status, isNot(AIChatStatus.loading));
    expect(
      cubit.state.recommendationMemory.lastExternalProfile?.id,
      'dior_sauvage',
    );
    expect(lastProductsAreCatalogOnly(), isTrue);

    await sendThroughUi('Something like Dior Sauvage');
    expect(cubit.state.status, isNot(AIChatStatus.loading));
    expect(
      cubit.state.messages.last.content.toLowerCase(),
      isNot(contains('available now: dior sauvage')),
    );
    expect(lastProductsAreCatalogOnly(), isTrue);

    await sendThroughUi('Something like Dior Sauvage but cheaper');
    expect(cubit.state.status, isNot(AIChatStatus.loading));
    expect(
      cubit.state.messages.last.content.toLowerCase(),
      isNot(contains('cheaper than')),
    );
    expect(lastProductsAreCatalogOnly(), isTrue);

    await sendThroughUi('cheaper than it');
    expect(cubit.state.status, isNot(AIChatStatus.loading));
    expect(
      cubit.state.messages.last.responseSource,
      'tool_similarCheaperToExternalProfile',
    );
    expect(lastProductsAreCatalogOnly(), isTrue);

    await sendThroughUi('عندك سوفاج؟');
    expect(cubit.state.status, isNot(AIChatStatus.loading));
    expect(
      cubit.state.messages.last.content.toLowerCase(),
      isNot(contains('available now: dior sauvage')),
    );

    await sendThroughUi('Do you have Azzaro Pour Homme?');
    expect(cubit.state.status, isNot(AIChatStatus.loading));
    expect(
      cubit.state.messages.last.content.toLowerCase(),
      isNot(contains('available now: azzaro')),
    );
    expect(lastProductsAreCatalogOnly(), isTrue);

    await sendThroughUi('Do you have Light Blue?');
    expect(cubit.state.status, AIChatStatus.answer);
    expect(cubit.state.messages.last.content, contains('Light Blue'));
    expect(
      cubit.state.messages.last.responseSource,
      'local_direct_availability_answer_only',
    );

    publishFilteredLog();
    expect(filteredLogs, isNotEmpty);
    expect(scenarioNumber, 8);
  });
}
