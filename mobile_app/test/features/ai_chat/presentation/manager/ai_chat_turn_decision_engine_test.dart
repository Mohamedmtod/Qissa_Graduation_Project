import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_turn_decision_engine.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

AIChatTurnContext _incoming(
  String message, {
  AIChatIntent? intent,
  bool isGreetingOnly = false,
  bool shouldContinueAvailabilityClarification = false,
  String? availabilityProductQuery,
}) {
  return AIChatTurnContext(
    trimmed: message,
    activeSessionId: 'session',
    responseLanguage: AIChatLanguageDetector.detect(message),
    effectiveRecommendationMemory: const RecommendationMemory(),
    intent: intent ?? LocalIntentParser.detectIntent(message),
    shouldContinueAvailabilityClarification:
        shouldContinueAvailabilityClarification,
    isGreetingOnly: isGreetingOnly || LocalIntentParser.isGreetingOnly(message),
    requestId: 'request',
    availabilityProductQuery: availabilityProductQuery,
  );
}

ProductModel _product({
  required String id,
  required String name,
  String brand = '',
  String nameAr = '',
  List<String> aliasesAr = const [],
}) {
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const [],
    nameAr: nameAr,
    brand: brand,
    aliasesAr: aliasesAr,
    price: 1000,
    stock: 5,
    gender: 'men',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: const ['fresh'],
    imageUrls: const [],
    description: '',
    categoryName: 'Perfumes',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    occasion: 'daily',
    time: 'day',
    intensity: 'medium',
    topNotes: const ['fresh'],
    middleNotes: const [],
    baseNotes: const [],
    tags: const ['fresh'],
  );
}

AIChatTurnDecision _decide(
  String message, {
  List<ProductModel>? catalog,
  AIChatState state = const AIChatState(),
  AIChatIntent? intent,
  bool clarification = false,
}) {
  return const AIChatTurnDecisionEngine().decide(
    incoming: _incoming(
      message,
      intent: intent,
      shouldContinueAvailabilityClarification: clarification,
    ),
    state: state,
    catalog: catalog ?? const [],
    shouldContinueAvailabilityClarification: (_, _) => false,
  );
}

