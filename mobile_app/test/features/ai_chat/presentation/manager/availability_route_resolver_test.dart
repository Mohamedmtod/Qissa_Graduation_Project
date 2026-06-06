import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_route_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

AIChatTurnContext _incoming(
  String message, {
  AIChatIntent? intent,
  bool shouldContinueAvailabilityClarification = false,
}) {
  final detectedIntent = intent ?? LocalIntentParser.detectIntent(message);
  return AIChatTurnContext(
    trimmed: message,
    activeSessionId: 'session',
    responseLanguage: AIChatLanguageDetector.detect(message),
    effectiveRecommendationMemory: const RecommendationMemory(),
    intent: detectedIntent,
    shouldContinueAvailabilityClarification:
        shouldContinueAvailabilityClarification,
    isGreetingOnly: false,
    requestId: 'request',
  );
}

AvailabilityRouteResult _resolve(
  String message, {
  AIChatState state = const AIChatState(),
  AIChatIntent? intent,
  bool shouldContinueAvailabilityClarification = false,
  bool Function(String message, AIChatIntent intent)? clarificationMatcher,
}) {
  return const AvailabilityRouteResolver().resolve(
    incoming: _incoming(
      message,
      intent: intent,
      shouldContinueAvailabilityClarification:
          shouldContinueAvailabilityClarification,
    ),
    state: state,
    shouldContinueAvailabilityClarification:
        clarificationMatcher ?? (_, _) => false,
  );
}

