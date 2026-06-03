import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_catalog.dart';

class _MockAIChatRepo extends Mock implements AIChatRepo {}

class _MockUserTasteRepo extends Mock implements UserTasteRepo {}

void main() {
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

  test(
    'AI chat roadmap smoke scenarios write filtered AIChatCubit log',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = _MockAIChatRepo();
      final tasteRepo = _MockUserTasteRepo();
      final filteredLogs = <String>[];

      void logLine(String message) {
        filteredLogs.add('[AIChatCubit] $message');
      }

      final smokeCatalog = [
        mockCatalog[0].copyWith(
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
          topNotes: const ['citrus'],
          middleNotes: const ['fruity'],
          baseNotes: const ['musk'],
          tags: const ['fresh', 'clean'],
          stock: 8,
        ),
        mockCatalog[0].copyWith(
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
          topNotes: const ['citrus'],
          middleNotes: const ['floral'],
          baseNotes: const ['woody', 'musk'],
          tags: const ['fresh', 'clean', 'classic'],
          stock: 30,
        ),
        mockCatalog[0].copyWith(
          id: 'acqua',
          name: 'Acqua di Giò',
          brand: 'Giorgio Armani',
          price: 3350,
          gender: 'unisex',
          season: 'summer',
          occasion: 'office',
          time: 'day',
          intensity: 'medium',
          notes: const ['citrus', 'aquatic', 'fruity', 'woody'],
          topNotes: const ['aquatic'],
          middleNotes: const ['aquatic'],
          baseNotes: const ['amber'],
          tags: const ['fresh', 'clean', 'classic'],
          stock: 29,
        ),
        mockCatalog[0].copyWith(
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
          stock: 29,
        ),
        mockCatalog[0].copyWith(
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
          stock: 21,
        ),
        mockCatalog[0].copyWith(
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
          topNotes: const ['aquatic'],
          middleNotes: const ['fruity'],
          baseNotes: const ['woody'],
          tags: const ['fresh', 'clean', 'classic'],
          stock: 18,
        ),
        mockCatalog[0].copyWith(
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
          topNotes: const ['aquatic'],
          middleNotes: const ['citrus', 'fruity'],
          baseNotes: const ['amber', 'woody'],
          tags: const ['fresh', 'clean', 'classic'],
          stock: 15,
        ),
        mockCatalog[0].copyWith(
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
          stock: 32,
        ),
        mockCatalog[0].copyWith(
          id: 'the_noir',
          name: 'Thé Noir 29',
          brand: 'Le Labo',
          price: 6750,
          gender: 'unisex',
          season: 'autumn',
          occasion: 'office',
          time: 'day',
          intensity: 'medium',
          notes: const ['citrus', 'musk', 'fruity', 'woody'],
          tags: const ['fresh', 'clean'],
          stock: 24,
        ),
        mockCatalog[0].copyWith(
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
          stock: 23,
        ),
        mockCatalog[0].copyWith(
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
          stock: 27,
        ),
      ];

      Future<void> writeFilteredLog() async {
        final logFile = File(
          'test_artifacts/ai_chat_smoke/ai_chat_cubit_filtered.log',
        );
        await logFile.parent.create(recursive: true);
        await logFile.writeAsString('${filteredLogs.join('\n')}\n');
      }

      when(() => repo.canPersistSession).thenReturn(false);
      when(() => repo.currentUserId).thenReturn(null);
      when(() => repo.lastWorkerFailureReasonCode).thenReturn(null);
      when(
        () => repo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => smokeCatalog);
      when(() => repo.setSessionId(any())).thenReturn(null);
      when(() => repo.invalidateCatalogCache()).thenReturn(null);
      when(
        () => repo.fetchLatestRestorableSession(userId: any(named: 'userId')),
      ).thenThrow(TimeoutException('smoke worker timeout'));
      when(
        () => repo.fetchRestorableSessionById(
          sessionId: any(named: 'sessionId'),
          userId: any(named: 'userId'),
        ),
      ).thenThrow(TimeoutException('smoke worker timeout'));
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
      ).thenAnswer((_) async => null);
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

      Future<void> sendAndLog(String message) async {
        await cubit.sendMessage(message);
        final last = cubit.state.messages.last;
        logLine(
          'message="$message" status=${cubit.state.status.name} '
          'lastType=${last.type.name} source=${last.responseSource} '
          'products=${last.recommendedProducts.map((item) => item.product.id).toList()} '
          'content="${last.content.replaceAll(RegExp(r'\\s+'), ' ')}"',
        );
        await writeFilteredLog();
        printOnFailure(filteredLogs.join('\n'));
      }

      addTearDown(cubit.close);

      await sendAndLog('I want a light fruity perfume for men');
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(cubit.state.messages.last.recommendedProducts, hasLength(3));

      await sendAndLog('make it suitable for university');
      expect(cubit.state.status, AIChatStatus.recommend);

      final rejectedIds = cubit.state.messages.last.recommendedProducts
          .map((item) => item.product.id)
          .toSet();
      await sendAndLog("I don't like these");
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(
        cubit.state.messages.last.recommendedProducts
            .map((item) => item.product.id)
            .toSet()
            .intersection(rejectedIds),
        isEmpty,
      );

      await sendAndLog('show me something cheaper');
      expect(cubit.state.status, AIChatStatus.recommend);

      await sendAndLog('is the first one suitable for work?');
      expect(cubit.state.status, AIChatStatus.answer);
      expect(cubit.state.messages.last.recommendedProducts, isEmpty);

      await sendAndLog('budget 600');
      expect(cubit.state.status, AIChatStatus.noMatch);
      expect(
        cubit.state.recommendationMemory.lastNoMatchContext?.reason,
        'budget_no_match',
      );

      await sendAndLog('ok show me it');
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(
        cubit
            .state
            .messages
            .last
            .recommendedProducts
            .first
            .product
            .effectivePrice,
        790,
      );
      expect(
        cubit.state.messages.last.recommendedProducts.first.matchReason,
        contains('above your original 600 EGP budget'),
      );

      await sendAndLog('is Acqua di Giò suitable for office?');
      expect(cubit.state.status, AIChatStatus.answer);
      expect(cubit.state.messages.last.content, contains('Acqua di Gi'));

      await sendAndLog('similar but cheaper');
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(cubit.state.messages.last.recommendedProducts, isNotEmpty);
      expect(
        cubit.state.messages.last.recommendedProducts.every(
          (item) => item.product.effectivePrice < 3350,
        ),
        isTrue,
      );

      await cubit.close();
      cubit = createCubit();

      await sendAndLog('Do you have Light Blue?');
      expect(cubit.state.messages.last.content, contains('Light Blue'));

      await sendAndLog('أغلى عطر عندك');
      expect(cubit.state.status, AIChatStatus.recommend);
      expect(cubit.state.messages.last.recommendedProducts, hasLength(3));

      await writeFilteredLog();
      final logFile = File(
        'test_artifacts/ai_chat_smoke/ai_chat_cubit_filtered.log',
      );
      expect(await logFile.exists(), isTrue);
    },
  );
}
