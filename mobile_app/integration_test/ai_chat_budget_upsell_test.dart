import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class MockAIChatRepo extends Mock implements AIChatRepo {}

ProductModel _product({
  required String id,
  required String name,
  required double price,
  required String gender,
  required String season,
  required String occasion,
  required String time,
  required String intensity,
  required List<String> notes,
  required List<String> tags,
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: [name.substring(0, 2).toLowerCase()],
    brand: 'Brand',
    price: price,
    stock: 5,
    gender: gender,
    season: season,
    fragranceFamily: 'fresh',
    notes: notes,
    imageUrls: const ['https://placehold.co/300x300/png'],
    description: 'Test description',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: notes.take(1).toList(),
    middleNotes: notes.skip(1).take(1).toList(),
    baseNotes: notes.skip(2).take(1).toList(),
    tags: tags,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAIChatRepo mockAIChatRepo;
  late AIChatCubit cubit;
  late List<ProductModel> catalog;

  setUpAll(() {
    registerFallbackValue(const SessionPreferences());
    registerFallbackValue(AIChatLanguage.english);
    registerFallbackValue(AIChatMessage.botText('fallback'));
  });

  setUp(() {
    mockAIChatRepo = MockAIChatRepo();
    catalog = [
      _product(
        id: 'p1',
        name: 'Campus Citrus Drive',
        price: 1000,
        gender: 'men',
        season: 'summer',
        occasion: 'daily',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'musk'],
        tags: const ['fresh', 'clean'],
      ),
      _product(
        id: 'p2',
        name: 'Cedar Class 01',
        price: 1500,
        gender: 'men',
        season: 'winter',
        occasion: 'formal',
        time: 'night',
        intensity: 'strong',
        notes: const ['cedar', 'amber', 'musk'],
        tags: const ['classic', 'elegant'],
      ),
    ];

    when(() => mockAIChatRepo.setSessionId(any())).thenReturn(null);
    when(() => mockAIChatRepo.invalidateCatalog()).thenReturn(null);
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
      () => mockAIChatRepo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => catalog);

    cubit = AIChatCubit(
      aiChatRepo: mockAIChatRepo,
      thinkingDelay: Duration.zero,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  Finder messageField() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.textInputAction == TextInputAction.send &&
          widget.maxLines == 4,
      description: 'AI chat message field',
    );
  }

  Future<void> pumpTestApp(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              BlocProvider.value(value: cubit, child: const AIChatPage()),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? 'unknown';
            return Scaffold(body: Text('Product $id'));
          },
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

  Future<void> sendMessage(WidgetTester tester, String text) async {
    final field = messageField();
    expect(field, findsOneWidget);
    await tester.tap(field, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  Future<List<String>> getVisibleTexts(WidgetTester tester) async {
    await tester.pumpAndSettle();
    return find
        .byType(Text)
        .evaluate()
        .map((e) => e.widget)
        .whereType<Text>()
        .map((w) => w.data?.trim())
        .where((t) => t != null && t.isNotEmpty)
        .cast<String>()
        .toList();
  }

  testWidgets(
    'English upsell flow shows separate section, badge, and click telemetry',
    (WidgetTester tester) async {
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
          productIds: const ['p1', 'p2'],
          matchReasons: const {
            'p1': 'Good within-budget option.',
            'p2': 'Great fit with stronger character.',
          },
          updatedPreferences: const SessionPreferences(
            gender: 'men',
            maxBudget: 1400,
          ),
        ),
      );

      await pumpTestApp(tester);
      await sendMessage(tester, 'I need a men perfume under 1400');

      final visibleTexts = await getVisibleTexts(tester);
      debugPrint('[AI-UPSELL-IT] EN visible texts: $visibleTexts');

      expect(find.text('Best matches within your budget'), findsOneWidget);
      expect(
        find.text('Slightly above budget, but worth considering'),
        findsOneWidget,
      );
      expect(find.textContaining('+7% over budget'), findsOneWidget);

      await tester.tap(find.text('Cedar Class 01').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Product p2'), findsOneWidget);
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
      verify(
        () => mockAIChatRepo.logAIChatEvent(
          eventType: 'conversion_upsell_product_clicked',
          sessionId: any(named: 'sessionId'),
          metadata: any(named: 'metadata'),
          userId: any(named: 'userId'),
        ),
      ).called(1);
    },
  );

  testWidgets('Arabic upsell flow shows Arabic section title and disclosure', (
    WidgetTester tester,
  ) async {
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
        productIds: const ['p1', 'p2'],
        matchReasons: const {
          'p1': 'خيار مناسب داخل الميزانية.',
          'p2': 'يناسب طلبك بشكل ممتاز.',
        },
        updatedPreferences: const SessionPreferences(
          gender: 'men',
          maxBudget: 1400,
        ),
      ),
    );

    await pumpTestApp(tester);
    await sendMessage(tester, 'عايز عطر رجالي تحت 1400');

    final visibleTexts = await getVisibleTexts(tester);
    debugPrint('[AI-UPSELL-IT] AR visible texts: $visibleTexts');

    expect(find.text('داخل ميزانيتك'), findsOneWidget);
    expect(find.text('أعلى قليلًا من ميزانيتك'), findsOneWidget);
    expect(find.textContaining('أعلى 7% من الميزانية'), findsOneWidget);
    expect(
      visibleTexts.any((text) => text.contains('أعلى قليلًا من ميزانيتك')),
      isTrue,
    );
  });

  testWidgets('Out of stock availability flow shows Notify Me card', (
    WidgetTester tester,
  ) async {
    when(
      () => mockAIChatRepo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => [catalog[1].copyWith(stock: 0)]);

    await pumpTestApp(tester);
    await sendMessage(tester, 'Do you have Cedar Class 01?');

    final visibleTexts = await getVisibleTexts(tester);
    expect(
      visibleTexts.any(
        (text) =>
            text.contains('out of stock') && text.contains('Cedar Class 01'),
      ),
      isTrue,
    );
    expect(
      visibleTexts.any((text) => text.toLowerCase().contains('notify')),
      isTrue,
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
  });
}
