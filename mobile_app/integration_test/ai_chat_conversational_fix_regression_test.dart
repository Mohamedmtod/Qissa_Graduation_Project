import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/recommended_product_card.dart';
import 'package:perfume_app/main.dart' as app;

class _Scenario {
  const _Scenario({
    required this.id,
    required this.messages,
    this.minRecommendationCount = 0,
    this.mustContainAny = const <String>[],
    this.mustNotContain = const <String>[],
  });

  final String id;
  final List<String> messages;
  final int minRecommendationCount;
  final List<String> mustContainAny;
  final List<String> mustNotContain;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder findChatMessageField() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.textInputAction == TextInputAction.send &&
          widget.maxLines == 4,
      description: 'AI chat message input field',
    );
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int maxSeconds = 12,
  }) async {
    for (var i = 0; i < maxSeconds * 10; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<List<String>> collectVisibleTexts(WidgetTester tester) async {
    await tester.pumpAndSettle();
    return find
        .byType(Text)
        .evaluate()
        .map((element) => element.widget)
        .whereType<Text>()
        .map((widget) => widget.data?.trim())
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toList();
  }

  Future<void> sendChatMessage(WidgetTester tester, String text) async {
    final textFieldFinder = findChatMessageField();
    expect(textFieldFinder, findsOneWidget);

    await tester.ensureVisible(textFieldFinder);
    await tester.tap(textFieldFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(textFieldFinder, text);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    await waitFor(tester, find.byType(CircularProgressIndicator), maxSeconds: 5);
    await tester.pumpAndSettle(const Duration(seconds: 6));
    await waitFor(tester, textFieldFinder, maxSeconds: 20);
  }

  Future<void> startNewChat(WidgetTester tester) async {
    final refreshIcon = find.byIcon(Icons.refresh);
    if (refreshIcon.evaluate().isEmpty) return;

    await tester.tap(refreshIcon, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> launchAppAndOpenChat(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    final welcomeLoginBtn = find.text('Log in');
    if (welcomeLoginBtn.evaluate().isNotEmpty) {
      await tester.tap(welcomeLoginBtn.last, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    final emailFields = find.byType(TextFormField);
    await waitFor(tester, emailFields);

    if (emailFields.evaluate().length >= 2) {
      await tester.enterText(emailFields.first, 'm123m@mm.mmm');
      await tester.enterText(emailFields.at(1), 'M123m@mm.mmm');
      await tester.pumpAndSettle();

      final submitLogin = find.text('Log in').last;
      await tester.tap(submitLogin, warnIfMissed: false);
      await waitFor(tester, find.text('AI'));
    }

    final aiTab = find.text('AI');
    if (aiTab.evaluate().isNotEmpty) {
      await tester.tap(aiTab.last, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
  }

  Future<void> runScenario(WidgetTester tester, _Scenario scenario) async {
    debugPrint('[AI-CONV-FIX] Scenario start: ${scenario.id}');
    await startNewChat(tester);

    for (final message in scenario.messages) {
      await sendChatMessage(tester, message);
    }

    final visibleTexts = await collectVisibleTexts(tester);
    final combined = visibleTexts.join('\n');
    final tailCombined = visibleTexts
        .skip(visibleTexts.length > 12 ? visibleTexts.length - 12 : 0)
        .join('\n');
    final recommendationCount =
        find.byType(RecommendedProductCard).evaluate().length;

    debugPrint('[AI-CONV-FIX] Visible texts: $visibleTexts');
    debugPrint('[AI-CONV-FIX] Recommendation card count: $recommendationCount');

    expect(
      recommendationCount,
      greaterThanOrEqualTo(scenario.minRecommendationCount),
      reason: '${scenario.id} expected at least ${scenario.minRecommendationCount} recommendation card(s)',
    );

    if (scenario.mustContainAny.isNotEmpty) {
      expect(
        scenario.mustContainAny.any(combined.contains),
        isTrue,
        reason: '${scenario.id} expected one of: ${scenario.mustContainAny}',
      );
    }

    final forbiddenScope =
        scenario.id == 'lighter follow up' ? tailCombined : combined;

    for (final forbidden in scenario.mustNotContain) {
      expect(
        forbiddenScope.contains(forbidden),
        isFalse,
        reason: '${scenario.id} should not contain: $forbidden',
      );
    }

  }

  final scenarios = <_Scenario>[
    const _Scenario(
      id: 'vanilla-led recommendation',
      messages: ['أنا بعشق ريحة الفانيليا، عايز حاجة مبنية عليها بشكل أساسي صيفي.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'bleu vibe cheaper',
      messages: ['أنا بستخدم Bleu de Chanel دايماً، عايز حاجة نفس الـ Vibe بس أرخص شوية.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'fantasy note',
      messages: ['عندكم عطر بريحة الشاورما والتوم؟'],
      mustContainAny: ['غير موجود', 'واقعية', 'real fragrance family'],
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'contradiction',
      messages: ['عايز عطر خفيف جدًا ومابيتشمش بس يكون قوي جدًا وبيملى المكان.'],
      mustContainAny: ['تعارض', 'Which matters more'],
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'gibberish arabic',
      messages: ['شسيبلاتنم'],
      mustContainAny: ['لم أفهم', 'اكتب لي', 'I could not understand'],
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'gibberish english',
      messages: ['asdfghjkl'],
      mustContainAny: ['I could not understand', 'clarify', 'Could you'],
      mustNotContain: ['رجالي أم نسائي'],
    ),
    const _Scenario(
      id: 'compromise balanced taste',
      messages: [
        'أنا بحب العطور المسكرة جدًا، بس مراتي بتكرهها. هاتلي حل وسط يرضينا إحنا الاتنين.',
      ],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'impossible budget 150',
      messages: ['عايز عطر ميزانيتي آخرها 150 جنيه.'],
      mustContainAny: ['أقل سعر', 'لا يوجد حاليًا عطر بهذا السعر', 'lowest available price'],
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'vip masterpiece',
      messages: ['الفلوس مش مشكلة نهائي، هاتلي تحفة فنية.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'gym practical',
      messages: ['عطر أروح بيه الجيم وميضايقش حد.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'franco university request',
      messages: ['3awez 3etr fresh w rkhis lel gam3a'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'slang loud cheap request',
      messages: ['عايز برفان فواح يجيب آخر الشارع وسعره حنين.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'office daily',
      messages: ['عطر للـ Office استخدمه كل يوم.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'university all day',
      messages: ['أنا طالب جامعة وعايز عطر يقعد معايا طول اليوم.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'hot campus day',
      messages: ['عندي يوم طويل جدًا في الحرم الجامعي، عايز حاجة تستحمل الحر.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'important interview',
      messages: ['عندي انترفيو مهم بكرة في شركة كبيرة، عايز ريحة تبين إني بروفيشنال ومش مزعجة.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'date night',
      messages: ['عايز عطر لـ Date night مسائي.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'bedtime calm scent',
      messages: ['عايز عطر هادي جدًا ومريح للأعصاب أحطه قبل ما أنام.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'heavy workout savior',
      messages: ['بلعب حديد وبشيل أوزان تقيلة وبعرق كتير، إيه اللي ينقذني؟'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'luxury tiny budget',
      messages: ['عايز عطر أمراء وملوك بسعر 100 جنيه.'],
      mustContainAny: ['غير واقعي', 'غير متاح', 'not realistic'],
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'mixed language localization',
      messages: ['محتاج عطر sweet للـ date night يكون long lasting.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'lighter follow up',
      messages: ['رشحلي عطر شتوي', 'هات حاجة أهدى شوية.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'regression refine after recommendation without gender re-ask',
      messages: [
        'رجالي',
        'صيفي',
        'رجالي قويه هادئة صيفي ليمون ومن غير عود',
      ],
      minRecommendationCount: 1,
      mustNotContain: [
        'هل تبحث عن عطر رجالي أم نسائي؟',
        'رجالي أم نسائي',
      ],
    ),
    const _Scenario(
      id: 'greeting then full freeform no downgrade',
      messages: [
        'أهلا',
        'عايز عطر رجالي صيفي فريش وميزانيتي 2500',
      ],
      minRecommendationCount: 1,
      mustNotContain: [
        'هل تبحث عن عطر رجالي أم نسائي؟',
        'رجالي أم نسائي',
      ],
    ),
    const _Scenario(
      id: 'modifier chain stability',
      messages: [
        'هات عطر.',
        'خليه أقوى.',
        'لا خليه أرخص.',
        'خليه سويت أكتر.',
        'رجع القوة زي الأول.',
      ],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'typo heavy arabic',
      messages: ['عيظ عتر رجلي رخيس وحلو.'],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'long wall of text with clear tail',
      messages: [
        'أنا بقالي فترة بدور على حاجة مناسبة لروتين يومي طويل جدًا، وبصراحة جرّبت حاجات كتير وكانت يا إما تقيلة أو مزعجة أو سعرها مش مناسب، وكمان أنا بروح الجامعة وبعدها بقعد وقت طويل برة البيت وفي الجو الحر بتختفي الريحة بسرعة، وفي نفس الوقت مش عايز حاجة تخنق اللي حواليا أو تبقى لافتة زيادة عن اللزوم. المهم في النهاية عايز عطر fresh ورخيص للجامعة ويستحمل الحر.',
      ],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
    const _Scenario(
      id: 'long wall of text exact strategic case',
      messages: [
        'أنا من زمان بحب الروائح الهادية لكن ساعات بحس إن العطور الثقيلة بتضايقني، ودايمًا وأنا رايح الشغل أو الجامعة ببقى محتار أختار إيه لأن الجو ساعات بيكون حر وساعات برد، وكمان بحب يكون في العطر لمسة أنيقة من غير ما يبقى ملفت زيادة عن اللزوم، وبصراحة جرّبت قبل كده كذا حاجة وكانت يا إما غالية أو مش ثابتة أو فيها ليمون زيادة عن اللزوم وأنا مش بحب الليمون قوي، وفي النهاية أنا محتاج منك ترشحلي عطر عملي شيك وثابت وتحت 1500 جنيه.',
      ],
      minRecommendationCount: 1,
      mustNotContain: ['هل تبحث عن عطر رجالي أم نسائي؟'],
    ),
  ];

  testWidgets('AI chat conversational fix regression pack', (
    WidgetTester tester,
  ) async {
    await launchAppAndOpenChat(tester);

    for (final scenario in scenarios) {
      await runScenario(tester, scenario);
    }
  });
}
