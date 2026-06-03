import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  required double price,
  double? salePrice,
  int stock = 5,
  String gender = 'men',
  String season = 'summer',
  String fragranceFamily = 'fresh',
  List<String> notes = const [],
  List<String> topNotes = const [],
  List<String> middleNotes = const [],
  List<String> baseNotes = const [],
  String occasion = 'daily',
  String time = 'all_day',
  String intensity = 'medium',
  List<String> tags = const ['fresh'],
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: buildSearchPrefixes(name),
    brand: 'Brand',
    price: price,
    salePrice: salePrice,
    stock: stock,
    gender: gender,
    season: season,
    fragranceFamily: fragranceFamily,
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: 'Test description',
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

void main() {
  group('LocalCandidateFilter', () {
    test(
      'excludes products with empty note arrays when note preferences exist',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          maxBudget: 1000,
          preferredNotes: ['vanilla'],
        );

        final matchingProduct = _product(
          id: 'match',
          name: 'Vanilla Match',
          price: 900,
          notes: const ['vanilla'],
        );
        final emptyNotesProduct = _product(
          id: 'empty',
          name: 'No Notes Data',
          price: 850,
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [emptyNotesProduct, matchingProduct],
          preferences: preferences,
        );

        expect(results.map((item) => item.product.id), contains('match'));
        expect(
          results.map((item) => item.product.id),
          isNot(contains('empty')),
        );
      },
    );

    test(
      'does not fall back to weak scent candidates when strong scent signal is present',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          maxBudget: 1000,
          preferredNotes: ['vanilla'],
        );

        final emptyNotesProduct = _product(
          id: 'empty',
          name: 'No Notes Data',
          price: 850,
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [emptyNotesProduct],
          preferences: preferences,
        );

        expect(results, isEmpty);
      },
    );

    test('matches general preferred notes against full scent pyramid', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 5000,
        season: 'winter',
        preferredNotes: ['vanilla'],
      );

      final baseNoteMatch = _product(
        id: 'base-vanilla',
        name: 'Winter Vanilla Base',
        price: 4200,
        gender: 'men',
        season: 'winter',
        notes: const ['amber'],
        baseNotes: const ['vanilla', 'tonka bean'],
        tags: const ['warm', 'sweet'],
      );
      final noScentMatch = _product(
        id: 'no-vanilla',
        name: 'Winter Woods',
        price: 3900,
        gender: 'men',
        season: 'winter',
        notes: const ['cedar'],
        baseNotes: const ['musk'],
        tags: const ['woody'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [noScentMatch, baseNoteMatch],
        preferences: preferences,
      );

      expect(results.map((item) => item.product.id), contains('base-vanilla'));
      expect(
        results.map((item) => item.product.id),
        isNot(contains('no-vanilla')),
      );
    });

    test(
      'keeps broad fallback available when there is no strong scent signal',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          maxBudget: 1000,
        );

        final budgetFit = _product(
          id: 'budget_fit',
          name: 'Budget Fit',
          price: 900,
          notes: const [],
          topNotes: const [],
          middleNotes: const [],
          baseNotes: const [],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [budgetFit],
          preferences: preferences,
        );

        expect(results, isNotEmpty);
        expect(results.first.product.id, 'budget_fit');
      },
    );

    test(
      'fallback does not promote products without preferred note overlap when strong scent signal is present',
      () {
        final preferences = const SessionPreferences(
          preferredNotes: ['tobacco', 'honey'],
          excludedNotes: ['vanilla'],
        );

        final weak = _product(
          id: 'weak',
          name: 'Weak',
          price: 1200,
          notes: const ['citrus'],
          topNotes: const ['citrus'],
          middleNotes: const ['aquatic'],
          baseNotes: const ['cedar'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [weak],
          preferences: preferences,
        );

        expect(results, isEmpty);
      },
    );

    test('relaxed fallback still blocks clear gender mismatch', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1000,
      );

      final mismatch = _product(
        id: 'mismatch',
        name: 'Mismatch',
        price: 900,
        gender: 'women',
        notes: const [],
        topNotes: const [],
        middleNotes: const [],
        baseNotes: const [],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [mismatch],
        preferences: preferences,
      );

      expect(results, isEmpty);
    });

    test('strictly excludes products above max budget', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1000,
      );

      final withinBudget = _product(
        id: 'allowed',
        name: 'Allowed Budget',
        price: 1000,
      );
      final aboveBudget = _product(
        id: 'blocked',
        name: 'Blocked Budget',
        price: 1000.01,
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [aboveBudget, withinBudget],
        preferences: preferences,
      );

      expect(results.map((item) => item.product.id), contains('allowed'));
      expect(
        results.map((item) => item.product.id),
        isNot(contains('blocked')),
      );
    });

    test('exact budget helper accepts only products within exact budget', () {
      final preferences = const SessionPreferences(maxBudget: 1000);
      final exact = _product(id: 'exact', name: 'Exact', price: 1000);
      final upsell = _product(id: 'upsell', name: 'Upsell', price: 1050);

      expect(
        LocalCandidateFilter.passesExactBudgetFilter(exact, preferences),
        isTrue,
      );
      expect(
        LocalCandidateFilter.passesExactBudgetFilter(upsell, preferences),
        isFalse,
      );
    });

    test('upsell helper accepts only products up to 10% above budget', () {
      final preferences = const SessionPreferences(maxBudget: 1000);
      final allowedUpsell = _product(
        id: 'allowed_upsell',
        name: 'Allowed Upsell',
        price: 1100,
      );
      final rejectedUpsell = _product(
        id: 'rejected_upsell',
        name: 'Rejected Upsell',
        price: 1110,
      );

      expect(
        LocalCandidateFilter.passesUpsellBudgetFilter(
          allowedUpsell,
          preferences,
        ),
        isTrue,
      );
      expect(
        LocalCandidateFilter.passesUpsellBudgetFilter(
          rejectedUpsell,
          preferences,
        ),
        isFalse,
      );
    });

    test('strict budget disables upsell budget status', () {
      final preferences = const SessionPreferences(maxBudget: 1000);
      final upsell = _product(id: 'upsell', name: 'Upsell', price: 1050);

      expect(
        LocalCandidateFilter.budgetStatusForProduct(upsell, preferences),
        equals(RecommendedBudgetStatus.slightlyAboveBudget),
      );
      expect(
        LocalCandidateFilter.budgetStatusForProduct(
          upsell,
          preferences,
          allowUpsell: false,
        ),
        isNull,
      );
      expect(
        LocalCandidateFilter.passesUpsellBudgetFilter(
          upsell,
          preferences,
          allowUpsell: false,
        ),
        isFalse,
      );
    });

    test('reason mentions concrete note overlap for strong scent matches', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1000,
        preferredNotes: ['citrus', 'musk'],
      );
      final match = _product(
        id: 'match',
        name: 'Citrus Musk',
        price: 900,
        notes: const ['citrus', 'musk'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [match],
        preferences: preferences,
      );

      expect(results.single.matchReason, contains('citrus and musk'));
    });

    test(
      'fresh ambroxan profile ranks signature match above sweet heavy overlap',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          intensity: 'strong',
          preferredNotes: ['citrus', 'pepper', 'ambroxan', 'woody', 'amber'],
          tags: ['fresh', 'bold'],
        );
        final sauvageLike = _product(
          id: 'sauvage_like',
          name: 'Fresh Pepper Ambrox',
          price: 4200,
          fragranceFamily: 'fresh spicy',
          notes: const ['citrus', 'pepper', 'ambroxan', 'woody'],
          baseNotes: const ['ambroxan', 'cedar'],
          intensity: 'strong',
          tags: const ['fresh', 'bold', 'clean'],
        );
        final sweetHeavy = _product(
          id: 'sweet_heavy',
          name: 'Sweet Floral Amber',
          price: 3900,
          gender: 'unisex',
          fragranceFamily: 'amber gourmand',
          notes: const ['citrus', 'amber', 'floral', 'spicy', 'sweet'],
          baseNotes: const ['vanilla', 'amber', 'woody'],
          intensity: 'medium',
          tags: const ['fresh', 'clean', 'sweet'],
        );
        final bleuLike = _product(
          id: 'bleu_like',
          name: 'Blue Citrus Woods',
          price: 4100,
          gender: 'unisex',
          fragranceFamily: 'fresh spicy',
          notes: const ['citrus', 'amber', 'spicy', 'woody'],
          baseNotes: const ['woody', 'musk'],
          intensity: 'medium',
          tags: const ['fresh', 'bold', 'clean'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [sweetHeavy, bleuLike, sauvageLike],
          preferences: preferences,
        );

        expect(results.first.product.id, 'sauvage_like');
        expect(
          results.map((item) => item.product.id).take(2),
          isNot(contains('sweet_heavy')),
        );
      },
    );

    test('budget status helper allows exact and explicit upsell only', () {
      final preferences = const SessionPreferences(maxBudget: 1000);
      final exact = _product(id: 'exact', name: 'Exact', price: 1000);
      final allowedUpsell = _product(
        id: 'allowed_upsell',
        name: 'Allowed Upsell',
        price: 1100,
      );
      final blockedUpsell = _product(
        id: 'blocked_upsell',
        name: 'Blocked Upsell',
        price: 1110,
      );
      final farTooHigh = _product(
        id: 'far_too_high',
        name: 'Far Too High',
        price: 2545,
      );

      expect(
        LocalCandidateFilter.budgetStatusForProduct(exact, preferences),
        equals(RecommendedBudgetStatus.withinBudget),
      );
      expect(
        LocalCandidateFilter.budgetStatusForProduct(allowedUpsell, preferences),
        equals(RecommendedBudgetStatus.slightlyAboveBudget),
      );
      expect(
        LocalCandidateFilter.budgetStatusForProduct(blockedUpsell, preferences),
        isNull,
      );
      expect(
        LocalCandidateFilter.budgetStatusForProduct(farTooHigh, preferences),
        isNull,
      );
    });

    test(
      'upsell recommendations return only slightly-above-budget products',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          maxBudget: 1000,
        );

        final exact = _product(id: 'exact', name: 'Exact', price: 990);
        final upsell = _product(id: 'upsell', name: 'Upsell', price: 1050);
        final tooHigh = _product(id: 'too_high', name: 'Too High', price: 1200);

        final results = LocalCandidateFilter.getTopUpsellRecommendations(
          catalog: [exact, upsell, tooHigh],
          preferences: preferences,
        );

        expect(results.map((item) => item.product.id), equals(['upsell']));
        expect(
          results.first.budgetStatus,
          equals(RecommendedBudgetStatus.slightlyAboveBudget),
        );
        expect(
          results.first.candidateSource,
          RecommendedCandidateSource.upsell,
        );
      },
    );

    test('strict budget returns no upsell recommendations', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1000,
      );
      final upsell = _product(id: 'upsell', name: 'Upsell', price: 1050);

      final results = LocalCandidateFilter.getTopUpsellRecommendations(
        catalog: [upsell],
        preferences: preferences,
        allowUpsell: false,
      );

      expect(results, isEmpty);
    });

    test('returns empty results when the only note match is over budget', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1000,
        preferredNotes: ['vanilla'],
      );

      final overBudget = _product(
        id: 'blocked',
        name: 'Over Budget Vanilla',
        price: 1099,
        notes: const ['vanilla'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [overBudget],
        preferences: preferences,
      );

      expect(results, isEmpty);
    });

    test('uses effectivePrice for exact budget filtering on sale products', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1000,
      );

      final saleProduct = _product(
        id: 'sale_fit',
        name: 'Sale Fit',
        price: 1300,
        salePrice: 999,
      );

      expect(
        LocalCandidateFilter.passesExactBudgetFilter(saleProduct, preferences),
        isTrue,
      );

      final recommendations = LocalCandidateFilter.getTopRecommendations(
        catalog: [saleProduct],
        preferences: preferences,
      );
      expect(
        recommendations.map((item) => item.product.id),
        contains('sale_fit'),
      );
    });

    test('hard filter excludes products containing excluded notes', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 2000,
        excludedNotes: ['oud'],
      );

      final withOud = _product(
        id: 'with_oud',
        name: 'Oud Heavy',
        price: 1200,
        notes: const ['oud', 'amber'],
      );
      final withoutOud = _product(
        id: 'without_oud',
        name: 'Fresh Clean',
        price: 1100,
        notes: const ['citrus', 'musk'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [withOud, withoutOud],
        preferences: preferences,
      );

      expect(results.map((item) => item.product.id), contains('without_oud'));
      expect(
        results.map((item) => item.product.id),
        isNot(contains('with_oud')),
      );
    });

    test(
      'prefers more practical prices for university when no budget is provided',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          occasion: 'university',
        );

        final practical = _product(
          id: 'practical',
          name: 'Practical Pick',
          price: 1180,
        );
        final luxury = _product(id: 'luxury', name: 'Luxury Pick', price: 4950);

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [luxury, practical],
          preferences: preferences,
        );

        expect(results, isNotEmpty);
        expect(results.first.product.id, 'practical');
      },
    );

    test('gym ranking prefers fresh light practical options', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        occasion: 'gym',
        intensity: 'light',
        time: 'day',
        tags: ['fresh', 'clean'],
      );

      final gymFit = _product(
        id: 'gym_fit',
        name: 'Gym Fit',
        price: 1100,
        occasion: 'daily',
        time: 'day',
        intensity: 'light',
        tags: const ['fresh', 'clean', 'sporty'],
        notes: const ['citrus', 'aquatic'],
      );
      final loudNight = _product(
        id: 'loud_night',
        name: 'Loud Night',
        price: 3200,
        occasion: 'formal',
        time: 'night',
        intensity: 'strong',
        tags: const ['warm', 'elegant'],
        notes: const ['oud', 'amber'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [loudNight, gymFit],
        preferences: preferences,
      );

      expect(results, isNotEmpty);
      expect(results.first.product.id, 'gym_fit');
    });

    test('office ranking prefers clean all-day moderate picks', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        occasion: 'office',
        time: 'all_day',
        intensity: 'light',
        tags: ['clean', 'elegant'],
      );

      final officeFit = _product(
        id: 'office_fit',
        name: 'Office Fit',
        price: 1450,
        occasion: 'office',
        time: 'all_day',
        intensity: 'light',
        tags: const ['clean', 'elegant', 'classic'],
        notes: const ['citrus', 'musk'],
      );
      final dateLoud = _product(
        id: 'date_loud',
        name: 'Date Loud',
        price: 1350,
        occasion: 'date',
        time: 'night',
        intensity: 'strong',
        tags: const ['sweet', 'romantic'],
        notes: const ['vanilla', 'amber'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [dateLoud, officeFit],
        preferences: preferences,
      );

      expect(results, isNotEmpty);
      expect(results.first.product.id, 'office_fit');
    });

    test(
      'date ranking prefers warm evening scents over fresh daytime ones',
      () {
        final preferences = const SessionPreferences(
          occasion: 'date',
          time: 'night',
          intensity: 'strong',
          tags: ['sweet', 'warm'],
        );

        final dateFit = _product(
          id: 'date_fit',
          name: 'Date Fit',
          gender: 'unisex',
          price: 1800,
          season: 'winter',
          fragranceFamily: 'oriental',
          occasion: 'date',
          time: 'night',
          intensity: 'strong',
          tags: const ['sweet', 'romantic', 'warm'],
          notes: const ['vanilla', 'amber'],
        );
        final daytimeFresh = _product(
          id: 'daytime_fresh',
          name: 'Daytime Fresh',
          gender: 'unisex',
          price: 1000,
          occasion: 'daily',
          time: 'day',
          intensity: 'light',
          tags: const ['fresh', 'clean'],
          notes: const ['citrus', 'aquatic'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [daytimeFresh, dateFit],
          preferences: preferences,
        );

        expect(results, isNotEmpty);
        expect(results.first.product.id, 'date_fit');
      },
    );

    test('romantic date context under budget returns grounded candidates', () {
      const preferences = SessionPreferences(
        maxBudget: 1400,
        occasion: 'date',
        tags: ['sweet', 'warm', 'romantic'],
      );

      final dateFit = _product(
        id: 'date_fit',
        name: 'Date Fit',
        gender: 'unisex',
        price: 1200,
        occasion: 'date',
        time: 'night',
        intensity: 'medium',
        tags: const ['sweet', 'romantic', 'warm'],
        notes: const ['vanilla', 'amber'],
      );
      final overBudget = _product(
        id: 'over_budget',
        name: 'Over Budget',
        gender: 'unisex',
        price: 1800,
        occasion: 'date',
        tags: const ['sweet', 'romantic'],
        notes: const ['rose'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [overBudget, dateFit],
        preferences: preferences,
      );

      expect(results.map((result) => result.product.id), contains('date_fit'));
      expect(
        results.map((result) => result.product.id),
        isNot(contains('over_budget')),
      );
    });

    test('university ranking penalizes luxury loud products', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        occasion: 'university',
        time: 'all_day',
        intensity: 'light',
        tags: ['fresh', 'clean'],
      );

      final affordable = _product(
        id: 'affordable',
        name: 'Affordable',
        price: 1250,
        occasion: 'daily',
        time: 'all_day',
        intensity: 'medium',
        tags: const ['fresh', 'clean', 'sporty'],
        notes: const ['citrus'],
      );
      final luxuryLoud = _product(
        id: 'luxury_loud',
        name: 'Luxury Loud',
        price: 5200,
        occasion: 'formal',
        time: 'night',
        intensity: 'strong',
        tags: const ['warm', 'elegant'],
        notes: const ['oud', 'amber'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [luxuryLoud, affordable],
        preferences: preferences,
      );

      expect(results, isNotEmpty);
      expect(results.first.product.id, 'affordable');
    });

    test(
      'single scent-signal tag in lifestyle context does not trigger strong scent gate',
      () {
        final preferences = const SessionPreferences(
          occasion: 'daily',
          time: 'all_day',
          intensity: 'light',
          tags: ['clean', 'elegant'],
        );

        final officeFit = _product(
          id: 'office_fit',
          name: 'Office Fit',
          price: 1300,
          occasion: 'daily',
          time: 'day',
          intensity: 'medium',
          tags: const ['fresh', 'clean', 'sporty'],
          notes: const ['citrus'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [officeFit],
          preferences: preferences,
        );

        expect(results, isNotEmpty);
        expect(results.first.product.id, 'office_fit');
      },
    );

    test(
      'strong scent signal prefers scent similarity over simply lower price',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          maxBudget: 3000,
          preferredNotes: ['bergamot', 'pepper', 'cedar'],
          preferredMiddleNotes: ['pepper'],
          preferredBaseNotes: ['cedar'],
          tags: ['aromatic', 'woody', 'fresh'],
        );

        final scentClose = _product(
          id: 'scent_close',
          name: 'Scent Close',
          price: 2400,
          fragranceFamily: 'woody aromatic',
          notes: const ['bergamot', 'pepper', 'cedar'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar'],
          tags: const ['aromatic', 'woody', 'fresh'],
        );

        final cheaperFar = _product(
          id: 'cheaper_far',
          name: 'Cheaper Far',
          price: 1200,
          fragranceFamily: 'amber gourmand',
          notes: const ['caramel', 'amber'],
          middleNotes: const ['caramel'],
          baseNotes: const ['amber'],
          tags: const ['sweet', 'gourmand'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [cheaperFar, scentClose],
          preferences: preferences,
        );

        expect(results, isNotEmpty);
        expect(results.first.product.id, 'scent_close');
        expect(
          results.any((item) => item.product.id == 'cheaper_far'),
          isFalse,
        );
      },
    );

    test(
      'exact acceptance requires preferred-note overlap while fallback allows anchored style match',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          preferredNotes: ['woody'],
          tags: ['fresh'],
        );
        final candidate = _product(
          id: 'anchored_fallback',
          name: 'Anchored Fallback',
          price: 1200,
          gender: 'men',
          fragranceFamily: 'fresh',
          notes: const [],
          topNotes: const [],
          middleNotes: const [],
          baseNotes: const [],
          tags: const ['fresh'],
        );

        final exactDecision =
            LocalCandidateFilter.evaluateWorkerRecommendationCandidate(
              candidate,
              preferences,
              policy: WorkerRecommendationAcceptancePolicy.exactCandidate,
            );
        final fallbackDecision =
            LocalCandidateFilter.evaluateWorkerRecommendationCandidate(
              candidate,
              preferences,
              policy: WorkerRecommendationAcceptancePolicy.fallbackCandidate,
            );

        expect(exactDecision.isAccepted, isFalse);
        expect(exactDecision.reasonCode, 'missing_required_note_data');
        expect(fallbackDecision.isAccepted, isTrue);

        final recommendations = LocalCandidateFilter.getTopRecommendations(
          catalog: [candidate],
          preferences: preferences,
        );
        expect(
          recommendations.single.candidateSource,
          RecommendedCandidateSource.relaxed,
        );
        expect(
          recommendations.single.matchReason,
          contains('Broad available match'),
        );
      },
    );

    test(
      'fallback acceptance still blocks candidates without minimum scent anchor',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          preferredNotes: ['woody', 'spicy'],
          tags: ['fresh'],
        );
        final weakAnchorCandidate = _product(
          id: 'weak_anchor',
          name: 'Weak Anchor',
          price: 900,
          gender: 'men',
          fragranceFamily: 'amber gourmand',
          notes: const ['caramel'],
          tags: const ['sweet'],
        );

        final decision =
            LocalCandidateFilter.evaluateWorkerRecommendationCandidate(
              weakAnchorCandidate,
              preferences,
              policy: WorkerRecommendationAcceptancePolicy.fallbackCandidate,
            );

        expect(decision.isAccepted, isFalse);
        expect(decision.reasonCode, 'missing_preferred_note');
      },
    );

    test(
      'office+light persona allows strong woody/smoky candidates (PROD-EN-011)',
      () {
        // This is the exact five-turn persona accumulation profile:
        // gender=men, budget=1500, intensity=light, occasion=office,
        // notes=woody, tags=smoky/elegant/classic/clean
        final preferences = const SessionPreferences(
          gender: 'men',
          maxBudget: 1500,
          intensity: 'light',
          occasion: 'office',
          preferredNotes: ['woody'],
          tags: ['smoky', 'elegant', 'classic', 'clean'],
        );

        // Woody/smoky perfumes are typically strong — this was the hard block
        final woodySmokyStrong = _product(
          id: 'woody_smoky_strong',
          name: 'Woody Smoky Office',
          price: 1200,
          gender: 'men',
          fragranceFamily: 'woody',
          occasion: 'office',
          time: 'all_day',
          intensity: 'strong',
          notes: const ['woody', 'smoky', 'cedar'],
          tags: const ['smoky', 'elegant', 'classic'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [woodySmokyStrong],
          preferences: preferences,
        );

        // Must NOT be empty — this was the root cause of PROD-EN-011
        expect(results, isNotEmpty);
        expect(results.first.product.id, 'woody_smoky_strong');
      },
    );

    test('non-office context still hard-blocks light vs strong intensity', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1500,
        intensity: 'light',
        occasion: 'gym',
        preferredNotes: ['citrus'],
      );

      final strongProduct = _product(
        id: 'strong_gym',
        name: 'Strong Gym',
        price: 1200,
        gender: 'men',
        occasion: 'gym',
        intensity: 'strong',
        notes: const ['citrus', 'musk'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [strongProduct],
        preferences: preferences,
      );

      // gym context → still hard-blocked
      expect(results, isEmpty);
    });

    test('excluded notes remain hard block even in office context', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1500,
        intensity: 'light',
        occasion: 'office',
        preferredNotes: ['woody'],
        excludedNotes: ['oud'],
      );

      final oudWoody = _product(
        id: 'oud_woody',
        name: 'Oud Woody',
        price: 1300,
        gender: 'men',
        occasion: 'office',
        intensity: 'strong',
        notes: const ['woody', 'oud', 'cedar'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [oudWoody],
        preferences: preferences,
      );

      // excluded note is still a hard block regardless of office softening
      expect(results, isEmpty);
    });

    test('office + light + strong without note overlap is hard-blocked', () {
      // User asks for light office scent but has NO explicit note preferences.
      // A strong random product must not leak through.
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1500,
        intensity: 'light',
        occasion: 'office',
        tags: ['elegant', 'classic'],
        // no preferredNotes
      );

      final strongNoOverlap = _product(
        id: 'strong_no_overlap',
        name: 'Strong Oriental',
        price: 1200,
        gender: 'men',
        fragranceFamily: 'oriental',
        occasion: 'office',
        intensity: 'strong',
        notes: const ['amber', 'musk', 'oud'],
        tags: const ['warm', 'spicy'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [strongNoOverlap],
        preferences: preferences,
      );

      // No note overlap and no preferredNotes → must remain blocked
      expect(results, isEmpty);
    });

    test(
      'office + light + strong with only lifestyle tags and no notes is blocked',
      () {
        // User has occasion+tags but no explicit note preferences.
        // Tags like elegant/classic are lifestyle context, not scent signals
        // sufficient to allow a strong note mismatch to pass.
        final preferences = const SessionPreferences(
          gender: 'men',
          maxBudget: 1500,
          intensity: 'light',
          occasion: 'office',
          tags: ['elegant', 'classic', 'clean'],
          // no preferredNotes at all
        );

        final strongProduct = _product(
          id: 'strong_elegant',
          name: 'Strong Elegant',
          price: 1100,
          gender: 'men',
          fragranceFamily: 'woody',
          occasion: 'office',
          intensity: 'strong',
          notes: const ['cedar', 'sandalwood'],
          tags: const ['elegant', 'classic'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [strongProduct],
          preferences: preferences,
        );

        // No preferredNotes → guard fails → blocked
        expect(results, isEmpty);
      },
    );

    test('formal + light + strong with note overlap passes (like office)', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1500,
        intensity: 'light',
        occasion: 'formal',
        preferredNotes: ['cedar', 'sandalwood'],
        tags: ['elegant'],
      );

      final formalStrong = _product(
        id: 'formal_strong',
        name: 'Formal Strong Cedar',
        price: 1300,
        gender: 'men',
        fragranceFamily: 'woody',
        occasion: 'formal',
        intensity: 'strong',
        notes: const ['cedar', 'sandalwood', 'vetiver'],
        tags: const ['elegant', 'classic'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [formalStrong],
        preferences: preferences,
      );

      // formal + note overlap → soft-pass allowed
      expect(results, isNotEmpty);
      expect(results.first.product.id, 'formal_strong');
    });

    test(
      'office + light + smoky tag allows strong smoky candidate without preferred notes',
      () {
        final preferences = const SessionPreferences(
          gender: 'men',
          maxBudget: 1500,
          intensity: 'light',
          occasion: 'office',
          tags: ['smoky', 'clean', 'elegant'],
        );

        final smokyOffice = _product(
          id: 'smoky_office',
          name: 'Vanilla Smoke Halo',
          price: 1180,
          gender: 'men',
          fragranceFamily: 'woody',
          occasion: 'office',
          time: 'all_day',
          intensity: 'strong',
          notes: const ['tobacco', 'amber', 'woody'],
          tags: const ['smoky', 'elegant'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [smokyOffice],
          preferences: preferences,
        );

        expect(results, isNotEmpty);
        expect(results.first.product.id, 'smoky_office');
      },
    );

    test('cedar and smoky work profile returns safe contextual candidate', () {
      final preferences = const SessionPreferences(
        gender: 'men',
        maxBudget: 1600,
        intensity: 'light',
        occasion: 'office',
        preferredNotes: ['cedar'],
        tags: ['smoky', 'elegant'],
      );

      final cedarSmoke = _product(
        id: 'cedar_smoke',
        name: 'Cedar Smoke Office',
        price: 1450,
        gender: 'men',
        fragranceFamily: 'woody',
        occasion: 'formal',
        time: 'all_day',
        intensity: 'strong',
        notes: const ['cedar', 'tobacco', 'amber'],
        tags: const ['smoky', 'classic'],
      );

      final results = LocalCandidateFilter.getTopRecommendations(
        catalog: [cedarSmoke],
        preferences: preferences,
      );

      expect(results, isNotEmpty);
      expect(results.first.product.id, 'cedar_smoke');
    });

    test(
      'expensiveFirst keeps scent-matched candidates ordered by price desc',
      () {
        final preferences = const SessionPreferences(
          preferredNotes: ['bergamot', 'pepper', 'cedar'],
          rankingStrategy: RankingStrategy.expensiveFirst,
        );

        final pricey = _product(
          id: 'pricey',
          name: 'Pricey Match',
          price: 2900,
          notes: const ['bergamot', 'pepper', 'cedar'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar'],
          tags: const ['fresh', 'woody'],
        );
        final cheaper = _product(
          id: 'cheaper',
          name: 'Cheaper Match',
          price: 1800,
          notes: const ['bergamot', 'pepper', 'cedar'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar'],
          tags: const ['fresh', 'woody'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [cheaper, pricey],
          preferences: preferences,
        );

        expect(results.map((item) => item.product.id), ['pricey', 'cheaper']);
        expect(results.first.matchReason, contains('أفخم'));
      },
    );

    test(
      'cheapestFirst keeps scent-matched candidates ordered by price asc',
      () {
        final preferences = const SessionPreferences(
          preferredNotes: ['bergamot', 'pepper', 'cedar'],
          rankingStrategy: RankingStrategy.cheapestFirst,
        );

        final cheaper = _product(
          id: 'cheaper',
          name: 'Cheaper Match',
          price: 1800,
          notes: const ['bergamot', 'pepper', 'cedar'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar'],
          tags: const ['fresh', 'woody'],
        );
        final pricey = _product(
          id: 'pricey',
          name: 'Pricey Match',
          price: 2900,
          notes: const ['bergamot', 'pepper', 'cedar'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar'],
          tags: const ['fresh', 'woody'],
        );

        final results = LocalCandidateFilter.getTopRecommendations(
          catalog: [pricey, cheaper],
          preferences: preferences,
        );

        expect(results.map((item) => item.product.id), ['cheaper', 'pricey']);
        expect(results.first.matchReason, contains('أوفر'));
      },
    );
  });
}
