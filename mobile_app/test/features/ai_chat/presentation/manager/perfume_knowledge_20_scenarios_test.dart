import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_interpretation_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
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

  group('Perfume Knowledge 20 strength scenarios', () {
    late MockAIChatRepo repo;
    late List<Map<String, Object?>> events;

    AIChatCubit buildCubit({
      required List<ProductModel> catalog,
      PerfumeKnowledgeProfile? Function(String query)? knowledgeResolver,
      ExternalPerfumeLookupResult Function(String query)? externalResolver,
      PerfumeKnowledgeProfile? Function(ExternalPerfumeCandidate candidate)?
      candidateResolver,
      AIChatInterpretationResult? Function(String message)?
      interpretationResolver,
    }) {
      repo = MockAIChatRepo();
      events = <Map<String, Object?>>[];

      when(
        () => repo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => catalog);
      when(() => repo.lookupPerfumeKnowledge(any())).thenAnswer((invocation) {
        final query = invocation.positionalArguments.first as String;
        return Future.value(knowledgeResolver?.call(query));
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
      ).thenAnswer((invocation) {
        final message = invocation.namedArguments[#currentMessage] as String;
        return Future.value(interpretationResolver?.call(message));
      });
      when(
        () => repo.lookupExternalPerfumeKnowledge(
          query: any(named: 'query'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((invocation) {
        final query = invocation.namedArguments[#query] as String;
        final result = externalResolver?.call(query);
        return Future.value(result?.profile);
      });
      when(
        () => repo.lookupExternalPerfumeKnowledgeResult(
          query: any(named: 'query'),
          responseLanguage: any(named: 'responseLanguage'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((invocation) {
        final query = invocation.namedArguments[#query] as String;
        return Future.value(
          externalResolver?.call(query) ??
              const ExternalPerfumeLookupResult.notFound(),
        );
      });
      when(
        () => repo.resolveExternalPerfumeKnowledgeCandidate(
          candidate: any(named: 'candidate'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((invocation) {
        final candidate =
            invocation.namedArguments[#candidate] as ExternalPerfumeCandidate;
        return Future.value(candidateResolver?.call(candidate));
      });
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

    Future<AIChatState> send(AIChatCubit cubit, String message) async {
      await cubit.sendMessage(message);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return cubit.state;
    }

    void logScenario(String id, AIChatState state) {
      final last = state.messages.last;
      final products = last.recommendedProducts
          .map((item) => '${item.product.name}#${item.product.id}')
          .toList(growable: false);
      final eventNames = events
          .map((event) => event['eventType'].toString())
          .toList(growable: false);

      // ignore: avoid_print
      print(
        '[PK-20] $id | status=${state.status.name} | '
        'type=${last.type.name} | products=$products | '
        'availability=${state.availabilityContext.availabilityStatus.name} | '
        'events=$eventNames | content="${last.content}"',
      );
    }

    Future<void> runScenario(
      String id,
      AIChatCubit cubit,
      String message,
      void Function(AIChatState state) assertState,
    ) async {
      final state = await send(cubit, message);
      logScenario(id, state);
      assertState(state);
      await cubit.close();
    }

    PerfumeKnowledgeProfile profile({
      required String id,
      required String displayName,
      required String brand,
      required List<String> accords,
      List<String> aliases = const [],
      List<String> topNotes = const [],
      List<String> middleNotes = const [],
      List<String> baseNotes = const [],
      String family = 'aromatic fougere',
      String? gender = 'men',
      String? season = 'all_seasons',
      String? occasion = 'evening',
      String? time = 'night',
      String? intensity = 'strong',
      String? sourceUrl,
      String extractionMethod = 'fragrantica_arabia',
      double confidence = 0.9,
    }) {
      return PerfumeKnowledgeProfile(
        id: id,
        displayName: displayName,
        brand: brand,
        aliases: aliases,
        accords: accords,
        topNotes: topNotes,
        middleNotes: middleNotes,
        baseNotes: baseNotes,
        fragranceFamily: family,
        genderHint: gender,
        seasonHint: season,
        occasionHint: occasion,
        timeHint: time,
        intensityHint: intensity,
        sourceName: 'Fragrantica Arabia',
        sourceUrl: sourceUrl,
        extractionMethod: extractionMethod,
        lookupConfidence: confidence,
      );
    }

    PerfumeKnowledgeProfile sauvageProfile() => profile(
      id: 'dior_sauvage_parfum',
      displayName: 'Sauvage Parfum',
      brand: 'Dior',
      aliases: const ['dior sauvage parfum', 'sauvage parfum'],
      accords: const ['citrus', 'spicy', 'woody'],
      topNotes: const ['bergamot'],
      middleNotes: const ['spicy'],
      baseNotes: const ['woody'],
      sourceUrl:
          'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-Parfum-56324.html',
    );

    PerfumeKnowledgeProfile azzaroProfile() => profile(
      id: 'azzaro_pour_homme',
      displayName: 'Azzaro Pour Homme',
      brand: 'Azzaro',
      aliases: const ['azzaro pour homme', 'azzaro homme'],
      accords: const ['citrus', 'spicy', 'woody', 'aromatic'],
      topNotes: const ['citrus'],
      middleNotes: const ['spicy'],
      baseNotes: const ['woody'],
      occasion: 'daily',
      time: 'all_day',
      intensity: 'medium',
    );

    PerfumeKnowledgeProfile leMaleElixirProfile() => profile(
      id: 'le_male_elixir',
      displayName: 'Le Male Elixir',
      brand: 'Jean Paul Gaultier',
      aliases: const ['le male elixir'],
      accords: const ['vanilla', 'amber', 'sweet', 'aromatic'],
      topNotes: const ['lavender'],
      middleNotes: const ['vanilla', 'benzoin'],
      baseNotes: const ['tonka bean', 'honey', 'tobacco'],
      sourceUrl:
          'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Le-Male-Elixir-81642.html',
    );

    PerfumeKnowledgeProfile leMaleParfumProfile() => profile(
      id: 'le_male_le_parfum',
      displayName: 'Le Male Le Parfum',
      brand: 'Jean Paul Gaultier',
      aliases: const ['le male le parfum'],
      accords: const ['vanilla', 'amber', 'spicy', 'powdery'],
      topNotes: const ['cardamom'],
      middleNotes: const ['lavender', 'iris'],
      baseNotes: const ['vanilla'],
    );

    PerfumeKnowledgeProfile strongerProfile() => profile(
      id: 'stronger_with_you_spices',
      displayName: 'Emporio Armani Stronger With You Spices',
      brand: 'Giorgio Armani',
      aliases: const ['stronger with you spices'],
      accords: const ['vanilla', 'warm spicy', 'amber', 'sweet', 'aromatic'],
      topNotes: const ['pink pepper'],
      middleNotes: const ['cinnamon', 'lavender'],
      baseNotes: const ['vanilla', 'amberwood'],
      family: 'amber spicy',
      season: 'winter',
    );

    PerfumeKnowledgeProfile modelNeedsRefreshProfile() => profile(
      id: 'model_only_sauvage',
      displayName: 'Sauvage Parfum',
      brand: 'Dior',
      aliases: const ['sauvage parfum'],
      accords: const ['citrus', 'woody'],
      extractionMethod: 'model',
      sourceUrl: null,
      confidence: 0.7,
    );

    List<ExternalPerfumeCandidate> leMaleCandidates({int count = 3}) {
      final candidates = <ExternalPerfumeCandidate>[
        const ExternalPerfumeCandidate(
          id: '1',
          displayName: 'Le Male Elixir',
          brand: 'Jean Paul Gaultier',
          sourceUrl:
              'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Le-Male-Elixir-81642.html',
          score: 0.82,
        ),
        const ExternalPerfumeCandidate(
          id: '2',
          displayName: 'Le Male Le Parfum',
          brand: 'Jean Paul Gaultier',
          sourceUrl:
              'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Le-Male-Le-Parfum-72158.html',
          score: 0.79,
        ),
        const ExternalPerfumeCandidate(
          id: '3',
          displayName: 'Le Male',
          brand: 'Jean Paul Gaultier',
          sourceUrl:
              'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Le-Male-430.html',
          score: 0.75,
        ),
        const ExternalPerfumeCandidate(
          id: '4',
          displayName: 'Ultra Male',
          brand: 'Jean Paul Gaultier',
          sourceUrl:
              'https://www.fragranticarabia.com/perfumes/Jean-Paul-Gaultier/Ultra-Male-30947.html',
          score: 0.61,
        ),
      ];
      return candidates.take(count).toList(growable: false);
    }

    List<ExternalPerfumeCandidate> strongerCandidates() {
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

    ProductModel product({
      required String id,
      required String name,
      required String brand,
      required List<String> notes,
      List<String> topNotes = const [],
      List<String> middleNotes = const [],
      List<String> baseNotes = const [],
      List<String> tags = const [],
      String family = 'aromatic fougere',
      String gender = 'men',
      String season = 'all_seasons',
      String occasion = 'evening',
      String time = 'night',
      String intensity = 'strong',
      int stock = 8,
      double price = 1500,
    }) {
      return mockCatalog[0].copyWith(
        id: id,
        name: name,
        brand: brand,
        stock: stock,
        price: price,
        gender: gender,
        season: season,
        occasion: occasion,
        time: time,
        intensity: intensity,
        fragranceFamily: family,
        notes: notes,
        topNotes: topNotes,
        middleNotes: middleNotes,
        baseNotes: baseNotes,
        tags: tags,
      );
    }

    ProductModel sauvageCatalog({int stock = 5}) => product(
      id: 'catalog_sauvage',
      name: 'Sauvage Parfum',
      brand: 'Dior',
      stock: stock,
      notes: const ['citrus', 'woody', 'amber', 'vanilla'],
      topNotes: const ['bergamot'],
      middleNotes: const ['sandalwood'],
      baseNotes: const ['tonka bean', 'vanilla'],
      tags: const ['citrus', 'woody', 'amber', 'warm spicy'],
      family: 'amber fougere',
    );

    ProductModel savageSubstitute({String id = 'catalog_savage_alt'}) =>
        product(
          id: id,
          name: 'Urban Savage Twist',
          brand: 'Qissa',
          notes: const ['citrus', 'spicy', 'woody'],
          topNotes: const ['bergamot'],
          middleNotes: const ['spicy'],
          baseNotes: const ['woody'],
          tags: const ['fresh', 'bold', 'classic', 'aromatic'],
        );

    ProductModel sauvageCatalogSubstitute() => product(
      id: 'catalog_savage_alt',
      name: 'Urban Savage Twist',
      brand: 'Qissa',
      notes: const ['citrus', 'woody', 'amber', 'vanilla'],
      topNotes: const ['bergamot'],
      middleNotes: const ['sandalwood'],
      baseNotes: const ['tonka bean', 'vanilla'],
      tags: const ['citrus', 'woody', 'amber', 'warm spicy'],
      family: 'amber fougere',
    );

    ProductModel azzaroSubstitute() => product(
      id: 'catalog_azzaro_alt',
      name: 'Classic Lavender Woods',
      brand: 'Qissa',
      notes: const ['citrus', 'spicy', 'woody'],
      topNotes: const ['citrus'],
      middleNotes: const ['spicy'],
      baseNotes: const ['woody'],
      tags: const ['fresh', 'bold', 'classic', 'aromatic'],
      occasion: 'daily',
      time: 'all_day',
      intensity: 'medium',
    );

    ProductModel leMaleSubstitute() => product(
      id: 'catalog_le_male_alt',
      name: 'Honey Tobacco Vanilla',
      brand: 'Qissa',
      notes: const ['vanilla', 'amber', 'sweet', 'honey', 'tobacco'],
      topNotes: const ['lavender'],
      middleNotes: const ['vanilla'],
      baseNotes: const ['tonka bean', 'honey', 'tobacco'],
      tags: const ['vanilla', 'sweet', 'amber', 'aromatic'],
    );

    ProductModel strongerSubstitute() => product(
      id: 'catalog_stronger_alt',
      name: 'Amber Vanilla Spice',
      brand: 'Qissa',
      notes: const ['vanilla', 'warm spicy', 'amber', 'sweet', 'aromatic'],
      topNotes: const ['pink pepper'],
      middleNotes: const ['cinnamon', 'lavender'],
      baseNotes: const ['vanilla', 'amberwood'],
      tags: const ['vanilla', 'warm spicy', 'amber', 'sweet'],
      family: 'amber spicy',
      season: 'winter',
    );

    ProductModel unrelatedFresh() => product(
      id: 'catalog_unrelated_fresh',
      name: 'Fresh Gym Mist',
      brand: 'Qissa',
      notes: const ['citrus', 'mint', 'aquatic'],
      topNotes: const ['lemon'],
      middleNotes: const ['mint'],
      baseNotes: const ['musk'],
      tags: const ['fresh', 'clean', 'aquatic'],
      family: 'citrus aromatic',
      season: 'summer',
      occasion: 'daily',
      time: 'day',
      intensity: 'light',
    );

    List<ProductModel> baseCatalog() => [
      savageSubstitute(),
      azzaroSubstitute(),
      leMaleSubstitute(),
      strongerSubstitute(),
      unrelatedFresh(),
    ];

    PerfumeKnowledgeProfile? resolveCandidate(
      ExternalPerfumeCandidate candidate,
    ) {
      final normalized = candidate.displayName.toLowerCase();
      if (normalized.contains('elixir')) return leMaleElixirProfile();
      if (normalized.contains('le parfum')) return leMaleParfumProfile();
      if (normalized.contains('stronger')) return strongerProfile();
      return null;
    }

    test('S01 catalog exact hit shows requested product only', () async {
      await runScenario(
        'S01_CATALOG_EXACT',
        buildCubit(catalog: [sauvageCatalog(), ...baseCatalog()]),
        'is Sauvage Parfum available?',
        (state) {
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
          verifyNever(
            () => repo.lookupExternalPerfumeKnowledgeResult(
              query: any(named: 'query'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );
    });

    test('S02 catalog hit is case-insensitive', () async {
      await runScenario(
        'S02_CATALOG_CASE_INSENSITIVE',
        buildCubit(catalog: [sauvageCatalog(), ...baseCatalog()]),
        'IS sauvage parfum AVAILABLE?',
        (state) {
          expect(state.status, AIChatStatus.answer);
          expect(
            state.messages.last.recommendedProducts.single.product.id,
            'catalog_sauvage',
          );
        },
      );
    });

    test(
      'S03 out-of-stock product never shows unavailable product card',
      () async {
        await runScenario(
          'S03_OUT_OF_STOCK_NO_UNAVAILABLE_CARD',
          buildCubit(
            catalog: [sauvageCatalog(stock: 0), sauvageCatalogSubstitute()],
          ),
          'is Sauvage Parfum available?',
          (state) {
            expect(state.status, anyOf(AIChatStatus.answer, AIChatStatus.ask));
            expect(
              state.messages.last.recommendedProducts.where(
                (item) => item.product.stock <= 0,
              ),
              isEmpty,
            );
            expect(
              events.map((event) => event['eventType']),
              contains('availability_out_of_stock'),
            );
          },
        );
      },
    );

    test('S04 broad catalog name asks for clarification', () async {
      await runScenario(
        'S04_CATALOG_AMBIGUOUS',
        buildCubit(
          catalog: [
            product(
              id: 'cedar_1',
              name: 'Cedar Class 01',
              brand: 'Cedar',
              notes: const ['cedar', 'woody', 'amber'],
            ),
            product(
              id: 'cedar_2',
              name: 'Cedar Night',
              brand: 'Cedar',
              notes: const ['cedar', 'smoky', 'amber'],
            ),
          ],
        ),
        'is Cedar available?',
        (state) {
          expect(state.status, AIChatStatus.ask);
          expect(
            state.availabilityContext.availabilityStatus,
            AvailabilityStatus.ambiguous,
          );
          expect(state.messages.last.recommendedProducts, isEmpty);
          expect(
            state.messages.last.content,
            contains('more than one close match'),
          );
          expect(
            state.messages.last.content,
            contains('full name or brand'),
          );
          expect(
            events.map((event) => event['eventType']),
            contains('recommendation_clarifying_question_shown'),
          );
        },
      );
    });

    test('S04b single broad catalog option resolves directly', () async {
      await runScenario(
        'S04B_CATALOG_SINGLE_BROAD_HIT',
        buildCubit(catalog: [sauvageCatalog(), ...baseCatalog()]),
        'is Dior available?',
        (state) {
          expect(state.status, AIChatStatus.answer);
          expect(state.messages.last.type, MessageType.availability);
          expect(
            state.messages.last.recommendedProducts.single.product.id,
            'catalog_sauvage',
          );
          expect(state.messages.last.content, contains('Sauvage Parfum'));
          expect(
            events.map((event) => event['eventType']),
            contains('availability_catalog_found'),
          );
        },
      );
    });

    test(
      'S04c Arabic know-product question returns product intro card',
      () async {
        final sauvage = sauvageCatalog().copyWith(
          name: 'Dior Sauvage',
          nameAr: 'ديور سوفاج',
          aliasesAr: const ['سوفاج', 'ديور سوفاج'],
          price: 4650,
        );
        await runScenario(
          'S04C_AR_KNOW_PRODUCT_INTRO',
          buildCubit(catalog: [sauvage, ...baseCatalog()]),
          'عارف سوفاج؟',
          (state) {
            expect(state.status, AIChatStatus.answer);
            expect(state.messages.last.type, MessageType.availability);
            expect(state.messages.last.content, contains('أعرف'));
            expect(state.messages.last.content, contains('Dior Sauvage'));
            expect(
              state.messages.last.recommendedProducts.single.product.id,
              'catalog_sauvage',
            );
            expect(
              state.availabilityContext.matchedProductId,
              'catalog_sauvage',
            );
          },
        );
      },
    );

    test(
      'S04d Arabic know-product typo resolves known profile back to catalog',
      () async {
        final sauvage = sauvageCatalog().copyWith(
          name: 'Dior Sauvage',
          nameAr: 'ديور سوفاج',
          aliasesAr: const ['سوفاج', 'السوفاج', 'ديور سوفاج'],
          price: 4650,
          stock: 20,
        );
        await runScenario(
          'S04D_AR_KNOW_PRODUCT_TYPO_PROFILE_CATALOG',
          buildCubit(catalog: [sauvage, savageSubstitute(), ...baseCatalog()]),
          'عارف سسوفاج؟',
          (state) {
            expect(state.status, AIChatStatus.answer);
            expect(state.messages.last.type, MessageType.availability);
            expect(state.messages.last.content, contains('Dior Sauvage'));
            expect(state.messages.last.content, contains('4650'));
            expect(state.messages.last.content, isNot(contains('غير موجود')));
            expect(
              state.messages.last.recommendedProducts.single.product.id,
              'catalog_sauvage',
            );
            expect(
              state.availabilityContext.matchedProductId,
              'catalog_sauvage',
            );
          },
        );
      },
    );

    test(
      'S04e know-product typo can use interpretation candidate before fallback',
      () async {
        final bleu = product(
          id: 'bleu_de_chanel',
          name: 'Bleu de Chanel',
          brand: 'Chanel',
          price: 4950,
          notes: const ['bergamot', 'grapefruit', 'cedar'],
          tags: const ['fresh', 'woody', 'aromatic'],
        ).copyWith(aliases: const ['Blue de Chanel']);
        await runScenario(
          'S04E_KNOW_PRODUCT_INTERPRETATION_CANDIDATE',
          buildCubit(
            catalog: [bleu, ...baseCatalog()],
            interpretationResolver: (message) =>
                message.toLowerCase().contains('blue channel')
                ? const AIChatInterpretationResult(
                    intent: 'answer',
                    confidence: 0.91,
                    preferencePatch: SessionPreferences(),
                    askSlot: null,
                    productQueryCandidate: 'Bleu de Chanel',
                    reasonCode: 'test_product_name_normalized',
                  )
                : null,
          ),
          'do you know blue channel?',
          (state) {
            expect(state.status, AIChatStatus.answer);
            expect(state.messages.last.type, MessageType.availability);
            expect(state.messages.last.content, contains('Bleu de Chanel'));
            expect(
              state.messages.last.recommendedProducts.single.product.id,
              'bleu_de_chanel',
            );
          },
        );
      },
    );

    test('S05 knowledge hit does not call external lookup', () async {
      await runScenario(
        'S05_KNOWLEDGE_HIT',
        buildCubit(
          catalog: [savageSubstitute()],
          knowledgeResolver: (_) => sauvageProfile(),
        ),
        'is Sauvage Parfum available?',
        (state) {
          expect(state.status, AIChatStatus.answer);
          expect(
            state.messages.last.recommendedProducts.single.product.id,
            'catalog_savage_alt',
          );
          expect(
            events.map((event) => event['eventType']),
            contains('perfume_knowledge_hit'),
          );
          verifyNever(
            () => repo.lookupExternalPerfumeKnowledgeResult(
              query: any(named: 'query'),
              responseLanguage: any(named: 'responseLanguage'),
              requestId: any(named: 'requestId'),
            ),
          );
        },
      );
    });

    test(
      'S06 knowledge hit with weak catalog asks instead of guessing',
      () async {
        await runScenario(
          'S06_KNOWLEDGE_LOW_CONFIDENCE',
          buildCubit(
            catalog: [unrelatedFresh()],
            knowledgeResolver: (_) => leMaleElixirProfile(),
          ),
          'is Le Male Elixir available?',
          (state) {
            expect(state.status, AIChatStatus.ask);
            expect(state.messages.last.recommendedProducts, isEmpty);
            expect(
              state.messages.last.content,
              contains('found its scent profile'),
            );
          },
        );
      },
    );

    test(
      'S07 external found is saved and returns catalog substitute',
      () async {
        await runScenario(
          'S07_EXTERNAL_FOUND',
          buildCubit(
            catalog: [azzaroSubstitute()],
            externalResolver: (_) =>
                ExternalPerfumeLookupResult.found(azzaroProfile()),
          ),
          'is Azzaro Pour Homme available?',
          (state) {
            expect(state.status, AIChatStatus.answer);
            expect(
              state.messages.last.recommendedProducts.single.product.id,
              'catalog_azzaro_alt',
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
        );
      },
    );

    test('S08 external source failure is explained clearly', () async {
      await runScenario(
        'S08_EXTERNAL_SOURCE_FAILED',
        buildCubit(
          catalog: baseCatalog(),
          externalResolver: (_) => const ExternalPerfumeLookupResult.notFound(
            reason: 'source_lookup_failed',
          ),
        ),
        'is Stronger With You Intensely available?',
        (state) {
          expect(state.status, AIChatStatus.ask);
          expect(state.messages.last.recommendedProducts, isEmpty);
          expect(
            state.messages.last.content,
            contains('could not verify its external scent profile'),
          );
          expect(
            events.map((event) => event['eventType']),
            contains('perfume_knowledge_external_lookup_failed'),
          );
        },
      );
    });

    test('S09 external low confidence behaves as not found', () async {
      await runScenario(
        'S09_EXTERNAL_LOW_CONFIDENCE',
        buildCubit(
          catalog: baseCatalog(),
          externalResolver: (_) => const ExternalPerfumeLookupResult.notFound(
            reason: 'low_confidence',
          ),
        ),
        'is Unknown Weak Match available?',
        (state) {
          expect(state.status, AIChatStatus.ask);
          expect(state.messages.last.recommendedProducts, isEmpty);
          expect(state.messages.last.content, contains('exact name'));
        },
      );
    });

    test(
      'S10 external ambiguous limits choices to three and shows no cards',
      () async {
        await runScenario(
          'S10_EXTERNAL_AMBIGUOUS_LIMIT',
          buildCubit(
            catalog: baseCatalog(),
            externalResolver: (_) => ExternalPerfumeLookupResult.ambiguous(
              leMaleCandidates(count: 4),
            ),
          ),
          'is Le Male available?',
          (state) {
            expect(state.status, AIChatStatus.ask);
            expect(state.availabilityContext.externalCandidates, hasLength(3));
            expect(state.messages.last.recommendedProducts, isEmpty);
            expect(state.messages.last.content, contains('Le Male Elixir'));
          },
        );
      },
    );

    test('S10b standalone perfume name uses availability flow', () async {
      await runScenario(
        'S10B_STANDALONE_NAME_AVAILABILITY',
        buildCubit(
          catalog: baseCatalog(),
          externalResolver: (_) =>
              ExternalPerfumeLookupResult.ambiguous(leMaleCandidates(count: 4)),
        ),
        'Le Male',
        (state) {
          expect(state.status, AIChatStatus.ask);
          expect(state.availabilityContext.externalCandidates, hasLength(3));
          expect(state.messages.last.recommendedProducts, isEmpty);
          expect(state.messages.last.content, contains('Le Male Elixir'));
          expect(
            events.map((event) => event['eventType']),
            contains('perfume_knowledge_external_lookup_ambiguous'),
          );
        },
      );
    });

    test('S11 ambiguous follow-up by number resolves candidate', () async {
      final cubit = buildCubit(
        catalog: [leMaleSubstitute()],
        externalResolver: (_) =>
            ExternalPerfumeLookupResult.ambiguous(leMaleCandidates()),
        candidateResolver: resolveCandidate,
      );
      var state = await send(cubit, 'is Le Male available?');
      logScenario('S11_STEP1_AMBIGUOUS', state);
      state = await send(cubit, '1');
      logScenario('S11_STEP2_NUMBER_1', state);
      expect(state.status, AIChatStatus.answer);
      expect(
        state.messages.last.recommendedProducts.single.product.id,
        'catalog_le_male_alt',
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
      await cubit.close();
    });

    test(
      'S12 ambiguous follow-up by ordinal word resolves second candidate',
      () async {
        final cubit = buildCubit(
          catalog: [leMaleSubstitute()],
          externalResolver: (_) =>
              ExternalPerfumeLookupResult.ambiguous(leMaleCandidates()),
          candidateResolver: resolveCandidate,
        );
        await send(cubit, 'is Le Male available?');
        final state = await send(cubit, 'second');
        logScenario('S12_ORDINAL_SECOND', state);
        expect(state.messages.last.content, isNot(contains('still unclear')));
        verify(
          () => repo.resolveExternalPerfumeKnowledgeCandidate(
            candidate: any(
              named: 'candidate',
              that: predicate<ExternalPerfumeCandidate>(
                (candidate) => candidate.displayName == 'Le Male Le Parfum',
              ),
            ),
            requestId: any(named: 'requestId'),
          ),
        ).called(1);
        await cubit.close();
      },
    );

    test(
      'S13 ambiguous follow-up by unique partial resolves candidate',
      () async {
        final cubit = buildCubit(
          catalog: [leMaleSubstitute()],
          externalResolver: (_) =>
              ExternalPerfumeLookupResult.ambiguous(leMaleCandidates()),
          candidateResolver: resolveCandidate,
        );
        await send(cubit, 'is Le Male available?');
        final state = await send(cubit, 'Elixir');
        logScenario('S13_PARTIAL_ELIXIR', state);
        expect(state.status, AIChatStatus.answer);
        expect(
          state.messages.last.content,
          contains('Le Male Elixir is not available'),
        );
        await cubit.close();
      },
    );

    test('S14 ambiguous follow-up by non-unique partial asks again', () async {
      final cubit = buildCubit(
        catalog: [leMaleSubstitute()],
        externalResolver: (_) =>
            ExternalPerfumeLookupResult.ambiguous(leMaleCandidates()),
        candidateResolver: resolveCandidate,
      );
      await send(cubit, 'is Le Male available?');
      final state = await send(cubit, 'Le Male');
      logScenario('S14_PARTIAL_STILL_AMBIGUOUS', state);
      expect(state.status, AIChatStatus.ask);
      expect(state.messages.last.content, contains('still unclear'));
      verifyNever(
        () => repo.resolveExternalPerfumeKnowledgeCandidate(
          candidate: any(named: 'candidate'),
          requestId: any(named: 'requestId'),
        ),
      );
      await cubit.close();
    });

    test('S15 single candidate accepts yes confirmation', () async {
      final cubit = buildCubit(
        catalog: [strongerSubstitute()],
        externalResolver: (_) =>
            ExternalPerfumeLookupResult.ambiguous(strongerCandidates()),
        candidateResolver: resolveCandidate,
      );
      await send(cubit, 'is Stronger With You Intensely available?');
      final state = await send(cubit, 'yes');
      logScenario('S15_SINGLE_YES', state);
      expect(
        state.messages.last.content,
        isNot(contains('That choice is still unclear')),
      );
      verify(
        () => repo.resolveExternalPerfumeKnowledgeCandidate(
          candidate: any(named: 'candidate'),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
      await cubit.close();
    });

    test('S16 multiple candidates do not accept yes as a guess', () async {
      final cubit = buildCubit(
        catalog: [leMaleSubstitute()],
        externalResolver: (_) =>
            ExternalPerfumeLookupResult.ambiguous(leMaleCandidates()),
        candidateResolver: resolveCandidate,
      );
      await send(cubit, 'is Le Male available?');
      final state = await send(cubit, 'yes');
      logScenario('S16_MULTI_YES_REJECTED', state);
      expect(state.status, AIChatStatus.ask);
      expect(state.messages.last.content, contains('still unclear'));
      verifyNever(
        () => repo.resolveExternalPerfumeKnowledgeCandidate(
          candidate: any(named: 'candidate'),
          requestId: any(named: 'requestId'),
        ),
      );
      await cubit.close();
    });

    test('S17 Arabic affirmative resolves a single candidate', () async {
      final cubit = buildCubit(
        catalog: [strongerSubstitute()],
        externalResolver: (_) =>
            ExternalPerfumeLookupResult.ambiguous(strongerCandidates()),
        candidateResolver: resolveCandidate,
      );
      await send(cubit, 'هل Stronger With You Intensely متوفر؟');
      final state = await send(cubit, 'ايوه');
      logScenario('S17_ARABIC_YES', state);
      verify(
        () => repo.resolveExternalPerfumeKnowledgeCandidate(
          candidate: any(named: 'candidate'),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
      expect(state.messages.last.content, isNot(contains('still unclear')));
      await cubit.close();
    });

    test(
      'S18 resolved candidate failure falls back safely with no card',
      () async {
        final cubit = buildCubit(
          catalog: [leMaleSubstitute()],
          externalResolver: (_) =>
              ExternalPerfumeLookupResult.ambiguous(leMaleCandidates()),
          candidateResolver: (_) => null,
        );
        await send(cubit, 'is Le Male available?');
        final state = await send(cubit, 'Elixir');
        logScenario('S18_RESOLVE_FAIL_SAFE', state);
        expect(state.status, AIChatStatus.ask);
        expect(state.messages.last.recommendedProducts, isEmpty);
        expect(state.messages.last.content, contains('exact name'));
        await cubit.close();
      },
    );

    test(
      'S19 refreshed model-only knowledge uses external profile when available',
      () async {
        await runScenario(
          'S19_REFRESH_MODEL_PROFILE',
          buildCubit(
            catalog: [savageSubstitute()],
            knowledgeResolver: (_) => modelNeedsRefreshProfile(),
            externalResolver: (_) =>
                ExternalPerfumeLookupResult.found(sauvageProfile()),
          ),
          'is Sauvage Parfum available?',
          (state) {
            expect(state.status, AIChatStatus.answer);
            expect(
              state.messages.last.recommendedProducts.single.product.id,
              'catalog_savage_alt',
            );
            expect(
              events.map((event) => event['eventType']),
              contains('perfume_knowledge_external_lookup_success'),
            );
          },
        );
      },
    );

    test(
      'S20 final cards always come from catalog, never external candidate',
      () async {
        final cubit = buildCubit(
          catalog: [leMaleSubstitute()],
          externalResolver: (_) =>
              ExternalPerfumeLookupResult.ambiguous(leMaleCandidates()),
          candidateResolver: resolveCandidate,
        );
        await send(cubit, 'is Le Male available?');
        final state = await send(cubit, 'Elixir');
        logScenario('S20_CATALOG_ONLY_CARD', state);
        expect(state.messages.last.type, MessageType.availability);
        expect(
          state.messages.last.recommendedProducts.map(
            (item) => item.product.name,
          ),
          isNot(contains('Le Male Elixir')),
        );
        expect(
          state.messages.last.recommendedProducts.single.product.id,
          'catalog_le_male_alt',
        );
        await cubit.close();
      },
    );
  });
}
