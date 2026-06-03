import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  String brand = 'Brand',
  double price = 900,
  String gender = 'men',
  String season = 'summer',
  String occasion = 'daily',
  String time = 'all_day',
  String intensity = 'medium',
  String fragranceFamily = 'fresh',
  List<String> notes = const ['citrus', 'musk'],
  List<String> topNotes = const [],
  List<String> middleNotes = const [],
  List<String> baseNotes = const [],
  List<String> tags = const ['fresh'],
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const [],
    brand: brand,
    price: price,
    stock: 5,
    gender: gender,
    season: season,
    fragranceFamily: fragranceFamily,
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: 'Fresh profile.',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: topNotes,
    middleNotes: middleNotes,
    baseNotes: baseNotes,
    tags: tags,
  );
}

AIChatTurnContext _turn({
  String message = 'recommend citrus for men under 1000',
  AIChatIntent intent = AIChatIntent.newRecommendation,
  RecommendationMemory memory = const RecommendationMemory(),
}) {
  return AIChatTurnContext(
    trimmed: message,
    activeSessionId: 'session',
    responseLanguage: AIChatLanguage.english,
    effectiveRecommendationMemory: memory,
    intent: intent,
    shouldContinueAvailabilityClarification: false,
    isGreetingOnly: false,
    requestId: 'request',
  );
}

AIChatDiscoveryContext _discovery({
  required SessionPreferences preferences,
  bool ready = true,
  bool followUp = false,
  List<String> missingSlots = const [],
  String? readinessReason,
  AIChatBudgetPolicy budgetPolicy = AIChatBudgetPolicy.flexible,
}) {
  return AIChatDiscoveryContext(
    hasRecommendationContext: followUp,
    effectiveHasRecommendationContext: followUp,
    isFollowUpOrCompare: followUp,
    shouldPruneBotHistory: false,
    localPreferences: preferences,
    localMissingSlots: missingSlots,
    localReadyForRecommendation: ready,
    readinessReason: readinessReason,
    budgetPolicy: budgetPolicy,
  );
}

AIChatRecommendationResolver _resolver() {
  return AIChatRecommendationResolver(
    translate: (language, {required ar, required en}) =>
        language.isArabic ? ar : en,
  );
}

