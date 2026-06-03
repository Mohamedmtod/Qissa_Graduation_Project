import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_tool_executor.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  required double price,
  int stock = 5,
  bool isActive = true,
  String gender = 'unisex',
  String season = 'all_seasons',
  String family = 'fresh',
  List<String> notes = const <String>[],
  List<String> tags = const <String>[],
  String occasion = 'daily',
  String time = 'all_day',
  String intensity = 'medium',
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const <String>[],
    brand: 'Brand',
    price: price,
    stock: stock,
    gender: gender,
    season: season,
    fragranceFamily: family,
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: 'Test product',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: isActive,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: notes,
    middleNotes: const <String>[],
    baseNotes: const <String>[],
    tags: tags,
  );
}

AIChatReply _toolReply(AIChatToolCall toolCall, {String? answer}) {
  return AIChatReply.toolCall(
    toolCall: toolCall,
    answer: answer,
    updatedPreferences: const SessionPreferences(),
    requestId: 'tool-test',
  );
}

void main() {
  group('AIChatToolExecutor', () {
    const executor = AIChatToolExecutor();

    test(
      'search_products executes catalog search with structured args',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.searchProducts,
              arguments: {
                'gender': 'men',
                'occasion': 'university',
                'tags': ['fresh', 'clean'],
              },
            ),
            answer: 'I found a clean campus direction that should feel easy.',
          ),
          catalog: [
            _product(
              id: 'fit',
              name: 'Campus Fresh',
              price: 1200,
              gender: 'men',
              season: 'summer',
              occasion: 'office',
              time: 'day',
              intensity: 'light',
              notes: const ['citrus', 'musk'],
              tags: const ['fresh', 'clean', 'university'],
            ),
            _product(
              id: 'wrong_gender',
              name: 'Wrong Gender',
              price: 900,
              gender: 'women',
              tags: const ['fresh', 'clean'],
            ),
          ],
          currentPreferences: const SessionPreferences(),
          language: AIChatLanguage.english,
        );

        expect(result.handled, isTrue);
        expect(result.reply!.isRecommend, isTrue);
        expect(
          result.reply!.answer,
          'I found a clean campus direction that should feel easy.',
        );
        expect(result.status, AIChatToolResultStatus.success);
        expect(result.action, AIChatToolResultAction.recommend);
        expect(result.shouldRenderCards, isTrue);
        expect(
          result.renderIntent,
          AIChatToolRenderIntent.closestMatchesWithCaveat,
        );
        expect(result.recommendations.map((item) => item.product.id), ['fit']);
        expect(result.productIds, ['fit']);
        expect(result.preferences.gender, 'men');
      },
    );

    test('get_cheapest_products sorts by effective price', () async {
      final result = await executor.execute(
        reply: _toolReply(
          const AIChatToolCall(
            name: AIChatToolName.cheapestCatalog,
            arguments: {'limit': 2},
          ),
        ),
        catalog: [
          _product(id: 'mid', name: 'Mid', price: 1200),
          _product(id: 'cheap', name: 'Cheap', price: 700),
          _product(id: 'high', name: 'High', price: 2000),
        ],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
      );

      expect(result.handled, isTrue);
      expect(result.recommendations.map((item) => item.product.id), [
        'cheap',
        'mid',
      ]);
    });

    test(
      'search tools return not handled when no catalog result exists',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.searchProducts,
              arguments: {
                'notes': ['strawberry'],
              },
            ),
          ),
          catalog: const <ProductModel>[],
          currentPreferences: const SessionPreferences(),
          language: AIChatLanguage.english,
        );

        expect(result.handled, isFalse);
        expect(result.status, AIChatToolResultStatus.noResults);
        expect(result.action, AIChatToolResultAction.noMatch);
        expect(result.shouldRenderCards, isFalse);
        expect(result.reasonCode, 'tool_no_results');
      },
    );

    test('low confidence tool call asks for clarification', () async {
      final result = await executor.execute(
        reply: _toolReply(
          const AIChatToolCall(
            name: AIChatToolName.searchProducts,
            confidence: 0.42,
          ),
        ),
        catalog: [_product(id: 'fit', name: 'Fit', price: 900)],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
      );

      expect(result.handled, isTrue);
      expect(result.reply!.isAsk, isTrue);
      expect(result.status, AIChatToolResultStatus.needsClarification);
      expect(result.shouldRenderCards, isFalse);
      expect(result.traceReason, 'tool_confidence_below_threshold');
    });

    test('ask_clarification tool applies optional preference patch', () async {
      final patch = PreferencePatch()
        ..appendList(PreferenceListField.tags, ['clean', 'elegant']);

      final result = await executor.execute(
        reply: _toolReply(
          AIChatToolCall(
            name: AIChatToolName.askClarification,
            arguments: {
              'question': 'Do you mean sweet/sugary, or nice and pleasant?',
              'preferencePatch': patch.toJson(),
            },
          ),
        ),
        catalog: [_product(id: 'fit', name: 'Fit', price: 900)],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
      );

      expect(result.handled, isTrue);
      expect(result.reply!.isAsk, isTrue);
      expect(result.reply!.question, contains('sweet/sugary'));
      expect(result.status, AIChatToolResultStatus.needsClarification);
      expect(result.action, AIChatToolResultAction.askClarification);
      expect(result.shouldRenderCards, isFalse);
      expect(result.traceReason, 'llm_requested_clarification');
      expect(result.preferences.tags, ['clean', 'elegant']);
    });

    test(
      'update_preferences_and_recommend applies patch and recommends',
      () async {
        final patch = PreferencePatch()
          ..clearScalar(PreferenceScalar.intensity)
          ..appendList(PreferenceListField.tags, ['fresh']);
        final result = await executor.execute(
          reply: _toolReply(
            AIChatToolCall(
              name: AIChatToolName.updatePreferencesAndRecommend,
              arguments: {'preferencePatch': patch.toJson()},
            ),
          ),
          catalog: [
            _product(
              id: 'fresh-match',
              name: 'Fresh Match',
              price: 900,
              tags: const ['fresh'],
              notes: const ['citrus'],
            ),
          ],
          currentPreferences: const SessionPreferences(
            intensity: 'light',
            excludedNotes: ['vanilla'],
          ),
          language: AIChatLanguage.english,
        );

        expect(result.handled, isTrue);
        expect(result.reply!.isRecommend, isTrue);
        expect(result.status, AIChatToolResultStatus.success);
        expect(result.action, AIChatToolResultAction.recommend);
        expect(result.shouldRenderCards, isTrue);
        expect(result.productIds, contains('fresh-match'));
        expect(
          result.renderIntent,
          AIChatToolRenderIntent.preferenceRefinementResults,
        );
        expect(result.preferences.intensity, isNull);
        expect(result.preferences.tags, ['fresh']);
        expect(result.preferences.excludedNotes, ['vanilla']);
      },
    );

    test('budget floor tool renders lowest product with disclosure', () async {
      final result = await executor.execute(
        reply: _toolReply(
          const AIChatToolCall(
            name: AIChatToolName.showLowestAvailableAfterBudgetNoMatch,
          ),
        ),
        catalog: [
          _product(id: 'floor', name: 'Floor', price: 790),
          _product(id: 'higher', name: 'Higher', price: 1200),
        ],
        currentPreferences: const SessionPreferences(maxBudget: 600),
        language: AIChatLanguage.english,
        recommendationMemory: const RecommendationMemory(
          lastNoMatchContext: LastNoMatchContext(
            reason: 'budget_no_match',
            requestedBudget: 600,
            lowestAvailablePrice: 790,
            lowestAvailableProductIds: ['floor'],
          ),
        ),
      );

      expect(result.handled, isTrue);
      expect(result.status, AIChatToolResultStatus.success);
      expect(result.renderIntent, AIChatToolRenderIntent.budgetFloorDisclosure);
      expect(result.productIds, ['floor']);
      expect(
        result.disclosures.single,
        contains('above your original 600 EGP'),
      );
    });

    test(
      'budget floor tool requires previous budget no-match context',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.showLowestAvailableAfterBudgetNoMatch,
            ),
          ),
          catalog: [_product(id: 'floor', name: 'Floor', price: 790)],
          currentPreferences: const SessionPreferences(maxBudget: 600),
          language: AIChatLanguage.english,
        );

        expect(result.handled, isFalse);
        expect(result.status, AIChatToolResultStatus.validationFailed);
        expect(result.reasonCode, 'missing_budget_no_match_context');
      },
    );

    test('reject_visible_products excludes previous visible ids', () async {
      final result = await executor.execute(
        reply: _toolReply(
          const AIChatToolCall(
            name: AIChatToolName.rejectVisibleProducts,
            arguments: {'limit': 3},
          ),
        ),
        catalog: [
          _product(id: 'old', name: 'Old', price: 900, notes: const ['fruity']),
          _product(id: 'new', name: 'New', price: 950, notes: const ['fruity']),
        ],
        currentPreferences: const SessionPreferences(
          preferredNotes: ['fruity'],
        ),
        language: AIChatLanguage.english,
        recommendationMemory: const RecommendationMemory(
          lastRecommendedProducts: [
            RecommendedProductRef(
              productId: 'old',
              name: 'Old',
              brand: 'Brand',
              displayIndex: 1,
              price: 900,
              stock: 5,
              season: 'all_seasons',
              occasion: 'daily',
              intensity: 'medium',
              notes: ['fruity'],
            ),
          ],
        ),
      );

      expect(result.handled, isTrue);
      expect(result.status, AIChatToolResultStatus.success);
      expect(result.renderIntent, AIChatToolRenderIntent.rejectionRecovery);
      expect(result.productIds, isNot(contains('old')));
      expect(result.productIds, contains('new'));
    });

    test(
      'reject_visible_products asks direction when all alternatives filtered',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(name: AIChatToolName.rejectVisibleProducts),
          ),
          catalog: [
            _product(
              id: 'old',
              name: 'Old',
              price: 900,
              notes: const ['fruity'],
            ),
          ],
          currentPreferences: const SessionPreferences(
            preferredNotes: ['fruity'],
          ),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'old',
                name: 'Old',
                brand: 'Brand',
                displayIndex: 1,
                price: 900,
                stock: 5,
                season: 'all_seasons',
                occasion: 'daily',
                intensity: 'medium',
                notes: ['fruity'],
              ),
            ],
          ),
        );

        expect(result.handled, isTrue);
        expect(result.reply!.isAsk, isTrue);
        expect(result.status, AIChatToolResultStatus.needsClarification);
        expect(result.shouldRenderCards, isFalse);
      },
    );

    test('similar_cheaper uses focused product as anchor', () async {
      final result = await executor.execute(
        reply: _toolReply(
          const AIChatToolCall(
            name: AIChatToolName.similarCheaper,
            arguments: {'anchorRef': 'last_focused_product'},
          ),
        ),
        catalog: [
          _product(
            id: 'anchor',
            name: 'Acqua',
            price: 3350,
            gender: 'men',
            family: 'fresh aquatic',
            notes: const ['aquatic', 'citrus', 'fresh', 'musk'],
            tags: const ['fresh', 'clean', 'masculine'],
          ),
          _product(
            id: 'similar',
            name: 'Ocean Fresh',
            price: 2100,
            gender: 'men',
            family: 'fresh aquatic',
            notes: const ['aquatic', 'citrus', 'fresh', 'musk'],
            tags: const ['fresh', 'clean', 'masculine'],
          ),
          _product(
            id: 'unrelated',
            name: 'Dark Vanilla',
            price: 700,
            gender: 'men',
            family: 'sweet gourmand',
            notes: const ['vanilla', 'oud', 'sweet'],
            tags: const ['warm'],
          ),
        ],
        currentPreferences: const SessionPreferences(gender: 'men'),
        language: AIChatLanguage.english,
        recommendationMemory: const RecommendationMemory(
          lastFocusedProductId: 'anchor',
        ),
      );

      expect(result.handled, isTrue);
      expect(result.status, AIChatToolResultStatus.success);
      expect(result.renderIntent, AIChatToolRenderIntent.similarCheaperResults);
      expect(result.traceReason, 'anchor_price_similarity');
      expect(result.productIds, ['similar']);
      expect(result.productIds, isNot(contains('unrelated')));
    });

    test(
      'similar_cheaper asks clarification when anchor is ambiguous',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(name: AIChatToolName.similarCheaper),
          ),
          catalog: [
            _product(id: 'one', name: 'One', price: 2000),
            _product(id: 'two', name: 'Two', price: 2200),
          ],
          currentPreferences: const SessionPreferences(),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'one',
                name: 'One',
                brand: 'Brand',
                displayIndex: 1,
                price: 2000,
                stock: 5,
                season: 'all_seasons',
                occasion: 'daily',
                intensity: 'medium',
                notes: [],
              ),
              RecommendedProductRef(
                productId: 'two',
                name: 'Two',
                brand: 'Brand',
                displayIndex: 2,
                price: 2200,
                stock: 5,
                season: 'all_seasons',
                occasion: 'daily',
                intensity: 'medium',
                notes: [],
              ),
            ],
          ),
        );

        expect(result.handled, isTrue);
        expect(result.reply!.isAsk, isTrue);
        expect(result.status, AIChatToolResultStatus.needsClarification);
        expect(result.shouldRenderCards, isFalse);
        expect(
          result.traceReason,
          'anchor_ambiguous_multiple_visible_products',
        );
      },
    );

    test(
      'cheaper_followup uses visible minimum price when no focus exists',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.cheaperFollowup,
              arguments: {'limit': 3},
            ),
          ),
          catalog: [
            _product(id: 'visible_high', name: 'Visible High', price: 2000),
            _product(id: 'visible_low', name: 'Visible Low', price: 1500),
            _product(id: 'below_one', name: 'Below One', price: 900),
            _product(id: 'below_two', name: 'Below Two', price: 1400),
            _product(id: 'too_high', name: 'Too High', price: 1600),
          ],
          currentPreferences: const SessionPreferences(),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'visible_high',
                name: 'Visible High',
                brand: 'Brand',
                displayIndex: 1,
                price: 2000,
                stock: 5,
                season: 'all_seasons',
                occasion: 'daily',
                intensity: 'medium',
                notes: [],
              ),
              RecommendedProductRef(
                productId: 'visible_low',
                name: 'Visible Low',
                brand: 'Brand',
                displayIndex: 2,
                price: 1500,
                stock: 5,
                season: 'all_seasons',
                occasion: 'daily',
                intensity: 'medium',
                notes: [],
              ),
            ],
          ),
        );

        expect(result.handled, isTrue);
        expect(result.status, AIChatToolResultStatus.success);
        expect(
          result.renderIntent,
          AIChatToolRenderIntent.cheaperFollowupResults,
        );
        expect(result.traceReason, 'visible_minimum_price_ceiling');
        expect(result.productIds, containsAll(['below_one', 'below_two']));
        expect(result.productIds, isNot(contains('too_high')));
        expect(result.productIds, isNot(contains('visible_low')));
      },
    );

    test(
      'cheaper_followup with focused anchor uses anchor price ceiling',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(name: AIChatToolName.cheaperFollowup),
          ),
          catalog: [
            _product(
              id: 'anchor',
              name: 'Anchor',
              price: 2500,
              gender: 'men',
              family: 'fresh citrus',
              notes: const ['citrus', 'musk', 'fresh'],
              tags: const ['fresh', 'clean'],
            ),
            _product(
              id: 'lower_similar',
              name: 'Lower Similar',
              price: 1200,
              gender: 'men',
              family: 'fresh citrus',
              notes: const ['citrus', 'musk', 'fresh'],
              tags: const ['fresh', 'clean'],
            ),
            _product(
              id: 'higher_similar',
              name: 'Higher Similar',
              price: 2600,
              gender: 'men',
              family: 'fresh citrus',
              notes: const ['citrus', 'musk', 'fresh'],
              tags: const ['fresh', 'clean'],
            ),
          ],
          currentPreferences: const SessionPreferences(gender: 'men'),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            lastFocusedProductId: 'anchor',
          ),
        );

        expect(result.handled, isTrue);
        expect(result.status, AIChatToolResultStatus.success);
        expect(
          result.renderIntent,
          AIChatToolRenderIntent.cheaperFollowupResults,
        );
        expect(result.productIds, ['lower_similar']);
        expect(result.productIds, isNot(contains('higher_similar')));
      },
    );

    test(
      'recommend_similar_to_external_profile uses last external profile',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.recommendSimilarToExternalProfile,
              arguments: {'externalProfileId': 'dior_sauvage'},
            ),
          ),
          catalog: [
            _product(
              id: 'close',
              name: 'Fresh Pepper Woods',
              price: 2500,
              gender: 'men',
              family: 'fresh spicy',
              notes: const ['bergamot', 'pepper', 'ambroxan', 'woody'],
              tags: const ['fresh', 'spicy', 'masculine'],
            ),
            _product(
              id: 'far',
              name: 'Sweet Rose',
              price: 1500,
              gender: 'women',
              family: 'floral',
              notes: const ['rose', 'vanilla', 'sweet'],
              tags: const ['romantic'],
            ),
          ],
          currentPreferences: const SessionPreferences(gender: 'men'),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            lastExternalProfile: ExternalProfileRef(
              id: 'dior_sauvage',
              name: 'Dior Sauvage',
              brand: 'Dior',
              fragranceFamily: 'fresh spicy',
              notes: ['bergamot', 'pepper', 'ambroxan', 'woody'],
              tags: ['fresh', 'spicy', 'masculine'],
              confidence: 0.91,
            ),
          ),
        );

        expect(result.handled, isTrue);
        expect(result.status, AIChatToolResultStatus.success);
        expect(
          result.renderIntent,
          AIChatToolRenderIntent.externalProfileSimilarResults,
        );
        expect(result.source, 'tool_recommendSimilarToExternalProfile');
        expect(result.externalProfileId, 'dior_sauvage');
        expect(result.productIds, ['close']);
        expect(result.productIds, isNot(contains('dior_sauvage')));
        expect(
          result.updatedRecommendationMemory?.lastExternalProfile?.id,
          'dior_sauvage',
        );
      },
    );

    test(
      'similar_cheaper_to_external_profile applies verified price ceiling',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.similarCheaperToExternalProfile,
              arguments: {'externalProfileId': 'dior_sauvage'},
            ),
          ),
          catalog: [
            _product(
              id: 'below',
              name: 'Below',
              price: 3200,
              gender: 'men',
              family: 'fresh spicy',
              notes: const ['bergamot', 'pepper', 'woody'],
              tags: const ['fresh', 'spicy'],
            ),
            _product(
              id: 'above',
              name: 'Above',
              price: 5200,
              gender: 'men',
              family: 'fresh spicy',
              notes: const ['bergamot', 'pepper', 'woody'],
              tags: const ['fresh', 'spicy'],
            ),
          ],
          currentPreferences: const SessionPreferences(gender: 'men'),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            lastExternalProfile: ExternalProfileRef(
              id: 'dior_sauvage',
              name: 'Dior Sauvage',
              fragranceFamily: 'fresh spicy',
              notes: ['bergamot', 'pepper', 'woody'],
              tags: ['fresh', 'spicy'],
              confidence: 0.91,
              priceReference: 5000,
            ),
          ),
        );

        expect(result.handled, isTrue);
        expect(result.status, AIChatToolResultStatus.success);
        expect(
          result.renderIntent,
          AIChatToolRenderIntent.externalProfileCheaperResults,
        );
        expect(
          result.traceReason,
          'external_profile_similarity_with_verified_price_ceiling',
        );
        expect(result.productIds, ['below']);
        expect(result.productIds, isNot(contains('above')));
        expect(
          result.updatedRecommendationMemory?.lastExternalProfile?.id,
          'dior_sauvage',
        );
      },
    );

    test(
      'similar_cheaper_to_external_profile avoids cheaper claim without price',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.similarCheaperToExternalProfile,
              arguments: {'externalProfileId': 'dior_sauvage'},
            ),
          ),
          catalog: [
            _product(
              id: 'similar',
              name: 'Similar',
              price: 8000,
              gender: 'men',
              family: 'fresh spicy',
              notes: const ['bergamot', 'pepper', 'woody'],
              tags: const ['fresh', 'spicy'],
            ),
          ],
          currentPreferences: const SessionPreferences(gender: 'men'),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            lastExternalProfile: ExternalProfileRef(
              id: 'dior_sauvage',
              name: 'Dior Sauvage',
              fragranceFamily: 'fresh spicy',
              notes: ['bergamot', 'pepper', 'woody'],
              tags: ['fresh', 'spicy'],
              confidence: 0.91,
            ),
          ),
        );

        expect(result.handled, isTrue);
        expect(result.status, AIChatToolResultStatus.success);
        expect(result.productIds, ['similar']);
        expect(result.disclosures.single, contains('cannot verify'));
        expect(
          result.traceReason,
          'external_profile_similarity_without_verified_price_reference',
        );
        expect(
          result.reply!.matchReasons['similar'],
          contains('cannot verify'),
        );
      },
    );

    test('external profile tool rejects ungrounded profile id', () async {
      final result = await executor.execute(
        reply: _toolReply(
          const AIChatToolCall(
            name: AIChatToolName.recommendSimilarToExternalProfile,
            arguments: {'externalProfileId': 'invented_profile'},
          ),
        ),
        catalog: [_product(id: 'p1', name: 'P1', price: 1000)],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
        recommendationMemory: const RecommendationMemory(
          lastExternalProfile: ExternalProfileRef(
            id: 'dior_sauvage',
            name: 'Dior Sauvage',
            notes: ['fresh'],
          ),
        ),
      );

      expect(result.handled, isFalse);
      expect(result.reasonCode, 'ungrounded_external_profile_id');
      expect(result.shouldRenderCards, isFalse);
    });

    test('all declared tool names have a Dart handler', () async {
      final catalog = [
        _product(id: 'p1', name: 'Light Blue', price: 1000),
        _product(id: 'p2', name: 'Fresh Cheaper', price: 700),
      ];
      for (final toolName in AIChatToolName.values) {
        final args = switch (toolName) {
          AIChatToolName.searchProducts => {'limit': 1},
          AIChatToolName.cheapestCatalog => {'limit': 1},
          AIChatToolName.mostExpensiveCatalog => {'limit': 1},
          AIChatToolName.updatePreferencesAndRecommend => {
            'preferencePatch':
                (PreferencePatch()
                      ..appendList(PreferenceListField.tags, ['fresh']))
                    .toJson(),
          },
          AIChatToolName.answerProductQuestion => {'productId': 'p1'},
          AIChatToolName.askProductClarification => const <String, dynamic>{},
          AIChatToolName.similarCheaper => {'productId': 'p1'},
          AIChatToolName.cheaperFollowup => {'limit': 1},
          AIChatToolName.showLowestAvailableAfterBudgetNoMatch => {
            'productId': 'p1',
          },
          AIChatToolName.rejectVisibleProducts => {
            'rejectedProductIds': ['p1'],
          },
          AIChatToolName.resolvePerfumeReference => {'query': 'Light Blue'},
          AIChatToolName.selectPerfumeReferenceOption => {'userReply': '1'},
          AIChatToolName.lookupExternalPerfumeProfile => {'query': 'Dior'},
          AIChatToolName.recommendSimilarToExternalProfile => {
            'externalProfileId': 'profile',
          },
          AIChatToolName.similarCheaperToExternalProfile => {
            'externalProfileId': 'profile',
          },
          AIChatToolName.askClarification => {'question': 'Which one?'},
        };
        final result = await executor.execute(
          reply: _toolReply(AIChatToolCall(name: toolName, arguments: args)),
          catalog: catalog,
          currentPreferences: const SessionPreferences(tags: ['fresh']),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            lastFocusedProductId: 'p1',
            lastNoMatchContext: LastNoMatchContext(
              reason: 'budget_no_match',
              requestedBudget: 500,
              lowestAvailablePrice: 700,
              lowestAvailableProductIds: ['p2'],
            ),
            lastExternalProfile: ExternalProfileRef(
              id: 'profile',
              name: 'External Profile',
              notes: ['fresh'],
              tags: ['fresh'],
            ),
            pendingPerfumeReferenceClarification:
                PendingPerfumeReferenceClarification(
                  query: 'Light',
                  options: [
                    PerfumeReferenceOptionRef(
                      index: 1,
                      name: 'Light Blue',
                      source: 'catalog',
                      productId: 'p1',
                    ),
                  ],
                ),
          ),
        );
        expect(
          result.reasonCode,
          isNot('tool_not_implemented'),
          reason: '${toolName.name} should not use the old stub.',
        );
        expect(
          result.traceReason,
          isNot('tool_not_implemented'),
          reason: '${toolName.name} should not use the old stub.',
        );
      }
    });

    test('resolve_perfume_reference resolves catalog product safely', () async {
      final result = await executor.execute(
        reply: _toolReply(
          const AIChatToolCall(
            name: AIChatToolName.resolvePerfumeReference,
            arguments: {'query': 'Light Blue'},
          ),
        ),
        catalog: [_product(id: 'light_blue', name: 'Light Blue', price: 1200)],
        currentPreferences: const SessionPreferences(),
        language: AIChatLanguage.english,
      );

      expect(result.handled, isTrue);
      expect(result.status, AIChatToolResultStatus.success);
      expect(result.action, AIChatToolResultAction.answer);
      expect(result.shouldRenderCards, isFalse);
      expect(result.referenceStatus, 'resolved');
      expect(result.referenceSource, 'catalog');
      expect(
        result.updatedRecommendationMemory!.lastFocusedProductId,
        'light_blue',
      );
    });

    test(
      'resolve_perfume_reference asks clarification for ambiguous catalog',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.resolvePerfumeReference,
              arguments: {'query': 'Blue'},
            ),
          ),
          catalog: [
            _product(id: 'blue_1', name: 'Blue Fresh', price: 1200),
            _product(id: 'blue_2', name: 'Blue Night', price: 1300),
          ],
          currentPreferences: const SessionPreferences(),
          language: AIChatLanguage.english,
        );

        expect(result.handled, isTrue);
        expect(result.status, AIChatToolResultStatus.needsClarification);
        expect(result.shouldRenderCards, isFalse);
        expect(result.referenceStatus, 'needs_clarification');
        expect(
          result
              .updatedRecommendationMemory!
              .pendingPerfumeReferenceClarification,
          isNotNull,
        );
      },
    );

    test(
      'lookup_external_perfume_profile stores profile as anchor only',
      () async {
        final executor = AIChatToolExecutor(
          lookupExternal:
              ({required query, required responseLanguage, requestId}) async {
                return const ExternalPerfumeLookupResult.found(
                  PerfumeKnowledgeProfile(
                    id: 'dior_sauvage',
                    displayName: 'Dior Sauvage',
                    brand: 'Dior',
                    accords: ['fresh', 'spicy'],
                    topNotes: ['bergamot'],
                    baseNotes: ['ambroxan'],
                    fragranceFamily: 'fresh spicy',
                    lookupConfidence: 0.93,
                  ),
                );
              },
        );

        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.lookupExternalPerfumeProfile,
              arguments: {'query': 'Dior Sauvage'},
            ),
          ),
          catalog: const <ProductModel>[],
          currentPreferences: const SessionPreferences(),
          language: AIChatLanguage.english,
        );

        expect(result.handled, isTrue);
        expect(result.status, AIChatToolResultStatus.success);
        expect(result.shouldRenderCards, isFalse);
        expect(result.externalProfileId, 'dior_sauvage');
        expect(
          result.updatedRecommendationMemory!.lastExternalProfile!.name,
          'Dior Sauvage',
        );
      },
    );

    test(
      'select_perfume_reference_option resolves number reply from pending options',
      () async {
        final result = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.selectPerfumeReferenceOption,
              arguments: {'userReply': '2'},
            ),
          ),
          catalog: [
            _product(id: 'one', name: 'Option One', price: 1000),
            _product(id: 'two', name: 'Option Two', price: 1100),
          ],
          currentPreferences: const SessionPreferences(),
          language: AIChatLanguage.english,
          recommendationMemory: const RecommendationMemory(
            pendingPerfumeReferenceClarification:
                PendingPerfumeReferenceClarification(
                  query: 'option',
                  options: [
                    PerfumeReferenceOptionRef(
                      index: 1,
                      name: 'Option One',
                      source: 'catalog',
                      productId: 'one',
                    ),
                    PerfumeReferenceOptionRef(
                      index: 2,
                      name: 'Option Two',
                      source: 'catalog',
                      productId: 'two',
                    ),
                  ],
                ),
          ),
        );

        expect(result.handled, isTrue);
        expect(result.status, AIChatToolResultStatus.success);
        expect(result.selectedOptionIndex, 2);
        expect(result.updatedRecommendationMemory!.lastFocusedProductId, 'two');
        expect(
          result
              .updatedRecommendationMemory!
              .pendingPerfumeReferenceClarification,
          isNull,
        );
      },
    );
  });
}
