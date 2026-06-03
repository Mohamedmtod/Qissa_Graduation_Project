import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/final_recommendation_guard.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required double price,
  int stock = 5,
  bool isActive = true,
  String fragranceFamily = 'fresh',
  List<String> notes = const ['citrus', 'musk'],
  List<String> topNotes = const [],
  List<String> middleNotes = const [],
  List<String> baseNotes = const [],
  List<String> tags = const ['fresh'],
  String description = 'Fresh profile.',
  String intensity = 'medium',
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: id,
    nameLower: id,
    searchPrefixes: const [],
    brand: 'Brand',
    price: price,
    stock: stock,
    gender: 'men',
    season: 'summer',
    fragranceFamily: fragranceFamily,
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: description,
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: isActive,
    occasion: 'office',
    time: 'day',
    intensity: intensity,
    topNotes: topNotes,
    middleNotes: middleNotes,
    baseNotes: baseNotes,
    tags: tags,
  );
}

FinalRecommendationGuard _guard(List<Map<String, dynamic>> events) {
  return FinalRecommendationGuard(
    translate: (language, {required ar, required en}) =>
        language.isArabic ? ar : en,
    logEvent: (eventType, metadata) {
      events.add({'eventType': eventType, ...metadata});
    },
  );
}

void _expectCustomerFacingReason(String reason) {
  const forbidden = [
    'intensity differs from request',
    'catalog note gap',
    'external lookup failed',
    'fallback from candidates',
    'staff_generated_seed_data',
    'guard_blocked',
    'no_match_reason',
    'Only note:',
    'not exact on',
  ];
  for (final value in forbidden) {
    expect(reason, isNot(contains(value)), reason: 'Internal copy leaked.');
  }
}