void main() {
  tearDown(AIChatExperimentConfig.resetTestOverrides);

  group('AvailabilityRouteResolver', () {
    test('short mixed-language similar follow-up uses matched context', () {
      final result = _resolve(
        'similar ده',
        intent: AIChatIntent.followUpProduct,
        state: const AIChatState(
          availabilityContext: AvailabilityContext(
            lastQuery: 'Sauvage',
            matchedProductId: 'sauvage',
            matchedProductName: 'Sauvage Parfum',
            availabilityStatus: AvailabilityStatus.found,
          ),
        ),
      );

      expect(result.route, AvailabilityRoute.followUp);
      expect(result.reasonCode, 'availability_matched_similarity_follow_up');
    });

    test('standalone Latin perfume name routes to direct availability', () {
      final result = _resolve('Sauvage Parfum');

      expect(result.route, AvailabilityRoute.direct);
      expect(result.reasonCode, 'availability_standalone_latin_name');
    });

    test('standalone Latin text with preference signal does not route', () {
      final result = _resolve('Sauvage Parfum for summer');

      expect(result.route, AvailabilityRoute.none);
      expect(result.shouldSkip, isTrue);
    });

    test('generic commands do not route to availability lookup', () {
      const messages = [
        'suggest perfumes',
        'suggest any other',
        'suggest most selling',
        'what is new?',
        'what types do you have',
        'remove sugary',
        'sugary = false',
        'for daily use',
        'okay university',
      ];

      for (final message in messages) {
        final result = _resolve(message);
        expect(result.route, AvailabilityRoute.none, reason: message);
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
          reason: message,
        );
      }
    });

    test('gender-only replies do not route to availability lookup', () {
      const messages = ['men', 'women', 'unisex', 'male', 'female'];

      for (final message in messages) {
        final result = _resolve(message);
        expect(result.route, AvailabilityRoute.none, reason: message);
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
          reason: message,
        );
      }
    });

    test('long Arabic greeting does not route to availability lookup', () {
      final result = _resolve('السلام عليكم ورحمة الله وبركاته');

      expect(result.route, AvailabilityRoute.none);
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'السلام عليكم ورحمة الله وبركاته',
        ),
        isNull,
      );
    });

    test(
      'matched product cheaper similar follow-up pivots before follow-up',
      () {
        final result = _resolve(
          'show me cheaper similar',
          intent: AIChatIntent.followUpProduct,
          state: const AIChatState(
            availabilityContext: AvailabilityContext(
              lastQuery: 'Sauvage',
              matchedProductId: 'sauvage',
              matchedProductName: 'Sauvage Parfum',
              availabilityStatus: AvailabilityStatus.found,
            ),
          ),
        );

        expect(result.route, AvailabilityRoute.similarCheaperPivot);
        expect(result.reasonCode, 'availability_matched_similar_cheaper_pivot');
      },
    );

    test(
      'generic give-me wording still uses availability context for cheaper similarity',
      () {
        final result = _resolve(
          'Give me something like it but cheaper.',
          intent: AIChatIntent.followUpProduct,
          state: const AIChatState(
            availabilityContext: AvailabilityContext(
              lastQuery: 'Dior Sauvage',
              matchedProductId: 'dior_sauvage',
              matchedProductName: 'Dior Sauvage',
              availabilityStatus: AvailabilityStatus.found,
            ),
          ),
        );

        expect(result.route, AvailabilityRoute.similarCheaperPivot);
        expect(result.shouldSkip, isFalse);
      },
    );

    test(
      'explicit similar cheaper product request avoids direct availability ambiguity',
      () {
        const message = 'Do you have something like Dior Sauvage but cheaper?';
        final result = _resolve(message);

        expect(
          LocalIntentParser.detectIntent(message),
          AIChatIntent.followUpProduct,
        );
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
        );
        expect(result.route, AvailabilityRoute.none);
      },
    );

    test(
      'colloquial Arabic cheaper similar follow-up is not extracted as product',
      () {
        const message = 'طيب رشحلي حاجة شبهه بس ارخص';
        final result = _resolve(
          message,
          intent: AIChatIntent.followUpProduct,
          state: const AIChatState(
            availabilityContext: AvailabilityContext(
              lastQuery: 'ديور سوفاج',
              availabilityStatus: AvailabilityStatus.notFoundKnownProfile,
              referenceProfileKey: 'dior_sauvage',
            ),
          ),
        );

        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
        );
        expect(result.route, AvailabilityRoute.followUp);
        expect(result.reasonCode, 'availability_contextual_follow_up');
      },
    );

    test(
      'vague recommendation-like message does not route to availability',
      () {
        final result = _resolve(
          'recommend something fresh for summer',
          intent: AIChatIntent.availabilityCheck,
        );

        expect(result.route, AvailabilityRoute.none);
        expect(result.shouldSkip, isTrue);
      },
    );

    test(
      'recommendation continuation command does not route to availability',
      () {
        final bestMatch = _resolve(
          'Recommend the best match for me.',
          intent: AIChatIntent.availabilityCheck,
        );
        final strictBudget = _resolve(
          'Actually make it strictly under 800 EGP.',
          intent: AIChatIntent.availabilityCheck,
        );

        expect(bestMatch.route, AvailabilityRoute.none);
        expect(bestMatch.shouldSkip, isTrue);
        expect(strictBudget.route, AvailabilityRoute.none);
        expect(strictBudget.shouldSkip, isTrue);
      },
    );

    test(
      'occasion scent requests do not route to availability without product anchor',
      () {
        AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

        const messages = [
          'عندي interview وعايز ريحة كويسة.',
          'عايز عطر ريحته زي محل براندات فخمة.',
          'عايز عطر شبه ريحة المحلات الفخمة.',
        ];

        for (final message in messages) {
          final result = _resolve(
            message,
            intent: AIChatIntent.availabilityCheck,
          );

          expect(result.route, AvailabilityRoute.none, reason: message);
          expect(result.shouldSkip, isTrue, reason: message);
        }
      },
    );

    test('persona and preference statements do not route to availability', () {
      const messages = [
        'I am a 28-year-old man.',
        'I work in finance.',
        'I prefer woody and smoky scents.',
        'My budget is 1500 EGP.',
      ];

      for (final message in messages) {
        final result = _resolve(
          message,
          intent: AIChatIntent.availabilityCheck,
        );

        expect(result.route, AvailabilityRoute.none, reason: message);
        expect(result.shouldSkip, isTrue, reason: message);
      }
    });

    test(
      'note-only availability wording stays in recommendation refinement',
      () {
        const messages = [
          'is there with mango',
          'do you have anything with pineapple',
        ];

        for (final message in messages) {
          final result = _resolve(
            message,
            intent: AIChatIntent.availabilityCheck,
          );

          expect(result.route, AvailabilityRoute.none, reason: message);
          expect(result.shouldSkip, isTrue, reason: message);
          expect(
            AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
            isNull,
            reason: message,
          );
          expect(
            AvailabilityIntentUtils.looksLikeAvailabilityQuery(
              message,
              hasRecommendationContext: true,
            ),
            isFalse,
            reason: message,
          );
        }
      },
    );

    test('V2 requires product anchor for availability route', () {
      AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

      final vague = _resolve(
        'is there anything fresh?',
        intent: AIChatIntent.availabilityCheck,
      );
      expect(vague.route, AvailabilityRoute.none);
      expect(vague.shouldSkip, isTrue);

      final exact = _resolve(
        'do you have Light Blue?',
        intent: AIChatIntent.availabilityCheck,
      );
      expect(exact.route, AvailabilityRoute.direct);
      expect(exact.shouldSkip, isFalse);
    });

    test('V2 blocks availability hijack for ranking business notes and vibe', () {
      AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

      const messages = [
        '\u0625\u064a\u0647 \u0623\u0643\u062a\u0631 \u0639\u0637\u0631 \u062b\u0627\u0628\u062a \u0639\u0646\u062f\u0643\u0645\u061f',
        '\u0628\u062d\u0628 \u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627\u060c \u0639\u0646\u062f\u0643\u0645 \u0625\u064a\u0647\u061f',
        '\u0627\u0644\u062f\u0641\u0639 \u0623\u0648\u0646\u0644\u0627\u064a\u0646 \u0648\u0644\u0627 \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645\u061f',
        '\u0627\u0644\u0639\u0637\u0648\u0631 \u0623\u0635\u0644\u064a\u0629\u061f',
        '\u0625\u064a\u0647 \u0623\u0643\u062a\u0631 \u0627\u0644\u0639\u0637\u0648\u0631 \u0645\u0628\u064a\u0639\u064b\u0627 \u0639\u0646\u062f\u0643\u0645\u061f',
        '\u0645\u0634 \u0628\u062d\u0628 \u0627\u0644\u0639\u0637\u0648\u0631 \u0627\u0644\u0642\u0648\u064a\u0629\u060c \u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0629 \u0647\u0627\u062f\u064a\u0629.',
        '\u0634\u063a\u0644\u064a \u0641\u064a\u0647 \u0645\u0642\u0627\u0628\u0644\u0629 \u0639\u0645\u0644\u0627\u0621 \u0643\u062a\u064a\u0631\u060c \u0645\u062d\u062a\u0627\u062c \u0639\u0637\u0631 \u0645\u0646\u0627\u0633\u0628.',
        '\u0639\u0646\u062f\u064a \u0645\u0646\u0627\u0633\u0628\u0629 \u0641\u064a \u0645\u0643\u0627\u0646 \u0645\u0641\u062a\u0648\u062d\u060c \u0623\u0633\u062a\u062e\u062f\u0645 \u0625\u064a\u0647\u061f',
        '\u0639\u0646\u062f\u064a \u0645\u0646\u0627\u0633\u0628\u0629 \u0641\u064a \u0642\u0627\u0639\u0629 \u0645\u063a\u0644\u0642\u0629.',
        '\u0639\u0627\u064a\u0632\u0629 \u0639\u0637\u0631 \u0644\u0644\u0646\u0648\u0645.',
      ];

      for (final message in messages) {
        final result = _resolve(
          message,
          intent: AIChatIntent.availabilityCheck,
        );

        expect(result.route, AvailabilityRoute.none, reason: message);
        expect(result.shouldSkip, isTrue, reason: message);
      }
    });

    test('V2 routes similar external references away from availability', () {
      AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: true);

      final result = _resolve(
        '\u0639\u0646\u062f\u0643\u0645 \u0639\u0637\u0631 \u0634\u0628\u0647 Sauvage\u061f',
        intent: AIChatIntent.availabilityCheck,
      );

      expect(result.route, AvailabilityRoute.none);
      expect(result.shouldSkip, isTrue);
    });

    test('explicit availability query overrides existing matched context', () {
      final result = _resolve(
        'do you have Bleu de Chanel?',
        state: const AIChatState(
          availabilityContext: AvailabilityContext(
            lastQuery: 'Sauvage',
            matchedProductId: 'sauvage',
            matchedProductName: 'Sauvage Parfum',
            availabilityStatus: AvailabilityStatus.found,
          ),
        ),
      );

      expect(result.route, AvailabilityRoute.direct);
      expect(result.reasonCode, 'availability_explicit_product');
    });

    test('active clarification continuation has highest priority', () {
      final result = _resolve(
        'the first one',
        shouldContinueAvailabilityClarification: true,
      );

      expect(result.route, AvailabilityRoute.clarification);
      expect(result.reasonCode, 'availability_clarification_continuation');
    });
  });
}
