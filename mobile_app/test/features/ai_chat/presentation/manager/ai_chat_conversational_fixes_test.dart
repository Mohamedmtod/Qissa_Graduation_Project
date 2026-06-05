import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_business_info_responder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_input_interceptor.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

void main() {
  group('LocalIntentParser conversational fixes', () {
    test('does not parse age as budget in gift scenario', () {
      final parsed = LocalIntentParser.parse(
        'بدوّر على عطر هدية لمديري في الشغل، عمره 45 سنة.',
        const SessionPreferences(),
      );

      expect(parsed.maxBudget, isNull);
      expect(parsed.occasion, anyOf('formal', 'office'));
    });

    test('does not parse requested perfume count as budget', () {
      final parsed = LocalIntentParser.parse(
        'i want a 3 male summer perfumes with a cheap price',
        const SessionPreferences(),
      );

      expect(parsed.gender, 'men');
      expect(parsed.season, 'summer');
      expect(parsed.maxBudget, isNull);
      expect(parsed.rankingStrategy, RankingStrategy.cheapestFirst);
    });

    test('maps gym request into practical fragrance hints', () {
      final parsed = LocalIntentParser.parse(
        'عطر أروح بيه الجيم وميضايقش حد.',
        const SessionPreferences(),
      );

      expect(parsed.intensity, 'light');
      expect(parsed.tags, contains('fresh'));
      expect(parsed.tags, contains('clean'));
    });

    test('maps office request into office/all-day profile', () {
      final parsed = LocalIntentParser.parse(
        'عطر للـ Office استخدمه كل يوم.',
        const SessionPreferences(),
      );

      expect(parsed.occasion, anyOf('office', 'daily'));
      expect(parsed.time, 'all_day');
      expect(parsed.intensity, 'light');
    });

    test('maps date night into evening romantic profile', () {
      final parsed = LocalIntentParser.parse(
        'عايز عطر لـ Date night مسائي.',
        const SessionPreferences(),
      );

      expect(parsed.occasion, 'date');
      expect(parsed.time, 'night');
      expect(parsed.tags, contains('sweet'));
    });

    test('lighter follow-up resolves to light intensity', () {
      final parsed = LocalIntentParser.parse(
        'هات حاجة أهدى شوية.',
        const SessionPreferences(season: 'winter'),
      );

      expect(parsed.intensity, 'light');
      expect(parsed.season, 'winter');
    });

    test('normalizes franco-arabic university request before parsing', () {
      final normalized = AIChatTextNormalizer.normalizeForParsing(
        '3awez 3etr fresh w rkhis lel gam3a',
      );
      final parsed = LocalIntentParser.parse(
        '3awez 3etr fresh w rkhis lel gam3a',
        const SessionPreferences(),
      );

      expect(normalized, contains('عايز'));
      expect(normalized, contains('عطر'));
      expect(normalized, contains('university'));
      expect(parsed.occasion, 'university');
      expect(parsed.tags, contains('fresh'));
    });

    test('normalizes slang and typo-heavy requests safely', () {
      final slangParsed = LocalIntentParser.parse(
        'عايز برفان فواح يجيب آخر الشارع وسعره حنين.',
        const SessionPreferences(),
      );
      final typoParsed = LocalIntentParser.parse(
        'عيظ عتر رجلي رخيس وحلو.',
        const SessionPreferences(),
      );

      expect(slangParsed.intensity, 'strong');
      expect(typoParsed.gender, 'men');
      expect(typoParsed.tags, isNot(contains('sweet')));
    });

    test('maps interview request into professional office profile', () {
      final parsed = LocalIntentParser.parse(
        'عندي انترفيو مهم بكرة في شركة كبيرة، عايز ريحة تبين إني بروفيشنال ومش مزعجة.',
        const SessionPreferences(),
      );

      expect(parsed.occasion, 'office');
      expect(parsed.intensity, 'light');
      expect(parsed.tags, contains('elegant'));
    });

    test('maps bedtime request into calm night profile', () {
      final parsed = LocalIntentParser.parse(
        'عايز عطر هادي جداً ومريح للأعصاب أحطه قبل ما أنام.',
        const SessionPreferences(),
      );

      expect(parsed.time, 'night');
      expect(parsed.intensity, 'light');
    });

    test('maps hot campus day into summer university profile', () {
      final parsed = LocalIntentParser.parse(
        'عندي يوم طويل جداً في الحرم الجامعي، عايز حاجة تستحمل الحر.',
        const SessionPreferences(),
      );

      expect(parsed.occasion, 'university');
      expect(parsed.season, 'summer');
      expect(parsed.time, 'all_day');
    });

    test(
      'maps VIP masterpiece intent into premium profile and clears budget',
      () {
        final parsed = LocalIntentParser.parse(
          'الفلوس مش مشكلة نهائي، هاتلي تحفة فنية.',
          const SessionPreferences(maxBudget: 1200),
        );

        expect(parsed.maxBudget, isNull);
        expect(parsed.tags, contains('elegant'));
        expect(parsed.intensity, 'strong');
      },
    );

    test('treats compromise as balanced request rather than contradiction', () {
      final parsed = LocalIntentParser.parse(
        'أنا بحب العطور المسكرة جداً، بس مراتي بتكرهها. هاتلي حل وسط يرضينا إحنا الاتنين.',
        const SessionPreferences(),
      );

      expect(parsed.gender, 'women');
      expect(parsed.intensity, 'medium');
      expect(parsed.tags, contains('sweet'));
    });

    test(
      'keeps bleu vibe cheaper request affordable without over-constraining time',
      () {
        final parsed = LocalIntentParser.parse(
          'أنا بستخدم Bleu de Chanel دايماً، عايز حاجة نفس الـ Vibe بس أرخص شوية.',
          const SessionPreferences(),
        );

        expect(parsed.gender, 'men');
        expect(parsed.maxBudget, 1200);
        expect(parsed.season, isNull);
        expect(parsed.tags, contains('classic'));
        expect(parsed.tags, contains('elegant'));
        expect(parsed.intensity, isNot('strong'));
      },
    );

    test('cheapest catalog query produces budget and not a gender ask', () {
      final parsed = LocalIntentParser.parse(
        'what is the cheapest perfume u have?',
        const SessionPreferences(),
      );

      expect(parsed.maxBudget, 1200.0);
      expect(parsed.gender, isNull);
    });

    test('does not promote negated strong intensity in mixed Arabic English', () {
      final parsed = LocalIntentParser.parse(
        '\u0639\u0627\u064a\u0632 clean perfume \u0644\u0644office under 1200 \u0648\u0645\u0634 \u0642\u0648\u064a',
        const SessionPreferences(),
      );

      expect(parsed.maxBudget, 1200);
      expect(parsed.intensity, isNot('strong'));
    });

    test('does not promote negated heavy intensity', () {
      final parsed = LocalIntentParser.parse(
        '\u0639\u0627\u064a\u0632 perfume \u0641\u064a\u0647 vanilla \u0648 musk \u0628\u0633 \u0645\u0634 \u062a\u0642\u064a\u0644',
        const SessionPreferences(),
      );

      expect(parsed.preferredNotes, containsAll(<String>['vanilla', 'musk']));
      expect(parsed.intensity, isNot('strong'));
    });

    test('keeps strong intent when only suffocating is negated', () {
      final arabicParsed = LocalIntentParser.parse(
        '\u0639\u0627\u064a\u0632 \u0639\u0637\u0631 \u0642\u0648\u064a \u0628\u0633 \u0645\u0634 \u062e\u0627\u0646\u0642',
        const SessionPreferences(),
      );
      final englishParsed = LocalIntentParser.parse(
        'I want a strong perfume but not suffocating',
        const SessionPreferences(),
      );

      expect(arabicParsed.intensity, 'strong');
      expect(englishParsed.intensity, 'strong');
    });

    test('keeps explicit stronger modifier as strong', () {
      final parsed = LocalIntentParser.parse(
        'Make it stronger',
        const SessionPreferences(),
      );

      expect(parsed.intensity, 'strong');
    });
  });

  group('AIChatInputInterceptor', () {
    test('detects fantasy note requests', () {
      final result = AIChatInputInterceptor.detect(
        'عندكم عطر بريحة الشاورما والتوم؟',
        const SessionPreferences(),
      );

      expect(result?.kind, AIChatInterceptKind.fantasyNoteLike);
    });

    test('detects contradictory requests', () {
      final result = AIChatInputInterceptor.detect(
        'عايز عطر خفيف جدًا ومابيتشمش بس يكون قوي جدًا وبيملى المكان.',
        const SessionPreferences(),
      );

      expect(result?.kind, AIChatInterceptKind.contradictionLike);
    });

    test('detects clear gibberish in Arabic and English', () {
      final arabic = AIChatInputInterceptor.detect(
        'هههههههههه',
        const SessionPreferences(),
      );
      final english = AIChatInputInterceptor.detect(
        'asdfghjkl',
        const SessionPreferences(),
      );
      final shortRandom = AIChatInputInterceptor.detect(
        'xqzplm',
        const SessionPreferences(),
      );
      final symbolNoise = AIChatInputInterceptor.detect(
        '@@@###',
        const SessionPreferences(),
      );

      expect(arabic?.kind, AIChatInterceptKind.gibberishLike);
      expect(english?.kind, AIChatInterceptKind.gibberishLike);
      expect(shortRandom?.kind, AIChatInterceptKind.gibberishLike);
      expect(symbolNoise?.kind, AIChatInterceptKind.gibberishLike);
    });

    test('does not treat short human-looking messages as gibberish', () {
      for (final message in [
        'yes',
        'ok',
        'sure',
        'تمام',
        'ماشي',
        'why',
        'how',
        'maybe',
      ]) {
        final result = AIChatInputInterceptor.detect(
          message,
          const SessionPreferences(),
        );

        expect(result, isNull, reason: message);
      }
    });

    test('detects luxury-budget mismatch', () {
      final result = AIChatInputInterceptor.detect(
        'عايز عطر أمراء وملوك بسعر 100 جنيه.',
        const SessionPreferences(maxBudget: 100),
      );

      expect(result?.kind, AIChatInterceptKind.luxuryBudgetMismatch);
    });

    test('detects invisible room-filling request as contradiction', () {
      final result = AIChatInputInterceptor.detect(
        'extremely light invisible perfume that fills the whole room and lasts forever',
        const SessionPreferences(),
      );

      expect(result?.kind, AIChatInterceptKind.contradictionLike);
    });

    test('does not classify normal light office request as contradiction', () {
      final result = AIChatInputInterceptor.detect(
        'I need a light office perfume',
        const SessionPreferences(),
      );

      expect(result, isNull);
    });

    test('does not treat normalized franco request as gibberish', () {
      final result = AIChatInputInterceptor.detect(
        '3awez 3etr fresh w rkhis lel gam3a',
        const SessionPreferences(),
      );

      expect(result, isNull);
    });

    test('does not treat compromise request as contradiction', () {
      final result = AIChatInputInterceptor.detect(
        'هاتلي حل وسط يرضينا إحنا الاتنين.',
        const SessionPreferences(),
      );

      expect(result, isNull);
    });
    test('does not flag natural exclude-then-prefer requests', () {
      const messages = [
        '\u0645\u0634 \u0628\u062d\u0628 \u0627\u0644\u0639\u0637\u0648\u0631 \u0627\u0644\u0642\u0648\u064a\u0629\u060c \u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0629 \u0647\u0627\u062f\u064a\u0629.',
        '\u0645\u0634 \u0633\u0648\u064a\u062a\u060c \u0639\u0627\u064a\u0632 \u0641\u0631\u064a\u0634.',
        'without oud but with vanilla',
      ];

      for (final message in messages) {
        final result = AIChatInputInterceptor.detect(
          message,
          const SessionPreferences(),
        );

        expect(result, isNull, reason: message);
      }
    });

    test('flags same-note include and exclude contradictions', () {
      const messages = [
        'without oud but with oud',
        '\u0628\u062f\u0648\u0646 \u0641\u0627\u0646\u064a\u0644\u064a\u0627 \u0648\u0645\u0639 \u0641\u0627\u0646\u064a\u0644\u064a\u0627',
      ];

      for (final message in messages) {
        final result = AIChatInputInterceptor.detect(
          message,
          const SessionPreferences(),
        );

        expect(
          result?.kind,
          AIChatInterceptKind.contradictionLike,
          reason: message,
        );
      }
    });
  });

  group('AIChatBusinessInfoResponder', () {
    test('recognizes Arabic payment and authenticity questions', () {
      const responder = AIChatBusinessInfoResponder(translate: _testTranslate);

      final payment = responder.requestType(
        LocalIntentParser.normalizeInput(
          '\u0627\u0644\u062f\u0641\u0639 \u0623\u0648\u0646\u0644\u0627\u064a\u0646 \u0648\u0644\u0627 \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645\u061f',
        ),
      );
      final authenticity = responder.requestType(
        LocalIntentParser.normalizeInput(
          '\u0627\u0644\u0639\u0637\u0648\u0631 \u0623\u0635\u0644\u064a\u0629\u061f',
        ),
      );

      expect(payment, 'payment');
      expect(authenticity, 'authenticity');
      expect(
        responder.buildAnswer(
          null,
          request: authenticity!,
          language: AIChatLanguage.arabic,
        ),
        contains('Qissa'),
      );
    });
  });
}

String _testTranslate(
  AIChatLanguage language, {
  required String ar,
  required String en,
}) {
  return language.isArabic ? ar : en;
}