void main() {
  group('FinalRecommendationGuard', () {
    test('drops missing catalog ids and preserves safe ids', () {
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['missing', 'p1'],
          matchReasons: const {'p1': 'Fresh and clean.'},
          updatedPreferences: const SessionPreferences(maxBudget: 1000),
        ),
        catalog: [_product(id: 'p1', price: 900)],
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: [
            RecommendedProduct(
              product: _product(id: 'p1', price: 900),
              matchReason: 'Fresh and clean.',
              matchScore: 0.9,
              matchLabel: 'Excellent Match',
            ),
          ],
          candidatesList: [_product(id: 'p1', price: 900)],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts.map((item) => item.product.id), ['p1']);
      expect(
        events.any((event) => event['issueCode'] == 'catalog_id_missing'),
        isTrue,
      );
    });

    test('deduplicates repeated worker product ids before rendering', () {
      final p1 = _product(id: 'p1', price: 900);
      final p2 = _product(id: 'p2', price: 850);
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['p1', 'p1', 'p2'],
          matchReasons: const {
            'p1': 'Fresh first match.',
            'p2': 'Fresh second match.',
          },
          updatedPreferences: const SessionPreferences(maxBudget: 1000),
        ),
        catalog: [p1, p2],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts.map((item) => item.product.id), ['p1', 'p2']);
      expect(
        events.any((event) => event['issueCode'] == 'duplicate_cards_blocked'),
        isTrue,
      );
    });

    test('blocks hard over-budget ids', () {
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['p1'],
          matchReasons: const {'p1': 'Great option.'},
          updatedPreferences: const SessionPreferences(maxBudget: 1000),
        ),
        catalog: [_product(id: 'p1', price: 1300)],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts, isEmpty);
      expect(result.shouldNoMatch, isTrue);
      expect(
        events.any((event) => event['issueCode'] == 'budget_policy_block'),
        isTrue,
      );
    });

    test('blocks out-of-stock worker ids', () {
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['p1'],
          matchReasons: const {'p1': 'Fresh option.'},
          updatedPreferences: const SessionPreferences(maxBudget: 1000),
        ),
        catalog: [_product(id: 'p1', price: 900, stock: 0)],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts, isEmpty);
      expect(result.shouldNoMatch, isTrue);
      expect(
        events.any((event) => event['issueCode'] == 'inactive_or_out_of_stock'),
        isTrue,
      );
    });

    test('blocks inactive worker ids', () {
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['p1'],
          matchReasons: const {'p1': 'Fresh option.'},
          updatedPreferences: const SessionPreferences(maxBudget: 1000),
        ),
        catalog: [_product(id: 'p1', price: 900, isActive: false)],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts, isEmpty);
      expect(result.shouldNoMatch, isTrue);
      expect(
        events.any((event) => event['issueCode'] == 'inactive_or_out_of_stock'),
        isTrue,
      );
    });

    test('blocks canonical excluded notes before rendering', () {
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['vanilla'],
          matchReasons: const {'vanilla': 'Warm sweet match.'},
          updatedPreferences: const SessionPreferences(
            maxBudget: 1500,
            excludedNotes: ['vanilla'],
          ),
        ),
        catalog: [
          _product(
            id: 'vanilla',
            price: 1200,
            notes: const ['vanilla', 'amber'],
          ),
        ],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts, isEmpty);
      expect(result.shouldNoMatch, isTrue);
      expect(
        events.any((event) => event['issueCode'] == 'excluded_note_violation'),
        isTrue,
      );
    });

    test('blocks fine-note exclusions across raw pyramid and description', () {
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['citrus'],
          matchReasons: const {'citrus': 'Clean bright match.'},
          updatedPreferences: const SessionPreferences(
            maxBudget: 1500,
            excludedNotes: ['lemon'],
          ),
        ),
        catalog: [
          _product(
            id: 'citrus',
            price: 1200,
            notes: const ['fresh'],
            topNotes: const ['orange blossom'],
            description: 'Bright citrus opening with clean musk.',
          ),
        ],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts, isEmpty);
      expect(result.shouldNoMatch, isTrue);
      expect(
        events.any((event) => event['issueCode'] == 'fine_note_violation'),
        isTrue,
      );
    });

    test('uses local recovery when worker ids are all blocked', () {
      final safe = _product(id: 'safe', price: 900);
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['blocked'],
          matchReasons: const {'blocked': 'Wrong note.'},
          updatedPreferences: const SessionPreferences(
            maxBudget: 1000,
            excludedNotes: ['oud'],
          ),
        ),
        catalog: [
          _product(id: 'blocked', price: 900, notes: ['oud']),
          safe,
        ],
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: [
            RecommendedProduct(
              product: safe,
              matchReason: 'Fresh safe match.',
              matchScore: 0.8,
              matchLabel: 'Great Match',
            ),
          ],
          candidatesList: [safe],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts, isEmpty);
      expect(result.localRecoveryProducts.map((item) => item.product.id), [
        'safe',
      ]);
    });

    test('strict budget blocks slightly over-budget Worker ids', () {
      final events = <Map<String, dynamic>>[];
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['upsell'],
          matchReasons: const {'upsell': 'Strong match.'},
          updatedPreferences: const SessionPreferences(maxBudget: 900),
        ),
        catalog: [_product(id: 'upsell', price: 920)],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
          budgetPolicy: AIChatBudgetPolicy.strict,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts, isEmpty);
      expect(result.shouldNoMatch, isTrue);
      expect(
        events.any((event) => event['issueCode'] == 'budget_policy_block'),
        isTrue,
      );
    });

    test('strict budget local recovery keeps only within-budget products', () {
      final safe = _product(id: 'safe', price: 790);
      final over = _product(id: 'over', price: 920);
      final result = _guard(<Map<String, dynamic>>[]).guard(
        reply: AIChatReply.recommend(
          productIds: const ['missing'],
          matchReasons: const {},
          updatedPreferences: const SessionPreferences(maxBudget: 900),
        ),
        catalog: [safe, over],
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: [
            RecommendedProduct(
              product: over,
              matchReason: 'Slightly above.',
              matchScore: 0.9,
              matchLabel: 'Great Match',
            ),
            RecommendedProduct(
              product: safe,
              matchReason: 'Within budget.',
              matchScore: 0.8,
              matchLabel: 'Great Match',
            ),
          ],
          candidatesList: [over, safe],
          localFallbackAnswer: null,
          budgetPolicy: AIChatBudgetPolicy.strict,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.localRecoveryProducts.map((item) => item.product.id), [
        'safe',
      ]);
    });

    test('all blocked worker and local recovery cards produce no match', () {
      final events = <Map<String, dynamic>>[];
      final inactiveLocal = _product(
        id: 'inactive_local',
        price: 800,
        isActive: false,
      );
      final result = _guard(events).guard(
        reply: AIChatReply.recommend(
          productIds: const ['too_high'],
          matchReasons: const {'too_high': 'Luxury option.'},
          updatedPreferences: const SessionPreferences(maxBudget: 1000),
        ),
        catalog: [
          _product(id: 'too_high', price: 3450),
          inactiveLocal,
        ],
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: [
            RecommendedProduct(
              product: inactiveLocal,
              matchReason: 'Local fallback.',
              matchScore: 0.8,
              matchLabel: 'Great Match',
            ),
          ],
          candidatesList: [inactiveLocal],
          localFallbackAnswer: null,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts, isEmpty);
      expect(result.localRecoveryProducts, isEmpty);
      expect(result.shouldNoMatch, isTrue);
      expect(
        events.any((event) => event['issueCode'] == 'budget_policy_block'),
        isTrue,
      );
      expect(
        events.any((event) => event['issueCode'] == 'inactive_or_out_of_stock'),
        isTrue,
      );
    });

    test('flexible budget still allows disclosed upsell', () {
      final result = _guard(<Map<String, dynamic>>[]).guard(
        reply: AIChatReply.recommend(
          productIds: const ['upsell'],
          matchReasons: const {'upsell': 'Strong match.'},
          updatedPreferences: const SessionPreferences(maxBudget: 900),
        ),
        catalog: [_product(id: 'upsell', price: 920)],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
          budgetPolicy: AIChatBudgetPolicy.flexible,
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      expect(result.safeProducts.map((item) => item.product.id), ['upsell']);
      expect(
        result.safeProducts.single.budgetStatus,
        RecommendedBudgetStatus.slightlyAboveBudget,
      );
    });

    test(
      'uses recommendation context preferences when Worker omits budget',
      () {
        final result = _guard(<Map<String, dynamic>>[]).guard(
          reply: AIChatReply.recommend(
            productIds: const ['too-high', 'safe'],
            matchReasons: const {
              'too-high': 'Looks suitable.',
              'safe': 'Within budget.',
            },
            updatedPreferences: const SessionPreferences(),
          ),
          catalog: [
            _product(id: 'too-high', price: 1960),
            _product(id: 'safe', price: 1115),
          ],
          recommendationContext: AIChatRecommendationContext(
            localCandidatesRefs: [
              RecommendedProduct(
                product: _product(id: 'safe', price: 1115),
                matchReason: 'Within budget.',
                matchScore: 0.8,
                matchLabel: 'Great Match',
              ),
            ],
            candidatesList: [
              _product(id: 'too-high', price: 1960),
              _product(id: 'safe', price: 1115),
            ],
            localFallbackAnswer: null,
            budgetPolicy: AIChatBudgetPolicy.flexible,
            effectivePreferences: const SessionPreferences(maxBudget: 1200),
          ),
          language: AIChatLanguage.english,
          responseSource: 'ai_worker',
        );

        expect(result.safeProducts.map((item) => item.product.id), ['safe']);
      },
    );

    test(
      'replaces generic Worker reason with grounded local candidate reason',
      () {
        final product = _product(id: 'safe', price: 900);
        final result = _guard(<Map<String, dynamic>>[]).guard(
          reply: AIChatReply.recommend(
            productIds: const ['safe'],
            matchReasons: const {
              'safe':
                  'This perfume matches your current taste and preferences.',
            },
            updatedPreferences: const SessionPreferences(maxBudget: 1000),
          ),
          catalog: [product],
          recommendationContext: AIChatRecommendationContext(
            localCandidatesRefs: [
              RecommendedProduct(
                product: product,
                matchReason:
                    'Matches your citrus and musk preferences within budget.',
                matchScore: 0.84,
                matchLabel: 'Great Match',
              ),
            ],
            candidatesList: [product],
            localFallbackAnswer: null,
            effectivePreferences: const SessionPreferences(maxBudget: 1000),
          ),
          language: AIChatLanguage.english,
          responseSource: 'ai_worker',
        );

        expect(
          result.safeProducts.single.matchReason,
          'Matches your citrus and musk preferences within budget.',
        );
      },
    );

    test('replaces catalog facet reason with persuasive grounded copy', () {
      final product = _product(
        id: 'safe',
        price: 900,
        intensity: 'medium',
        notes: const ['fruity', 'citrus'],
      );
      final result = _guard(<Map<String, dynamic>>[]).guard(
        reply: AIChatReply.recommend(
          productIds: const ['safe'],
          matchReasons: const {'safe': 'Matched catalog facets: note:fruity.'},
          updatedPreferences: const SessionPreferences(
            intensity: 'light',
            preferredNotes: ['fruity'],
            maxBudget: 1000,
          ),
        ),
        catalog: [product],
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: [
            RecommendedProduct(
              product: product,
              matchReason: 'Matched catalog facets: note:fruity.',
              matchScore: 0.84,
              matchLabel: 'Great Match',
            ),
          ],
          candidatesList: [product],
          localFallbackAnswer: null,
          effectivePreferences: const SessionPreferences(
            intensity: 'light',
            preferredNotes: ['fruity'],
            maxBudget: 1000,
          ),
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker_safe_recovery',
      );

      final reason = result.safeProducts.single.matchReason;
      _expectCustomerFacingReason(reason);
      expect(reason, contains('Strong pick because'));
      expect(reason, contains('fruity notes'));
      expect(reason, contains('inside your 1000 EGP budget'));
      expect(
        reason,
        contains(
          'This is close to your request, but it may feel a little stronger than you asked for.',
        ),
      );
      expect(reason, isNot(contains('Matched catalog facets')));
      expect(reason, isNot(contains('note:fruity')));
      expect(reason, isNot(contains('Only note:')));
    });

    test('match reason mentions requested context that is not exact', () {
      final product = _product(id: 'partial', price: 900, intensity: 'medium');
      final result = _guard(<Map<String, dynamic>>[]).guard(
        reply: AIChatReply.recommend(
          productIds: const ['partial'],
          matchReasons: const {'partial': 'Matches your fresh preference.'},
          updatedPreferences: const SessionPreferences(
            intensity: 'light',
            maxBudget: 1200,
          ),
        ),
        catalog: [product],
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: [
            RecommendedProduct(
              product: product,
              matchReason: 'Matches your fresh preference.',
              matchScore: 0.7,
              matchLabel: 'Good Match',
            ),
          ],
          candidatesList: [product],
          localFallbackAnswer: null,
          effectivePreferences: const SessionPreferences(
            intensity: 'light',
            maxBudget: 1200,
          ),
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      final reason = result.safeProducts.single.matchReason;
      _expectCustomerFacingReason(reason);
      expect(reason, contains('Matches your fresh preference.'));
      expect(
        reason,
        contains(
          'This is close to your request, but it may feel a little stronger than you asked for.',
        ),
      );
      expect(reason, isNot(contains('Suitability:')));
      expect(reason, isNot(contains('medium_for_light_request')));
      expect(reason, isNot(contains('not exact on')));
    });

    test('deduplicates worker intensity note when caveat is appended', () {
      final product = _product(
        id: 'partial',
        price: 900,
        intensity: 'medium',
        notes: const ['fruity'],
      );
      final result = _guard(<Map<String, dynamic>>[]).guard(
        reply: AIChatReply.recommend(
          productIds: const ['partial'],
          matchReasons: const {
            'partial':
                'Matches fruity notes, note: intensity differs from request.',
          },
          updatedPreferences: const SessionPreferences(
            intensity: 'light',
            preferredNotes: ['fruity'],
            maxBudget: 1200,
          ),
        ),
        catalog: [product],
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: [
            RecommendedProduct(
              product: product,
              matchReason:
                  'Matches fruity notes, note: intensity differs from request.',
              matchScore: 0.8,
              matchLabel: 'Strong Match',
            ),
          ],
          candidatesList: [product],
          localFallbackAnswer: null,
          effectivePreferences: const SessionPreferences(
            intensity: 'light',
            preferredNotes: ['fruity'],
            maxBudget: 1200,
          ),
        ),
        language: AIChatLanguage.english,
        responseSource: 'ai_worker',
      );

      final reason = result.safeProducts.single.matchReason;
      _expectCustomerFacingReason(reason);
      expect(reason, contains('Matches fruity notes'));
      expect(
        reason,
        contains(
          'This is close to your request, but it may feel a little stronger than you asked for.',
        ),
      );
      expect(reason, contains('Matches fruity notes. This is close'));
      expect(reason, isNot(contains('notes Matches')));
      expect(reason, isNot(contains('intensity differs from request')));
      expect(reason, isNot(contains('Only note:')));
    });

    test(
      'replaces worker reason that claims unsupported requested fruit note',
      () {
        final product = _product(
          id: 'vanilla',
          price: 900,
          notes: const ['vanilla', 'aquatic'],
        );
        final result = _guard(<Map<String, dynamic>>[]).guard(
          reply: AIChatReply.recommend(
            productIds: const ['vanilla'],
            matchReasons: const {
              'vanilla': 'Matches mango notes and fits your vanilla request.',
            },
            updatedPreferences: const SessionPreferences(
              season: 'summer',
              preferredNotes: ['vanilla', 'mango'],
              maxBudget: 1200,
            ),
          ),
          catalog: [product],
          recommendationContext: AIChatRecommendationContext(
            localCandidatesRefs: [
              RecommendedProduct(
                product: product,
                matchReason: 'Matches mango notes.',
                matchScore: 0.75,
                matchLabel: 'Good Match',
              ),
            ],
            candidatesList: [product],
            localFallbackAnswer: null,
            effectivePreferences: const SessionPreferences(
              season: 'summer',
              preferredNotes: ['vanilla', 'mango'],
              maxBudget: 1200,
            ),
          ),
          language: AIChatLanguage.english,
          responseSource: 'ai_worker',
        );

        final reason = result.safeProducts.single.matchReason;
        _expectCustomerFacingReason(reason);
        expect(reason.toLowerCase(), isNot(contains('matches mango notes')));
        expect(reason, contains('vanilla notes'));
        expect(
          reason,
          contains(
            'I could not find mango explicitly in the catalog, so I am showing the closest catalog-backed alternatives.',
          ),
        );
        expect(reason, isNot(contains('not exact on mango note')));
      },
    );

    test(
      'allows accepted budget floor tool with disclosure above strict budget',
      () {
        final product = _product(id: 'floor', price: 790);
        final result = _guard(<Map<String, dynamic>>[]).guard(
          reply: AIChatReply.recommend(
            productIds: const ['floor'],
            matchReasons: const {
              'floor':
                  'This is above your original 600 EGP budget, but it is the lowest available option at 790 EGP.',
            },
            updatedPreferences: const SessionPreferences(maxBudget: 600),
          ),
          catalog: [product],
          recommendationContext: AIChatRecommendationContext(
            localCandidatesRefs: [
              RecommendedProduct(
                product: product,
                matchReason:
                    'This is above your original 600 EGP budget, but it is the lowest available option at 790 EGP.',
                matchScore: 1,
                matchLabel: 'Lowest Available',
              ),
            ],
            candidatesList: [product],
            localFallbackAnswer: null,
            effectivePreferences: const SessionPreferences(maxBudget: 600),
          ),
          language: AIChatLanguage.english,
          responseSource: 'tool_showLowestAvailableAfterBudgetNoMatch',
        );

        expect(result.safeProducts.map((item) => item.product.id), ['floor']);
        expect(
          result.safeProducts.single.matchReason,
          contains('above your original 600 EGP budget'),
        );
      },
    );

    test('keeps Arabic reference-cheaper reason with English product name', () {
      final product = _product(id: 'safe', price: 3200);
      const reason =
          'أرخص من Dior Sauvage وقريب منه في الرائحة لأنه يشترك معه في حمضيات، خشبي، عنبر.';
      final result = _guard(<Map<String, dynamic>>[]).guard(
        reply: AIChatReply.recommend(
          productIds: const ['safe'],
          matchReasons: const {'safe': reason},
          updatedPreferences: const SessionPreferences(maxBudget: 3899),
        ),
        catalog: [product],
        recommendationContext: AIChatRecommendationContext(
          localCandidatesRefs: [
            RecommendedProduct(
              product: product,
              matchReason: reason,
              matchScore: 0.62,
              matchLabel: 'بديل قريب',
            ),
          ],
          candidatesList: [product],
          localFallbackAnswer: null,
          effectivePreferences: const SessionPreferences(maxBudget: 3899),
        ),
        language: AIChatLanguage.arabic,
        responseSource: 'local_fallback',
      );

      expect(result.safeProducts.single.matchReason, reason);
      expect(result.safeProducts.single.matchLabel, 'بديل قريب');
    });

    test('Arabic generated reason displays light intensity as هادي', () {
      final product = _product(id: 'soft', price: 900, intensity: 'light');
      final result = _guard(<Map<String, dynamic>>[]).guard(
        reply: AIChatReply.recommend(
          productIds: const ['soft'],
          matchReasons: const {},
          updatedPreferences: const SessionPreferences(intensity: 'light'),
        ),
        catalog: [product],
        recommendationContext: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
          effectivePreferences: SessionPreferences(intensity: 'light'),
        ),
        language: AIChatLanguage.arabic,
        responseSource: 'local_fallback',
      );

      expect(result.safeProducts.single.matchReason, contains('هادي'));
      expect(result.safeProducts.single.matchReason, isNot(contains('خفيف')));
    });
  });
}
