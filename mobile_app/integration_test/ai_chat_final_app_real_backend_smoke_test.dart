import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_business_info.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProductRepo extends Mock implements ProductRepo {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserTasteRepo extends Mock implements UserTasteRepo {}

class _RealWorkerSmokeRepo extends AIChatRepo {
  _RealWorkerSmokeRepo({
    required super.productRepo,
    required FirebaseAuth auth,
    required this.catalog,
  }) : super(auth: auth, allowGuestWorkerRequests: true);

  final List<ProductModel> catalog;
  final Map<String, PerfumeKnowledgeProfile> _knowledgeCache = {};
  final List<Map<String, Object?>> sanitizedEvents = [];
  int externalLookupCount = 0;
  int cacheHitCount = 0;

  @override
  bool get canPersistSession => false;

  @override
  String? get currentUserId => null;

  @override
  Future<List<ProductModel>> getCatalog({bool forceRefresh = false}) async {
    return catalog;
  }

  @override
  void invalidateCatalog() {}

  @override
  void invalidateCatalogCache() {}

  @override
  Future<AIChatSession?> fetchLatestRestorableSession({
    required String userId,
    Duration maxAge = const Duration(days: 7),
  }) async {
    return null;
  }

  @override
  Future<AIChatSession?> fetchRestorableSessionById({
    required String sessionId,
    required String userId,
    Duration maxAge = const Duration(days: 7),
  }) async {
    return null;
  }

  @override
  Future<List<AIChatStoredMessage>> fetchSessionMessages(String sessionId) {
    return Future.value(const <AIChatStoredMessage>[]);
  }

  @override
  Future<void> createSession({
    required String sessionId,
    required AIChatLanguage language,
    DateTime? startedAt,
    String? userId,
  }) async {}

  @override
  Future<void> appendMessage({
    required AIChatMessage message,
    String? sessionId,
  }) async {}

  @override
  Future<void> completeSession({
    required String sessionId,
    required int messageCount,
    String? finalRecommendationMessageId,
    DateTime? endedAt,
  }) async {}

  @override
  Future<AIChatBusinessInfo?> fetchBusinessInfo({
    bool forceRefresh = false,
  }) async {
    return null;
  }

  @override
  Future<Map<String, AIChatProductPublicStats>> fetchProductPublicStats({
    bool forceRefresh = false,
  }) async {
    return const <String, AIChatProductPublicStats>{};
  }

  @override
  Future<PerfumeKnowledgeProfile?> lookupPerfumeKnowledge(String query) async {
    final key = PerfumeKnowledgeProfile.documentIdForQuery(query);
    final cached = _knowledgeCache[key];
    if (cached != null) cacheHitCount += 1;
    return cached;
  }

  @override
  Future<ExternalPerfumeLookupResult> lookupExternalPerfumeKnowledgeResult({
    required String query,
    required AIChatLanguage responseLanguage,
    String? requestId,
  }) async {
    externalLookupCount += 1;
    return super.lookupExternalPerfumeKnowledgeResult(
      query: query,
      responseLanguage: responseLanguage,
      requestId: requestId,
    );
  }

  @override
  Future<PerfumeKnowledgeProfile> savePerfumeKnowledgeProfile(
    PerfumeKnowledgeProfile profile,
  ) async {
    _knowledgeCache[profile.id] = profile;
    _knowledgeCache[PerfumeKnowledgeProfile.documentIdForQuery(
          profile.displayName,
        )] =
        profile;
    if (profile.brand.trim().isNotEmpty) {
      _knowledgeCache[PerfumeKnowledgeProfile.documentIdForQuery(
            '${profile.brand} ${profile.displayName}',
          )] =
          profile;
    }
    return profile;
  }

  @override
  Future<void> logAIChatEvent({
    required String eventType,
    String? sessionId,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    sanitizedEvents.add(<String, Object?>{
      'eventType': eventType,
      'metadataKeys': (metadata ?? const <String, dynamic>{}).keys.toList(),
    });
  }

  @override
  Future<void> saveAIChatDebugLog({
    required String phase,
    String? sessionId,
    String? requestId,
    String? language,
    String? messageText,
    String? detectedIntent,
    String? responseSource,
    String? issueCode,
    String? reasonCode,
    Map<String, dynamic>? preferencesSnapshot,
    Map<String, dynamic>? availabilityContextSnapshot,
    Map<String, dynamic>? recommendationMemorySnapshot,
    Map<String, dynamic>? candidateSummary,
    List<Map<String, dynamic>>? recommendedProducts,
    Map<String, dynamic>? workerReplySummary,
  }) async {}
}

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
  String family = 'fresh',
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
    fragranceFamily: family,
    notes: notes,
    imageUrls: const ['https://placehold.co/300x300/png'],
    description: 'Real backend smoke product',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: notes.take(2).toList(growable: false),
    middleNotes: notes.skip(1).take(2).toList(growable: false),
    baseNotes: notes.skip(2).take(3).toList(growable: false),
    tags: tags,
  );
}

