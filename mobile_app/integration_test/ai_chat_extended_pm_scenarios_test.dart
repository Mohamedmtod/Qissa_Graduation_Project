import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/recommended_product_card.dart';
import 'package:perfume_app/main.dart' as app;

class ExtendedScenarioCase {
  const ExtendedScenarioCase({
    required this.id,
    required this.category,
    required this.messages,
  });

  final String id;
  final String category;
  final List<String> messages;
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

    debugPrint('[AI-PM-EXT] Sending message: $text');
    expect(
      textFieldFinder,
      findsOneWidget,
      reason: 'The test must type into the chat message box.',
    );

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

    final visibleTexts = await collectVisibleTexts(tester);
    debugPrint('[AI-PM-EXT] Visible texts after response: $visibleTexts');
  }

  Future<void> startNewChat(WidgetTester tester) async {
    final refreshIcon = find.byIcon(Icons.refresh);
    if (refreshIcon.evaluate().isEmpty) return;

    await tester.tap(refreshIcon, warnIfMissed: false);
    await tester.pumpAndSettle();
    debugPrint('[AI-PM-EXT] Started new chat session');
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

  Future<void> runScenario(
    WidgetTester tester,
    ExtendedScenarioCase scenario,
  ) async {
    debugPrint('[AI-PM-EXT] Scenario start: ${scenario.id}');
    debugPrint('[AI-PM-EXT] Category: ${scenario.category}');
    await startNewChat(tester);

    for (final message in scenario.messages) {
      await sendChatMessage(tester, message);
    }

    final visibleTexts = await collectVisibleTexts(tester);
    final recommendationCount = find.byType(RecommendedProductCard).evaluate().length;

    debugPrint('[AI-PM-EXT] Scenario final visible texts: $visibleTexts');
    debugPrint('[AI-PM-EXT] Recommendation card count: $recommendationCount');
    debugPrint('[AI-PM-EXT] Scenario end: ${scenario.id}');
  }

  final scenarios = <ExtendedScenarioCase>[
    const ExtendedScenarioCase(
      id: 'EX01 clear direct request',
      category: 'Happy Path & Core Intents',
      messages: ['عايز عطر رجالي صيفي منعش.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX02 women rose vanilla',
      category: 'Happy Path & Core Intents',
      messages: ['محتاجة عطر نسائي بريحة الورد والفانيليا.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX03 unisex casual',
      category: 'Happy Path & Core Intents',
      messages: ['عايز عطر للجنسين ينفع خروجات عادية.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX04 winter oud amber',
      category: 'Happy Path & Core Intents',
      messages: ['عطر شتوي بالعود والعنبر.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX05 exact budget 1000',
      category: 'Budget & Upsell',
      messages: ['عايز عطر رجالي ميزانيتي 1000 جنيه بالظبط.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX06 transparent upsell 900 oud',
      category: 'Budget & Upsell',
      messages: ['عايز عطر عود ميزانيته 900 جنيه.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX07 impossible budget 150',
      category: 'Budget & Upsell',
      messages: ['عايز عطر ميزانيتي آخرها 150 جنيه.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX08 downshift under 700',
      category: 'Budget & Upsell',
      messages: ['رشحلي عطر شتوي', 'لا غالي، هات حاجة تحت 700.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX09 luxury no budget cap',
      category: 'Budget & Upsell',
      messages: ['عايز أفخم عطر عندكم بغض النظر عن السعر.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX10 explicit negation citrus',
      category: 'Negation & Constraints',
      messages: ['عايز عطر صيفي بس من غير أي ليمون أو حمضيات.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX11 headache avoid heavy',
      category: 'Negation & Constraints',
      messages: ['عايز عطر خفيف لأن العطور التقيلة بتعملي صداع.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX12 replace musk with sandalwood',
      category: 'Negation & Constraints',
      messages: ['هاتلي عطر بالمسك', 'شيل المسك وحط مكانه خشب صندل.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX13 aquatic with oud',
      category: 'Negation & Constraints',
      messages: ['عايز عطر مائي بس فيه عود.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX14 gym practical',
      category: 'Lifestyle & Practicality',
      messages: ['عطر أروح بيه الجيم وميضايقش حد.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX15 office daily',
      category: 'Lifestyle & Practicality',
      messages: ['عطر للـ Office استخدمه كل يوم.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX16 university all day',
      category: 'Lifestyle & Practicality',
      messages: ['أنا طالب جامعة وعايز عطر يقعد معايا طول اليوم.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX17 romantic date',
      category: 'Lifestyle & Practicality',
      messages: ['عايز عطر لـ Date night مسائي.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX18 gift for manager',
      category: 'Lifestyle & Practicality',
      messages: ['بدوّر على عطر هدية لمديري في الشغل، عمره 45 سنة.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX19 contradiction impossible',
      category: 'Graceful Degradation',
      messages: ['عايز عطر خفيف جداً ومابيتشمش بس يكون قوي جداً وبيملى المكان.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX20 fantasy notes',
      category: 'Graceful Degradation',
      messages: ['عندكم عطر بريحة الشاورما والتوم؟'],
    ),
    const ExtendedScenarioCase(
      id: 'EX21 luxury at 100',
      category: 'Graceful Degradation',
      messages: ['عايز عطر أمراء وملوك بسعر 100 جنيه.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX22 off topic football',
      category: 'Graceful Degradation',
      messages: ['إيه رأيك في ماتش الأهلي والزمالك؟'],
    ),
    const ExtendedScenarioCase(
      id: 'EX23 gibberish latin',
      category: 'Graceful Degradation',
      messages: ['asdfghjkl'],
    ),
    const ExtendedScenarioCase(
      id: 'EX24 gibberish arabic',
      category: 'Graceful Degradation',
      messages: ['شسيبلاتنم'],
    ),
    const ExtendedScenarioCase(
      id: 'EX25 radical memory switch',
      category: 'Memory & Flow',
      messages: ['عايز عطر رجالي', 'لا خليها نسائي أحسن.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX26 vague buy perfume',
      category: 'Memory & Flow',
      messages: ['عايز اشتري برفان.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX27 lighter follow-up',
      category: 'Memory & Flow',
      messages: ['رشحلي عطر شتوي', 'هات حاجة أهدى شوية.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX28 best seller open',
      category: 'Memory & Flow',
      messages: ['إيه أحسن عطر بيتباع عندكم؟'],
    ),
    const ExtendedScenarioCase(
      id: 'EX29 strict english',
      category: 'Localization',
      messages: ['I need a long-lasting woody perfume for winter.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX30 mixed arabic english',
      category: 'Localization',
      messages: ['محتاج عطر sweet للـ date night يكون long lasting.'],
    ),
    const ExtendedScenarioCase(
      id: 'EX31 language switch',
      category: 'Localization',
      messages: [
        'عايز عطر صيفي رجالي.',
        'خليه فيه فانيليا.',
        'Now answer me in English and make it lighter.',
      ],
    ),
  ];

  testWidgets('Extended PM AI chat scenarios with logs', (
    WidgetTester tester,
  ) async {
    debugPrint('[AI-PM-EXT] Test suite start: extended PM scenarios');
    await launchAppAndOpenChat(tester);

    for (final scenario in scenarios) {
      await runScenario(tester, scenario);
    }

    debugPrint('[AI-PM-EXT] Test suite end: extended PM scenarios');
  });
}
