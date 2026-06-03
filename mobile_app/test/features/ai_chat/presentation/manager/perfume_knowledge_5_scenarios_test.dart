import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

import 'mock_catalog.dart';

class MockAIChatRepo extends Mock implements AIChatRepo {}

void main() {
  setUpAll(() {
    registerFallbackValue(const SessionPreferences());
    registerFallbackValue(AIChatLanguage.english);
    registerFallbackValue(
      const ExternalPerfumeCandidate(
        id: '1',
        displayName: 'Fallback',
        brand: 'Fallback',
        sourceUrl:
            'https://www.fragranticarabia.com/perfumes/Fallback/Fallback-1.html',
      ),
    );
  });

  group('Perfume Knowledge 5 real scenarios', () {
    late MockAIChatRepo repo;
    late List<Map<String, Object?>> events;

    AIChatCubit buildCubit({
      required List<ProductModel> catalog,
      PerfumeKnowledgeProfile? knowledgeProfile,
      PerfumeKnowledgeProfile? externalProfile,
      ExternalPerfumeLookupResult? externalResult,
      PerfumeKnowledgeProfile? resolvedExternalProfile,
    }) {
      repo = MockAIChatRepo();
      events = <Map<String, Object?>>[];

      when(
        () => repo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => catalog);
      when(
        () => repo.lookupPerfumeKnowledge(any()),
      ).thenAnswer((_) async => knowledgeProfile);
      when(
        () => repo.lookupExternalPerfumeKnowledge(
          query: any(named: 'query'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((_) async => externalProfile);
      when(
        () => repo.lookupExternalPerfumeKnowledgeResult(
          query: any(named: 'query'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer(
        (_) async =>
            externalResult ??
            (externalProfile == null
                ? const ExternalPerfumeLookupResult.notFound()
                : ExternalPerfumeLookupResult.found(externalProfile)),
      );
      when(
        () => repo.resolveExternalPerfumeKnowledgeCandidate(
          candidate: any(named: 'candidate'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((_) async => resolvedExternalProfile);
      when(
        () => repo.logAIChatEvent(
          eventType: any(named: 'eventType'),
          sessionId: any(named: 'sessionId'),
          metadata: any(named: 'metadata'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((invocation) async {
        events.add({
          'eventType': invocation.namedArguments[#eventType],
          'metadata': invocation.namedArguments[#metadata],
        });
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
      ).thenAnswer((_) async {});

      return AIChatCubit(aiChatRepo: repo, thinkingDelay: Duration.zero);
    }

    PerfumeKnowledgeProfile sauvageProfile({
      String id = 'dior_sauvage_parfum',
    }) {
      return PerfumeKnowledgeProfile(
        id: id,
        displayName: 'Sauvage Parfum',
        brand: 'Dior',
        aliases: const ['dior sauvage parfum', 'sauvage parfum'],
        accords: const ['citrus', 'spicy', 'woody'],
        topNotes: const ['bergamot'],
        middleNotes: const ['spicy'],
        baseNotes: const ['woody'],
        fragranceFamily: 'aromatic fougere',
        genderHint: 'men',
        seasonHint: 'all_seasons',
        occasionHint: 'evening',
        timeHint: 'night',
        intensityHint: 'strong',
        sourceName: 'Fragrantica Arabia',
        sourceUrl:
            'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-Parfum-56324.html',
        extractionMethod: 'fragrantica_arabia',
        lookupConfidence: 0.94,
      );
    }

    PerfumeKnowledgeProfile azzaroPourHommeProfile() {
      return PerfumeKnowledgeProfile(
        id: 'azzaro_pour_homme',
        displayName: 'Azzaro Pour Homme',
        brand: 'Azzaro',
        aliases: const ['azzaro pour homme', 'azzaro homme'],
        accords: const ['citrus', 'spicy', 'woody', 'aromatic'],
        topNotes: const ['citrus'],
        middleNotes: const ['spicy'],
        baseNotes: const ['woody'],
        fragranceFamily: 'aromatic fougere',
        genderHint: 'men',
        seasonHint: 'all_seasons',
        occasionHint: 'daily',
        timeHint: 'all_day',
        intensityHint: 'medium',
        sourceName: 'Model perfume knowledge',
        lookupConfidence: 0.86,
      );
    }

    PerfumeKnowledgeProfile leMaleElixirProfile() {
      return const PerfumeKnowledgeProfile(
        id: 'le_male_elixir',
        displayName: 'Le Male Elixir',
        brand: 'Jean Paul Gaultier',
        aliases: ['le male elixir'],
        accords: ['vanilla', 'amber', 'sweet', 'aromatic'],
        topNotes: ['lavender'],
        middleNotes: ['vanilla', 'benzoin'],
        baseNotes: ['tonka bean', 'honey', 'tobacco'],
        fragranceFamily: 'aromatic fougere',
        genderHint: 'men',
        seasonHint: 'all_seasons',
        occasionHint: 'evening',
        timeHint: 'night',
        intensityHint: 'strong',
        sourceName: 'Fragrantica Arabia',
        sourceUrl:
            'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Le-Male-Elixir-81642.html',
        extractionMethod: 'fragrantica_arabia',
        lookupConfidence: 0.9,
      );
    }

    PerfumeKnowledgeProfile strongerWithYouSpicesProfile() {
      return const PerfumeKnowledgeProfile(
        id: 'stronger_with_you_spices',
        displayName: 'Emporio Armani Stronger With You Spices',
        brand: 'Giorgio Armani',
        aliases: [
          'emporio armani stronger with you spices',
          'stronger with you spices',
        ],
        accords: ['vanilla', 'warm spicy', 'amber', 'sweet', 'aromatic'],
        topNotes: ['pink pepper'],
        middleNotes: ['cinnamon', 'lavender'],
        baseNotes: ['vanilla', 'amberwood'],
        fragranceFamily: 'amber spicy',
        genderHint: 'men',
        seasonHint: 'winter',
        occasionHint: 'evening',
        timeHint: 'night',
        intensityHint: 'strong',
        sourceName: 'Fragrantica Arabia',
        sourceUrl:
            'https://www.fragranticarabia.com/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Spices-122057.html',
        extractionMethod: 'fragrantica_arabia',
        lookupConfidence: 0.82,
      );
    }

    List<ExternalPerfumeCandidate> strongerWithYouCandidates() {
      return const [
        ExternalPerfumeCandidate(
          id: '1',
          displayName: 'Emporio Armani Stronger With You Spices',
          brand: 'Giorgio Armani',
          sourceUrl:
              'https://www.fragranticarabia.com/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Spices-122057.html',
          score: 0.41,
        ),
      ];
    }

    List<ExternalPerfumeCandidate> leMaleCandidates() {
      return const [
        ExternalPerfumeCandidate(
          id: '1',
          displayName: 'Le Male Elixir',
          brand: 'Jean Paul Gaultier',
          sourceUrl:
              'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Le-Male-Elixir-81642.html',
          score: 0.82,
        ),
        ExternalPerfumeCandidate(
          id: '2',
          displayName: 'Le Male Le Parfum',
          brand: 'Jean Paul Gaultier',
          sourceUrl:
              'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Le-Male-Le-Parfum-72158.html',
          score: 0.79,
        ),
        ExternalPerfumeCandidate(
          id: '3',
          displayName: 'Le Male',
          brand: 'Jean Paul Gaultier',
          sourceUrl:
              'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Le-Male-430.html',
          score: 0.75,
        ),
      ];
    }

    ProductModel sauvageCatalogProduct({int stock = 5}) {
      return mockCatalog[1].copyWith(
        id: 'catalog_sauvage',
        name: 'Sauvage Parfum',
        brand: 'Dior',
        stock: stock,
        gender: 'men',
        season: 'all_seasons',
        occasion: 'evening',
        time: 'night',
        intensity: 'strong',
        fragranceFamily: 'amber fougere',
        notes: const ['citrus', 'woody', 'amber', 'vanilla'],
        topNotes: const ['bergamot'],
        middleNotes: const ['sandalwood'],
        baseNotes: const ['tonka bean', 'vanilla'],
        tags: const ['citrus', 'woody', 'amber', 'warm spicy'],
      );
    }

    ProductModel substituteProduct({String id = 'catalog_substitute'}) {
      return mockCatalog[0].copyWith(
        id: id,
        name: 'Urban Savage Twist',
        brand: 'Qissa',
        stock: 9,
        gender: 'men',
        season: 'all_seasons',
        occasion: 'evening',
        time: 'night',
        intensity: 'strong',
        fragranceFamily: 'aromatic fougere',
        notes: const ['citrus', 'spicy', 'woody'],
        topNotes: const ['bergamot'],
        middleNotes: const ['spicy'],
        baseNotes: const ['woody'],
        tags: const ['fresh', 'bold', 'classic', 'aromatic'],
      );
    }

    ProductModel azzaroStyleSubstitute() {
      return mockCatalog[0].copyWith(
        id: 'catalog_azzaro_style',
        name: 'Classic Lavender Woods',
        brand: 'Qissa',
        stock: 11,
        gender: 'men',
        season: 'all_seasons',
        occasion: 'daily',
        time: 'all_day',
        intensity: 'medium',
        fragranceFamily: 'aromatic fougere',
        notes: const ['citrus', 'spicy', 'woody'],
        topNotes: const ['citrus'],
        middleNotes: const ['spicy'],
        baseNotes: const ['woody'],
        tags: const ['fresh', 'bold', 'classic', 'aromatic'],
      );
    }

    ProductModel leMaleStyleSubstitute() {
      return mockCatalog[2].copyWith(
        id: 'catalog_le_male_style',
        name: 'Honey Tobacco Vanilla',
        brand: 'Qissa',
        stock: 8,
        gender: 'men',
        season: 'all_seasons',
        occasion: 'evening',
        time: 'night',
        intensity: 'strong',
        fragranceFamily: 'aromatic fougere',
        notes: const ['vanilla', 'amber', 'sweet', 'honey', 'tobacco'],
        topNotes: const ['lavender'],
        middleNotes: const ['vanilla'],
        baseNotes: const ['tonka bean', 'honey', 'tobacco'],
        tags: const ['vanilla', 'sweet', 'amber', 'aromatic'],
      );
    }

    ProductModel strongerWithYouStyleSubstitute() {
      return mockCatalog[2].copyWith(
        id: 'catalog_stronger_style',
        name: 'Amber Vanilla Spice',
        brand: 'Qissa',
        stock: 7,
        gender: 'men',
        season: 'winter',
        occasion: 'evening',
        time: 'night',
        intensity: 'strong',
        fragranceFamily: 'amber spicy',
        notes: const ['vanilla', 'warm spicy', 'amber', 'sweet', 'aromatic'],
        topNotes: const ['pink pepper'],
        middleNotes: const ['cinnamon', 'lavender'],
        baseNotes: const ['vanilla', 'amberwood'],
        tags: const ['vanilla', 'warm spicy', 'amber', 'sweet'],
      );
    }

    Future<void> runScenario({
      required String id,
      required AIChatCubit cubit,
      required String message,
      required void Function(AIChatState state) assertState,
    }) async {
      await cubit.sendMessage(message);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final state = cubit.state;

      final last = state.messages.last;
      final productNames = last.recommendedProducts
          .map((item) => item.product.name)
          .toList(growable: false);
      final eventNames = events
          .map((event) => event['eventType'].toString())
          .toList(growable: false);

      // ignore: avoid_print
      print(
        '[PK-5] $id | status=${state.status.name} | '
        'messageType=${last.type.name} | products=$productNames | '
        'events=$eventNames | content="${last.content}"',
      );

      assertState(state);
    }

    blocTest<AIChatCubit, AIChatState>(
      'S1 catalog hit returns the catalog product only',
      build: () => buildCubit(catalog: [sauvageCatalogProduct()]),
      act: (cubit) => runScenario(
        id: 'S1_CATALOG_HIT',
        cubit: cubit,
        message: 'Do you have Sauvage Parfum?',
        assertState: (state) {
          expect(state.status, AIChatStatus.answer);
          expect(state.messages.last.type, MessageType.availability);
          expect(
            state.messages.last.recommendedProducts.single.product.id,
            'catalog_sauvage',
          );
          expect(
            events.map((event) => event['eventType']),
            contains('availability_catalog_found'),
          );
        },
      ),
    );

    blocTest<AIChatCubit, AIChatState>(
      'S2 out of stock catalog product returns available substitute',
      build: () => buildCubit(
        catalog: [
          mockCatalog[1].copyWith(stock: 0),
          mockCatalog[1].copyWith(
            id: 'catalog_substitute',
            name: 'Cedar Reserve',
            stock: 8,
          ),
        ],
      ),
      act: (cubit) => runScenario(
        id: 'S2_OUT_OF_STOCK_SUBSTITUTE',
        cubit: cubit,
        message: 'Do you have Cedar Class 01?',
        assertState: (state) {
          expect(state.status, AIChatStatus.answer);
          expect(state.messages.last.type, MessageType.availability);
          expect(
            state.messages.last.recommendedProducts.first.product.id,
            'catalog_substitute',
          );
          expect(
            events.map((event) => event['eventType']),
            contains('availability_catalog_out_of_stock_substitute'),
          );
        },
      ),
    );

    blocTest<AIChatCubit, AIChatState>(
      'S3 perfume knowledge hit returns catalog-only substitute',
      build: () => buildCubit(
        catalog: [substituteProduct()],
        knowledgeProfile: sauvageProfile(),
      ),
      act: (cubit) => runScenario(
        id: 'S3_KNOWLEDGE_HIT',
        cubit: cubit,
        message: 'Do you have Sauvage Parfum?',
        assertState: (state) {
          expect(state.status, AIChatStatus.answer);
          expect(state.messages.last.type, MessageType.availability);
          expect(
            state.messages.last.recommendedProducts.single.product.id,
            'catalog_substitute',
          );
          verifyNever(
            () => repo.lookupExternalPerfumeKnowledgeResult(
              query: any(named: 'query'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
          expect(
            events.map((event) => event['eventType']),
            contains('perfume_knowledge_hit'),
          );
        },
      ),
    );

    blocTest<AIChatCubit, AIChatState>(
      'S4 external lookup success is saved and returns substitute',
      build: () => buildCubit(
        catalog: [azzaroStyleSubstitute()],
        externalProfile: azzaroPourHommeProfile(),
      ),
      act: (cubit) => runScenario(
        id: 'S4_EXTERNAL_SUCCESS',
        cubit: cubit,
        message: 'Do you have Azzaro Pour Homme?',
        assertState: (state) {
          expect(state.status, AIChatStatus.answer);
          expect(state.messages.last.type, MessageType.availability);
          expect(
            state.messages.last.recommendedProducts.single.product.id,
            'catalog_azzaro_style',
          );
          expect(
            events.map((event) => event['eventType']),
            containsAll([
              'perfume_knowledge_external_lookup_success',
              'perfume_knowledge_saved_needs_review',
              'availability_external_substitute_shown',
            ]),
          );
        },
      ),
    );

    blocTest<AIChatCubit, AIChatState>(
      'S5 unknown external failure asks for scent style and shows no card',
      build: () => buildCubit(catalog: [substituteProduct()]),
      act: (cubit) => runScenario(
        id: 'S5_EXTERNAL_FAIL_ASK',
        cubit: cubit,
        message: 'Do you have Moon Volcano Essence?',
        assertState: (state) {
          expect(state.status, AIChatStatus.ask);
          expect(state.messages.last.type, MessageType.text);
          expect(state.messages.last.recommendedProducts, isEmpty);
          expect(
            events.map((event) => event['eventType']),
            containsAll([
              'perfume_knowledge_miss',
              'perfume_knowledge_external_lookup_failed',
              'availability_external_unknown_asked',
            ]),
          );
        },
      ),
    );

    blocTest<AIChatCubit, AIChatState>(
      'S6 Azzaro Pour Homme external profile recommends catalog-only substitute',
      build: () => buildCubit(
        catalog: [azzaroStyleSubstitute()],
        externalProfile: azzaroPourHommeProfile(),
      ),
      act: (cubit) => runScenario(
        id: 'S6_AZZARO_POUR_HOMME_EXTERNAL',
        cubit: cubit,
        message: 'Do you have Azzaro Pour Homme?',
        assertState: (state) {
          expect(state.status, AIChatStatus.answer);
          expect(state.messages.last.type, MessageType.availability);
          expect(
            state.messages.last.recommendedProducts.single.product.id,
            'catalog_azzaro_style',
          );
          expect(
            state.messages.last.recommendedProducts.single.product.name,
            isNot('Azzaro Pour Homme'),
          );
          expect(
            state.messages.last.content,
            contains('Azzaro Pour Homme is not available'),
          );
          expect(
            events.map((event) => event['eventType']),
            containsAll([
              'perfume_knowledge_miss',
              'perfume_knowledge_external_lookup_success',
              'perfume_knowledge_saved_needs_review',
              'availability_external_substitute_shown',
            ]),
          );
        },
      ),
    );

    blocTest<AIChatCubit, AIChatState>(
      'S7 ambiguous external candidates resolve from partial follow-up',
      build: () => buildCubit(
        catalog: [leMaleStyleSubstitute()],
        externalResult: ExternalPerfumeLookupResult.ambiguous(
          leMaleCandidates(),
        ),
        resolvedExternalProfile: leMaleElixirProfile(),
      ),
      act: (cubit) async {
        await cubit.sendMessage('Do you have Le Male?');
        expect(cubit.state.status, AIChatStatus.ask);
        expect(
          cubit.state.availabilityContext.externalCandidates,
          hasLength(3),
        );
        expect(cubit.state.messages.last.content, contains('Le Male Elixir'));
        await cubit.sendMessage('Elixir');
      },
      verify: (cubit) {
        expect(cubit.state.status, AIChatStatus.answer);
        expect(cubit.state.messages.last.type, MessageType.availability);
        expect(
          cubit.state.messages.last.recommendedProducts.single.product.id,
          'catalog_le_male_style',
        );
        verify(
          () => repo.resolveExternalPerfumeKnowledgeCandidate(
            candidate: any(
              named: 'candidate',
              that: predicate<ExternalPerfumeCandidate>(
                (candidate) => candidate.displayName == 'Le Male Elixir',
              ),
            ),
            requestId: any(named: 'requestId'),
          ),
        ).called(1);
      },
    );

    blocTest<AIChatCubit, AIChatState>(
      'S8 single external candidate accepts affirmative follow-up',
      build: () => buildCubit(
        catalog: [strongerWithYouStyleSubstitute()],
        externalResult: ExternalPerfumeLookupResult.ambiguous(
          strongerWithYouCandidates(),
        ),
        resolvedExternalProfile: strongerWithYouSpicesProfile(),
      ),
      act: (cubit) async {
        await cubit.sendMessage('is Stronger With You Intensely available ?');
        expect(cubit.state.status, AIChatStatus.ask);
        expect(
          cubit.state.availabilityContext.externalCandidates,
          hasLength(1),
        );
        expect(cubit.state.messages.last.content, startsWith('Do you mean'));
        await cubit.sendMessage('yes');
      },
      verify: (cubit) {
        expect(
          cubit.state.messages.last.content,
          isNot(contains('That choice is still unclear')),
        );
        expect(
          cubit.state.messages.last.content,
          anyOf(contains('scent profile'), contains('similar in profile')),
        );
        verify(
          () => repo.resolveExternalPerfumeKnowledgeCandidate(
            candidate: any(
              named: 'candidate',
              that: predicate<ExternalPerfumeCandidate>(
                (candidate) =>
                    candidate.displayName ==
                    'Emporio Armani Stronger With You Spices',
              ),
            ),
            requestId: any(named: 'requestId'),
          ),
        ).called(1);
      },
    );
  });
}
