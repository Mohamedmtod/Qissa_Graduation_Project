import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/staff_taste_scorer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

void main() {
  group('Staff taste shadow validation', () {
    const scorer = StaffTasteScorer();
    final products = _staffedCatalogFixture();

    test('employee fixture keeps the MVP slice reviewed and complete', () {
      expect(products, hasLength(20));
      for (final product in products) {
        expect(
          product.staffDataCoverage,
          1.0,
          reason: '${product.id} should be complete enough for shadow scoring.',
        );
        expect(
          product.reviewNeeded,
          isFalse,
          reason: '${product.id} should represent main-admin reviewed data.',
        );
        expect(
          ['reviewed', 'trusted'],
          contains(product.staffIntelligenceStatus),
          reason: '${product.id} should not be draft in validation fixture.',
        );
      }
    });

    test('wedding elegant non-cloying request favors formal safe picks', () {
      final ranked = _rank(
        products,
        scorer,
        preferences: const SessionPreferences(
          occasion: 'wedding',
          tags: ['elegant', 'luxury', 'not_cloying', 'non_offensive'],
        ),
      );

      expect(ranked.first.product.id, 'royal_wedding');
      expect(ranked.first.result.score, greaterThan(0.65));
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:wedding'),
      );
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:elegant'),
      );
    });

    test('safe gift request favors gift and crowd-pleaser products', () {
      final ranked = _rank(
        products,
        scorer,
        preferences: const SessionPreferences(
          occasion: 'gift',
          tags: ['safe_blind_buy', 'crowd_pleaser', 'non_offensive'],
        ),
      );

      expect(ranked.first.product.id, 'safe_gift');
      expect(ranked.first.result.riskLabel, 'safe_blind_buy');
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:gift'),
      );
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:safe_blind_buy'),
      );
    });

    test('loud date request favors expressive evening products', () {
      final ranked = _rank(
        products,
        scorer,
        preferences: const SessionPreferences(
          occasion: 'date',
          tags: ['loud_projection', 'luxury', 'youthful'],
        ),
      );

      expect(ranked.first.product.id, 'bold_date');
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:loud_projection'),
      );
      expect(ranked.first.result.bestFor, contains('date'));
    });

    test('university soft request favors non-offensive campus products', () {
      final ranked = _rank(
        products,
        scorer,
        preferences: const SessionPreferences(
          occasion: 'university',
          tags: ['non_offensive', 'soft_projection', 'clean'],
        ),
      );

      expect(ranked.first.product.id, 'campus_soft');
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:university'),
      );
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:non_offensive'),
      );
    });

    test('sauvage-like but softer request favors softer DNA alternatives', () {
      final ranked = _rank(
        products,
        scorer,
        preferences: const SessionPreferences(
          tags: ['sauvage_like', 'soft_projection', 'moderate_projection'],
        ),
      );

      expect(ranked.first.product.id, 'soft_sauvage_alt');
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:sauvage_like'),
      );
      expect(
        ranked.first.result.reasonCodes,
        contains('staff_tag_matched:soft_projection'),
      );
    });

    test('draft partial and review-needed products remain neutral', () {
      final unsafeDraft = _product(
        id: 'draft_pick',
        staffTagScores: const {'wedding': 3, 'elegant': 3, 'luxury': 3},
        staffIntelligenceStatus: 'draft',
      );
      final partial = _product(
        id: 'partial_pick',
        staffTagScores: const {'wedding': 3},
        staffIntelligenceStatus: 'trusted',
      );
      final reviewNeeded = _product(
        id: 'review_needed_pick',
        staffTagScores: const {'gift': 3, 'safe_blind_buy': 3, 'clean': 3},
        staffIntelligenceStatus: 'trusted',
        reviewNeeded: true,
      );

      for (final product in [unsafeDraft, partial, reviewNeeded]) {
        final result = scorer.score(
          product: product,
          preferences: const SessionPreferences(
            occasion: 'wedding',
            tags: ['elegant', 'safe_blind_buy'],
          ),
        );
        expect(result.isNeutral, isTrue);
        expect(result.score, 0);
      }
    });
  });
}

List<_RankedStaffProduct> _rank(
  List<ProductModel> products,
  StaffTasteScorer scorer, {
  required SessionPreferences preferences,
}) {
  final ranked = [
    for (final product in products)
      _RankedStaffProduct(
        product: product,
        result: scorer.score(product: product, preferences: preferences),
      ),
  ];
  ranked.sort((a, b) => b.result.score.compareTo(a.result.score));
  return ranked;
}

