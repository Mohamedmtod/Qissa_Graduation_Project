import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/suitability_policy_engine.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  required double price,
  String gender = 'unisex',
  String season = 'all_seasons',
  String occasion = 'daily',
  String time = 'all_day',
  String intensity = 'medium',
  String family = 'fresh',
  List<String> notes = const <String>[],
  List<String> tags = const <String>[],
  Map<String, int> staffTagScores = const <String, int>{},
  List<String> staffWarnings = const <String>[],
  String staffIntelligenceStatus = 'draft',
  bool reviewNeeded = false,
  int staffConfidence = 1,
  String? staffUpdatedBy,
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const <String>[],
    brand: 'Brand',
    price: price,
    stock: 5,
    gender: gender,
    season: season,
    fragranceFamily: family,
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: '',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: true,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: const <String>[],
    middleNotes: const <String>[],
    baseNotes: const <String>[],
    tags: tags,
    staffTagScores: staffTagScores,
    staffWarnings: staffWarnings,
    staffIntelligenceStatus: staffIntelligenceStatus,
    reviewNeeded: reviewNeeded,
    staffConfidence: staffConfidence,
    staffUpdatedBy: staffUpdatedBy,
  );
}

RecommendedProduct _recommendation(ProductModel product) {
  return RecommendedProduct(
    product: product,
    matchScore: 0.90,
    matchLabel: 'Strong Match',
    matchReason: 'Catalog match.',
  );
}