void main() {
  setUp(() {
    AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: false);
  });

  tearDown(AIChatExperimentConfig.resetTestOverrides);

  group('AIChatTurnDecisionEngine', () {
    test('blocks greetings from availability', () {
      final decision = _decide('السلام عليكم ورحمة الله وبركاته');

      expect(decision.route, AIChatTurnDecisionRoute.greeting);
      expect(decision.shouldAllowAvailability, isFalse);
      expect(decision.reasonCode, 'greeting_only');
    });

    test('routes generic catalog commands locally', () {
      const messages = {
        'suggest perfumes': AIChatTurnDecisionRoute.localCommand,
        'suggest any other': AIChatTurnDecisionRoute.localCommand,
        'suggest most selling': AIChatTurnDecisionRoute.localCommand,
        'what is new?': AIChatTurnDecisionRoute.localCommand,
        'what types do you have': AIChatTurnDecisionRoute.localCommand,
      };

      for (final entry in messages.entries) {
        final decision = _decide(entry.key);
        expect(decision.route, entry.value, reason: entry.key);
        expect(decision.shouldAllowAvailability, isFalse, reason: entry.key);
      }
    });

    test('gender-only replies stay out of availability routing', () {
      final decision = _decide('men');

      expect(decision.shouldAllowAvailability, isFalse);
      expect(decision.route, isNot(AIChatTurnDecisionRoute.availability));
    });

    test(
      'blocks preference modifiers and context follow-ups from availability',
      () {
        const messages = [
          'remove sugary',
          'sugary = false',
          'for daily use',
          'okay university',
        ];

        for (final message in messages) {
          final decision = _decide(message);
          expect(decision.shouldAllowAvailability, isFalse, reason: message);
          expect(
            decision.route,
            anyOf(
              AIChatTurnDecisionRoute.localCommand,
              AIChatTurnDecisionRoute.modifier,
              AIChatTurnDecisionRoute.recommendation,
            ),
            reason: message,
          );
        }
      },
    );

    test(
      'routes budget-only follow-ups to recommendation before standalone ambiguity',
      () {
        for (final message in const [
          'Under 1600 EGP.',
          'Under 1400.',
          'Around 1500 EGP.',
        ]) {
          final decision = _decide(message);
          expect(
            decision.route,
            AIChatTurnDecisionRoute.recommendation,
            reason: message,
          );
          expect(decision.shouldAllowAvailability, isFalse, reason: message);
          expect(
            decision.reasonCode,
            'fresh_preference_signal',
            reason: message,
          );
        }
      },
    );

    test('allows explicit availability with product query', () {
      final decision = _decide('Is Dior Sauvage available?');

      expect(decision.route, AIChatTurnDecisionRoute.availability);
      expect(decision.shouldAllowAvailability, isTrue);
      expect(decision.productQuery, 'dior sauvage');
    });

    test('routes perfume-shaped iPhone query to off-topic guard', () {
      final decision = _decide('فيه عطر iPhone 15 Pro Max؟ عايز سعره وكارت');

      expect(decision.route, AIChatTurnDecisionRoute.offTopic);
      expect(decision.shouldAllowAvailability, isFalse);
      expect(decision.reasonCode, 'out_of_domain_non_perfume_request');
    });

    test('routes clear non-perfume buying requests to off-topic guard', () {
      final decision = _decide('رشحلي موبايل كويس للشراء');

      expect(decision.route, AIChatTurnDecisionRoute.offTopic);
      expect(decision.shouldAllowAvailability, isFalse);
      expect(decision.reasonCode, 'out_of_domain_non_perfume_request');
    });

    test('keeps multi-intent availability anchored to first named product', () {
      final decision = _decide(
        'هل متاح Oud Mood؟ ولو متاح قارن بينه وبين Badee Al Oud ورشح الأنسب للشتاء',
      );

      expect(decision.route, AIChatTurnDecisionRoute.availability);
      expect(decision.shouldAllowAvailability, isTrue);
      expect(decision.productQuery, 'oud mood');
    });

    test('treats ranking-style perfume requests as recommendations', () {
      final decision = _decide('خلاص بلاش صيفي، عايز أغلى عطر شتوي عندك');

      expect(decision.route, AIChatTurnDecisionRoute.recommendation);
      expect(decision.shouldAllowAvailability, isFalse);
      expect(decision.reasonCode, 'default_recommendation_flow');
    });

    test('allows validated interpretation availability product query', () {
      final decision = const AIChatTurnDecisionEngine().decide(
        incoming: _incoming(
          'do you have Rosendo Mateu?',
          intent: AIChatIntent.availabilityCheck,
          availabilityProductQuery: 'Rosendo Mateu',
        ),
        state: const AIChatState(),
        catalog: const [],
        shouldContinueAvailabilityClarification: (_, _) => false,
      );

      expect(decision.route, AIChatTurnDecisionRoute.availability);
      expect(decision.shouldAllowAvailability, isTrue);
      expect(decision.productQuery, 'Rosendo Mateu');
      expect(decision.reasonCode, 'interpretation_availability_confirmed');
    });

    test('V2 keeps exact product availability deterministic', () {
      AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

      final decision = _decide('Do you have Light Blue?');

      expect(decision.route, AIChatTurnDecisionRoute.availability);
      expect(decision.shouldAllowAvailability, isTrue);
      expect(decision.productQuery, 'light blue');
      expect(decision.decisionOwner, isNull);
    });

    test(
      'V2 routes note-only availability wording to semantic note search',
      () {
        AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

        final decision = _decide('is there with mango?');

        expect(decision.route, AIChatTurnDecisionRoute.recommendation);
        expect(decision.shouldAllowAvailability, isFalse);
        expect(decision.decisionOwner, 'llmSemantic');
        expect(decision.ownershipClass, 'llmSemantic');
        expect(decision.semanticIntent, 'noteSearch');
        expect(
          decision.localSkippedReason,
          'note_request_without_product_anchor',
        );
      },
    );

    test('V2 routes subjective visible question to semantic owner', () {
      AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

      final decision = _decide('which one is better?');

      expect(decision.route, AIChatTurnDecisionRoute.recommendation);
      expect(decision.shouldAllowAvailability, isFalse);
      expect(decision.decisionOwner, 'llmSemantic');
      expect(decision.semanticIntent, 'subjectiveVisibleQuestion');
    });

    test(
      'V2 marks social turn as semantic while preserving greeting route',
      () {
        AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

        final decision = _decide('how are you');

        expect(decision.route, AIChatTurnDecisionRoute.greeting);
        expect(decision.shouldAllowAvailability, isFalse);
        expect(decision.decisionOwner, 'llmSemantic');
        expect(decision.semanticIntent, 'social');
      },
    );

    test('V2 routes Arabic vibe/refinement language to semantic owner', () {
      AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

      final decision = _decide('عايز حاجة شيك ومش خانقة');

      expect(decision.route, AIChatTurnDecisionRoute.recommendation);
      expect(decision.shouldAllowAvailability, isFalse);
      expect(decision.decisionOwner, 'llmSemantic');
      expect(decision.semanticIntent, 'vibeSearch');
    });

    test(
      'allows redirected product request after recommendation rejection',
      () {
        final decision = _decide(
          'no i dont want those i want "stay with you" perfume',
          state: const AIChatState(),
          catalog: [_product(id: 'stay', name: 'Stay With You')],
          intent: AIChatIntent.newRecommendation,
        );

        expect(decision.route, AIChatTurnDecisionRoute.recommendation);
        expect(decision.shouldAllowAvailability, isFalse);

        final withMemory = const AIChatTurnDecisionEngine().decide(
          incoming: AIChatTurnContext(
            trimmed: 'no i dont want those i want "stay with you" perfume',
            activeSessionId: 'session',
            responseLanguage: AIChatLanguage.english,
            effectiveRecommendationMemory: RecommendationMemory(
              lastRecommendedProducts: [
                RecommendedProductRef(
                  productId: 'p1',
                  name: 'Old',
                  brand: '',
                  displayIndex: 1,
                  price: 1000,
                  stock: 1,
                  season: 'summer',
                  occasion: 'daily',
                  intensity: 'medium',
                  notes: const ['fresh'],
                ),
              ],
            ),
            intent: AIChatIntent.newRecommendation,
            shouldContinueAvailabilityClarification: false,
            isGreetingOnly: false,
            requestId: 'request',
          ),
          state: const AIChatState(),
          catalog: [_product(id: 'stay', name: 'Stay With You')],
          shouldContinueAvailabilityClarification: (_, _) => false,
        );

        expect(withMemory.route, AIChatTurnDecisionRoute.availability);
        expect(withMemory.shouldAllowAvailability, isTrue);
        expect(withMemory.productQuery, 'stay with you');
      },
    );

    test(
      'allows availability follow-up context before recommendation parsing',
      () {
        final decision = _decide(
          'show me something similar',
          state: const AIChatState(
            availabilityContext: AvailabilityContext(
              lastQuery: 'Sauvage',
              matchedProductId: 'sauvage',
              matchedProductName: 'Sauvage Parfum',
              availabilityStatus: AvailabilityStatus.found,
            ),
          ),
        );

        expect(decision.route, AIChatTurnDecisionRoute.availabilityFollowUp);
        expect(decision.shouldAllowAvailability, isTrue);
      },
    );

    test('allows standalone product only when catalog-backed', () {
      final catalog = [_product(id: 'dior-sauvage', name: 'Dior Sauvage')];
      final known = _decide('Dior Sauvage', catalog: catalog);
      final unknown = _decide('hello my friend', catalog: catalog);

      expect(known.route, AIChatTurnDecisionRoute.availability);
      expect(known.shouldAllowAvailability, isTrue);
      expect(known.reasonCode, 'catalog_backed_standalone_product');

      expect(unknown.route, AIChatTurnDecisionRoute.clarify);
      expect(unknown.shouldAllowAvailability, isFalse);
      expect(unknown.reasonCode, 'ambiguous_standalone_latin_phrase');
    });

    test(
      'allows product-shaped title case standalone names for perfume knowledge',
      () {
        final decision = _decide('Le Male');

        expect(decision.route, AIChatTurnDecisionRoute.availability);
        expect(decision.shouldAllowAvailability, isTrue);
        expect(decision.reasonCode, 'product_shaped_standalone_name');
        expect(decision.productQuery, 'le male');
      },
    );

    test('routes Arabic catalog-backed price questions to availability', () {
      final decision = _decide(
        'السوفاج بكام؟',
        catalog: [
          _product(
            id: 'dior-sauvage',
            name: 'Dior Sauvage',
            brand: 'Dior',
            aliasesAr: const ['سوفاج'],
          ),
        ],
      );

      expect(decision.route, AIChatTurnDecisionRoute.availability);
      expect(decision.shouldAllowAvailability, isTrue);
      expect(decision.reasonCode, 'catalog_backed_product_query');
      expect(decision.productQuery, 'Dior Sauvage');
    });

    test(
      'routes catalog-backed similar cheaper product request to recommendation',
      () {
        final decision = _decide(
          '\u0639\u0646\u062f\u0643 \u0639\u0637\u0631 \u064a\u0643\u0648\u0646 \u0634\u0628\u0647 Dior Sauvage \u0628\u0633 \u064a\u0643\u0648\u0646 \u0633\u0639\u0631\u0647 \u0623\u0631\u062e\u0635 \u0645\u0646\u0647\u061f',
          catalog: [
            _product(
              id: 'dior-sauvage',
              name: 'Dior Sauvage',
              brand: 'Dior',
              aliasesAr: const ['\u0633\u0648\u0641\u0627\u062c'],
            ),
          ],
        );

        expect(decision.route, AIChatTurnDecisionRoute.recommendation);
        expect(decision.shouldAllowAvailability, isFalse);
        expect(decision.reasonCode, 'reference_cheaper_recommendation');
      },
    );
  });
}