List<ProductModel> _staffedCatalogFixture() {
  return [
    _product(
      id: 'royal_wedding',
      staffTagScores: const {
        'wedding': 3,
        'elegant': 3,
        'luxury': 3,
        'not_cloying': 2,
        'non_offensive': 2,
        'safe_blind_buy': 2,
      },
    ),
    _product(
      id: 'safe_gift',
      staffTagScores: const {
        'gift': 3,
        'safe_blind_buy': 3,
        'crowd_pleaser': 3,
        'clean': 3,
        'non_offensive': 3,
      },
    ),
    _product(
      id: 'bold_date',
      staffTagScores: const {
        'date': 3,
        'loud_projection': 3,
        'luxury': 2,
        'youthful': 2,
        'crowd_pleaser': 2,
      },
    ),
    _product(
      id: 'campus_soft',
      staffTagScores: const {
        'university': 3,
        'clean': 3,
        'non_offensive': 3,
        'soft_projection': 3,
        'soft_on_nose': 2,
      },
    ),
    _product(
      id: 'soft_sauvage_alt',
      staffTagScores: const {
        'daily': 2,
        'clean': 2,
        'sauvage_like': 3,
        'soft_projection': 3,
        'moderate_projection': 3,
      },
    ),
    _product(
      id: 'office_clean',
      staffTagScores: const {
        'office': 3,
        'clean': 3,
        'non_offensive': 3,
        'moderate_projection': 2,
      },
    ),
    _product(
      id: 'classic_formal',
      staffTagScores: const {
        'wedding': 2,
        'classic': 3,
        'elegant': 3,
        'moderate_projection': 2,
      },
    ),
    _product(
      id: 'fresh_daily',
      staffTagScores: const {
        'daily': 3,
        'fresh': 3,
        'clean': 2,
        'safe_blind_buy': 2,
      },
    ),
    _product(
      id: 'baccarat_evening',
      staffTagScores: const {
        'date': 2,
        'luxury': 3,
        'baccarat_like': 3,
        'loud_projection': 2,
      },
      staffWarnings: const ['too_sweet_for_some'],
    ),
    _product(
      id: 'aventus_office',
      staffTagScores: const {
        'office': 2,
        'masculine': 3,
        'aventus_like': 3,
        'moderate_projection': 2,
      },
    ),
    _product(
      id: 'acqua_summer',
      staffTagScores: const {
        'daily': 3,
        'fresh': 3,
        'acqua_di_gio_like': 3,
        'non_offensive': 2,
      },
    ),
    _product(
      id: 'good_girl_gift',
      staffTagScores: const {
        'gift': 2,
        'feminine': 3,
        'good_girl_like': 3,
        'crowd_pleaser': 2,
      },
    ),
    _product(
      id: 'luxury_boss',
      staffTagScores: const {
        'office': 2,
        'luxury': 3,
        'elegant': 3,
        'long_lasting': 3,
      },
    ),
    _product(
      id: 'youth_daily',
      staffTagScores: const {
        'daily': 3,
        'youthful': 3,
        'fresh': 2,
        'soft_projection': 2,
      },
    ),
    _product(
      id: 'soft_feminine',
      staffTagScores: const {
        'daily': 2,
        'feminine': 3,
        'soft_on_nose': 3,
        'soft_projection': 3,
      },
    ),
    _product(
      id: 'masculine_classic',
      staffTagScores: const {
        'office': 2,
        'masculine': 3,
        'classic': 3,
        'long_lasting': 2,
      },
    ),
    _product(
      id: 'medium_risk_unique',
      staffTagScores: const {
        'date': 2,
        'polarizing': 2,
        'luxury': 2,
        'loud_projection': 2,
      },
    ),
    _product(
      id: 'hot_weather_safe',
      staffTagScores: const {
        'daily': 3,
        'fresh': 3,
        'non_offensive': 2,
        'safe_blind_buy': 2,
      },
    ),
    _product(
      id: 'crowd_wedding',
      staffTagScores: const {
        'wedding': 2,
        'crowd_pleaser': 3,
        'elegant': 2,
        'moderate_projection': 2,
      },
    ),
    _product(
      id: 'not_headachey_daily',
      staffTagScores: const {
        'daily': 3,
        'clean': 2,
        'not_headachey': 3,
        'soft_on_nose': 3,
      },
    ),
  ];
}

ProductModel _product({
  required String id,
  required Map<String, int> staffTagScores,
  List<String> staffWarnings = const [],
  String staffIntelligenceStatus = 'trusted',
  bool reviewNeeded = false,
  int staffConfidence = 3,
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: id,
    nameLower: id,
    searchPrefixes: const [],
    brand: 'Staff Fixture',
    price: 1000,
    stock: 10,
    gender: 'unisex',
    season: 'all_seasons',
    fragranceFamily: 'staff',
    notes: const [],
    imageUrls: const [],
    description: 'Staff validation fixture',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: 'daily',
    time: 'all_day',
    intensity: 'medium',
    topNotes: const [],
    middleNotes: const [],
    baseNotes: const [],
    tags: const [],
    staffTagScores: staffTagScores,
    staffWarnings: staffWarnings,
    staffIntelligenceStatus: staffIntelligenceStatus,
    reviewNeeded: reviewNeeded,
    staffConfidence: staffConfidence,
  );
}

class _RankedStaffProduct {
  final ProductModel product;
  final StaffTasteScoreResult result;

  const _RankedStaffProduct({required this.product, required this.result});
}
