import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/reference_product_similarity_ranker.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

import 'mock_catalog.dart';

void main() {
  ProductModel makeReference() {
    return mockCatalog[0].copyWith(
      id: 'ref_sauvage',
      name: 'Dior Sauvage',
      brand: 'Dior',
      price: 4650,
      gender: 'men',
      season: 'all_seasons',
      occasion: 'daily',
      time: 'all_day',
      intensity: 'strong',
      fragranceFamily: 'aromatic fougere',
      notes: const ['bergamot', 'pepper', 'lavender', 'ambroxan', 'cedar'],
      topNotes: const ['bergamot'],
      middleNotes: const ['pepper', 'lavender'],
      baseNotes: const ['ambroxan', 'cedar', 'labdanum'],
      tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
      stock: 20,
    );
  }

  SessionPreferences makeEffectivePrefs() {
    return const SessionPreferences(
      gender: 'men',
      season: 'all_seasons',
      occasion: 'daily',
      time: 'all_day',
      intensity: 'strong',
      preferredNotes: ['bergamot', 'pepper', 'lavender', 'ambroxan', 'cedar'],
      preferredTopNotes: ['bergamot'],
      preferredMiddleNotes: ['pepper', 'lavender'],
      preferredBaseNotes: ['ambroxan', 'cedar'],
      tags: ['fresh', 'spicy', 'woody', 'aromatic'],
    );
  }

  group('ReferenceProductSimilarityRanker', () {
    test(
      'prefers close aromatic candidate and filters out distant gourmand outlier',
      () {
        final reference = makeReference();
        final closeCandidate = mockCatalog[1].copyWith(
          id: 'close_aromatic',
          name: 'Urban Pepper Woods',
          price: 2400,
          gender: 'men',
          season: 'all_seasons',
          occasion: 'daily',
          time: 'all_day',
          intensity: 'strong',
          fragranceFamily: 'woody aromatic',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper', 'lavender'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
          stock: 10,
        );
        final honeyOutlier = mockCatalog[2].copyWith(
          id: 'honey_outlier',
          name: 'Honey Amber Dusk',
          price: 1700,
          gender: 'unisex',
          season: 'all_seasons',
          occasion: 'daily',
          time: 'all_day',
          intensity: 'strong',
          fragranceFamily: 'amber gourmand',
          notes: const ['berry', 'floral', 'amber'],
          topNotes: const ['berry'],
          middleNotes: const ['floral'],
          baseNotes: const ['amber'],
          tags: const ['berry', 'floral', 'amber', 'strong', 'daily'],
          stock: 20,
        );

        final results = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [closeCandidate, honeyOutlier],
          sessionPreferences: const SessionPreferences(),
          effectivePreferences: makeEffectivePrefs(),
          mode: ReferenceSimilarityMode.similarCheaper,
        );

        expect(results, isNotEmpty);
        expect(results.first.product.id, 'close_aromatic');
        expect(
          results.any((item) => item.product.id == 'honey_outlier'),
          isFalse,
        );
      },
    );

    test(
      'uses explicit session gender as hard filter while keeping unisex compatible',
      () {
        final reference = makeReference();
        final menCandidate = mockCatalog[1].copyWith(
          id: 'men_candidate',
          name: 'Men Aromatic',
          price: 2200,
          gender: 'men',
          fragranceFamily: 'aromatic fougere',
          intensity: 'strong',
          notes: const ['bergamot', 'pepper', 'cedar'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar'],
        );
        final unisexCandidate = mockCatalog[1].copyWith(
          id: 'unisex_candidate',
          name: 'Unisex Aromatic',
          price: 2100,
          gender: 'unisex',
          fragranceFamily: 'aromatic',
          intensity: 'strong',
          notes: const ['bergamot', 'pepper', 'cedar'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar'],
        );

        final results = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [menCandidate, unisexCandidate],
          sessionPreferences: const SessionPreferences(gender: 'women'),
          effectivePreferences: makeEffectivePrefs(),
          mode: ReferenceSimilarityMode.similarCheaper,
        );

        expect(results.length, 1);
        expect(results.first.product.id, 'unisex_candidate');
      },
    );

    test(
      'similarCheaper keeps reference gender compatible candidates when session gender is empty',
      () {
        final reference = makeReference();
        final menCandidate = mockCatalog[1].copyWith(
          id: 'men_candidate',
          name: 'Cedar Spice Focus',
          price: 2155,
          gender: 'men',
          fragranceFamily: 'aromatic woody',
          season: 'all_seasons',
          occasion: 'daily',
          time: 'all_day',
          intensity: 'strong',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
        );
        final unisexCandidate = mockCatalog[1].copyWith(
          id: 'unisex_candidate',
          name: 'Soft Powder Silk',
          price: 1505,
          gender: 'unisex',
          fragranceFamily: 'aromatic woody',
          season: 'all_seasons',
          occasion: 'daily',
          time: 'all_day',
          intensity: 'strong',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
        );
        final womenCandidate = mockCatalog[2].copyWith(
          id: 'women_candidate',
          name: 'Citrus Sand Whisper',
          price: 855,
          gender: 'women',
          fragranceFamily: 'aromatic woody',
          season: 'all_seasons',
          occasion: 'daily',
          time: 'all_day',
          intensity: 'strong',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
        );

        final results = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [womenCandidate, unisexCandidate, menCandidate],
          sessionPreferences: const SessionPreferences(),
          effectivePreferences: makeEffectivePrefs(),
          mode: ReferenceSimilarityMode.similarCheaper,
        );

        expect(results.map((item) => item.product.id), [
          'men_candidate',
          'unisex_candidate',
        ]);
        expect(
          results.any((item) => item.product.id == 'women_candidate'),
          isFalse,
        );
      },
    );

    test(
      'does not promote fake similarity when all cheaper candidates fail scent gate',
      () {
        final reference = makeReference();
        final distantOnly = mockCatalog[2].copyWith(
          id: 'distant_only',
          name: 'Sweet Berry Amber',
          price: 1500,
          gender: 'unisex',
          fragranceFamily: 'amber gourmand',
          notes: const ['berry', 'caramel', 'amber'],
          topNotes: const ['berry'],
          middleNotes: const ['caramel'],
          baseNotes: const ['amber'],
          tags: const ['sweet', 'gourmand'],
          intensity: 'light',
        );

        final results = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [distantOnly],
          sessionPreferences: const SessionPreferences(),
          effectivePreferences: makeEffectivePrefs(),
          mode: ReferenceSimilarityMode.similarCheaper,
        );

        expect(results, isEmpty);
      },
    );

    test('similarCheaper excludes equal and higher priced products', () {
      final reference = makeReference();
      final equalPrice = mockCatalog[1].copyWith(
        id: 'equal_price',
        price: 4650,
        fragranceFamily: 'aromatic fougere',
        intensity: 'strong',
        notes: const ['bergamot', 'pepper', 'cedar'],
        topNotes: const ['bergamot'],
        middleNotes: const ['pepper'],
        baseNotes: const ['cedar'],
      );
      final higherPrice = mockCatalog[1].copyWith(
        id: 'higher_price',
        price: 5000,
        fragranceFamily: 'aromatic fougere',
        intensity: 'strong',
        notes: const ['bergamot', 'pepper', 'cedar'],
        topNotes: const ['bergamot'],
        middleNotes: const ['pepper'],
        baseNotes: const ['cedar'],
      );
      final cheaperPrice = mockCatalog[1].copyWith(
        id: 'cheaper_price',
        price: 2300,
        fragranceFamily: 'aromatic fougere',
        intensity: 'strong',
        notes: const ['bergamot', 'pepper', 'cedar'],
        topNotes: const ['bergamot'],
        middleNotes: const ['pepper'],
        baseNotes: const ['cedar'],
      );

      final results = ReferenceProductSimilarityRanker.rank(
        referenceProduct: reference,
        catalog: [equalPrice, higherPrice, cheaperPrice],
        sessionPreferences: const SessionPreferences(),
        effectivePreferences: makeEffectivePrefs(),
        mode: ReferenceSimilarityMode.similarCheaper,
      );

      expect(results.length, 1);
      expect(results.first.product.id, 'cheaper_price');
    });

    test('similarCheaper ranks scent proximity before day office context', () {
      final reference = makeReference().copyWith(
        notes: const ['citrus', 'amber', 'woody'],
        topNotes: const ['citrus'],
        middleNotes: const ['amber'],
        baseNotes: const ['woody', 'amber'],
        tags: const ['fresh', 'classic', 'masculine', 'aromatic'],
      );
      final erosLike = mockCatalog[1].copyWith(
        id: 'eros_like',
        name: 'Eros',
        price: 2950,
        gender: 'unisex',
        fragranceFamily: 'aromatic fougere',
        season: 'spring',
        occasion: 'daily',
        time: 'night',
        intensity: 'medium',
        notes: const ['citrus', 'amber', 'fruity', 'vanilla', 'sweet', 'woody'],
        topNotes: const ['citrus'],
        middleNotes: const ['citrus'],
        baseNotes: const ['vanilla', 'woody'],
        tags: const ['fresh', 'classic', 'masculine'],
      );
      final lightBlueLike = mockCatalog[2].copyWith(
        id: 'light_blue_like',
        name: 'Light Blue',
        price: 3250,
        gender: 'unisex',
        fragranceFamily: 'fresh citrus',
        season: 'summer',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const [
          'citrus',
          'amber',
          'musk',
          'rose',
          'floral',
          'fruity',
          'woody',
        ],
        topNotes: const ['citrus', 'woody'],
        middleNotes: const ['citrus', 'woody', 'floral', 'rose'],
        baseNotes: const ['woody', 'musk', 'amber'],
        tags: const ['fresh', 'clean', 'classic'],
      );
      final myWayLike = mockCatalog[0].copyWith(
        id: 'my_way_like',
        name: 'My Way',
        price: 3150,
        gender: 'unisex',
        fragranceFamily: 'fresh citrus',
        season: 'spring',
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['citrus', 'musk', 'floral', 'vanilla', 'woody'],
        topNotes: const ['citrus'],
        middleNotes: const ['citrus', 'musk'],
        baseNotes: const ['vanilla', 'musk', 'woody'],
        tags: const ['fresh', 'clean'],
      );

      final results = ReferenceProductSimilarityRanker.rank(
        referenceProduct: reference,
        catalog: [lightBlueLike, myWayLike, erosLike],
        sessionPreferences: const SessionPreferences(),
        effectivePreferences: makeEffectivePrefs(),
        mode: ReferenceSimilarityMode.similarCheaper,
      );

      expect(results.map((item) => item.product.id), ['eros_like']);
      expect(
        results.map((item) => item.product.id),
        isNot(contains('light_blue_like')),
      );
      expect(
        results.map((item) => item.product.id),
        isNot(contains('my_way_like')),
      );
    });

    test(
      'similarCheaper filters floral-heavy distractions without aromatic masculine anchors',
      () {
        final reference = makeReference();
        final missDiorLike = mockCatalog[0].copyWith(
          id: 'miss_dior_like',
          name: 'Miss Dior',
          price: 3450,
          gender: 'unisex',
          fragranceFamily: 'fresh citrus',
          notes: const ['citrus', 'amber', 'rose', 'floral', 'woody'],
          middleNotes: const ['floral', 'rose'],
          baseNotes: const ['woody'],
          tags: const ['fresh', 'clean'],
        );
        final fahrenheitLike = mockCatalog[1].copyWith(
          id: 'fahrenheit_like',
          name: 'Fahrenheit',
          price: 3450,
          gender: 'unisex',
          fragranceFamily: 'aromatic fougere',
          notes: const [
            'bergamot',
            'pepper',
            'cedar',
            'ambroxan',
            'citrus',
            'amber',
            'floral',
            'woody',
          ],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper', 'lavender', 'musk', 'leather', 'woody'],
          baseNotes: const ['ambroxan', 'cedar', 'amber', 'woody'],
          tags: const ['fresh', 'classic', 'masculine'],
        );

        final results = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [missDiorLike, fahrenheitLike],
          sessionPreferences: const SessionPreferences(),
          effectivePreferences: makeEffectivePrefs(),
          mode: ReferenceSimilarityMode.similarCheaper,
          arabicReasons: true,
        );

        expect(results.map((item) => item.product.id), ['fahrenheit_like']);
        expect(results.single.matchReason, contains('Dior Sauvage'));
      },
    );

    test(
      'similarCheaper blocks feminine-coded unisex candidates for masculine references',
      () {
        final reference = makeReference();
        final feminineCoded = mockCatalog[0].copyWith(
          id: 'miss_feminine',
          name: 'Miss Pepper Woods',
          price: 2600,
          gender: 'unisex',
          fragranceFamily: 'aromatic fougere',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
        );
        final masculineCandidate = mockCatalog[1].copyWith(
          id: 'masculine_candidate',
          name: 'Pepper Woods',
          price: 2550,
          gender: 'men',
          fragranceFamily: 'aromatic fougere',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
        );

        final results = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [feminineCoded, masculineCandidate],
          sessionPreferences: const SessionPreferences(),
          effectivePreferences: makeEffectivePrefs(),
          mode: ReferenceSimilarityMode.similarCheaper,
        );

        expect(results.map((item) => item.product.id), ['masculine_candidate']);
      },
    );

    test(
      'similarCheaper can produce fully Arabic labels and grounded reasons',
      () {
        final reference = makeReference();
        final candidate = mockCatalog[1].copyWith(
          id: 'arabic_reason',
          name: 'Cedar Pepper',
          price: 2600,
          gender: 'men',
          fragranceFamily: 'aromatic woody',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
        );

        final results = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [candidate],
          sessionPreferences: const SessionPreferences(),
          effectivePreferences: makeEffectivePrefs(),
          mode: ReferenceSimilarityMode.similarCheaper,
          arabicReasons: true,
        );

        expect(results.single.matchLabel, isNot(contains('Match')));
        expect(results.single.matchReason, contains('أرخص من Dior Sauvage'));
        expect(results.single.matchReason, contains('برغموت'));
        expect(results.single.matchReason, isNot(contains('Lower-priced')));
        expect(results.single.matchReason, isNot(contains('partial profile')));
      },
    );

    test(
      'ranking strategy can reorder equal-cheap candidates by price desc or asc',
      () {
        final reference = makeReference();
        final expensive = mockCatalog[1].copyWith(
          id: 'expensive_match',
          name: 'Expensive Match',
          price: 2900,
          gender: 'men',
          fragranceFamily: 'aromatic woody',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
        );
        final cheaper = mockCatalog[2].copyWith(
          id: 'cheaper_match',
          name: 'Cheaper Match',
          price: 2200,
          gender: 'men',
          fragranceFamily: 'aromatic woody',
          notes: const ['bergamot', 'pepper', 'cedar', 'ambroxan'],
          topNotes: const ['bergamot'],
          middleNotes: const ['pepper'],
          baseNotes: const ['cedar', 'ambroxan'],
          tags: const ['fresh', 'spicy', 'woody', 'aromatic'],
        );

        final expensiveFirstResults = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [cheaper, expensive],
          sessionPreferences: const SessionPreferences(),
          effectivePreferences: const SessionPreferences(
            rankingStrategy: RankingStrategy.expensiveFirst,
          ),
          mode: ReferenceSimilarityMode.similarCheaper,
          arabicReasons: true,
        );
        expect(expensiveFirstResults.map((item) => item.product.id), [
          'expensive_match',
          'cheaper_match',
        ]);
        expect(expensiveFirstResults.first.matchReason, contains('أفخم'));

        final cheapestFirstResults = ReferenceProductSimilarityRanker.rank(
          referenceProduct: reference,
          catalog: [expensive, cheaper],
          sessionPreferences: const SessionPreferences(),
          effectivePreferences: const SessionPreferences(
            rankingStrategy: RankingStrategy.cheapestFirst,
          ),
          mode: ReferenceSimilarityMode.similarCheaper,
          arabicReasons: true,
        );
        expect(cheapestFirstResults.map((item) => item.product.id), [
          'cheaper_match',
          'expensive_match',
        ]);
        expect(cheapestFirstResults.first.matchReason, contains('أوفر'));
      },
    );
  });
}