List<ProductModel> _catalog() {
  return <ProductModel>[
    _product(
      id: 'budget_citrus',
      name: 'Budget Citrus',
      brand: 'Noura Atelier',
      price: 790,
      gender: 'men',
      season: 'summer',
      occasion: 'university',
      time: 'day',
      intensity: 'light',
      notes: const ['citrus', 'fruity', 'musk', 'clean'],
      tags: const ['fresh', 'clean', 'student'],
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
      id: 'acqua_gio',
      name: 'Acqua di Gio',
      brand: 'Giorgio Armani',
      price: 3350,
      gender: 'men',
      season: 'summer',
      occasion: 'office',
      time: 'day',
      intensity: 'medium',
      notes: const ['citrus', 'aquatic', 'fruity', 'woody'],
      tags: const ['fresh', 'clean', 'classic'],
    ),
    _product(
      id: 'aqua_breeze',
      name: 'Aqua Breeze',
      brand: 'Scent Theory',
      price: 2500,
      gender: 'unisex',
      season: 'summer',
      occasion: 'university',
      time: 'day',
      intensity: 'medium',
      notes: const ['citrus', 'aquatic', 'fruity', 'woody'],
      tags: const ['fresh', 'clean'],
    ),
    _product(
      id: 'campus_musk',
      name: 'Campus Musk',
      brand: 'Maison Rayah',
      price: 1450,
      gender: 'unisex',
      season: 'all seasons',
      occasion: 'university',
      time: 'day',
      intensity: 'light',
      notes: const ['musk', 'clean', 'citrus', 'soft'],
      tags: const ['clean', 'soft', 'student'],
      family: 'musky',
    ),
    _product(
      id: 'blue_wood',
      name: 'Blue Wood',
      brand: 'Qissa',
      price: 2100,
      gender: 'men',
      season: 'all seasons',
      occasion: 'daily',
      time: 'day',
      intensity: 'medium',
      notes: const ['citrus', 'woody', 'amber', 'aromatic'],
      tags: const ['fresh', 'woody', 'classic'],
      family: 'woody aromatic',
    ),
    _product(
      id: 'noir_29',
      name: 'The Noir 29',
      brand: 'Le Labo',
      price: 6750,
      gender: 'unisex',
      season: 'autumn',
      occasion: 'office',
      time: 'day',
      intensity: 'medium',
      notes: const ['musk', 'woody', 'tea', 'fresh'],
      tags: const ['clean', 'elegant'],
      family: 'woody',
    ),
    _product(
      id: 'bright_crystal',
      name: 'Bright Crystal',
      brand: 'Versace',
      price: 2950,
      gender: 'women',
      season: 'spring',
      occasion: 'daily',
      time: 'day',
      intensity: 'medium',
      notes: const ['floral', 'aquatic', 'musk', 'fresh'],
      tags: const ['fresh', 'soft', 'clean'],
      family: 'floral',
    ),
  ];
}