void main() {
  group('AIChatRecommendationResolver', () {
    test(
      'returns ask when request is not ready and no local candidates exist',
      () {
        final result = _resolver().resolve(
          incoming: _turn(message: 'recommend something'),
          discovery: _discovery(
            preferences: const SessionPreferences(),
            ready: false,
            missingSlots: const ['gender'],
          ),
          catalog: const [],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.recommendationContext, isNull);
        expect(result.handledResult.handled, isTrue);
        expect(result.handledResult.reply?.actionType, ActionType.ask);
        expect(result.trace.candidateSource, 'none');
      },
    );

    test(
      'asks before relaxing excluded notes when relaxed candidates exist',
      () {
        final result = _resolver().resolve(
          incoming: _turn(),
          discovery: _discovery(
            preferences: const SessionPreferences(
              gender: 'men',
              maxBudget: 1000,
              excludedNotes: ['oud'],
            ),
          ),
          catalog: [
            _product(id: 'oud', name: 'Oud Heavy', notes: const ['oud']),
          ],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.recommendationContext, isNull);
        expect(result.handledResult.handled, isTrue);
        expect(result.handledResult.reply?.isAsk, isTrue);
        expect(result.handledResult.isNoMatch, isFalse);
        expect(result.handledResult.issueCode, 'constraint_conflict');
        expect(result.handledResult.reasonCode, 'excluded_note_no_match');
        expect(result.trace.noMatchReason, 'excluded_note_no_match');
        expect(
          result.trace.finalGuardDecision,
          'excluded_note_conflict_clarification',
        );
        expect(
          result.handledResult.reply?.question,
          contains('excluded notes'),
        );
      },
    );

    test(
      'does not blame excluded notes when relaxing them still has no candidates',
      () {
        final result = _resolver().resolve(
          incoming: _turn(message: 'recommend winter oud'),
          discovery: _discovery(
            preferences: const SessionPreferences(
              season: 'winter',
              intensity: 'strong',
              preferredMiddleNotes: ['oud'],
              excludedNotes: ['citrus'],
            ),
          ),
          catalog: [
            _product(
              id: 'citrus',
              name: 'Citrus Fresh',
              season: 'summer',
              intensity: 'light',
              notes: const ['citrus'],
            ),
          ],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.recommendationContext, isNull);
        expect(result.handledResult.handled, isTrue);
        expect(result.handledResult.isNoMatch, isTrue);
        expect(
          result.handledResult.reasonCode,
          isNot('excluded_note_no_match'),
        );
        expect(result.trace.noMatchReason, isNot('excluded_note_no_match'));
      },
    );

    test(
      'builds strict local candidates as the only Worker candidate source',
      () {
        final match = _product(id: 'fresh', name: 'Fresh Match');
        final result = _resolver().resolve(
          incoming: _turn(),
          discovery: _discovery(
            preferences: const SessionPreferences(
              gender: 'men',
              maxBudget: 1000,
              preferredNotes: ['citrus'],
            ),
          ),
          catalog: [match],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.handledResult.handled, isFalse);
        expect(result.recommendationContext, isNotNull);
        expect(result.recommendationContext!.candidatesList.map((p) => p.id), [
          'fresh',
        ]);
        expect(result.trace.candidateSource, 'catalogSearchPrimary');
        expect(result.trace.workerCandidateCount, 1);
      },
    );

    test(
      'reference cheaper request uses reference price instead of default budget',
      () {
        final sauvage = _product(
          id: 'sauvage',
          name: 'Dior Sauvage',
          price: 4650,
          gender: 'men',
          season: 'all_seasons',
          notes: const ['citrus', 'spicy', 'woody', 'amber'],
          topNotes: const ['citrus'],
          middleNotes: const ['spicy'],
          baseNotes: const ['woody', 'amber'],
          tags: const ['fresh', 'bold', 'classic', 'aromatic'],
        );
        final cheaperSimilar = _product(
          id: 'cedar',
          name: 'Cedar Reserve',
          price: 1800,
          gender: 'men',
          season: 'all_seasons',
          notes: const ['citrus', 'spicy', 'woody', 'amber'],
          topNotes: const ['citrus'],
          middleNotes: const ['spicy'],
          baseNotes: const ['woody', 'amber'],
          tags: const ['fresh', 'classic', 'aromatic'],
        );
        final overReference = _product(
          id: 'expensive',
          name: 'Expensive Similar',
          price: 5200,
          gender: 'men',
          season: 'all_seasons',
          notes: const ['citrus', 'spicy', 'woody', 'amber'],
        );

        final result = _resolver().resolve(
          incoming: _turn(message: 'عايز عطر زي سوفاج بس ارخص'),
          discovery: _discovery(
            preferences: const SessionPreferences(
              gender: 'men',
              preferredNotes: ['citrus', 'spicy', 'woody', 'amber'],
              tags: ['fresh', 'bold', 'classic', 'aromatic'],
              intensity: 'strong',
            ),
            readinessReason: 'practical_initial',
          ),
          catalog: [sauvage, cheaperSimilar, overReference],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.handledResult.handled, isTrue);
        expect(result.handledResult.isNoMatch, isFalse);
        expect(result.handledResult.source, 'reference_cheaper_pivot');
        expect(result.trace.finalGuardDecision, 'reference_cheaper_pivot');
        expect(
          result.handledResult.recommendedProducts.map((p) => p.product.id),
          ['cedar'],
        );
        expect(
          result.handledResult.recommendedProducts.every(
            (item) => item.product.effectivePrice < sauvage.effectivePrice,
          ),
          isTrue,
        );
        expect(result.handledResult.reply?.updatedPreferences.maxBudget, 4649);
      },
    );

    test(
      'contextual cheaper request uses last available product without asking slots',
      () {
        final sauvage = _product(
          id: 'sauvage',
          name: 'Dior Sauvage',
          price: 4650,
          gender: 'men',
          season: 'all_seasons',
          notes: const ['citrus', 'spicy', 'woody', 'amber'],
          topNotes: const ['citrus'],
          middleNotes: const ['spicy'],
          baseNotes: const ['woody', 'amber'],
          tags: const ['fresh', 'bold', 'classic', 'aromatic'],
        );
        final cheaperSimilar = _product(
          id: 'cedar',
          name: 'Cedar Reserve',
          price: 1800,
          gender: 'men',
          season: 'all_seasons',
          notes: const ['citrus', 'spicy', 'woody', 'amber'],
          topNotes: const ['citrus'],
          middleNotes: const ['spicy'],
          baseNotes: const ['woody', 'amber'],
          tags: const ['fresh', 'classic', 'aromatic'],
        );
        const memory = RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'sauvage',
              name: 'Dior Sauvage',
              brand: 'Dior',
              displayIndex: 1,
              price: 4650,
              stock: 10,
              season: 'all_seasons',
              occasion: 'daily',
              intensity: 'strong',
              notes: ['citrus', 'spicy', 'woody', 'amber'],
              topNotes: ['citrus'],
              middleNotes: ['spicy'],
              baseNotes: ['woody', 'amber'],
              tags: ['fresh', 'bold', 'classic', 'aromatic'],
            ),
          ],
          lastFocusedProductId: 'sauvage',
        );

        final result = _resolver().resolve(
          incoming: _turn(
            message: 'something like it but cheaper',
            intent: AIChatIntent.followUpProduct,
            memory: memory,
          ),
          discovery: _discovery(
            preferences: const SessionPreferences(),
            ready: false,
            followUp: true,
            missingSlots: const ['gender', 'season', 'notesOrIntensity'],
          ),
          catalog: [sauvage, cheaperSimilar],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.handledResult.handled, isTrue);
        expect(result.handledResult.reply?.actionType, ActionType.recommend);
        expect(result.handledResult.source, 'reference_cheaper_pivot');
        expect(
          result.handledResult.recommendedProducts.map((p) => p.product.id),
          ['cedar'],
        );
        expect(result.handledResult.reply?.updatedPreferences.maxBudget, 4649);
      },
    );

    test(
      'reference cheaper request does not resolve brand-only Dior product',
      () {
        final fahrenheit = _product(
          id: 'fahrenheit',
          name: 'Fahrenheit',
          brand: 'Dior',
          price: 3800,
          gender: 'men',
          notes: const ['citrus', 'amber', 'floral', 'woody'],
          tags: const ['fresh', 'classic'],
        );
        final sauvage = _product(
          id: 'sauvage',
          name: 'Dior Sauvage',
          brand: 'Dior',
          price: 4650,
          gender: 'men',
          season: 'all_seasons',
          notes: const ['citrus', 'spicy', 'woody', 'amber'],
          topNotes: const ['citrus'],
          middleNotes: const ['spicy'],
          baseNotes: const ['woody', 'amber'],
          tags: const ['fresh', 'bold', 'classic', 'aromatic'],
        );
        final cheaperSimilar = _product(
          id: 'eros',
          name: 'Eros',
          price: 2950,
          gender: 'unisex',
          fragranceFamily: 'aromatic fougere',
          notes: const ['citrus', 'amber', 'woody'],
          topNotes: const ['citrus'],
          baseNotes: const ['woody'],
          tags: const ['fresh', 'classic', 'masculine'],
        );

        final result = _resolver().resolve(
          incoming: _turn(message: 'عايز عطر زي سوفاج بس ارخص'),
          discovery: _discovery(
            preferences: const SessionPreferences(
              gender: 'men',
              preferredNotes: ['citrus', 'spicy', 'woody', 'amber'],
              tags: ['fresh', 'bold', 'classic', 'aromatic'],
              intensity: 'strong',
            ),
            readinessReason: 'practical_initial',
          ),
          catalog: [fahrenheit, sauvage, cheaperSimilar],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.handledResult.source, 'reference_cheaper_pivot');
        expect(
          result.handledResult.reply?.matchReasons.values.join(' '),
          contains('Dior Sauvage'),
        );
        expect(
          result.handledResult.reply?.matchReasons.values.join(' '),
          isNot(contains('Fahrenheit')),
        );
        expect(result.handledResult.reply?.updatedPreferences.maxBudget, 4649);
      },
    );

    test('reference cheaper candidate pool keeps up to 15 candidates', () {
      final sauvage = _product(
        id: 'sauvage',
        name: 'Dior Sauvage',
        price: 4650,
        gender: 'men',
        season: 'all_seasons',
        notes: const ['citrus', 'spicy', 'woody', 'amber'],
        topNotes: const ['citrus'],
        middleNotes: const ['spicy'],
        baseNotes: const ['woody', 'amber'],
        tags: const ['fresh', 'bold', 'classic', 'aromatic'],
      );
      ProductModel similar(String id, double price) {
        return _product(
          id: id,
          name: id,
          price: price,
          gender: 'men',
          season: 'all_seasons',
          fragranceFamily: 'aromatic fougere',
          notes: const ['citrus', 'spicy', 'woody', 'amber'],
          topNotes: const ['citrus'],
          middleNotes: const ['spicy'],
          baseNotes: const ['woody', 'amber'],
          tags: const ['fresh', 'bold', 'classic', 'aromatic'],
        );
      }

      ProductModel broaderSafe(String id, double price) {
        return _product(
          id: id,
          name: id,
          price: price,
          gender: 'men',
          season: 'all_seasons',
          fragranceFamily: 'woody',
          notes: const ['musk', 'green', 'clean'],
          tags: const ['clean'],
        );
      }

      final result =
          AIChatRecommendationResolver.resolveReferenceCheaperCandidates(
            message: 'like Dior Sauvage but cheaper',
            catalog: [
              sauvage,
              similar('similar_1', 4200),
              similar('similar_2', 4100),
              similar('similar_3', 4000),
              similar('similar_4', 3900),
              broaderSafe('safe_pool_1', 2200),
              broaderSafe('safe_pool_2', 2100),
            ],
            sessionPreferences: const SessionPreferences(),
            effectivePreferences: const SessionPreferences(
              gender: 'men',
              preferredNotes: ['citrus', 'spicy', 'woody', 'amber'],
              tags: ['fresh', 'bold', 'classic', 'aromatic'],
            ),
          );

      expect(result, isNotNull);
      expect(result!.candidates.length, 6);
      expect(result.displayCandidates.length, 3);
      expect(
        result.candidates.every(
          (item) => item.product.effectivePrice < sauvage.effectivePrice,
        ),
        isTrue,
      );
      expect(
        result.candidates.map((item) => item.product.id).toSet().length,
        6,
      );
    });

    test('reference cheaper local response displays top 3 only', () {
      final sauvage = _product(
        id: 'sauvage',
        name: 'Dior Sauvage',
        price: 4650,
        gender: 'men',
        season: 'all_seasons',
        notes: const ['citrus', 'spicy', 'woody', 'amber'],
        topNotes: const ['citrus'],
        middleNotes: const ['spicy'],
        baseNotes: const ['woody', 'amber'],
        tags: const ['fresh', 'bold', 'classic', 'aromatic'],
      );
      ProductModel similar(String id, double price) {
        return _product(
          id: id,
          name: id,
          price: price,
          gender: 'men',
          season: 'all_seasons',
          fragranceFamily: 'aromatic fougere',
          notes: const ['citrus', 'spicy', 'woody', 'amber'],
          topNotes: const ['citrus'],
          middleNotes: const ['spicy'],
          baseNotes: const ['woody', 'amber'],
          tags: const ['fresh', 'bold', 'classic', 'aromatic'],
        );
      }

      ProductModel broaderSafe(String id, double price) {
        return _product(
          id: id,
          name: id,
          price: price,
          gender: 'men',
          season: 'all_seasons',
          fragranceFamily: 'woody',
          notes: const ['musk', 'green', 'clean'],
          tags: const ['clean'],
        );
      }

      final result = _resolver().resolve(
        incoming: _turn(message: 'like Dior Sauvage but cheaper'),
        discovery: _discovery(
          preferences: const SessionPreferences(
            gender: 'men',
            preferredNotes: ['citrus', 'spicy', 'woody', 'amber'],
            tags: ['fresh', 'bold', 'classic', 'aromatic'],
            intensity: 'strong',
          ),
          readinessReason: 'practical_initial',
        ),
        catalog: [
          sauvage,
          similar('similar_1', 4200),
          similar('similar_2', 4100),
          similar('similar_3', 4000),
          similar('similar_4', 3900),
          broaderSafe('safe_pool_1', 2200),
          broaderSafe('safe_pool_2', 2100),
        ],
        currentPreferences: const SessionPreferences(),
      );

      expect(result.handledResult.handled, isTrue);
      expect(result.handledResult.recommendedProducts.length, 3);
      expect(result.handledResult.reply?.productIds.length, 3);
      expect(result.trace.localCandidateCount, 6);
      expect(result.trace.workerCandidateCount, 6);
    });

    test('uses full scent pyramid before reporting budget no-match', () {
      final matchingAboveInitialBudget = _product(
        id: 'winter-vanilla',
        name: 'Winter Vanilla',
        price: 4200,
        gender: 'men',
        season: 'winter',
        notes: const ['amber'],
        baseNotes: const ['vanilla'],
        tags: const ['warm', 'sweet'],
      );

      final initial = _resolver().resolve(
        incoming: _turn(message: 'men 1500 vanilla winter'),
        discovery: _discovery(
          preferences: const SessionPreferences(
            gender: 'men',
            maxBudget: 1500,
            season: 'winter',
            preferredNotes: ['vanilla'],
          ),
        ),
        catalog: [matchingAboveInitialBudget],
        currentPreferences: const SessionPreferences(),
      );

      expect(initial.handledResult.isNoMatch, isTrue);
      expect(initial.handledResult.reasonCode, 'budget_no_match');

      final expandedBudget = _resolver().resolve(
        incoming: _turn(message: '5000'),
        discovery: _discovery(
          preferences: const SessionPreferences(
            gender: 'men',
            maxBudget: 5000,
            season: 'winter',
            preferredNotes: ['vanilla'],
          ),
        ),
        catalog: [matchingAboveInitialBudget],
        currentPreferences: const SessionPreferences(),
      );

      expect(expandedBudget.recommendationContext, isNotNull);
      expect(
        expandedBudget.recommendationContext!.candidatesList.map((p) => p.id),
        contains('winter-vanilla'),
      );
      expect(expandedBudget.trace.noMatchReason, isNull);
    });

    test(
      'does not blame budget when no product matches scent criteria at any price',
      () {
        final result = _resolver().resolve(
          incoming: _turn(message: 'men 5000 vanilla winter'),
          discovery: _discovery(
            preferences: const SessionPreferences(
              gender: 'men',
              maxBudget: 5000,
              season: 'winter',
              preferredNotes: ['vanilla'],
            ),
          ),
          catalog: [
            _product(
              id: 'winter-woods',
              name: 'Winter Woods',
              price: 3900,
              gender: 'men',
              season: 'winter',
              notes: const ['cedar'],
              baseNotes: const ['musk'],
              tags: const ['woody'],
            ),
          ],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.handledResult.isNoMatch, isTrue);
        expect(result.handledResult.reasonCode, 'scent_no_match');
        expect(result.trace.noMatchReason, 'scent_no_match');
      },
    );

    test('persona best-match profile produces local Worker candidates', () {
      final result = _resolver().resolve(
        incoming: _turn(message: 'Recommend the best match for me.'),
        discovery: _discovery(
          preferences: const SessionPreferences(
            gender: 'men',
            maxBudget: 1500,
            occasion: 'office',
            preferredNotes: ['woody', 'smoky'],
            tags: ['smoky', 'elegant', 'classic'],
          ),
          readinessReason: 'initial',
        ),
        catalog: [
          _product(
            id: 'office-woody',
            name: 'Office Woody',
            price: 1180,
            gender: 'men',
            occasion: 'office',
            time: 'all_day',
            intensity: 'medium',
            notes: const ['woody', 'smoky', 'amber'],
          ),
        ],
        currentPreferences: const SessionPreferences(),
      );

      expect(result.handledResult.handled, isTrue);
      expect(result.handledResult.reply?.isRecommend, isTrue);
      expect(result.handledResult.recommendedProducts, isNotEmpty);
      expect(
        result.handledResult.recommendedProducts.map((p) => p.product.id),
        ['office-woody'],
      );
      expect(result.recommendationContext, isNull);
      expect(result.trace.localCandidateCount, greaterThan(0));
      expect(result.trace.candidateSource, 'catalogSearchPrimary');
      expect(result.trace.finalGuardDecision, 'local_best_match');
    });

    test(
      'practical-ready empty candidates returns no-match instead of ask',
      () {
        final result = _resolver().resolve(
          incoming: _turn(message: 'Recommend a fresh perfume under 1200.'),
          discovery: _discovery(
            preferences: const SessionPreferences(
              maxBudget: 1200,
              tags: ['fresh'],
            ),
            readinessReason: 'practical_initial',
          ),
          catalog: const [],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.recommendationContext, isNull);
        expect(result.handledResult.handled, isTrue);
        expect(result.handledResult.isNoMatch, isTrue);
        expect(result.handledResult.reply, isNull);
        expect(result.trace.readinessReason, 'practical_initial');
        expect(result.trace.candidateSource, 'none');
      },
    );

    test('strict budget excludes upsell candidates from Worker context', () {
      final exact = _product(id: 'exact', name: 'Exact', price: 790);
      final upsell = _product(id: 'upsell', name: 'Upsell', price: 920);
      final result = _resolver().resolve(
        incoming: _turn(
          message:
              'I have exactly 900 EGP, not one pound more, recommend daily unisex.',
        ),
        discovery: _discovery(
          preferences: const SessionPreferences(
            gender: 'unisex',
            occasion: 'daily',
            maxBudget: 900,
          ),
          budgetPolicy: AIChatBudgetPolicy.strict,
          readinessReason: 'practical_initial',
        ),
        catalog: [exact, upsell],
        currentPreferences: const SessionPreferences(),
      );

      expect(result.handledResult.handled, isFalse);
      expect(
        result.recommendationContext!.budgetPolicy,
        AIChatBudgetPolicy.strict,
      );
      expect(result.recommendationContext!.candidatesList.map((p) => p.id), [
        'exact',
      ]);
      expect(result.trace.budgetPolicy, 'strict');
    });

    test('flexible budget keeps explicit upsell candidates', () {
      final exact = _product(id: 'exact', name: 'Exact', price: 790);
      final upsell = _product(id: 'upsell', name: 'Upsell', price: 920);
      final result = _resolver().resolve(
        incoming: _turn(message: 'Recommend daily unisex under 900.'),
        discovery: _discovery(
          preferences: const SessionPreferences(
            gender: 'unisex',
            occasion: 'daily',
            maxBudget: 900,
          ),
          budgetPolicy: AIChatBudgetPolicy.flexible,
          readinessReason: 'practical_initial',
        ),
        catalog: [exact, upsell],
        currentPreferences: const SessionPreferences(),
      );

      expect(result.handledResult.handled, isFalse);
      expect(
        result.recommendationContext!.candidatesList.map((p) => p.id),
        containsAll(['exact', 'upsell']),
      );
      expect(result.trace.budgetPolicy, 'flexible');
    });

    test(
      'asks for comparison baseline when fewer than two products resolve',
      () {
        final result = _resolver().resolve(
          incoming: _turn(
            message: 'compare them',
            intent: AIChatIntent.compareProducts,
            memory: const RecommendationMemory(),
          ),
          discovery: _discovery(
            preferences: const SessionPreferences(gender: 'men'),
            followUp: true,
          ),
          catalog: [_product(id: 'fresh', name: 'Fresh Match')],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.recommendationContext, isNull);
        expect(result.handledResult.reply?.actionType, ActionType.ask);
        expect(result.handledResult.source, 'compare_clarification');
      },
    );

    test('direct product-name comparison resolves catalog products locally', () {
      final result = _resolver().resolve(
        incoming: _turn(
          message:
              'Compare Dior Sauvage and Bleu de Chanel for projection and price.',
          intent: AIChatIntent.compareProducts,
        ),
        discovery: _discovery(
          preferences: const SessionPreferences(gender: 'men'),
          followUp: true,
        ),
        catalog: [
          _product(
            id: 'dior-sauvage',
            name: 'Dior Sauvage',
            price: 1700,
            notes: const ['bergamot', 'pepper', 'ambroxan'],
            intensity: 'strong',
          ),
          _product(
            id: 'bleu-chanel',
            name: 'Bleu de Chanel',
            price: 2100,
            notes: const ['citrus', 'incense', 'cedar'],
            intensity: 'medium',
          ),
        ],
        currentPreferences: const SessionPreferences(gender: 'men'),
      );

      expect(result.handledResult.handled, isTrue);
      expect(result.handledResult.reply?.isAnswer, isTrue);
      expect(result.recommendationContext, isNull);
      expect(
        result.handledResult.reply?.answer,
        contains('Comparison complete'),
      );
      expect(result.handledResult.reply?.answer, contains('Dior Sauvage'));
      expect(result.handledResult.reply?.answer, contains('Bleu de Chanel'));
    });

    test(
      'comparison with imaginary product returns grounded no-cards answer',
      () {
        final result = _resolver().resolve(
          incoming: _turn(
            message: 'قارنلي بين Sauvage و Toyota Black Edition perfume',
            intent: AIChatIntent.compareProducts,
          ),
          discovery: _discovery(
            preferences: const SessionPreferences(gender: 'men'),
            followUp: true,
          ),
          catalog: [
            _product(
              id: 'dior-sauvage',
              name: 'Dior Sauvage',
              price: 1700,
              notes: const ['bergamot', 'pepper', 'ambroxan'],
            ),
          ],
          currentPreferences: const SessionPreferences(gender: 'men'),
        );

        expect(result.handledResult.handled, isTrue);
        expect(result.handledResult.reply?.isAnswer, isTrue);
        expect(
          result.handledResult.source,
          'compare_unresolved_catalog_product',
        );
        expect(
          result.handledResult.reasonCode,
          'comparison_unresolved_catalog_product',
        );
        expect(result.recommendationContext, isNull);
        expect(
          result.handledResult.reply?.answer,
          contains('Toyota Black Edition'),
        );
      },
    );

    test(
      'resolved follow-up uses referenced products instead of broad catalog',
      () {
        final ref = RecommendedProductRef(
          productId: 'fresh',
          name: 'Fresh Match',
          brand: 'Brand',
          displayIndex: 1,
          price: 900,
          stock: 5,
          season: 'summer',
          occasion: 'daily',
          intensity: 'medium',
          notes: const ['citrus'],
        );
        final result = _resolver().resolve(
          incoming: _turn(
            message: 'tell me about the first one',
            intent: AIChatIntent.followUpProduct,
            memory: RecommendationMemory(lastRecommendedProducts: [ref]),
          ),
          discovery: _discovery(
            preferences: const SessionPreferences(gender: 'men'),
            followUp: true,
          ),
          catalog: [
            _product(id: 'fresh', name: 'Fresh Match'),
            _product(id: 'other', name: 'Other Match'),
          ],
          currentPreferences: const SessionPreferences(),
        );

        expect(result.handledResult.handled, isFalse);
        expect(result.recommendationContext!.candidatesList.map((p) => p.id), [
          'fresh',
        ]);
        expect(result.recommendationContext!.localFallbackAnswer, isNotNull);
        expect(result.recommendationContext!.focusProductId, 'fresh');
        expect(result.trace.candidateSource, 'resolvedFollowUp');
      },
    );
  });
}
