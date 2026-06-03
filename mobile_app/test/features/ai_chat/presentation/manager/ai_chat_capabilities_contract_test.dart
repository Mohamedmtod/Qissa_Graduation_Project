import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_deterministic_commerce_router.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_tool_executor.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/final_recommendation_guard.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/perfume_reference_resolver.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

void main() {
  group('AI Chat capability contract', () {
    test('extracts preferences, budget, allergy and intent safely', () async {
      final preferences = LocalIntentParser.parse(
        'عايز perfume رجالي fresh fruity under 600 for university no oud light',
        SessionPreferences.empty(),
      );

      expect(preferences.gender, 'men');
      expect(preferences.maxBudget, 600);
      expect(preferences.occasion, 'university');
      expect(preferences.intensity, 'light');
      expect(preferences.preferredNotes, contains('fruity'));
      expect(preferences.tags, contains('fresh'));
      expect(preferences.excludedNotes, contains('oud'));

      final strictBudget = LocalIntentParser.parse(
        'budget 600 no 900',
        SessionPreferences.empty(),
      );
      expect(strictBudget.maxBudget, 600);

      final allergic = LocalIntentParser.parse(
        'vanilla gives me allergy',
        SessionPreferences.empty(),
      );
      expect(allergic.excludedNotes, contains('vanilla'));
      expect(allergic.medicalExcludedNotes, contains('vanilla'));

      expect(
        LocalIntentParser.detectIntent('Do you have Light Blue?'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('is the first one suitable for work?'),
        AIChatIntent.followUpProduct,
      );
    });

    test(
      'routes grounded commerce follow-ups to deterministic tools',
      () async {
        const router = AIChatDeterministicCommerceRouter();

        final budgetFloor = router.resolve(
          message: 'ok show me it',
          memory: const RecommendationMemory(
            lastNoMatchContext: LastNoMatchContext(
              reason: 'budget_no_match',
              requestedBudget: 600,
              lowestAvailablePrice: 790,
              lowestAvailableProductIds: ['floor'],
            ),
          ),
        );
        expect(
          budgetFloor?.toolName,
          AIChatToolName.showLowestAvailableAfterBudgetNoMatch,
        );

        final rejection = router.resolve(
          message: "I don't like these",
          memory: RecommendationMemory(
            lastRecommendedProducts: [_ref('old_one', 1), _ref('old_two', 2)],
          ),
        );
        expect(rejection?.toolName, AIChatToolName.rejectVisibleProducts);
        expect(rejection?.arguments['rejectedProductIds'], [
          'old_one',
          'old_two',
        ]);

        final cheaper = router.resolve(
          message: 'show me something cheaper',
          memory: RecommendationMemory(
            lastRecommendedProducts: [_ref('visible', 1, price: 1500)],
          ),
        );
        expect(cheaper?.toolName, AIChatToolName.cheaperFollowup);

        final similarCheaper = router.resolve(
          message: 'similar but cheaper',
          memory: const RecommendationMemory(lastFocusedProductId: 'anchor'),
        );
        expect(similarCheaper?.toolName, AIChatToolName.similarCheaper);

        final noRandomAnchor = router.resolve(
          message: 'similar but cheaper',
          memory: const RecommendationMemory(),
        );
        expect(noRandomAnchor, isNull);
      },
    );

    test(
      'executes tool contract with guardable catalog-only outcomes',
      () async {
        const executor = AIChatToolExecutor();

        final lowConfidence = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.searchProducts,
              confidence: 0.41,
            ),
          ),
          catalog: [_product(id: 'fit', name: 'Fit', price: 900)],
          currentPreferences: SessionPreferences.empty(),
          language: AIChatLanguage.english,
        );
        expect(lowConfidence.status, AIChatToolResultStatus.needsClarification);
        expect(lowConfidence.shouldRenderCards, isFalse);

        final recommendation = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.searchProducts,
              arguments: {
                'gender': 'men',
                'occasion': 'university',
                'notes': ['fruity'],
                'tags': ['fresh'],
              },
            ),
          ),
          catalog: [
            _product(
              id: 'fit',
              name: 'Campus Fresh',
              price: 1200,
              gender: 'men',
              occasion: 'office',
              intensity: 'light',
              notes: const ['fruity', 'citrus', 'musk'],
              tags: const ['fresh', 'clean', 'university'],
            ),
            _product(
              id: 'inactive',
              name: 'Inactive',
              price: 700,
              isActive: false,
              notes: const ['fruity'],
              tags: const ['fresh'],
            ),
          ],
          currentPreferences: SessionPreferences.empty(),
          language: AIChatLanguage.english,
        );
        expect(recommendation.status, AIChatToolResultStatus.success);
        expect(recommendation.action, AIChatToolResultAction.recommend);
        expect(recommendation.shouldRenderCards, isTrue);
        expect(recommendation.productIds, ['fit']);

        final budgetFloor = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.showLowestAvailableAfterBudgetNoMatch,
            ),
          ),
          catalog: [
            _product(id: 'floor', name: 'Budget Citrus', price: 790),
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
        expect(
          budgetFloor.renderIntent,
          AIChatToolRenderIntent.budgetFloorDisclosure,
        );
        expect(budgetFloor.productIds, ['floor']);
        expect(budgetFloor.disclosures.single, contains('above your original'));

        final rejection = await executor.execute(
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
            _product(
              id: 'new',
              name: 'New',
              price: 950,
              notes: const ['fruity'],
            ),
          ],
          currentPreferences: const SessionPreferences(
            preferredNotes: ['fruity'],
          ),
          language: AIChatLanguage.english,
          recommendationMemory: RecommendationMemory(
            lastRecommendedProducts: [_ref('old', 1, price: 900)],
          ),
        );
        expect(
          rejection.renderIntent,
          AIChatToolRenderIntent.rejectionRecovery,
        );
        expect(rejection.productIds, isNot(contains('old')));
        expect(rejection.productIds, contains('new'));
      },
    );

    test(
      'serializes compact context v3 without exposing sensitive text',
      () async {
        final context = AIChatCompactConversationContext.fromMessages(
          messages: [
            AIChatMessage.user('one'),
            AIChatMessage.botText('two'),
            AIChatMessage.user('email user@example.com or 01012345678'),
            AIChatMessage.botText('four'),
            AIChatMessage.user('show me it'),
          ],
          recentMessageLimit: 3,
          recommendationMemory: const RecommendationMemory(
            lastFocusedProductId: 'p1',
            lastRecommendedProducts: [
              RecommendedProductRef(
                productId: 'p1',
                name: 'Light Blue',
                brand: 'Dolce & Gabbana',
                displayIndex: 1,
                price: 3250,
                stock: 30,
                season: 'summer',
                occasion: 'office',
                intensity: 'medium',
                notes: ['fruity'],
              ),
            ],
            lastNoMatchContext: LastNoMatchContext(
              reason: 'budget_no_match',
              requestedBudget: 600,
              lowestAvailablePrice: 790,
              lowestAvailableProductIds: ['floor'],
            ),
            lastExternalProfile: ExternalProfileRef(
              id: 'dior_sauvage',
              name: 'Dior Sauvage',
              brand: 'Dior',
              fragranceFamily: 'fresh spicy',
              notes: ['bergamot', 'pepper'],
              tags: ['fresh', 'spicy'],
              confidence: 0.91,
            ),
            pendingPerfumeReferenceClarification:
                PendingPerfumeReferenceClarification(
                  query: 'Dior',
                  options: [
                    PerfumeReferenceOptionRef(
                      index: 1,
                      name: 'Dior Sauvage',
                      brand: 'Dior',
                      source: 'perfumeKnowledge',
                      externalProfileId: 'dior_sauvage',
                      confidence: 0.91,
                    ),
                  ],
                ),
          ),
          currentPreferences: const SessionPreferences(
            gender: 'men',
            maxBudget: 600,
            preferredNotes: ['fruity'],
          ),
        );

        final json = context.toJson();
        expect(json['compactContextVersion'], 3);
        expect(json['commerceContextVersion'], 1);
        expect(json['lastFocusedProductId'], 'p1');
        expect(json['lastRecommendationIds'], ['p1']);
        expect(json['allowedTools'], contains('reject_visible_products'));
        expect(
          json['allowedTools'],
          contains('similar_cheaper_to_external_profile'),
        );
        expect(json['lastExternalProfile'], containsPair('id', 'dior_sauvage'));
        expect(
          json['pendingPerfumeReferenceClarification'],
          containsPair('query', 'Dior'),
        );
        expect(json['recentMessages'], hasLength(3));
        expect(json.toString(), isNot(contains('user@example.com')));
        expect(json.toString(), isNot(contains('01012345678')));
      },
    );

    test(
      'resolves perfume references without guessing ambiguous names',
      () async {
        final catalogFirst = PerfumeReferenceResolver(
          lookupExternal:
              ({required query, required responseLanguage, requestId}) async {
                fail('catalog exact match must not call external lookup');
              },
        );
        final lightBlue = await catalogFirst.resolve(
          query: 'Light Blue',
          catalog: _catalog(),
          language: AIChatLanguage.english,
        );
        expect(lightBlue.status, PerfumeReferenceStatus.resolved);
        expect(lightBlue.source, PerfumeReferenceSource.catalog);
        expect(lightBlue.product?.id, 'light_blue');

        final ambiguousBrand = await const PerfumeReferenceResolver().resolve(
          query: 'Dior',
          catalog: [
            ..._catalog(),
            _product(
              id: 'dior_sauvage',
              name: 'Sauvage',
              brand: 'Dior',
              price: 3000,
            ),
            _product(
              id: 'dior_homme',
              name: 'Dior Homme Intense',
              brand: 'Dior',
              price: 3000,
            ),
          ],
          language: AIChatLanguage.english,
        );
        expect(
          ambiguousBrand.status,
          PerfumeReferenceStatus.needsClarification,
        );
        expect(
          ambiguousBrand.options.map((item) => item.productId),
          containsAll(['dior_sauvage', 'dior_homme']),
        );

        final seriesResolver = PerfumeReferenceResolver(
          lookupExternal:
              ({required query, required responseLanguage, requestId}) async {
                return const ExternalPerfumeLookupResult.ambiguous([
                  ExternalPerfumeCandidate(
                    id: 'swy_intensely',
                    displayName: 'Stronger With You Intensely',
                    brand: 'Giorgio Armani',
                    sourceUrl: 'https://example.com/intensely.html',
                    score: 0.86,
                  ),
                  ExternalPerfumeCandidate(
                    id: 'swy_absolutely',
                    displayName: 'Stronger With You Absolutely',
                    brand: 'Giorgio Armani',
                    sourceUrl: 'https://example.com/absolutely.html',
                    score: 0.84,
                  ),
                ]);
              },
        );
        final strongerWithYou = await seriesResolver.resolve(
          query: 'Stronger With You',
          catalog: _catalog(),
          language: AIChatLanguage.english,
        );
        expect(
          strongerWithYou.status,
          PerfumeReferenceStatus.needsClarification,
        );
        expect(strongerWithYou.options, hasLength(2));

        final exactExternal =
            await PerfumeReferenceResolver(
              lookupKnowledge: (_) async => _profile(
                id: 'swy_intensely',
                displayName: 'Stronger With You Intensely',
                brand: 'Giorgio Armani',
                aliases: const ['stronger with you intensely'],
              ),
            ).resolve(
              query: 'Stronger With You Intensely',
              catalog: _catalog(),
              language: AIChatLanguage.english,
            );
        expect(exactExternal.status, PerfumeReferenceStatus.resolved);
        expect(exactExternal.source, PerfumeReferenceSource.perfumeKnowledge);

        final fake =
            await PerfumeReferenceResolver(
              lookupKnowledge: (_) async => null,
              lookupExternal:
                  ({
                    required query,
                    required responseLanguage,
                    requestId,
                  }) async {
                    return const ExternalPerfumeLookupResult.notFound();
                  },
            ).resolve(
              query: 'Ocean Dragon Royal',
              catalog: _catalog(),
              language: AIChatLanguage.english,
            );
        expect(fake.status, PerfumeReferenceStatus.notFound);

        final cacheDenied =
            await PerfumeReferenceResolver(
              lookupKnowledge: (_) async {
                throw FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'permission-denied',
                );
              },
            ).resolve(
              query: 'Azzaro Pour Homme',
              catalog: _catalog(),
              language: AIChatLanguage.english,
            );
        expect(cacheDenied.status, PerfumeReferenceStatus.cacheUnavailable);

        const resolver = PerfumeReferenceResolver();
        expect(
          resolver
              .selectOption(
                userReply: 'الأول',
                options: strongerWithYou.options,
              )
              ?.externalProfileId,
          'swy_intensely',
        );
        expect(
          resolver
              .selectOption(
                userReply: 'absolutely',
                options: strongerWithYou.options,
              )
              ?.externalProfileId,
          'swy_absolutely',
        );
      },
    );

    test(
      'keeps external profiles as anchors and final cards catalog-safe',
      () async {
        const executor = AIChatToolExecutor();
        final similar = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.recommendSimilarToExternalProfile,
              arguments: {'externalProfileId': 'dior_sauvage'},
            ),
          ),
          catalog: [
            _product(
              id: 'catalog_close',
              name: 'Fresh Pepper Woods',
              price: 3200,
              gender: 'men',
              family: 'fresh spicy',
              notes: const ['bergamot', 'pepper', 'ambroxan', 'woody'],
              tags: const ['fresh', 'spicy', 'masculine'],
            ),
            _product(
              id: 'catalog_far',
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
        expect(
          similar.renderIntent,
          AIChatToolRenderIntent.externalProfileSimilarResults,
        );
        expect(similar.productIds, ['catalog_close']);
        expect(similar.productIds, isNot(contains('dior_sauvage')));

        final cheaper = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.similarCheaperToExternalProfile,
              arguments: {'externalProfileId': 'dior_sauvage'},
            ),
          ),
          catalog: [
            _product(
              id: 'below_reference',
              name: 'Below',
              price: 3200,
              gender: 'men',
              family: 'fresh spicy',
              notes: const ['bergamot', 'pepper', 'woody'],
              tags: const ['fresh', 'spicy'],
            ),
            _product(
              id: 'above_reference',
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
        expect(
          cheaper.renderIntent,
          AIChatToolRenderIntent.externalProfileCheaperResults,
        );
        expect(cheaper.productIds, ['below_reference']);
        expect(cheaper.productIds, isNot(contains('above_reference')));

        final withoutPrice = await executor.execute(
          reply: _toolReply(
            const AIChatToolCall(
              name: AIChatToolName.similarCheaperToExternalProfile,
              arguments: {'externalProfileId': 'dior_sauvage'},
            ),
          ),
          catalog: [
            _product(
              id: 'similar_catalog',
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
        expect(withoutPrice.productIds, ['similar_catalog']);
        expect(withoutPrice.disclosures.single, contains('cannot verify'));

        final guardEvents = <Map<String, dynamic>>[];
        final guarded = _guard(guardEvents).guard(
          reply: AIChatReply.recommend(
            productIds: const ['safe', 'missing', 'out', 'inactive', 'vanilla'],
            matchReasons: const {
              'safe': 'Fresh option.',
              'missing': 'Invented option.',
              'out': 'Out of stock option.',
              'inactive': 'Inactive option.',
              'vanilla': 'Contains vanilla.',
            },
            updatedPreferences: const SessionPreferences(
              maxBudget: 1500,
              excludedNotes: ['vanilla'],
              medicalExcludedNotes: ['vanilla'],
            ),
          ),
          catalog: [
            _product(id: 'safe', name: 'Safe', price: 900),
            _product(id: 'out', name: 'Out', price: 800, stock: 0),
            _product(
              id: 'inactive',
              name: 'Inactive',
              price: 800,
              isActive: false,
            ),
            _product(
              id: 'vanilla',
              name: 'Vanilla',
              price: 800,
              notes: const ['vanilla', 'sweet'],
            ),
          ],
          recommendationContext: AIChatRecommendationContext(
            localCandidatesRefs: [
              RecommendedProduct(
                product: _product(id: 'safe', name: 'Safe', price: 900),
                matchReason: 'Fresh option.',
                matchScore: 0.9,
                matchLabel: 'Strong Match',
              ),
            ],
            candidatesList: [_product(id: 'safe', name: 'Safe', price: 900)],
            localFallbackAnswer: null,
          ),
          language: AIChatLanguage.english,
          responseSource: 'contract_test',
        );

        expect(guarded.safeProducts.map((item) => item.product.id), ['safe']);
        expect(
          guardEvents.map((event) => event['issueCode']),
          containsAll([
            'catalog_id_missing',
            'inactive_or_out_of_stock',
            'excluded_note_violation',
          ]),
        );
      },
    );
  });
}