void main() {
  group('SuitabilityPolicyEngine', () {
    tearDown(AIChatExperimentConfig.resetTestOverrides);

    const engine = SuitabilityPolicyEngine();

    test(
      'university light fresh penalizes night winter when better alternative exists',
      () {
        final night = _product(
          id: 'night',
          name: 'Premium Night',
          price: 9200,
          season: 'winter',
          occasion: 'date',
          time: 'night',
          intensity: 'medium',
          notes: const ['amber'],
          tags: const ['sweet'],
        );
        final day = _product(
          id: 'day',
          name: 'Campus Clean',
          price: 1400,
          season: 'summer',
          occasion: 'office',
          time: 'day',
          intensity: 'light',
          notes: const ['citrus', 'musk'],
          tags: const ['fresh', 'clean', 'university'],
        );

        final results = engine.evaluateProducts(
          products: [night, day],
          context: const SuitabilityContext(
            preferences: SessionPreferences(
              occasion: 'university',
              intensity: 'light',
              tags: ['fresh', 'clean'],
            ),
          ),
        );

        expect(results['night']!.blockedBySuitability, isFalse);
        expect(
          results['night']!.suitabilityReasons,
          contains('night_for_university'),
        );
        expect(results['day']!.blockedBySuitability, isFalse);
        expect(
          results['day']!.suitabilityScore,
          greaterThan(results['night']!.suitabilityScore),
        );
      },
    );

    test('daily fresh ranks light daily over strong date', () {
      final strongDate = _product(
        id: 'date',
        name: 'Date Strong',
        price: 1500,
        occasion: 'date',
        time: 'night',
        intensity: 'strong',
        notes: const ['vanilla'],
        tags: const ['party'],
      );
      final freshDaily = _product(
        id: 'daily',
        name: 'Daily Fresh',
        price: 1100,
        occasion: 'daily',
        time: 'all_day',
        intensity: 'light',
        notes: const ['citrus', 'musk'],
        tags: const ['fresh', 'clean'],
      );

      final application = engine.applyToRecommendations(
        products: [_recommendation(strongDate), _recommendation(freshDaily)],
        context: const SuitabilityContext(
          preferences: SessionPreferences(
            occasion: 'daily',
            tags: ['fresh', 'clean'],
          ),
        ),
      );

      expect(
        application.resultsByProductId['date']!.blockedBySuitability,
        isFalse,
      );
      expect(
        application.products.map((item) => item.product.id).first,
        'daily',
      );
    });

    test(
      'generic scoring ranks day fruity over night winter for light request',
      () {
        final nightFruity = _product(
          id: 'night_fruity',
          name: 'Night Fruity',
          price: 3700,
          season: 'winter',
          occasion: 'daily',
          time: 'night',
          intensity: 'medium',
          notes: const ['fruity', 'vanilla'],
          tags: const ['romantic'],
        );
        final dayFruity = _product(
          id: 'day_fruity',
          name: 'Day Fruity',
          price: 3250,
          season: 'summer',
          occasion: 'office',
          time: 'day',
          intensity: 'medium',
          notes: const ['fruity', 'citrus'],
          tags: const ['fresh', 'clean'],
        );

        final application = engine.applyToRecommendations(
          products: [_recommendation(nightFruity), _recommendation(dayFruity)],
          context: const SuitabilityContext(
            preferences: SessionPreferences(
              gender: 'men',
              intensity: 'light',
              preferredNotes: ['fruity'],
            ),
          ),
        );

        expect(
          application.resultsByProductId['night_fruity']!.blockedBySuitability,
          isFalse,
        );
        expect(
          application.resultsByProductId['night_fruity']!.suitabilityReasons,
          contains('night_for_light_request'),
        );
        expect(
          application.products.map((item) => item.product.id).first,
          ['day_fruity'].single,
        );
        expect(
          application.resultsByProductId['day_fruity']!.suitabilityScore,
          greaterThan(
            application.resultsByProductId['night_fruity']!.suitabilityScore,
          ),
        );
      },
    );

    test(
      'internal suitability reasons are not appended to user match reason',
      () {
        final nightFruity = _product(
          id: 'night_fruity',
          name: 'Night Fruity',
          price: 3700,
          season: 'winter',
          occasion: 'daily',
          time: 'night',
          intensity: 'medium',
          notes: const ['fruity', 'vanilla'],
          tags: const ['romantic'],
        );

        final application = engine.applyToRecommendations(
          products: [_recommendation(nightFruity)],
          context: const SuitabilityContext(
            preferences: SessionPreferences(
              intensity: 'light',
              preferredNotes: ['fruity'],
            ),
          ),
        );

        expect(application.products.single.matchReason, 'Catalog match.');
        expect(
          application.resultsByProductId['night_fruity']!.suitabilityReasons,
          isNotEmpty,
        );
      },
    );

    test('adds staff taste shadow metadata without changing ranking', () {
      AIChatExperimentConfig.setTestOverrides(staffTasteScoringEnabled: false);
      final staffed = _product(
        id: 'staffed',
        name: 'Staffed Office',
        price: 1000,
        tags: const ['fresh'],
        staffTagScores: const {'office': 3, 'elegant': 3, 'soft_on_nose': 2},
        staffIntelligenceStatus: 'trusted',
        staffConfidence: 3,
      );
      final unstaffed = _product(
        id: 'unstaffed',
        name: 'Unstaffed Office',
        price: 950,
        tags: const ['fresh'],
      );

      final application = engine.applyToRecommendations(
        products: [_recommendation(unstaffed), _recommendation(staffed)],
        context: const SuitabilityContext(
          preferences: SessionPreferences(tags: ['office', 'elegant']),
        ),
      );

      expect(application.products.map((item) => item.product.id), [
        'unstaffed',
        'staffed',
      ]);
      expect(
        application.resultsByProductId['staffed']!.staffTasteScore,
        greaterThan(0),
      );
      expect(application.resultsByProductId['staffed']!.staffDataCoverage, 1.0);
      expect(application.resultsByProductId['unstaffed']!.staffTasteScore, 0);
    });

    test('gym penalizes strong night when clean light alternative exists', () {
      final strongNight = _product(
        id: 'strong',
        name: 'Strong Night',
        price: 1000,
        time: 'night',
        intensity: 'strong',
        notes: const ['amber'],
      );
      final gymClean = _product(
        id: 'clean',
        name: 'Clean Gym',
        price: 900,
        time: 'day',
        intensity: 'light',
        notes: const ['citrus'],
        tags: const ['fresh', 'clean', 'gym'],
      );

      final results = engine.evaluateProducts(
        products: [strongNight, gymClean],
        context: const SuitabilityContext(
          preferences: SessionPreferences(occasion: 'gym'),
        ),
      );

      expect(results['strong']!.blockedBySuitability, isFalse);
      expect(
        results['strong']!.suitabilityReasons,
        contains('too_strong_for_gym'),
      );
      expect(results['clean']!.blockedBySuitability, isFalse);
      expect(
        results['clean']!.suitabilityScore,
        greaterThan(results['strong']!.suitabilityScore),
      );
    });

    test('office prefers clean moderate day over loud party', () {
      final party = _product(
        id: 'party',
        name: 'Party Oud',
        price: 1900,
        occasion: 'party',
        time: 'night',
        intensity: 'strong',
        notes: const ['oud'],
        tags: const ['party'],
      );
      final office = _product(
        id: 'office',
        name: 'Office Musk',
        price: 1200,
        occasion: 'office',
        time: 'day',
        intensity: 'medium',
        notes: const ['musk'],
        tags: const ['clean', 'office'],
      );

      final application = engine.applyToRecommendations(
        products: [_recommendation(party), _recommendation(office)],
        context: const SuitabilityContext(
          preferences: SessionPreferences(occasion: 'office'),
        ),
      );

      expect(
        application.resultsByProductId['party']!.blockedBySuitability,
        isFalse,
      );
      expect(
        application.products.map((item) => item.product.id).first,
        'office',
      );
    });

    test('premium without budget gets penalty and caveat', () {
      final premium = _product(
        id: 'premium',
        name: 'Premium',
        price: 9000,
        occasion: 'daily',
        time: 'day',
        intensity: 'light',
        notes: const ['musk'],
        tags: const ['fresh'],
      );
      final practical = _product(
        id: 'practical',
        name: 'Practical',
        price: 1200,
        occasion: 'daily',
        time: 'day',
        intensity: 'light',
        notes: const ['musk'],
        tags: const ['fresh'],
      );

      final results = engine.evaluateProducts(
        products: [premium, practical],
        context: const SuitabilityContext(
          preferences: SessionPreferences(
            occasion: 'university',
            intensity: 'light',
            tags: ['fresh'],
          ),
        ),
      );

      expect(
        results['premium']!.suitabilityReasons,
        contains('premium_without_budget'),
      );
      expect(results['premium']!.caveat, 'premium_without_budget');
      expect(results['premium']!.blockedBySuitability, isFalse);
    });

    test('hard blocks excluded and unavailable products', () {
      final excluded = _product(
        id: 'excluded',
        name: 'Vanilla Option',
        price: 1000,
        notes: const ['vanilla', 'musk'],
      );
      final unavailable = _product(
        id: 'unavailable',
        name: 'Inactive Option',
        price: 1000,
        notes: const ['citrus'],
      ).copyWith(stock: 0);

      final results = engine.evaluateProducts(
        products: [excluded, unavailable],
        context: const SuitabilityContext(
          preferences: SessionPreferences(excludedNotes: ['vanilla']),
        ),
      );

      expect(results['excluded']!.blockedBySuitability, isTrue);
      expect(
        results['excluded']!.suitabilityReasons,
        contains('excluded_note'),
      );
      expect(results['unavailable']!.blockedBySuitability, isTrue);
      expect(
        results['unavailable']!.suitabilityReasons,
        contains('inactive_or_out_of_stock'),
      );
    });

    test('does not overblock when no better alternative exists', () {
      final onlyOption = _product(
        id: 'only',
        name: 'Only Night',
        price: 1300,
        season: 'winter',
        occasion: 'date',
        time: 'night',
        intensity: 'strong',
        notes: const ['amber'],
      );

      final results = engine.evaluateProducts(
        products: [onlyOption],
        context: const SuitabilityContext(
          preferences: SessionPreferences(
            occasion: 'university',
            intensity: 'light',
            tags: ['fresh'],
          ),
        ),
      );

      expect(results['only']!.suitabilityReasons, isNotEmpty);
      expect(results['only']!.blockedBySuitability, isFalse);
    });

    test('records staff taste score as shadow metadata only', () {
      AIChatExperimentConfig.setTestOverrides(staffTasteScoringEnabled: false);
      final trustedStaffPick = _product(
        id: 'staff',
        name: 'Staff Pick',
        price: 1300,
        tags: const ['fresh'],
        staffTagScores: const {'office': 3, 'elegant': 3, 'soft_on_nose': 2},
        staffIntelligenceStatus: 'trusted',
        staffConfidence: 3,
      );
      final regularPick = _product(
        id: 'regular',
        name: 'Regular Pick',
        price: 1200,
        tags: const ['fresh'],
      );

      final application = engine.applyToRecommendations(
        products: [
          _recommendation(regularPick),
          _recommendation(trustedStaffPick),
        ],
        context: const SuitabilityContext(
          preferences: SessionPreferences(
            occasion: 'office',
            tags: ['elegant'],
          ),
        ),
      );

      final staffResult = application.resultsByProductId['staff']!;
      expect(staffResult.staffTasteScore, greaterThan(0));
      expect(staffResult.staffIntelligenceStatus, 'trusted');
      expect(staffResult.staffDataCoverage, 1);
      expect(staffResult.reviewNeeded, isFalse);
      expect(staffResult.staffTaxonomyVersion, 1);
      expect(
        staffResult.staffTasteReasons,
        contains('staff_tag_matched:office'),
      );

      expect(application.products.map((item) => item.product.id).toList(), [
        'regular',
        'staff',
      ]);
    });

    test('staff taste ranking boost can promote trusted complete products', () {
      AIChatExperimentConfig.setTestOverrides(
        staffTasteScoringEnabled: true,
        staffTasteWeight: 0.10,
      );
      final trustedStaffPick = _product(
        id: 'staff',
        name: 'Trusted Staff Pick',
        price: 1300,
        tags: const ['fresh'],
        staffTagScores: const {'office': 3, 'elegant': 3, 'soft_on_nose': 2},
        staffIntelligenceStatus: 'trusted',
        staffConfidence: 3,
      );
      final regularPick = _product(
        id: 'regular',
        name: 'Regular Pick',
        price: 1200,
        tags: const ['fresh'],
      );

      final application = engine.applyToRecommendations(
        products: [
          _recommendation(regularPick),
          _recommendation(trustedStaffPick),
        ],
        context: const SuitabilityContext(
          preferences: SessionPreferences(
            occasion: 'office',
            tags: ['elegant'],
          ),
        ),
      );

      expect(application.products.map((item) => item.product.id).toList(), [
        'staff',
        'regular',
      ]);
      expect(
        application.resultsByProductId['staff']!.suitabilityScore,
        greaterThan(
          application.resultsByProductId['regular']!.suitabilityScore,
        ),
      );
    });

    test('generated staff seed data stays neutral in real ranking', () {
      AIChatExperimentConfig.setTestOverrides(
        staffTasteScoringEnabled: true,
        staffTasteWeight: 0.10,
      );
      final generatedSeed = _product(
        id: 'generated',
        name: 'Generated Seed Pick',
        price: 1300,
        tags: const ['fresh'],
        staffTagScores: const {'office': 3, 'elegant': 3, 'soft_on_nose': 2},
        staffIntelligenceStatus: 'trusted',
        staffConfidence: 3,
        staffUpdatedBy: 'staff_taste_patch_tool',
      );
      final regularPick = _product(
        id: 'regular',
        name: 'Regular Pick',
        price: 1200,
        tags: const ['fresh'],
      );

      final application = engine.applyToRecommendations(
        products: [
          _recommendation(regularPick),
          _recommendation(generatedSeed),
        ],
        context: const SuitabilityContext(
          preferences: SessionPreferences(
            occasion: 'office',
            tags: ['elegant'],
          ),
        ),
      );

      expect(application.products.map((item) => item.product.id).toList(), [
        'regular',
        'generated',
      ]);
      expect(application.resultsByProductId['generated']!.staffTasteScore, 0);
      expect(
        application.resultsByProductId['generated']!.suitabilityScore,
        application.resultsByProductId['regular']!.suitabilityScore,
      );
    });
  });
}