class _TurnResult {
  _TurnResult({
    required this.index,
    required this.message,
    required this.status,
    required this.type,
    required this.source,
    required this.contentPreview,
    required this.productIds,
    required this.productNames,
    required this.productPrices,
    required this.latencyMs,
    required this.issues,
    required this.caveats,
  });

  final int index;
  final String message;
  final String status;
  final String type;
  final String? source;
  final String contentPreview;
  final List<String> productIds;
  final List<String> productNames;
  final List<double> productPrices;
  final int latencyMs;
  final List<String> issues;
  final List<String> caveats;

  Map<String, Object?> toJson() => <String, Object?>{
    'index': index,
    'message': message,
    'status': status,
    'type': type,
    'source': source,
    'contentPreview': contentPreview,
    'productIds': productIds,
    'productNames': productNames,
    'latencyMs': latencyMs,
    'issues': issues,
    'caveats': caveats,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(EventType.view);
  });

  Future<void> runSmoke({
    required WidgetTester tester,
    required bool deterministicGate,
    bool w41ExternalAmbiguity = false,
    bool helloOnly = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    AIChatExperimentConfig.setTestOverrides(
      sendCompactContext: true,
      toolRouterV1: true,
      delegateMicroTurns: true,
      useCatalogSearchEngine: true,
      useSuitabilityPolicy: true,
      analyticsEventsEnabled: true,
      analyticsDebugSinkEnabled: true,
      analyticsRemoteSinkEnabled: false,
      deterministicGateShadowEnabled: true,
      deterministicGateV1: deterministicGate,
    );
    addTearDown(AIChatExperimentConfig.resetTestOverrides);

    final auth = _MockFirebaseAuth();
    when(() => auth.currentUser).thenReturn(null);

    final productRepo = _MockProductRepo();
    final repo = _RealWorkerSmokeRepo(
      productRepo: productRepo,
      auth: auth,
      catalog: _catalog(),
    );

    final tasteRepo = _MockUserTasteRepo();
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

    final results = <_TurnResult>[];
    Set<String> previousRecommendationIds = const <String>{};
    double? previousLowestPrice;

    Future<void> waitForTurn(int expectedMessages) async {
      for (var i = 0; i < 240; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (cubit.state.messages.length >= expectedMessages &&
            cubit.state.status != AIChatStatus.loading) {
          return;
        }
      }
      fail(
        'Timed out waiting for turn. gate=$deterministicGate '
        'messages=${cubit.state.messages.length} expected=$expectedMessages '
        'status=${cubit.state.status.name}',
      );
    }

    Future<_TurnResult> sendTurn(int index, String message) async {
      final beforeCount = cubit.state.messages.length;
      final expectedCount = beforeCount + 2;
      final stopwatch = Stopwatch()..start();
      var usedDirectSendFallback = false;
      final field = find.byKey(const ValueKey('ai_chat_message_input'));
      expect(field, findsOneWidget);
      await tester.ensureVisible(field);
      await tester.tap(field, warnIfMissed: false);
      tester.testTextInput.enterText(message);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(const Duration(milliseconds: 300));
      if (cubit.state.messages.length == beforeCount) {
        final sendButton = find.byKey(const ValueKey('ai_chat_send_button'));
        expect(sendButton, findsOneWidget);
        await tester.tap(sendButton, warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 300));
      if (cubit.state.messages.length == beforeCount) {
        usedDirectSendFallback = true;
        await cubit.sendMessage(message);
      }
      await waitForTurn(expectedCount);
      stopwatch.stop();

      final last = cubit.state.messages.last;
      final ids = last.recommendedProducts
          .map((item) => item.product.id)
          .toList(growable: false);
      final names = last.recommendedProducts
          .map((item) => item.product.name)
          .toList(growable: false);
      final prices = last.recommendedProducts
          .map((item) => item.product.effectivePrice)
          .toList(growable: false);
      final content = last.content.replaceAll(RegExp(r'\s+'), ' ').trim();
      final issues = <String>[];
      final caveats = <String>[];

      void issue(String value) => issues.add(value);
      void caveat(String value) => caveats.add(value);

      final lowerContent = content.toLowerCase();
      final hasCards = ids.isNotEmpty;
      final hasMojibake = RegExp(
        r'[\u00d8\u00d9\u00c3\u00c2\ufffd]',
      ).hasMatch(content);
      final isGeneric = RegExp(
        r'^(understood|okay|ok|sure|РЁР„Р©вЂ¦РЁВ§Р©вЂ¦|РЁВ­РЁВ§РЁВ¶РЁВ±)[.!РЁСџ\s]*$',
        caseSensitive: false,
      ).hasMatch(content);
      final invalidIds = ids
          .where((id) => !repo.catalog.any((product) => product.id == id))
          .toList(growable: false);
      final externalCard = names.any(
        (name) =>
            name.toLowerCase().contains('dior') ||
            name.toLowerCase().contains('sauvage'),
      );
      final fakeExternalClaim =
          lowerContent.contains('dior sauvage') &&
          RegExp(
            r'\b(available|in stock|stock|price|egp|buy)\b',
            caseSensitive: false,
          ).hasMatch(lowerContent);

      if (hasMojibake) issue('mojibake');
      if (isGeneric) issue('generic_message');
      if (invalidIds.isNotEmpty) {
        issue('invalid_product_ids:${invalidIds.join(',')}');
      }
      if (externalCard) issue('external_product_card');
      if (fakeExternalClaim) issue('fake_external_availability_or_price_claim');
      if (stopwatch.elapsedMilliseconds > 15000) {
        issue('latency_over_15s');
      } else if (stopwatch.elapsedMilliseconds > 8000) {
        caveat('latency_over_8s');
      }
      if (usedDirectSendFallback) {
        caveat('ui_send_fallback_to_cubit');
      }

      if (helloOnly) {
        if (hasCards) issue('hello_rendered_cards');
        if (cubit.state.status == AIChatStatus.noMatch) {
          issue('hello_no_match');
        }
        if (cubit.state.status == AIChatStatus.ask ||
            _containsAny(lowerContent, const [
              'gender',
              'men',
              'women',
              'male',
              'female',
            ])) {
          issue('hello_routed_to_preference_ask');
        }
        if (lowerContent.contains('availability') ||
            lowerContent.contains('specific perfume')) {
          issue('hello_routed_to_availability_copy');
        }
        if (lowerContent.contains('safe in-stock') ||
            lowerContent.contains('catalog match') ||
            lowerContent.contains('constraints')) {
          issue('hello_routed_to_no_match_copy');
        }
      } else if (w41ExternalAmbiguity) {
        switch (index) {
          case 1:
            if (hasCards) issue('sauvage_ambiguity_rendered_cards');
            if (cubit.state.status != AIChatStatus.ask) {
              issue('sauvage_not_ambiguous_ask');
            }
            if (!_containsAny(lowerContent, const [
              'sauvage',
              'which',
              'mean',
              'option',
              '1.',
              '2.',
              '3.',
            ])) {
              issue('sauvage_ambiguity_copy_missing_options');
            }
            break;
          case 2:
            if (cubit.state.status != AIChatStatus.answer &&
                cubit.state.status != AIChatStatus.recommend) {
              issue('sauvage_selection_not_resolved');
            }
            if (hasCards && externalCard) {
              issue('sauvage_selection_external_card');
            }
            break;
          case 3:
            if (cubit.state.status != AIChatStatus.recommend || !hasCards) {
              issue('dior_sauvage_exact_no_catalog_alternatives');
            }
            break;
          case 4:
            if (cubit.state.status == AIChatStatus.noMatch) {
              issue('sauvage_cheaper_no_match');
            }
            if (hasCards && externalCard) {
              issue('sauvage_cheaper_external_card');
            }
            break;
        }
      } else {
        switch (index) {
          case 1:
            if (hasCards) issue('social_rendered_cards');
            if (cubit.state.status == AIChatStatus.noMatch) {
              issue('social_no_match');
            }
            if (cubit.state.status == AIChatStatus.ask ||
                _containsAny(lowerContent, const [
                  'gender',
                  'men',
                  'women',
                  'male',
                  'female',
                  'РЁВ±РЁВ¬РЁВ§Р©вЂћР©Р‰',
                  'Р©вЂ РЁС–РЁВ§РЁВ¦Р©Р‰',
                  'Р©вЂћР©вЂћРЁВ±РЁВ¬РЁВ§Р©вЂћ',
                  'Р©вЂћР©вЂћР©вЂ РЁС–РЁВ§РЁРЋ',
                ])) {
              issue('social_routed_to_preference_ask');
            }
            if (lowerContent.contains('availability') ||
                lowerContent.contains('specific perfume')) {
              issue('social_routed_to_availability_copy');
            }
            break;
          case 2:
            if (hasCards) issue('sweet_ambiguity_rendered_cards');
            if (cubit.state.status != AIChatStatus.ask) {
              issue('sweet_ambiguity_not_ask');
            }
            if (stopwatch.elapsedMilliseconds > 3000) {
              caveat('sweet_ambiguity_not_fast');
            }
            if (!_containsAny(lowerContent, const [
              '\u0645\u0633\u0643\u0631\u0629',
              '\u062c\u0645\u064a\u0644\u0629',
              'sweet',
              'beautiful',
              'pleasant',
            ])) {
              caveat('sweet_ambiguity_not_sweet_vs_beautiful_copy');
            }
            break;
          case 3:
            if (cubit.state.preferences.preferredNotes
                    .map((item) => item.toLowerCase())
                    .contains('sweet') ||
                cubit.state.preferences.tags
                    .map((item) => item.toLowerCase())
                    .contains('sweet')) {
              issue('pleasant_phrase_became_sweet');
            }
            if (cubit.state.status == AIChatStatus.noMatch) {
              issue('pleasant_phrase_no_match');
            }
            break;
          case 4:
            if (cubit.state.status != AIChatStatus.recommend || !hasCards) {
              issue('basic_recommendation_failed');
            }
            previousRecommendationIds = ids.toSet();
            previousLowestPrice = prices.isEmpty
                ? null
                : prices.reduce((a, b) => a < b ? a : b);
            break;
          case 5:
            if (cubit.state.status == AIChatStatus.ask) {
              issue('university_refinement_asked_generic');
            }
            if (cubit.state.status == AIChatStatus.noMatch) {
              issue('university_refinement_no_match');
            }
            if (hasCards &&
                ids.toSet().containsAll(previousRecommendationIds)) {
              caveat('university_refinement_same_ids');
            }
            previousRecommendationIds = ids.toSet();
            previousLowestPrice = prices.isEmpty
                ? previousLowestPrice
                : prices.reduce((a, b) => a < b ? a : b);
            break;
          case 6:
            if (hasCards &&
                previousRecommendationIds
                    .intersection(ids.toSet())
                    .isNotEmpty) {
              issue('rejection_returned_same_products');
            }
            previousRecommendationIds = ids.toSet();
            previousLowestPrice = prices.isEmpty
                ? previousLowestPrice
                : prices.reduce((a, b) => a < b ? a : b);
            break;
          case 7:
            if (cubit.state.status != AIChatStatus.recommend || !hasCards) {
              issue('cheaper_followup_no_recommendations');
            }
            final priorLowest = previousLowestPrice;
            if (priorLowest != null &&
                prices.isNotEmpty &&
                !prices.any((price) => price < priorLowest)) {
              caveat('cheaper_followup_not_below_prior_lowest');
            }
            previousRecommendationIds = ids.toSet();
            previousLowestPrice = prices.isEmpty
                ? previousLowestPrice
                : prices.reduce((a, b) => a < b ? a : b);
            break;
          case 8:
            final mentionsLightBlue =
                lowerContent.contains('light blue') ||
                names.any((name) => name.toLowerCase().contains('light blue'));
            if (!mentionsLightBlue) issue('light_blue_not_resolved');
            break;
          case 9:
            if (cubit.state.status != AIChatStatus.recommend || !hasCards) {
              issue('external_profile_no_catalog_alternatives');
            }
            break;
          case 10:
            if (cubit.state.status != AIChatStatus.recommend || !hasCards) {
              issue('external_cheaper_no_catalog_alternatives');
            }
            break;
          case 11:
            if (cubit.state.status == AIChatStatus.error) {
              issue('external_followup_error');
            }
            if (hasCards && externalCard) {
              issue('external_followup_external_card');
            }
            break;
        }
      }

      final result = _TurnResult(
        index: index,
        message: message,
        status: cubit.state.status.name,
        type: last.type.name,
        source: last.responseSource,
        contentPreview: content.length > 180
            ? content.substring(0, 180)
            : content,
        productIds: ids,
        productNames: names,
        productPrices: prices,
        latencyMs: stopwatch.elapsedMilliseconds,
        issues: issues,
        caveats: caveats,
      );
      results.add(result);
      debugPrint(
        jsonEncode(<String, Object?>{
          'gate': deterministicGate,
          'turn': result.toJson(),
        }),
        wrapWidth: 1024,
      );
      return result;
    }

    final turns = helloOnly
        ? <String>['hello', 'hello']
        : w41ExternalAmbiguity
        ? <String>[
            'Something like Sauvage',
            '2',
            'Something like Dior Sauvage',
            'Something like Sauvage but cheaper',
          ]
        : <String>[
            'how are you',
            '\u0631\u0634\u062d\u0644\u064a \u0631\u064a\u062d\u0629 \u062d\u0644\u0648\u0629',
            '\u062c\u0645\u064a\u0644\u0629 \u0648\u0644\u0637\u064a\u0641\u0629',
            'I want a light fruity perfume for men',
            'make it suitable for university',
            "I don't like these",
            'show me something cheaper',
            'Do you have Light Blue?',
            'Something like Dior Sauvage',
            'Something like Dior Sauvage but cheaper',
            'cheaper than it',
          ];

    for (var i = 0; i < turns.length; i++) {
      if (i == 10) {
        await Future<void>.delayed(const Duration(seconds: 62));
        await tester.pump();
      }
      await sendTurn(i + 1, turns[i]);
    }

    final issueCount = results.fold<int>(
      0,
      (total, result) => total + result.issues.length,
    );
    final caveatCount = results.fold<int>(
      0,
      (total, result) => total + result.caveats.length,
    );
    final latencies = results.map((item) => item.latencyMs).toList();
    final summary = <String, Object?>{
      'gateEnabled': deterministicGate,
      'turnCount': results.length,
      'passCount': results.where((item) => item.issues.isEmpty).length,
      'failCount': results.where((item) => item.issues.isNotEmpty).length,
      'workerUsedCount': results
          .where((item) => (item.source ?? '').contains('worker'))
          .length,
      'fallbackUsedCount': results
          .where((item) => (item.source ?? '').contains('fallback'))
          .length,
      'noMatchCount': results.where((item) => item.status == 'noMatch').length,
      'genericMessageCount': results
          .where((item) => item.issues.contains('generic_message'))
          .length,
      'mojibakeCount': results
          .where((item) => item.issues.contains('mojibake'))
          .length,
      'invalidProductIdCount': results
          .where(
            (item) => item.issues.any(
              (issue) => issue.startsWith('invalid_product_ids'),
            ),
          )
          .length,
      'externalCardViolationCount': results
          .where((item) => item.issues.contains('external_product_card'))
          .length,
      'fakeProfileViolationCount': results
          .where(
            (item) => item.issues.contains(
              'fake_external_availability_or_price_claim',
            ),
          )
          .length,
      'sameProductsAfterRejectionCount': results
          .where(
            (item) => item.issues.contains('rejection_returned_same_products'),
          )
          .length,
      'over15sCount': results
          .where((item) => item.issues.contains('latency_over_15s'))
          .length,
      'avgLatencyMs': latencies.reduce((a, b) => a + b) / latencies.length,
      'maxLatencyMs': latencies.reduce((a, b) => a > b ? a : b),
      'uxCaveatCount': caveatCount,
      'externalLookupCount': repo.externalLookupCount,
      'cacheHitCount': repo.cacheHitCount,
      'eventCount': repo.sanitizedEvents.length,
    };

    final runName = helloOnly
        ? 'hello_gate_on'
        : w41ExternalAmbiguity
        ? 'w4_1_gate_on'
        : deterministicGate
        ? 'gate_on'
        : 'gate_off';
    final report = <String, Object?>{
      'summary': summary,
      'turns': results.map((item) => item.toJson()).toList(),
      'events': repo.sanitizedEvents,
      'summaryMarkdown': _summaryMarkdown(summary, results),
      'uxNotesMarkdown': _uxNotesMarkdown(results),
    };
    debugPrint(
      'FINAL_APP_REAL_BACKEND_SMOKE_REPORT_$runName '
      '${jsonEncode(report)}',
      wrapWidth: 4096,
    );

    binding.reportData = <String, Object?>{
      'finalAppRealBackendSmoke_$runName': summary,
    };

    expect(issueCount, 0, reason: _uxNotesMarkdown(results));
  }

  testWidgets(
    'final app real backend smoke with deterministic gate off',
    (tester) async {
      await runSmoke(tester: tester, deterministicGate: false);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  testWidgets(
    'final app real backend smoke with deterministic gate on',
    (tester) async {
      await runSmoke(tester: tester, deterministicGate: true);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  testWidgets(
    'W4.1 app real backend smoke with deterministic gate on',
    (tester) async {
      await runSmoke(
        tester: tester,
        deterministicGate: true,
        w41ExternalAmbiguity: true,
      );
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  testWidgets(
    'hello app real backend smoke with deterministic gate on',
    (tester) async {
      await runSmoke(tester: tester, deterministicGate: true, helloOnly: true);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

bool _containsAny(String value, Iterable<String> needles) {
  return needles.any(value.contains);
}

String _summaryMarkdown(Map<String, Object?> summary, List<_TurnResult> turns) {
  final buffer = StringBuffer()
    ..writeln('# Final App Real Backend Smoke')
    ..writeln()
    ..writeln('| Metric | Value |')
    ..writeln('|---|---:|');
  for (final entry in summary.entries) {
    buffer.writeln('| ${entry.key} | ${entry.value} |');
  }
  buffer
    ..writeln()
    ..writeln('## Turns')
    ..writeln()
    ..writeln(
      '| # | Message | Status | Type | Source | Products | Latency | Issues | Caveats |',
    )
    ..writeln('|---:|---|---|---|---|---|---:|---|---|');
  for (final turn in turns) {
    buffer.writeln(
      '| ${turn.index} | ${turn.message.replaceAll('|', '/')} | '
      '${turn.status} | ${turn.type} | ${turn.source ?? ''} | '
      '${turn.productIds.join(', ')} | ${turn.latencyMs}ms | '
      '${turn.issues.join(', ')} | ${turn.caveats.join(', ')} |',
    );
  }
  return buffer.toString();
}

String _uxNotesMarkdown(List<_TurnResult> turns) {
  final buffer = StringBuffer()
    ..writeln('# UX Notes')
    ..writeln();
  for (final turn in turns) {
    if (turn.issues.isEmpty && turn.caveats.isEmpty) continue;
    buffer
      ..writeln('## Turn ${turn.index}: ${turn.message}')
      ..writeln()
      ..writeln('- status: `${turn.status}`')
      ..writeln('- type: `${turn.type}`')
      ..writeln('- source: `${turn.source ?? ''}`')
      ..writeln('- latency: `${turn.latencyMs}ms`')
      ..writeln('- issues: `${turn.issues.join(', ')}`')
      ..writeln('- caveats: `${turn.caveats.join(', ')}`')
      ..writeln();
  }
  if (buffer.length <= '# UX Notes\n\n'.length) {
    buffer.writeln('No blocking UX issues or caveats were recorded.');
  }
  return buffer.toString();
}
