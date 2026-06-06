import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/budget_amount_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser_keywords.dart'
    as keywords;

import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

void main() {
  group('LocalIntentParser', () {
    test('detects strict and flexible budget policy', () {
      expect(
        LocalIntentParser.detectBudgetPolicy(
          'I have exactly 900 EGP, not one pound more.',
        ),
        AIChatBudgetPolicy.strict,
      );
      expect(
        LocalIntentParser.detectBudgetPolicy(
          'I need a fresh perfume below 800 EGP.',
        ),
        AIChatBudgetPolicy.strict,
      );
      expect(
        LocalIntentParser.detectBudgetPolicy(
          'Recommend a clean office perfume under 700 EGP. Do not show anything above budget.',
        ),
        AIChatBudgetPolicy.strict,
      );
      expect(
        LocalIntentParser.detectBudgetPolicy('No more than 700 please.'),
        AIChatBudgetPolicy.strict,
      );
      expect(
        LocalIntentParser.detectBudgetPolicy(
          'Actually make it strictly under 800 EGP.',
        ),
        AIChatBudgetPolicy.strict,
      );
      expect(
        LocalIntentParser.detectBudgetPolicy('Recommend something under 1000.'),
        AIChatBudgetPolicy.flexible,
      );
      expect(
        LocalIntentParser.detectBudgetPolicy('Something around 1000 EGP.'),
        AIChatBudgetPolicy.flexible,
      );
    });

    test('extracts standalone budget amounts without decimal truncation', () {
      final preferences = LocalIntentParser.parse(
        'Under 1200.',
        const SessionPreferences(gender: 'men', preferredNotes: ['citrus']),
      );

      expect(preferences.maxBudget, 1200);
      expect(preferences.gender, 'men');
      expect(preferences.preferredNotes, contains('citrus'));
    });

    test('parses strict under-budget phrasing with explicit above-budget ban', () {
      const message =
          'Recommend a clean office perfume under 700 EGP. Do not show anything above budget.';
      final normalized = LocalIntentParser.normalizeInput(message);
      expect(BudgetAmountParser.containsBudgetNumber(normalized), isTrue);
      expect(
        BudgetAmountParser.extractMaxBudget(
          normalized,
          currentBudget: null,
          budgetContextKeywords: keywords.budgetContextKeywords,
          cheapKeywords: keywords.cheapKeywords,
        ),
        700,
      );
      final preferences = LocalIntentParser.parse(
        message,
        SessionPreferences.empty(),
      );

      expect(preferences.maxBudget, 700);
      expect(
        LocalIntentParser.detectBudgetPolicy(
          'Recommend a clean office perfume under 700 EGP. Do not show anything above budget.',
        ),
        AIChatBudgetPolicy.strict,
      );
    });

    test('does not promote forbidden upsell reference to max budget', () {
      const message =
          '\u0645\u064a\u0632\u0627\u0646\u064a\u062a\u064a 600\u060c \u0648\u0644\u0648 \u0641\u064a \u062d\u0627\u062c\u0629 \u0623\u062d\u0633\u0646 \u0628\u0640900 \u0645\u062a\u0637\u0644\u0639\u0647\u0627\u0634';
      final normalized = LocalIntentParser.normalizeInput(message);

      expect(
        BudgetAmountParser.extractMaxBudget(
          normalized,
          currentBudget: null,
          budgetContextKeywords: keywords.budgetContextKeywords,
          cheapKeywords: keywords.cheapKeywords,
        ),
        600,
      );

      final preferences = LocalIntentParser.parse(
        message,
        SessionPreferences.empty(),
      );

      expect(preferences.maxBudget, 600);
      expect(
        LocalIntentParser.detectBudgetPolicy(message),
        AIChatBudgetPolicy.strict,
      );
    });

    test('keeps medical allergy exclusion locked across casual reversal', () {
      final allergic = LocalIntentParser.parse(
        '\u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627 \u0628\u062a\u0639\u0645\u0644\u064a \u062d\u0633\u0627\u0633\u064a\u0629',
        SessionPreferences.empty(),
      );

      expect(allergic.excludedNotes, contains('vanilla'));
      expect(allergic.medicalExcludedNotes, contains('vanilla'));

      final reversed = LocalIntentParser.parse(
        '\u062e\u0644\u0627\u0635 \u0631\u0634\u062d\u0644\u064a \u062d\u0627\u062c\u0629 \u0641\u064a\u0647\u0627 \u0641\u0627\u0646\u064a\u0644\u064a\u0627 \u0639\u0627\u062f\u064a',
        allergic,
      );

      expect(reversed.medicalExcludedNotes, contains('vanilla'));
      expect(reversed.excludedNotes, contains('vanilla'));
      expect(reversed.preferredNotes, isNot(contains('vanilla')));
    });

    test('Arabic shيل replacement excludes old note and keeps new note', () {
      final next = LocalIntentParser.parse(
        '\u0644\u0627 \u0634\u064a\u0644 \u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627 \u0648\u062e\u0644\u064a\u0647 \u0635\u0646\u062f\u0644 \u0645\u0639 \u0645\u0633\u0643',
        const SessionPreferences(preferredNotes: ['vanilla', 'musk']),
      );

      expect(next.excludedNotes, contains('vanilla'));
      expect(next.preferredNotes, isNot(contains('vanilla')));
      expect(next.preferredNotes, contains('musk'));
      expect(next.preferredNotes, contains('sandalwood'));
    });

    test(
      'strict continuation budget updates prior budget without clearing taste',
      () {
        final preferences = LocalIntentParser.parse(
          'Actually make it strictly under 800 EGP.',
          const SessionPreferences(
            gender: 'women',
            maxBudget: 1000,
            preferredNotes: ['floral'],
          ),
        );

        expect(preferences.gender, 'women');
        expect(preferences.maxBudget, 800);
        expect(preferences.preferredNotes, contains('floral'));
      },
    );

    test('does not classify generic commands as availability products', () {
      const messages = [
        'suggest perfumes',
        'suggest any other',
        'suggest most selling',
        'what is new?',
        'It is not in stock. Can you recommend the closest thing you have?',
        'If not, give me the closest alternative.',
        'remove sugary',
        'sugary = false',
        'for daily use',
        'okay university',
      ];

      for (final message in messages) {
        expect(
          LocalIntentParser.detectIntent(message),
          isNot(AIChatIntent.availabilityCheck),
          reason: message,
        );
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
          reason: message,
        );
      }
    });

    test('note preference commands do not become availability lookups', () {
      const messages = [
        'avoid oud',
        'keep vanilla',
        'without oud',
        '\u0628\u0644\u0627\u0634 \u0639\u0648\u062f',
        '\u0645\u0646 \u063a\u064a\u0631 \u0639\u0648\u062f',
        '\u0641\u064a\u0647 \u0641\u0627\u0646\u064a\u0644\u064a\u0627',
        '\u062e\u0644\u064a\u0647 \u0641\u0627\u0646\u064a\u0644\u064a\u0627',
      ];

      for (final message in messages) {
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
          reason: message,
        );
        expect(
          AvailabilityIntentUtils.looksLikeAvailabilityQuery(
            message,
            hasRecommendationContext: false,
          ),
          isFalse,
          reason: message,
        );
      }
    });

    test('sensitive skin choice is not classified as product comparison', () {
      const messages = [
        '\u0628\u0634\u0631\u062a\u064a \u062d\u0633\u0627\u0633\u0629\u060c \u0623\u062e\u062a\u0627\u0631 \u0625\u064a\u0647\u061f',
        'I have sensitive skin, what should I choose?',
      ];

      for (final message in messages) {
        expect(
          LocalIntentParser.detectIntent(message),
          AIChatIntent.newRecommendation,
          reason: message,
        );
      }
    });

    test('extracts Sauvage-style pepper and ambroxan anchors', () {
      final preferences = LocalIntentParser.parse(
        'محتاج عطر رجالي فريش حمضيات وفيه فلفل واضح وفي نهايته Ambroxan.',
        SessionPreferences.empty(),
      );

      expect(preferences.gender, 'men');
      expect(preferences.tags, contains('fresh'));
      expect(
        preferences.preferredNotes,
        containsAll(['citrus', 'pepper', 'ambroxan']),
      );
    });

    test('long Arabic greeting is not treated as availability lookup', () {
      const greeting = 'السلام عليكم ورحمة الله وبركاته';

      expect(LocalIntentParser.isGreetingOnly(greeting), isTrue);
      expect(
        LocalIntentParser.detectIntent(greeting),
        AIChatIntent.newRecommendation,
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(greeting),
        isNull,
      );
      expect(
        AvailabilityIntentUtils.looksLikeAvailabilityQuery(
          greeting,
          hasRecommendationContext: false,
        ),
        isFalse,
      );
    });

    test('keeps real product availability classification intact', () {
      expect(
        LocalIntentParser.detectIntent('Dior Sauvage'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('Is Dior Sauvage available?'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'Is Dior Sauvage available?',
        ),
        'dior sauvage',
      );
    });

    test('gender-only replies do not become availability queries', () {
      for (final message in const [
        'men',
        'women',
        'unisex',
        'male',
        'female',
      ]) {
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
          reason: message,
        );
        expect(
          AvailabilityIntentUtils.looksLikeAvailabilityQuery(
            message,
            hasRecommendationContext: false,
          ),
          isFalse,
          reason: message,
        );
      }
    });

    test('ranking requests stay in recommendation flow', () {
      const message = 'خلاص بلاش صيفي، عايز أغلى عطر شتوي عندك';

      expect(
        LocalIntentParser.detectIntent(message),
        AIChatIntent.newRecommendation,
      );
      final prefs = LocalIntentParser.parse(
        message,
        SessionPreferences.empty(),
      );
      expect(prefs.season, 'winter');
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
        isNull,
      );
      expect(
        AvailabilityIntentUtils.looksLikeAvailabilityQuery(
          message,
          hasRecommendationContext: false,
        ),
        isFalse,
      );
    });

    test('browse questions are treated as catalog browse requests', () {
      for (final message in const [
        'what types do you have',
        'what kinds do you have',
        'what categories do you have',
        'what perfumes do you have',
      ]) {
        expect(
          AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(message),
          isTrue,
          reason: message,
        );
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
          reason: message,
        );
      }
    });

    test('ranking strategy cues parse to the expected strategy', () {
      final expensive = LocalIntentParser.parse(
        'I want the most expensive perfume',
        SessionPreferences.empty(),
      );
      final cheap = LocalIntentParser.parse(
        'I want the cheapest and most affordable perfume',
        SessionPreferences.empty(),
      );

      expect(expensive.rankingStrategy, RankingStrategy.expensiveFirst);
      expect(cheap.rankingStrategy, RankingStrategy.cheapestFirst);
    });

    test('Arabic ranking request parses expensive first and keeps winter', () {
      final prefs = LocalIntentParser.parse(
        'خلاص بلاش صيفي، عايز أغلى عطر شتوي عندك',
        SessionPreferences.empty(),
      );

      expect(prefs.season, 'winter');
      expect(prefs.rankingStrategy, RankingStrategy.expensiveFirst);
    });

    test('extracts masculine gender phrasing safely', () {
      final current = SessionPreferences.empty().copyWith(
        preferredNotes: const ['woody'],
        maxBudget: 1500,
      );

      for (final message in const [
        'For a man.',
        'for men',
        'male perfume',
        'manly perfume',
        'masculine scent',
      ]) {
        final prefs = LocalIntentParser.parse(message, current);
        expect(prefs.gender, 'men', reason: message);
        expect(prefs.preferredNotes, contains('woody'), reason: message);
        expect(prefs.maxBudget, 1500, reason: message);
      }
    });

    test('manly adds masculine style tag without clearing memory', () {
      final current = SessionPreferences.empty().copyWith(
        preferredNotes: const ['amber'],
      );
      final prefs = LocalIntentParser.parse('make it manly', current);

      expect(prefs.gender, 'men');
      expect(prefs.tags, contains('masculine'));
      expect(prefs.preferredNotes, contains('amber'));
    });

    test(
      'connector and typo normalization keeps English university requests stable',
      () {
        final withConnector = LocalIntentParser.parse(
          'i want summer perfume manly and light for university',
          SessionPreferences.empty(),
        );
        final withoutConnector = LocalIntentParser.parse(
          'i want summer perfume manly light for university',
          SessionPreferences.empty(),
        );
        final typo = LocalIntentParser.parse(
          'i want suumer perfume manly light for universty',
          SessionPreferences.empty(),
        );

        for (final prefs in [withConnector, withoutConnector, typo]) {
          expect(prefs.gender, 'men');
          expect(prefs.season, 'summer');
          expect(prefs.occasion, 'university');
          expect(prefs.intensity, 'light');
          expect(prefs.tags, contains('masculine'));
        }
      },
    );

    test('negative sugary command removes sweet style signal', () {
      final current = SessionPreferences.empty().copyWith(
        preferredNotes: const ['vanilla'],
        tags: const ['sweet', 'sugary', 'clean'],
      );
      final prefs = LocalIntentParser.parse(
        'remove sugary, make it cleaner',
        current,
      );

      expect(prefs.tags, isNot(contains('sweet')));
      expect(prefs.tags, isNot(contains('sugary')));
      expect(prefs.tags, contains('clean'));
      expect(prefs.tags, contains('fresh'));
      expect(prefs.preferredNotes, isNot(contains('vanilla')));
      expect(prefs.excludedNotes, containsAll(['sweet', 'sugary']));
    });

    test('not too sweet is a soft limit, not a hard exclusion', () {
      final current = SessionPreferences.empty().copyWith(
        gender: 'women',
        maxBudget: 1200,
        preferredNotes: const ['sweet'],
        tags: const ['sweet', 'gift'],
      );
      final prefs = LocalIntentParser.parse('Nothing too sweet.', current);

      expect(prefs.tags, isNot(contains('sweet')));
      expect(prefs.tags, contains('clean'));
      expect(prefs.tags, contains('fresh'));
      expect(prefs.preferredNotes, isNot(contains('sweet')));
      expect(prefs.excludedNotes, isNot(contains('sweet')));
      expect(prefs.excludedNotes, isNot(contains('sugary')));
    });

    test('gift for fiancee infers women and gift context', () {
      final prefs = LocalIntentParser.parse(
        'عايز عطر هدية لخطيبتي',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'women');
      expect(prefs.tags, contains('gift'));
    });

    test('Arabic mother gift request infers women gift and budget', () {
      final prefs = LocalIntentParser.parse(
        '\u0633\u064a\u0628\u0643 \u0645\u0646 \u0643\u0644 \u062f\u0647 \u0623\u0646\u0627 \u0639\u0627\u064a\u0632 \u0647\u062f\u064a\u0629 \u0644\u0648\u0627\u0644\u062f\u062a\u064a \u062a\u062d\u062a 700',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'women');
      expect(prefs.occasion, 'gift');
      expect(prefs.maxBudget, 700);
      expect(prefs.tags, contains('gift'));
    });

    test('Arabic engineer work request infers men and calm office context', () {
      final prefs = LocalIntentParser.parse(
        '\u0627\u0646\u0627 \u0645\u0647\u0646\u062f\u0633 \u0648\u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0647 \u0644\u0644\u0634\u063a\u0644 \u0647\u0627\u062f\u064a\u0647 \u0641\u064a \u0627\u0644\u0635\u064a\u0641',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'men');
      expect(prefs.season, 'summer');
      expect(prefs.occasion, 'office');
      expect(prefs.intensity, 'light');
      expect(prefs.tags, contains('clean'));
      expect(prefs.tags, contains('fresh'));
      expect(prefs.tags, isNot(contains('gift')));
    });

    test('Arabic client-facing work request infers clean office context', () {
      final prefs = LocalIntentParser.parse(
        '\u0634\u063a\u0644\u064a \u0641\u064a\u0647 \u0645\u0642\u0627\u0628\u0644\u0629 \u0639\u0645\u0644\u0627\u0621 \u0643\u062a\u064a\u0631\u060c \u0645\u062d\u062a\u0627\u062c \u0639\u0637\u0631 \u0645\u0646\u0627\u0633\u0628.',
        SessionPreferences.empty(),
      );

      expect(prefs.occasion, 'office');
      expect(prefs.time, 'all_day');
      expect(prefs.intensity, 'light');
      expect(prefs.tags, contains('clean'));
      expect(prefs.tags, contains('fresh'));
    });

    test('Arabic explicit gift still keeps gift context', () {
      final prefs = LocalIntentParser.parse(
        '\u0639\u0627\u064a\u0632 \u0639\u0637\u0631 \u0647\u062f\u064a\u0629 \u0644\u062e\u0637\u064a\u0628\u062a\u064a \u0647\u0627\u062f\u064a',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'women');
      expect(prefs.tags, contains('gift'));
      expect(prefs.intensity, 'light');
    });

    test('wedding occasion does not infer gender by itself', () {
      final prefs = LocalIntentParser.parse(
        'عايز عطر فرح',
        SessionPreferences.empty(),
      );

      expect(prefs.occasion, 'formal');
      expect(prefs.gender, isNull);
    });

    test('gift for fiancee at wedding infers women and formal occasion', () {
      final prefs = LocalIntentParser.parse(
        'عايز عطر هدية لخطيبتي في مناسبة فرح',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'women');
      expect(prefs.occasion, 'formal');
      expect(prefs.tags, contains('gift'));
    });

    test('Arabic no oud fresh work request keeps fresh work context', () {
      final prefs = LocalIntentParser.parse(
        '\u0645\u0634 \u0628\u062d\u0628 \u0627\u0644\u0639\u0648\u062f\u060c \u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0629 \u0641\u0631\u064a\u0634 \u0644\u0644\u0634\u063a\u0644 \u0641\u064a \u062d\u062f\u0648\u062f 1200',
        SessionPreferences.empty(),
      );

      expect(prefs.excludedNotes, contains('oud'));
      expect(prefs.tags, contains('fresh'));
      expect(prefs.tags, contains('clean'));
      expect(prefs.occasion, 'office');
      expect(prefs.maxBudget, 1200.0);
    });

    test(
      'Arabic hard citrus negation excludes citrus instead of preferring it',
      () {
        final prefs = LocalIntentParser.parse(
          '\u0627\u0644\u0633\u0644\u0627\u0645 \u0639\u0644\u064a\u0643\u0645\u060c \u0643\u0646\u062a \u0628\u062f\u0648\u0631 \u0639\u0644\u0649 \u0639\u0637\u0631 \u0635\u064a\u0641\u064a \u0645\u0646\u0639\u0634 \u0644\u0644\u0634\u063a\u0644 \u0628\u0633 \u0623\u0647\u0645 \u062d\u0627\u062c\u0629 \u0645\u064a\u0643\u0648\u0646\u0634 \u0641\u064a\u0647 \u0631\u064a\u062d\u0629 \u0644\u064a\u0645\u0648\u0646 \u0623\u0648 \u062d\u0645\u0636\u064a\u0627\u062a \u0646\u0647\u0627\u0626\u064a\u060c \u0648\u0645\u0639\u0627\u064a\u0627 2000 \u062c\u0646\u064a\u0647',
          SessionPreferences.empty(),
        );

        expect(prefs.maxBudget, 2000.0);
        expect(prefs.season, 'summer');
        expect(prefs.occasion, 'office');
        expect(prefs.tags, contains('fresh'));
        expect(prefs.excludedNotes, contains('citrus'));
        expect(prefs.preferredNotes, isNot(contains('citrus')));
        expect(prefs.excludedNotes, isNot(contains('honey')));
      },
    );

    test(
      'Arabic forget budget clears budget and fresh oud request replaces stale preferred notes',
      () {
        final prefs = LocalIntentParser.parse(
          '\u0627\u0646\u0633\u0649 \u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629 \u0627\u0644\u0644\u064a \u0642\u0644\u062a\u0647\u0627 \u062e\u0627\u0644\u0635\u060c \u0648\u0631\u0634\u062d\u0644\u064a \u0639\u0637\u0631 \u0634\u062a\u0648\u064a \u062a\u0642\u064a\u0644 \u0641\u064a\u0647 \u0631\u064a\u062d\u0629 \u0639\u0648\u062f.',
          const SessionPreferences(
            maxBudget: 2000,
            season: 'summer',
            occasion: 'office',
            intensity: 'light',
            preferredNotes: ['citrus'],
            excludedNotes: ['citrus'],
            tags: ['fresh', 'clean'],
          ),
        );

        expect(prefs.maxBudget, isNull);
        expect(prefs.season, 'winter');
        expect(prefs.intensity, 'strong');
        expect([
          ...prefs.preferredNotes,
          ...prefs.preferredTopNotes,
          ...prefs.preferredMiddleNotes,
          ...prefs.preferredBaseNotes,
        ], contains('oud'));
        expect(prefs.preferredNotes, isNot(contains('citrus')));
        expect(prefs.preferredMiddleNotes, isNot(contains('citrus')));
        expect(prefs.excludedNotes, contains('citrus'));
      },
    );

    test('extracts budget with different Arabic phrasing', () {
      final prefs1 = LocalIntentParser.parse(
        'عايز عطر ميزانيته 1500 جنيه',
        SessionPreferences.empty(),
      );
      expect(prefs1.maxBudget, 1500.0);

      final prefs2 = LocalIntentParser.parse(
        'لا يزيد سعره عن 2000',
        SessionPreferences.empty(),
      );
      expect(prefs2.maxBudget, 2000.0);

      final prefs3 = LocalIntentParser.parse(
        'عطر رخيص',
        const SessionPreferences(maxBudget: 2000),
      );
      // 85% of 2000 = 1700
      expect(prefs3.maxBudget, 1700.0);

      final prefs4 = LocalIntentParser.parse(
        'عايزه ارخص شوية',
        const SessionPreferences(maxBudget: 1500),
      );
      // 85% of 1500 = 1275
      expect(prefs4.maxBudget, 1275.0);

      final prefs5 = LocalIntentParser.parse(
        'Make it cheaper',
        const SessionPreferences(maxBudget: 1500),
      );
      // 85% of 1500 = 1275
      expect(prefs5.maxBudget, 1275.0);

      final prefs6 = LocalIntentParser.parse(
        'عايز عطر ميزانيته ١٢٠٠ جنيه',
        SessionPreferences.empty(),
      );
      expect(prefs6.maxBudget, 1200.0);
      final prefs8 = LocalIntentParser.parse(
        'what is the cheapest perfume u have?',
        SessionPreferences.empty(),
      );
      expect(prefs8.maxBudget, 1200.0);

      final prefs9 = LocalIntentParser.parse(
        'عايز ارخص عطر عندكم',
        SessionPreferences.empty(),
      );
      expect(prefs9.maxBudget, 1200.0);

      final prefs7 = LocalIntentParser.parse(
        'عايز عطر تحت ۹۵۰ جنيه',
        SessionPreferences.empty(),
      );
      expect(prefs7.maxBudget, 950.0);
    });

    test(
      'can explicitly clear a stale budget without clearing other preferences',
      () {
        final prefs = LocalIntentParser.parse(
          'forget budget',
          const SessionPreferences(gender: 'men', maxBudget: 1500),
        );

        expect(prefs.gender, 'men');
        expect(prefs.maxBudget, isNull);
      },
    );

    test('extracts gender regardless of prefixes/suffixes', () {
      // "رجالي" should map to "men"
      final prefs1 = LocalIntentParser.parse(
        'عايز عطر رجالي',
        SessionPreferences.empty(),
      );
      expect(prefs1.gender, 'men');

      // "للنساء" should map to "women"
      final prefs2 = LocalIntentParser.parse(
        'عطر للنساء ممتاز',
        SessionPreferences.empty(),
      );
      expect(prefs2.gender, 'women');

      // "للجنسين" should map to "unisex"
      final prefs3 = LocalIntentParser.parse(
        'عطر للجنسين',
        SessionPreferences.empty(),
      );
      expect(prefs3.gender, 'unisex');
    });

    test('extracts season, time, and occasion', () {
      final prefs = LocalIntentParser.parse(
        // شتوي -> winter, مناسبات -> formal, مساء -> night
        'محتاج عطر شتوي مناسبات مساء',
        SessionPreferences.empty(),
      );

      expect(prefs.season, 'winter');
      expect(prefs.time, 'night');
      expect(prefs.occasion, 'formal');
    });

    test('prefers all day over day when both aliases start together', () {
      final prefs = LocalIntentParser.parse(
        'I need a unisex office perfume for all day under 900',
        SessionPreferences.empty(),
      );

      expect(prefs.time, 'all_day');
      expect(prefs.occasion, 'office');
      expect(prefs.gender, 'unisex');
    });

    test('handles implicit English note replacement with instead', () {
      final prefs = LocalIntentParser.parse(
        'Instead make it woody',
        const SessionPreferences(preferredNotes: ['vanilla']),
      );

      expect(prefs.preferredNotes, contains('woody'));
      expect(prefs.preferredNotes, isNot(contains('vanilla')));
      expect(prefs.excludedNotes, contains('vanilla'));
    });

    test('handles English remove note then make it positive note', () {
      final prefs = LocalIntentParser.parse(
        'Actually remove vanilla and make it woody.',
        const SessionPreferences(preferredNotes: ['vanilla']),
      );

      expect(prefs.preferredNotes, contains('woody'));
      expect(prefs.preferredNotes, isNot(contains('vanilla')));
      expect(prefs.excludedNotes, contains('vanilla'));
      expect(prefs.excludedNotes, isNot(contains('woody')));
    });

    test('extracts intensity', () {
      // فواح -> strong
      final prefs = LocalIntentParser.parse(
        'عايز عطر فواح جدا',
        SessionPreferences.empty(),
      );
      expect(prefs.intensity, 'strong');
    });

    test('maps "similar to Sauvage" to deterministic reference profile', () {
      final prefs = LocalIntentParser.parse(
        'عايز عطر زي سوفاج للجامعة',
        SessionPreferences.empty(),
      );

      expect(prefs.occasion, 'university');
      expect(prefs.gender, 'men');
      expect(prefs.intensity, 'strong');
      expect(prefs.preferredNotes, containsAll(['citrus', 'spicy', 'woody']));
      expect(prefs.tags, contains('fresh'));
    });

    test('maps English Sauvage reference to useful note hints', () {
      final prefs = LocalIntentParser.parse(
        'I want something like Dior Sauvage',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'men');
      expect(prefs.preferredNotes, containsAll(['citrus', 'spicy', 'woody']));
    });

    test('does not invent default budget for cheaper Sauvage reference', () {
      final prefs = LocalIntentParser.parse(
        'عايز عطر زي سوفاج بس ارخص',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'men');
      expect(prefs.maxBudget, isNull);
      expect(prefs.preferredNotes, containsAll(['citrus', 'spicy', 'woody']));
    });

    test('maps standalone Bleu de Chanel recommendation to profile hints', () {
      final prefs = LocalIntentParser.parse(
        'Recommend something similar to Bleu de Chanel but cheaper.',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'men');
      expect(prefs.intensity, 'medium');
      expect(prefs.preferredNotes, containsAll(['citrus', 'woody']));
      expect(prefs.tags, containsAll(['fresh', 'classic']));
    });

    test('detects availability intent for Arabic and English messages', () {
      expect(
        LocalIntentParser.detectIntent('هل عطر cedar class 01 موجود؟'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('Dior موجوده؟'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('is vanilla sky available?'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('is "stay with you" available?'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('is there dior suvage?'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('Le Male'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('Stronger With You Intensely'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('هل عندك سوفاج؟'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        LocalIntentParser.detectIntent('متوفر عندك ديور سوفاج؟'),
        AIChatIntent.availabilityCheck,
      );
    });

    test(
      'does not classify modifier phrasing as availability without anchor',
      () {
        expect(
          LocalIntentParser.detectIntent('اي ارخص عطر عندك؟'),
          AIChatIntent.newRecommendation,
        );
        expect(
          LocalIntentParser.detectIntent('عايز حاجة أقوى عندك'),
          AIChatIntent.newRecommendation,
        );
        expect(
          LocalIntentParser.detectIntent('هاتلي أهدى شوية'),
          AIChatIntent.newRecommendation,
        );
        expect(
          LocalIntentParser.detectIntent(
            'عندك؟',
            hasRecommendationContext: false,
          ),
          AIChatIntent.newRecommendation,
        );
        expect(
          LocalIntentParser.detectIntent(
            'عندك منه؟',
            hasRecommendationContext: true,
          ),
          AIChatIntent.availabilityCheck,
        );
      },
    );

    test('extracts product query from availability question', () {
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'هل عطر Cedar Class 01 موجود؟',
        ),
        equals('cedar class 01'),
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery('Dior موجوده؟'),
        equals('dior'),
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'Do you have Vanilla Sky in stock?',
        ),
        equals('vanilla sky'),
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'is "stay with you" available?',
        ),
        equals('stay with you'),
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'هل عطر stay with you موجود؟',
        ),
        equals('stay with you'),
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'is there dior suvage?',
        ),
        equals('dior suvage'),
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'هل عندك سوفاج؟',
        ),
        equals('سوفاج'),
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'متوفر عندك ديور سوفاج؟',
        ),
        equals('ديور سوفاج'),
      );
    });

    test('extracts product query from Arabic price question', () {
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'السوفاج بكام؟',
        ),
        equals('السوفاج'),
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'كم سعر السوفاج',
        ),
        equals('السوفاج'),
      );
    });

    test(
      'routes niche rain scent request away from availability ambiguity',
      () {
        const message =
            'Do you have something like petrichor, rain on soil, if possible?';

        expect(
          LocalIntentParser.detectIntent(message),
          isNot(AIChatIntent.availabilityCheck),
        );
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
        );
      },
    );

    test(
      'routes explicit similar cheaper request away from availability ambiguity',
      () {
        const message = 'Do you have something like Dior Sauvage but cheaper?';

        expect(
          LocalIntentParser.detectIntent(message),
          isNot(AIChatIntent.availabilityCheck),
        );
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
          isNull,
        );
        expect(
          AvailabilityIntentUtils.looksLikeAvailabilityQuery(
            message,
            hasRecommendationContext: false,
          ),
          isFalse,
        );
      },
    );

    test('keeps explicit product availability routing after niche guard', () {
      expect(
        LocalIntentParser.detectIntent('Do you have Dior Sauvage?'),
        AIChatIntent.availabilityCheck,
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'Do you have Dior Sauvage?',
        ),
        equals('dior sauvage'),
      );
    });

    test('keeps recommendation continuation away from availability lookup', () {
      expect(
        LocalIntentParser.detectIntent('Recommend the best match for me.'),
        AIChatIntent.newRecommendation,
      );
      expect(
        LocalIntentParser.detectIntent('Ш±ШґШ­Щ„ЩЉ Ш§ЩЃШ¶Щ„ Ш§Ш®ШЄЩЉШ§Ш±.'),
        AIChatIntent.newRecommendation,
      );
      expect(
        LocalIntentParser.detectIntent(
          'Actually make it strictly under 800 EGP.',
        ),
        AIChatIntent.newRecommendation,
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'recommend best match',
        ),
        isNull,
      );
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'show me the best option',
        ),
        isNull,
      );
      expect(
        LocalIntentParser.detectIntent('Dior Sauvage'),
        AIChatIntent.availabilityCheck,
      );
    });

    test(
      'keeps persona and preference statements out of availability lookup',
      () {
        const messages = [
          'I am a 28-year-old man.',
          'I work in finance.',
          'I prefer woody and smoky scents.',
          'My budget is 1500 EGP.',
        ];

        for (final message in messages) {
          expect(
            LocalIntentParser.detectIntent(message),
            AIChatIntent.newRecommendation,
            reason: message,
          );
          expect(
            AvailabilityIntentUtils.extractAvailabilityProductQuery(message),
            isNull,
            reason: message,
          );
        }

        expect(
          LocalIntentParser.detectIntent('Is Dior Sauvage available?'),
          AIChatIntent.availabilityCheck,
        );
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(
            'Do you have Dior Sauvage?',
          ),
          'dior sauvage',
        );
      },
    );

    test('persona preferences accumulate without age as budget', () {
      var preferences = const SessionPreferences();
      preferences = LocalIntentParser.parse(
        'I am a 28-year-old man.',
        preferences,
      );
      preferences = LocalIntentParser.parse('I work in finance.', preferences);
      preferences = LocalIntentParser.parse(
        'I prefer woody and smoky scents.',
        preferences,
      );
      preferences = LocalIntentParser.parse(
        'My budget is 1500 EGP.',
        preferences,
      );

      expect(preferences.gender, 'men');
      expect(preferences.maxBudget, 1500);
      expect(preferences.preferredNotes, contains('woody'));
      expect(preferences.tags, containsAll(['smoky', 'elegant', 'classic']));
      expect(preferences.occasion, 'office');
    });

    test('romantic Valentine request stays a soft date context', () {
      final preferences = LocalIntentParser.parse(
        "Recommend a romantic perfume for Valentine's Day under 1400 EGP.",
        const SessionPreferences(),
      );

      expect(preferences.maxBudget, 1400);
      expect(preferences.occasion, 'date');
      expect(preferences.tags, containsAll(['sweet', 'warm', 'romantic']));
      expect(preferences.preferredNotes, isNot(contains('woody')));
      expect(preferences.preferredNotes, isNot(contains('spicy')));
      expect(preferences.intensity, isNot('strong'));
      expect(preferences.time, isNot('day'));
    });

    test(
      'does not extract fake availability product from modifier wording',
      () {
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(
            'اي ارخص عطر عندك؟',
          ),
          isNull,
        );
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(
            'عايز حاجة أقوى عندك',
          ),
          isNull,
        );
      },
    );

    test(
      'treats explicit product redirect after rejection as availability',
      () {
        expect(
          LocalIntentParser.detectIntent(
            'no i dont want those i want "stay with you" perfume',
            hasRecommendationContext: true,
          ),
          AIChatIntent.availabilityCheck,
        );
        expect(
          AvailabilityIntentUtils.extractRedirectedProductQuery(
            'no i dont want those i want "stay with you" perfume',
            hasRecommendationContext: true,
          ),
          equals('stay with you'),
        );
      },
    );

    test(
      'returns null when availability question has no clear product name',
      () {
        expect(
          AvailabilityIntentUtils.extractAvailabilityProductQuery(
            'هل في عطر متوفر؟',
          ),
          isNull,
        );
      },
    );

    test(
      'does not treat recommendation phrasing with فيه/with as availability',
      () {
        expect(
          LocalIntentParser.detectIntent('عايز عطر فيه فانيليا'),
          isNot(AIChatIntent.availabilityCheck),
        );
        expect(
          LocalIntentParser.detectIntent('I want a perfume with vanilla'),
          isNot(AIChatIntent.availabilityCheck),
        );
        expect(
          LocalIntentParser.detectIntent('fresh perfume'),
          isNot(AIChatIntent.availabilityCheck),
        );
        expect(
          LocalIntentParser.detectIntent('sweet vanilla'),
          isNot(AIChatIntent.availabilityCheck),
        );
      },
    );

    test('extracts specific notes with layers', () {
      // Since parser extracts one layer per message, test them individually
      final topPrefs = LocalIntentParser.parse(
        'عطر افتتاحية ليمون',
        SessionPreferences.empty(),
      );
      expect(topPrefs.preferredTopNotes, contains('citrus'));

      final middlePrefs = LocalIntentParser.parse(
        'عطر قلبه ورد',
        SessionPreferences.empty(),
      );
      expect(middlePrefs.preferredMiddleNotes, contains('rose'));

      final basePrefs = LocalIntentParser.parse(
        'عطر قاعدة عود',
        SessionPreferences.empty(),
      );
      expect(basePrefs.preferredBaseNotes, contains('oud'));
    });

    test('extracts general preferred notes', () {
      // فانيليا -> vanilla, جلد -> leather
      final prefs = LocalIntentParser.parse(
        'عايز عطر بريحة الفانيليا والجلد',
        SessionPreferences.empty(),
      );
      expect(prefs.preferredNotes, isNotEmpty);
      expect(prefs.preferredNotes, containsAll(['vanilla', 'leather']));
    });

    test('extracts expanded fruit note aliases and preserves scalar memory', () {
      const current = SessionPreferences(
        gender: 'women',
        season: 'summer',
        preferredNotes: ['vanilla'],
      );

      final mango = LocalIntentParser.parse('is there with mango', current);
      expect(mango.gender, 'women');
      expect(mango.season, 'summer');
      expect(mango.preferredNotes, containsAll(['vanilla', 'mango']));
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'is there with mango',
        ),
        isNull,
      );
      expect(
        AvailabilityIntentUtils.looksLikeAvailabilityQuery(
          'is there with mango',
          hasRecommendationContext: true,
        ),
        isFalse,
      );
      expect(
        LocalIntentParser.detectIntent(
          'is there with mango',
          hasRecommendationContext: true,
        ),
        AIChatIntent.newRecommendation,
      );

      final fruits = LocalIntentParser.parse(
        'with pineapple coconut lychee strawberry green apple pear peach cherry watermelon fig date grape',
        SessionPreferences.empty(),
      );
      expect(
        fruits.preferredNotes,
        containsAll(<String>[
          'pineapple',
          'coconut',
          'lychee',
          'strawberry',
          'green_apple',
          'pear',
          'peach',
          'cherry',
          'watermelon',
          'fig',
          'date',
          'grape',
        ]),
      );
    });

    test('English note replacement removes old note and adds new note', () {
      const current = SessionPreferences(preferredNotes: ['floral']);
      final prefs = LocalIntentParser.parse(
        'replace floral with vanilla',
        current,
      );

      expect(prefs.preferredNotes, contains('vanilla'));
      expect(prefs.preferredNotes, isNot(contains('floral')));
      expect(prefs.excludedNotes, contains('floral'));
    });

    test('matches Arabic notes with definite article and punctuation', () {
      final prefs = LocalIntentParser.parse(
        'عايز بريحة الجلد، والفانيليا',
        SessionPreferences.empty(),
      );
      expect(prefs.preferredNotes, containsAll(['leather', 'vanilla']));
    });

    test('handles excluded notes properly via regex and keywords', () {
      // Exclude using "بدون" and "بلاش"
      // ياسمين -> floral, عود -> oud
      final prefs = LocalIntentParser.parse(
        'عطر بدون ياسمين وبلاش عود',
        SessionPreferences.empty(),
      );
      expect(prefs.excludedNotes, containsAll(['floral', 'oud']));
      // Make sure they are NOT in preferred lists
      expect(prefs.preferredNotes, isNot(contains('floral')));
      expect(prefs.preferredNotes, isNot(contains('oud')));
    });

    test('keeps choking exclusions out of preferred notes', () {
      final prefs = LocalIntentParser.parse(
        'عايز عطر شتوي تقيل فيه توباكو وعسل، بس ابعد تماماً عن الفانيليا عشان بتخنقني.',
        SessionPreferences.empty(),
      );

      expect(prefs.season, 'winter');
      expect(prefs.intensity, 'strong');
      expect(prefs.preferredNotes, containsAll(['tobacco', 'honey']));
      expect(prefs.preferredNotes, isNot(contains('vanilla')));
      expect(prefs.excludedNotes, contains('vanilla'));
    });

    test('handles tag extraction', () {
      // كلاسيك -> classic, أنيق -> elegant (normalized to انيق)
      final prefs = LocalIntentParser.parse(
        'عطر كلاسيك و انيق',
        SessionPreferences.empty(),
      );
      expect(prefs.tags, containsAll(['classic', 'elegant']));
    });

    test('maps professional vibe to elegant instead of clean', () {
      final prefs = LocalIntentParser.parse(
        'عايز حاجة professional',
        SessionPreferences.empty(),
      );

      expect(prefs.tags, contains('elegant'));
      expect(prefs.tags, isNot(contains('clean')));
    });

    group('isVague', () {
      test('identifies empty or very short inputs as vague', () {
        expect(LocalIntentParser.isVague(''), isTrue);
        expect(LocalIntentParser.isVague('عط'), isTrue);
      });

      test(
        'identifies generic greetings as NOT vague (processed differently)',
        () {
          expect(LocalIntentParser.isVague('مرحبا'), isFalse);
          expect(LocalIntentParser.isVague('اهلا بيك'), isFalse);
          expect(LocalIntentParser.isVague('hello'), isFalse);
        },
      );

      test('identifies clear criteria inputs as NOT vague', () {
        expect(LocalIntentParser.isVague('عطر رجالي'), isFalse);
        expect(LocalIntentParser.isVague('عايز عطر ب 1000 جنيه'), isFalse);
        expect(LocalIntentParser.isVague('عطر بريحة العود'), isFalse);
      });

      test(
        'identifies completely unrelated long text as vague (no criteria found)',
        () {
          expect(
            LocalIntentParser.isVague(
              'الحياة جميلة في الطقس المعتدل ولا يوجد شيء اخر',
            ),
            isTrue,
          );
        },
      );
    });

    test('treats greeting-only messages as pure greetings', () {
      expect(LocalIntentParser.isGreetingOnly('اهلا'), isTrue);
      expect(LocalIntentParser.isGreetingOnly('hello'), isTrue);
      expect(LocalIntentParser.isGreetingOnly('hello summer perfume'), isFalse);
      expect(LocalIntentParser.isGreetingOnly('اهلا عايز عطر صيفي'), isFalse);
    });

    test('normalizes Arabic characters before matching', () {
      // Test Tashkeel removal and character unification
      // "عَطْرٌ رِجَالِيٌّ" -> "عطر رجالي"
      final prefs1 = LocalIntentParser.parse(
        'عَطْرٌ رِجَالِيٌّ',
        SessionPreferences.empty(),
      );
      expect(prefs1.gender, 'men');

      // Test Alif normalization
      // أنيق -> انيق (elegant tag)
      final prefs2 = LocalIntentParser.parse(
        'أنيق جدا',
        SessionPreferences.empty(),
      );
      expect(prefs2.tags, contains('elegant'));
    });

    test('maintains previous preferences when unchanged', () {
      final currentPrefs = const SessionPreferences(
        gender: 'women',
        maxBudget: 2000.0,
      );

      // We only mention "فانيليا" (vanilla), so gender and budget should remain.
      final newPrefs = LocalIntentParser.parse('عطر فيه فانيليا', currentPrefs);

      expect(newPrefs.gender, 'women');
      expect(newPrefs.maxBudget, 2000.0);
      expect(newPrefs.preferredNotes, contains('vanilla'));
    });

    test('does not clear state for any-thing continuation phrases', () {
      final currentPrefs = const SessionPreferences(
        gender: 'men',
        season: 'summer',
        maxBudget: 1400,
        preferredNotes: ['citrus'],
      );

      final nextPrefs = LocalIntentParser.parse('أي حاجة', currentPrefs);

      expect(nextPrefs.gender, 'men');
      expect(nextPrefs.season, 'summer');
      expect(nextPrefs.maxBudget, 1400);
      expect(nextPrefs.preferredNotes, contains('citrus'));
    });

    test('patches excluded notes without resetting existing scalar state', () {
      final currentPrefs = const SessionPreferences(
        gender: 'men',
        season: 'summer',
        preferredNotes: ['oud', 'citrus'],
      );

      final nextPrefs = LocalIntentParser.parse('من غير عود', currentPrefs);

      expect(nextPrefs.gender, 'men');
      expect(nextPrefs.season, 'summer');
      expect(nextPrefs.excludedNotes, contains('oud'));
      expect(nextPrefs.preferredNotes, isNot(contains('oud')));
      expect(nextPrefs.preferredNotes, contains('citrus'));
    });

    test('patches intensity modifiers over existing preferences', () {
      final currentPrefs = const SessionPreferences(
        gender: 'men',
        season: 'winter',
        intensity: 'strong',
      );

      final lighter = LocalIntentParser.parse('أهدى شوية', currentPrefs);
      expect(lighter.intensity, 'light');
      expect(lighter.gender, 'men');
      expect(lighter.season, 'winter');

      final stronger = LocalIntentParser.parse('خليه أقوى', lighter);
      expect(stronger.intensity, 'strong');
      expect(stronger.gender, 'men');
      expect(stronger.season, 'winter');
    });

    test('season retarget does not inject reference-profile hints', () {
      const currentPrefs = SessionPreferences(
        gender: 'men',
        season: 'summer',
        preferredNotes: ['woody', 'spicy'],
        tags: ['fresh'],
      );

      final next = LocalIntentParser.parse('خليه شتوي', currentPrefs);

      expect(next.gender, 'men');
      expect(next.season, 'winter');
      expect(next.occasion, isNull);
      expect(next.time, isNull);
      expect(next.intensity, isNull);
      expect(next.tags, contains('fresh'));
      expect(next.tags, isNot(contains('clean')));
    });

    test('complex negation and replacement (بدال/بلاش/من غير)', () {
      // "بدال الفانيليا خليها خشب" -> Exclude vanilla, add woody
      final currentWithVanilla = const SessionPreferences(
        preferredNotes: ['vanilla'],
      );
      final prefs1 = LocalIntentParser.parse(
        'بدال الفانيليا خليها خشب',
        currentWithVanilla,
      );

      expect(prefs1.excludedNotes, contains('vanilla'));
      expect(prefs1.preferredNotes, contains('woody'));
      expect(prefs1.preferredNotes, isNot(contains('vanilla')));

      // "من غير ريحة الورد" -> Exclude rose
      final prefs2 = LocalIntentParser.parse(
        'عطر من غير ريحة الورد',
        SessionPreferences.empty(),
      );
      expect(prefs2.excludedNotes, contains('rose'));
    });

    test('note replacement phrase is not treated as scalar modifier patch', () {
      expect(
        LocalIntentParser.detectModifierPatch('بدال الفانيليا خليها خشب'),
        isNull,
      );
    });

    test('layered notes extraction (single layer per message)', () {
      // The local parser currently detects one layer per message.
      final message = 'عطر افتتاحية ليمون';
      final prefs = LocalIntentParser.parse(
        message,
        SessionPreferences.empty(),
      );
      expect(prefs.preferredTopNotes, contains('citrus'));

      final message2 = 'وقلب ياسمين';
      final prefs2 = LocalIntentParser.parse(message2, prefs);
      expect(prefs2.preferredMiddleNotes, contains('floral'));

      final message3 = 'والقاعدة مسك';
      final prefs3 = LocalIntentParser.parse(message3, prefs2);
      expect(prefs3.preferredBaseNotes, contains('musk'));
    });

    test('advanced budget extraction (digits priority)', () {
      final prefs1 = LocalIntentParser.parse(
        'في حدود ال 2000',
        SessionPreferences.empty(),
      );
      expect(prefs1.maxBudget, 2000.0);

      final prefs2 = LocalIntentParser.parse(
        'رينج 1000 ل 1500',
        SessionPreferences.empty(),
      );
      // Should pick the range end. Regex picks (\d{2,4}).
      expect(prefs2.maxBudget, 1500.0);

      final prefs3 = LocalIntentParser.parse(
        'اقصى حاجة 800\$',
        SessionPreferences.empty(),
      );
      expect(prefs3.maxBudget, 800.0);

      final prefs4 = LocalIntentParser.parse(
        'Under 1600 EGP.',
        const SessionPreferences(gender: 'men', preferredNotes: ['cedar']),
      );
      expect(prefs4.maxBudget, 1600.0);
      expect(prefs4.gender, 'men');
      expect(prefs4.preferredNotes, contains('cedar'));

      final prefs5 = LocalIntentParser.parse(
        'Under 1400.',
        const SessionPreferences(occasion: 'date', tags: ['romantic']),
      );
      expect(prefs5.maxBudget, 1400.0);
      expect(prefs5.occasion, 'date');

      final prefs6 = LocalIntentParser.parse(
        '????? 600 ?? ?? ?? ???? ????? ??900 ????? ????',
        SessionPreferences.empty(),
      );
      expect(prefs6.maxBudget, 600.0);
    });

    test('intensity and context mapping (فواح/هادي/شتوي/ليلي)', () {
      final prefs = LocalIntentParser.parse(
        'عايز عطر شتوي ليلي فواح جدا',
        SessionPreferences.empty(),
      );

      expect(prefs.season, 'winter');
      expect(prefs.time, 'night');
      expect(prefs.intensity, 'strong');
    });

    test('sanitization: preferred and excluded notes conflict resolution', () {
      // If a note was preferred, and now it's excluded, it should move to excluded.
      final current = const SessionPreferences(preferredNotes: ['vanilla']);
      final next = LocalIntentParser.parse('بلاش فانيليا خليه عود', current);

      expect(next.preferredNotes, contains('oud'));
      expect(next.preferredNotes, isNot(contains('vanilla')));
      expect(next.excludedNotes, contains('vanilla'));
    });

    test('Arabic remove vanilla and keep sandalwood with musk patch', () {
      const current = SessionPreferences(preferredNotes: ['vanilla', 'musk']);
      final next = LocalIntentParser.parse(
        '\u0644\u0627 \u0634\u064a\u0644 \u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627 \u0648\u062e\u0644\u064a\u0647 \u0635\u0646\u062f\u0644 \u0645\u0639 \u0645\u0633\u0643',
        current,
      );

      expect(next.preferredNotes, contains('musk'));
      expect(next.preferredNotes, contains('sandalwood'));
      expect(next.preferredNotes, isNot(contains('vanilla')));
      expect(next.excludedNotes, contains('vanilla'));
    });

    test('handles colloquial Arabic negation with contrast correctly', () {
      final prefs = LocalIntentParser.parse(
        'رشحلي عطر صيفي رجالي مفيهوش عود بس فيه فانيليا',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'men');
      expect(prefs.season, 'summer');
      expect(prefs.preferredNotes, contains('vanilla'));
      expect(prefs.preferredNotes, isNot(contains('oud')));
      expect(prefs.excludedNotes, contains('oud'));
    });

    test('scopes English without and with note clauses independently', () {
      final prefs = LocalIntentParser.parse(
        'Recommend a men summer perfume without oud but with vanilla',
        SessionPreferences.empty(),
      );

      expect(prefs.gender, 'men');
      expect(prefs.season, 'summer');
      expect(prefs.preferredNotes, contains('vanilla'));
      expect(prefs.preferredNotes, isNot(contains('oud')));
      expect(prefs.excludedNotes, contains('oud'));
      expect(prefs.excludedNotes, isNot(contains('vanilla')));
      expect(prefs.medicalExcludedNotes, isEmpty);
    });

    group('detectIntent', () {
      test('detects new recommendation', () {
        expect(
          LocalIntentParser.detectIntent('عايز عطر جديد'),
          AIChatIntent.newRecommendation,
        );
        expect(
          LocalIntentParser.detectIntent('I want a perfume'),
          AIChatIntent.newRecommendation,
        );
      });

      test('detects follow up based on keywords', () {
        // "كلمني اكتر" -> follow up
        expect(
          LocalIntentParser.detectIntent('كلمني اكتر عنه'),
          AIChatIntent.followUpProduct,
        );
        expect(
          LocalIntentParser.detectIntent('قولي اكتر عنه؟'),
          AIChatIntent.followUpProduct,
        );
        expect(
          LocalIntentParser.detectIntent('tell me more'),
          AIChatIntent.followUpProduct,
        );

        // "بكم سعره" -> follow up (actually pricing might be different but checked in keywords)
      });

      test(
        'note replacement phrasing is treated as new recommendation intent',
        () {
          expect(
            LocalIntentParser.detectIntent('بدال الفانيليا خليها خشب'),
            AIChatIntent.newRecommendation,
          );
        },
      );

      test('detects availability substitute follow-up phrasing', () {
        expect(
          LocalIntentParser.detectIntent('طب ايه اللي شبهه موجود؟'),
          AIChatIntent.followUpProduct,
        );
        expect(
          LocalIntentParser.detectIntent('alternative'),
          AIChatIntent.followUpProduct,
        );
        expect(
          LocalIntentParser.detectIntent('closest available'),
          AIChatIntent.followUpProduct,
        );
      });

      test(
        'treats cheaper budget adjustment as a new recommendation intent',
        () {
          expect(
            LocalIntentParser.detectIntent('Make it cheaper'),
            AIChatIntent.newRecommendation,
          );
        },
      );

      test('strict budget-only pivot is not treated as product follow-up', () {
        const message = 'Exactly 1500 EGP, not one pound more.';

        expect(
          LocalIntentParser.detectIntent(message),
          AIChatIntent.newRecommendation,
        );
        expect(
          LocalIntentParser.detectBudgetPolicy(message),
          AIChatBudgetPolicy.strict,
        );

        final prefs = LocalIntentParser.parse(
          message,
          const SessionPreferences(gender: 'men', preferredNotes: ['amber']),
        );
        expect(prefs.maxBudget, 1500);
        expect(prefs.gender, 'men');
        expect(prefs.preferredNotes, contains('amber'));
      });

      test('detects summary requests explicitly', () {
        expect(
          LocalIntentParser.detectIntent('لخصلي أنا طالب إيه لحد دلوقتي'),
          AIChatIntent.summary,
        );
        expect(
          LocalIntentParser.isSummaryRequest('summarize what I asked for'),
          isTrue,
        );
      });

      test('detects explicit reset / pivot phrasing', () {
        expect(
          LocalIntentParser.shouldResetConversationContext(
            'سيبك من كل ده أنا عايز هدية لوالدتي تحت 700',
          ),
          isTrue,
        );
      });

      test('does not treat generic demonstratives as follow up intent', () {
        expect(
          LocalIntentParser.detectIntent('دي جديدة'),
          AIChatIntent.newRecommendation,
        );
        expect(LocalIntentParser.isVague('دي جديدة'), isTrue);
      });

      test('detects comparison by keywords', () {
        expect(
          LocalIntentParser.detectIntent('قارن بينهم'),
          AIChatIntent.compareProducts,
        );
        expect(
          LocalIntentParser.detectIntent('compare first and second'),
          AIChatIntent.compareProducts,
        );
        expect(
          LocalIntentParser.detectIntent('وش الفرق بينهم'),
          AIChatIntent.compareProducts,
        );
      });

      test('does not treat scent blend request as product comparison', () {
        expect(
          LocalIntentParser.detectIntent(
            'ترشيحات رجالي شتوي يكون خليط بين ريحتين',
          ),
          AIChatIntent.newRecommendation,
        );
        expect(
          LocalIntentParser.detectIntent('recommend a mix of two scents'),
          AIChatIntent.newRecommendation,
        );
      });

      test('detects greeting even if mixed with short text', () {
        expect(LocalIntentParser.isGreetingOnly('اهلا'), isTrue);
        expect(LocalIntentParser.isGreetingOnly('hi'), isTrue);
      });
    });

    group('Social Gender Inference', () {
      test('extracts female gender from relationship keywords', () {
        final prefs = LocalIntentParser.parse(
          'عايز عطر لخطيبتي',
          SessionPreferences.empty(),
        );
        expect(prefs.gender, 'women');
      });

      test('extracts male gender from relationship keywords', () {
        final prefs = LocalIntentParser.parse(
          'رشحلي عطر لابني',
          SessionPreferences.empty(),
        );
        expect(prefs.gender, 'men');
      });

      test('handles relationship keywords with various prefixes', () {
        expect(
          LocalIntentParser.parse('لخطيبتي', SessionPreferences.empty()).gender,
          'women',
        );
        expect(
          LocalIntentParser.parse('لابني', SessionPreferences.empty()).gender,
          'men',
        );
        expect(
          LocalIntentParser.parse('لامي', SessionPreferences.empty()).gender,
          'women',
        );
      });

      test('handles spelling variations for relationship keywords', () {
        // "خطيبتى" (with ى) normalized to "خطيبتي"
        expect(
          LocalIntentParser.parse('خطيبتى', SessionPreferences.empty()).gender,
          'women',
        );
        expect(
          LocalIntentParser.parse('مراته', SessionPreferences.empty()).gender,
          'women',
        );
      });

      test('explicit gender priority over relationship inference', () {
        final prefs = LocalIntentParser.parse(
          'عايز عطر رجالي لخطيبتي',
          SessionPreferences.empty(),
        );
        expect(prefs.gender, 'men');
      });

      test('relationship inference priority over compromise unisex logic', () {
        // "متوازن" or "وسط" usually triggers compromise logic which sets unisex.
        // It should NOT override relationship gender.
        final prefs = LocalIntentParser.parse(
          'عايز حاجة balanced لخطيبتي',
          SessionPreferences.empty(),
        );
        expect(prefs.gender, 'women');
      });

      test(
        'new message relationship inference overrides old session gender',
        () {
          const currentPrefs = SessionPreferences(gender: 'men');
          final nextPrefs = LocalIntentParser.parse(
            'عايز هدية لخطيبتي',
            currentPrefs,
          );
          expect(nextPrefs.gender, 'women');
        },
      );
    });
    test(
      'detects vague perfume-topic requests separately from off-topic text',
      () {
        expect(LocalIntentParser.looksLikePerfumeRequest('عايز عطر'), isTrue);
        expect(
          LocalIntentParser.looksLikePerfumeRequest(
            'يكون رجالي',
            currentPreferences: const SessionPreferences(gender: 'men'),
          ),
          isTrue,
        );
        expect(
          LocalIntentParser.looksLikePerfumeRequest('ايه رأيك في Flutter؟'),
          isFalse,
        );
      },
    );

    test('isolates out-of-domain requests from perfume-shaped lookups', () {
      expect(
        LocalIntentParser.looksLikeOutOfDomainRequest(
          'رشحلي موبايل كويس للشراء',
        ),
        isTrue,
      );
      expect(
        LocalIntentParser.looksLikeOutOfDomainRequest(
          'فيه عطر iPhone 15 Pro Max؟ عايز سعره وكارت',
        ),
        isTrue,
      );
      expect(
        LocalIntentParser.looksLikeOutOfDomainRequest(
          'iPhone 15 Pro Max perfume',
        ),
        isTrue,
      );
    });

    test('trims multi-intent availability query at compare/recommend tail', () {
      expect(
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          'هل متاح Oud Mood؟ ولو متاح قارن بينه وبين Badee Al Oud ورشح الأنسب للشتاء',
        ),
        'oud mood',
      );
    });
  });
}
