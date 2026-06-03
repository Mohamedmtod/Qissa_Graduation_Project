import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseUser extends Mock implements User {}

class MockProductRepo extends Mock implements ProductRepo {}

ProductModel _product(String id) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: 'Perfume $id',
    nameLower: 'perfume $id',
    searchPrefixes: buildSearchPrefixes('Perfume $id'),
    brand: 'Brand',
    price: 100,
    stock: 1,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: const ['citrus'],
    imageUrls: const ['https://example.com/p.png'],
    description: 'desc',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: true,
    occasion: 'daily',
    time: 'all_day',
    intensity: 'medium',
    topNotes: const ['citrus'],
    middleNotes: const ['woody'],
    baseNotes: const ['musk'],
    tags: const ['fresh'],
  );
}

void main() {
  group('AIChatRepo.getCatalog', () {
    test('filters inactive products from catalog', () async {
      final repo = AIChatRepo.forCatalogTest(
        catalogFetcher: () async => [
          _product('active'),
          _product('inactive').copyWith(isActive: false),
        ],
      );

      final catalog = await repo.getCatalog();

      expect(catalog.map((p) => p.id), ['active']);
    });

    test('uses cache within TTL window', () async {
      var callCount = 0;
      var currentTime = DateTime(2026, 4, 5, 12);

      final repo = AIChatRepo.forCatalogTest(
        catalogFetcher: () async {
          callCount++;
          return [_product('p$callCount')];
        },
        nowProvider: () => currentTime,
      );

      final first = await repo.getCatalog();
      currentTime = currentTime.add(const Duration(minutes: 1));
      final second = await repo.getCatalog();

      expect(first.single.id, 'p1');
      expect(second.single.id, 'p1');
      expect(callCount, 1);
    });

    test('refetches after TTL expiry', () async {
      var callCount = 0;
      var currentTime = DateTime(2026, 4, 5, 12);

      final repo = AIChatRepo.forCatalogTest(
        catalogFetcher: () async {
          callCount++;
          return [_product('p$callCount')];
        },
        nowProvider: () => currentTime,
      );

      final first = await repo.getCatalog();
      currentTime = currentTime.add(const Duration(minutes: 3));
      final refreshed = await repo.getCatalog();

      expect(first.single.id, 'p1');
      expect(refreshed.single.id, 'p2');
      expect(callCount, 2);
    });

    test('invalidateCatalog forces next call to fetch fresh data', () async {
      var callCount = 0;
      final repo = AIChatRepo.forCatalogTest(
        catalogFetcher: () async {
          callCount++;
          return [_product('p$callCount')];
        },
      );

      final first = await repo.getCatalog();
      repo.invalidateCatalog();
      final refreshed = await repo.getCatalog();

      expect(first.single.id, 'p1');
      expect(refreshed.single.id, 'p2');
      expect(callCount, 2);
    });

    test(
      'invalidateCatalogCache forces next call to fetch fresh data',
      () async {
        var callCount = 0;
        final repo = AIChatRepo.forCatalogTest(
          catalogFetcher: () async {
            callCount++;
            return [_product('p$callCount')];
          },
        );

        final first = await repo.getCatalog();
        repo.invalidateCatalogCache();
        final refreshed = await repo.getCatalog();

        expect(first.single.id, 'p1');
        expect(refreshed.single.id, 'p2');
        expect(callCount, 2);
      },
    );

    test('forceRefresh bypasses cached catalog data', () async {
      var callCount = 0;
      final repo = AIChatRepo.forCatalogTest(
        catalogFetcher: () async {
          callCount++;
          return [_product(callCount == 1 ? 'old' : 'new')];
        },
      );

      final first = await repo.getCatalog();
      final refreshed = await repo.getCatalog(forceRefresh: true);

      expect(first.single.id, 'old');
      expect(refreshed.single.id, 'new');
      expect(callCount, 2);
    });
  });

  group('AIChatRepo analysis transcript handling', () {
    test('availability messages keep availability transcript type', () {
      final repo = AIChatRepo.forCatalogTest(catalogFetcher: () async => []);
      final transcript = [
        AIChatStoredMessage(
          id: 'u1',
          sessionId: 's1',
          role: AIChatMessageRole.user,
          content: 'Is Perfume p1 available?',
          messageType: AIChatMessageType.text,
          productIds: const [],
          createdAt: DateTime.utc(2026, 4, 20),
        ),
        AIChatStoredMessage(
          id: 'a1',
          sessionId: 's1',
          role: AIChatMessageRole.assistant,
          content: 'Yes, it is available now: Perfume p1 for 100 EGP.',
          messageType: AIChatMessageType.availability,
          productIds: const ['p1'],
          createdAt: DateTime.utc(2026, 4, 20),
        ),
      ];

      final payload = repo.buildAnalysisPayloadFromTranscriptForTesting(
        sessionId: 's1',
        preferences: const SessionPreferences(),
        transcript: transcript,
      );

      expect(payload.finalRecommendationProductIds, isEmpty);
      expect(payload.finalRecommendationMessageId, isNull);
      expect(payload.entries.last.messageType, equals('availability'));
      expect(payload.entries.last.productIds, equals(['p1']));
    });
  });

  group('AIChatRepo worker authentication', () {
    test(
      'skips worker call when Firebase user is missing and guest worker is disabled',
      () async {
        final auth = MockFirebaseAuth();
        when(() => auth.currentUser).thenReturn(null);

        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                throw StateError('Worker HTTP call should not be attempted.');
              },
            ),
          );

        final repo = AIChatRepo(
          productRepo: MockProductRepo(),
          auth: auth,
          dio: dio,
          workerBaseUrl: 'https://worker.example.test',
          allowGuestWorkerRequests: false,
        );

        final reply = await repo.fetchAIRecommendation(
          currentMessage: 'recommend something fresh',
          preferences: const SessionPreferences(),
          candidates: [_product('p1')],
          responseLanguage: AIChatLanguage.english,
          requestId: 'req-guest',
        );

        expect(reply, isNull);
        expect(repo.lastWorkerFailureReasonCode, 'worker_auth_required');
      },
    );

    test(
      'allows guest worker call without Authorization when explicitly enabled',
      () async {
        final auth = MockFirebaseAuth();
        when(() => auth.currentUser).thenReturn(null);

        final seenHeaders = <String, dynamic>{};
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                seenHeaders.addAll(options.headers);
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'action_type': 'ask',
                      'question': 'What budget do you prefer?',
                      'updated_preferences': <String, dynamic>{},
                    },
                  ),
                );
              },
            ),
          );

        final repo = AIChatRepo(
          productRepo: MockProductRepo(),
          auth: auth,
          dio: dio,
          workerBaseUrl: 'https://worker.example.test',
          allowGuestWorkerRequests: true,
        );

        final reply = await repo.fetchAIRecommendation(
          currentMessage: 'recommend something fresh',
          preferences: const SessionPreferences(),
          candidates: [_product('p1')],
          responseLanguage: AIChatLanguage.english,
          requestId: 'req-guest-allowed',
        );

        expect(reply, isNotNull);
        expect(reply?.actionType, ActionType.ask);
        expect(seenHeaders['Content-Type'], 'application/json');
        expect(seenHeaders.containsKey('Authorization'), isFalse);
        expect(repo.lastWorkerFailureReasonCode, isNull);
      },
    );

    test(
      'classifies worker network timeout without throwing raw error',
      () async {
        final auth = MockFirebaseAuth();
        final user = MockFirebaseUser();
        when(() => auth.currentUser).thenReturn(user);
        when(() => user.uid).thenReturn('u1');
        when(() => user.getIdToken()).thenAnswer((_) async => 'token');

        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.receiveTimeout,
                    message: 'worker timed out',
                  ),
                );
              },
            ),
          );

        final repo = AIChatRepo(
          productRepo: MockProductRepo(),
          auth: auth,
          dio: dio,
          workerBaseUrl: 'https://worker.example.test',
        );

        final reply = await repo.fetchAIRecommendation(
          currentMessage: 'recommend something fresh',
          preferences: const SessionPreferences(),
          candidates: [_product('p1')],
          responseLanguage: AIChatLanguage.english,
          requestId: 'req-timeout',
        );

        expect(reply, isNull);
        expect(repo.lastWorkerFailureReasonCode, 'worker_timeout');
      },
    );

    test(
      'invalid worker tool call is rejected as parse error safely',
      () async {
        final auth = MockFirebaseAuth();
        final user = MockFirebaseUser();
        when(() => auth.currentUser).thenReturn(user);
        when(() => user.uid).thenReturn('u1');
        when(() => user.getIdToken()).thenAnswer((_) async => 'token');

        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'schemaVersion': 2,
                      'type': 'tool_call',
                      'toolCall': {
                        'name': 'delete_products',
                        'arguments': <String, dynamic>{},
                      },
                    },
                  ),
                );
              },
            ),
          );

        final repo = AIChatRepo(
          productRepo: MockProductRepo(),
          auth: auth,
          dio: dio,
          workerBaseUrl: 'https://worker.example.test',
        );

        final reply = await repo.fetchAIRecommendation(
          currentMessage: 'recommend something fresh',
          preferences: const SessionPreferences(),
          candidates: [_product('p1')],
          responseLanguage: AIChatLanguage.english,
          requestId: 'req-invalid-tool',
        );

        expect(reply, isNull);
        expect(repo.lastWorkerFailureReasonCode, 'worker_parse_error');
      },
    );

    test(
      'retries worker recommendation once with refreshed token on 401',
      () async {
        final auth = MockFirebaseAuth();
        final user = MockFirebaseUser();
        when(() => auth.currentUser).thenReturn(user);
        when(() => user.uid).thenReturn('u1');
        when(() => user.getIdToken()).thenAnswer((_) async => 'stale-token');
        when(
          () => user.getIdToken(true),
        ).thenAnswer((_) async => 'fresh-token');

        final seenAuthHeaders = <String>[];
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                seenAuthHeaders.add(
                  options.headers['Authorization']?.toString() ?? '',
                );
                if (seenAuthHeaders.length == 1) {
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      response: Response(
                        requestOptions: options,
                        statusCode: 401,
                        data: const {'error': 'Unauthorized'},
                      ),
                      type: DioExceptionType.badResponse,
                    ),
                  );
                  return;
                }

                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'action_type': 'ask',
                      'question': 'What budget do you prefer?',
                      'updated_preferences': <String, dynamic>{},
                    },
                  ),
                );
              },
            ),
          );

        final repo = AIChatRepo(
          productRepo: MockProductRepo(),
          auth: auth,
          dio: dio,
          workerBaseUrl: 'https://worker.example.test',
        );

        final reply = await repo.fetchAIRecommendation(
          currentMessage: 'recommend something fresh',
          preferences: const SessionPreferences(),
          candidates: [_product('p1')],
          responseLanguage: AIChatLanguage.english,
          requestId: 'req-retry',
        );

        expect(reply?.isAsk, isTrue);
        expect(seenAuthHeaders, ['Bearer stale-token', 'Bearer fresh-token']);
      },
    );

    test(
      'sends compact context only through context-aware worker request',
      () async {
        final auth = MockFirebaseAuth();
        final user = MockFirebaseUser();
        when(() => auth.currentUser).thenReturn(user);
        when(() => user.uid).thenReturn('u1');
        when(() => user.getIdToken()).thenAnswer((_) async => 'token');

        Map<String, dynamic>? seenPayload;
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                seenPayload = Map<String, dynamic>.from(
                  options.data as Map<String, dynamic>,
                );
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'action_type': 'ask',
                      'question': 'What budget do you prefer?',
                      'updated_preferences': <String, dynamic>{},
                    },
                  ),
                );
              },
            ),
          );

        final repo = AIChatRepo(
          productRepo: MockProductRepo(),
          auth: auth,
          dio: dio,
          workerBaseUrl: 'https://worker.example.test',
        );

        final reply = await repo.fetchAIRecommendationWithContext(
          currentMessage: 'لكله',
          preferences: const SessionPreferences(
            gender: 'women',
            maxBudget: 4500,
          ),
          candidates: [_product('p1')],
          compactContext: const AIChatCompactConversationContext(
            recentMessages: [
              AIChatCompactMessage(role: 'user', text: 'حريمي'),
              AIChatCompactMessage(
                role: 'assistant',
                text: 'الاستخدام صيفي ولا شتوي ولا لكل المواسم؟',
              ),
              AIChatCompactMessage(role: 'user', text: 'لكله'),
            ],
            lastAssistantQuestion: 'الاستخدام صيفي ولا شتوي ولا لكل المواسم؟',
            lastAskSlot: 'season',
            lastVisibleProductIds: ['p1'],
            hasRecommendationContext: true,
            lastTurnWasAsk: true,
          ),
          responseLanguage: AIChatLanguage.arabic,
          requestId: 'req-context',
        );

        expect(reply?.isAsk, isTrue);
        expect(seenPayload?['currentMessage'], 'لكله');
        expect(seenPayload?['recentMessages'], isA<List>());
        expect(seenPayload?['lastAssistantQuestion'], contains('المواسم'));
        expect(seenPayload?['lastAskSlot'], 'season');
        expect(seenPayload?['lastVisibleProductIds'], ['p1']);
        expect(
          seenPayload?['conversationContext'],
          containsPair('lastTurnWasAsk', true),
        );
      },
    );
  });
}
