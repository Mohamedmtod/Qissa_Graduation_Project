import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/staff_taste_scorer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

void main() {
  group('StaffTasteScorer', () {
    const scorer = StaffTasteScorer();

    test('keeps draft review-needed and incomplete products neutral', () {
      final draft = _product(
        id: 'draft',
        staffTagScores: const {'office': 3, 'elegant': 3, 'soft_on_nose': 2},
        staffIntelligenceStatus: 'draft',
      );
      final reviewNeeded = _product(
        id: 'review',
        staffTagScores: const {'office': 3, 'elegant': 3, 'soft_on_nose': 2},
        staffIntelligenceStatus: 'trusted',
        reviewNeeded: true,
      );
      final incomplete = _product(
        id: 'partial',
        staffTagScores: const {'office': 3},
        staffIntelligenceStatus: 'trusted',
      );

      for (final product in [draft, reviewNeeded, incomplete]) {
        final result = scorer.score(
          product: product,
          preferences: const SessionPreferences(tags: ['office', 'elegant']),
        );
        expect(result.isNeutral, isTrue);
        expect(result.score, 0);
      }
    });

    test('scores reviewed and trusted complete staff data', () {
      final reviewed = _product(
        id: 'reviewed',
        staffTagScores: const {'office': 3, 'elegant': 3, 'soft_on_nose': 2},
        staffIntelligenceStatus: 'reviewed',
        staffConfidence: 3,
      );
      final trusted = reviewed.copyWith(
        id: 'trusted',
        staffIntelligenceStatus: 'trusted',
      );

      final reviewedScore = scorer.score(
        product: reviewed,
        preferences: const SessionPreferences(tags: ['office', 'elegant']),
      );
      final trustedScore = scorer.score(
        product: trusted,
        preferences: const SessionPreferences(tags: ['office', 'elegant']),
      );

      expect(reviewedScore.isNeutral, isFalse);
      expect(trustedScore.score, greaterThan(reviewedScore.score));
      expect(trustedScore.bestFor, containsAll(['office', 'elegant']));
    });

    test(
      'keeps generated staff taste seed data neutral until reviewed by admin',
      () {
        final generated = _product(
          id: 'generated',
          staffTagScores: const {'office': 3, 'elegant': 3, 'soft_on_nose': 2},
          staffIntelligenceStatus: 'reviewed',
          staffConfidence: 3,
          staffUpdatedBy: 'staff_taste_patch_tool',
        );

        final result = scorer.score(
          product: generated,
          preferences: const SessionPreferences(tags: ['office', 'elegant']),
        );

        expect(result.isNeutral, isTrue);
        expect(result.score, 0);
        expect(result.reasonCodes, contains('staff_generated_seed_data'));
      },
    );

    test('warnings create soft penalties and derived watch outs', () {
      final product = _product(
        id: 'warned',
        staffTagScores: const {'office': 3, 'elegant': 3, 'safe_blind_buy': 3},
        staffWarnings: const ['too_sweet_for_some'],
        staffIntelligenceStatus: 'trusted',
        staffConfidence: 3,
      );

      final result = scorer.score(
        product: product,
        preferences: const SessionPreferences(tags: ['safe_blind_buy']),
      );

      expect(
        result.reasonCodes,
        contains('staff_warning_penalty:too_sweet_for_some'),
      );
      expect(result.riskLabel, 'safe_blind_buy');
      expect(result.watchOut, ['too_sweet_for_some']);
    });
  });
}

ProductModel _product({
  required String id,
  Map<String, int> staffTagScores = const {},
  List<String> staffWarnings = const [],
  String staffIntelligenceStatus = 'draft',
  bool reviewNeeded = false,
  int staffConfidence = 1,
  String? staffUpdatedBy,
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: id,
    nameLower: id,
    searchPrefixes: const [],
    brand: 'Brand',
    price: 1000,
    stock: 5,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: const ['citrus'],
    imageUrls: const [],
    description: 'desc',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: 'daily',
    time: 'day',
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
    staffUpdatedBy: staffUpdatedBy,
  );
}