AIChatReply _toolReply(AIChatToolCall toolCall) {
  return AIChatReply.toolCall(
    toolCall: toolCall,
    updatedPreferences: SessionPreferences.empty(),
    requestId: 'capability-contract',
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

RecommendedProductRef _ref(String productId, int index, {double price = 1000}) {
  return RecommendedProductRef(
    productId: productId,
    name: 'Product $index',
    brand: 'Brand',
    displayIndex: index,
    price: price,
    stock: 5,
    season: 'summer',
    occasion: 'daily',
    intensity: 'light',
    notes: const ['fresh'],
  );
}

List<ProductModel> _catalog() {
  return [
    _product(
      id: 'light_blue',
      name: 'Light Blue',
      brand: 'Dolce & Gabbana',
      price: 3250,
    ),
    _product(
      id: 'acqua_gio',
      name: 'Acqua di Gio',
      brand: 'Giorgio Armani',
      price: 3350,
    ),
  ];
}

ProductModel _product({
  required String id,
  required String name,
  required double price,
  String brand = 'Brand',
  int stock = 5,
  bool isActive = true,
  String gender = 'unisex',
  String season = 'summer',
  String family = 'fresh',
  List<String> notes = const ['citrus', 'musk'],
  List<String> tags = const ['fresh', 'clean'],
  String occasion = 'daily',
  String time = 'day',
  String intensity = 'medium',
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const <String>[],
    brand: brand,
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

PerfumeKnowledgeProfile _profile({
  required String id,
  required String displayName,
  required String brand,
  List<String> aliases = const [],
  double confidence = 0.93,
}) {
  return PerfumeKnowledgeProfile(
    id: id,
    displayName: displayName,
    brand: brand,
    aliases: aliases,
    searchKeys: aliases,
    accords: const ['fresh', 'spicy'],
    topNotes: const ['citrus'],
    middleNotes: const ['pepper'],
    baseNotes: const ['amber'],
    fragranceFamily: 'fresh spicy',
    genderHint: 'men',
    lookupConfidence: confidence,
    status: PerfumeKnowledgeStatus.approved,
  );
}
