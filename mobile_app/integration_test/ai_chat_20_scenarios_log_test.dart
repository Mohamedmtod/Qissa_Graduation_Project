import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/recommended_product_card.dart';
import 'package:perfume_app/main.dart' as app;

class _ScenarioCase {
  const _ScenarioCase({
    required this.id,
    required this.messages,
    this.expectedFragments = const <String>[],
    this.absentFragments = const <String>[],
    this.expectRecommendation = true,
  });

  final String id;
  final List<String> messages;
  final List<String> expectedFragments;
  final List<String> absentFragments;
  final bool? expectRecommendation;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder findChatMessageField() {
    return find.byKey(const ValueKey('ai_chat_message_input'));
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int maxSeconds = 10,
  }) async {
    for (int i = 0; i < maxSeconds * 10; i++) {
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

    debugPrint('[AI-IT] Sending message: $text');
    expect(
      textFieldFinder,
      findsOneWidget,
      reason: 'The test must type into the chat message box, not feedback.',
    );

    await tester.ensureVisible(textFieldFinder);
    await tester.tap(textFieldFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(textFieldFinder, text);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    await waitFor(
      tester,
      find.byType(CircularProgressIndicator),
      maxSeconds: 5,
    );
    await tester.pumpAndSettle(const Duration(seconds: 6));
    await waitFor(tester, textFieldFinder, maxSeconds: 20);

    final visibleTexts = await collectVisibleTexts(tester);
    debugPrint('[AI-IT] Visible texts after response: $visibleTexts');
  }

  Future<bool> dismissSessionFeedbackSheetIfPresent(WidgetTester tester) async {
    final rateSheet = find.textContaining('Rate This Session');
    final submitFeedback = find.textContaining('Submit Session Feedback');

    if (rateSheet.evaluate().isEmpty && submitFeedback.evaluate().isEmpty) {
      return false;
    }

    debugPrint('[AI-IT] Session feedback sheet detected, dismissing it');
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    if (rateSheet.evaluate().isNotEmpty ||
        submitFeedback.evaluate().isNotEmpty) {
      await tester.drag(rateSheet.first, const Offset(0, 400));
      await tester.pumpAndSettle();
    }
    return true;
  }

  Future<void> startNewChat(WidgetTester tester) async {
    final refreshIcon = find.byIcon(Icons.refresh);
    if (refreshIcon.evaluate().isNotEmpty) {
      await tester.tap(refreshIcon, warnIfMissed: false);
      await tester.pumpAndSettle();
      final dismissedFeedback = await dismissSessionFeedbackSheetIfPresent(
        tester,
      );

      if (dismissedFeedback) {
        await tester.tap(refreshIcon, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      debugPrint('[AI-IT] Started new chat session');
    }
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

    final emailFieldBase = find.byType(TextFormField);
    await waitFor(tester, emailFieldBase);

    if (emailFieldBase.evaluate().length >= 2) {
      await tester.enterText(emailFieldBase.first, 'm123m@mm.mmm');
      await tester.enterText(emailFieldBase.at(1), 'M123m@mm.mmm');
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

  Future<void> runScenario(WidgetTester tester, _ScenarioCase scenario) async {
    debugPrint('[AI-IT] Scenario start: ${scenario.id}');
    await startNewChat(tester);

    for (final message in scenario.messages) {
      await sendChatMessage(tester, message);
    }

    final visibleTexts = await collectVisibleTexts(tester);
    debugPrint('[AI-IT] Scenario final visible texts: $visibleTexts');

    if (scenario.expectRecommendation != null) {
      if (scenario.expectRecommendation!) {
        expect(
          find.byType(RecommendedProductCard),
          findsWidgets,
          reason: 'Expected recommendations for ${scenario.id}',
        );
      } else {
        expect(
          find.byType(RecommendedProductCard),
          findsNothing,
          reason: 'Did not expect recommendations for ${scenario.id}',
        );
      }
    }

    for (final fragment in scenario.expectedFragments) {
      expect(
        visibleTexts.any((text) => text.contains(fragment)),
        isTrue,
        reason: 'Expected fragment "$fragment" in ${scenario.id}',
      );
    }

    for (final fragment in scenario.absentFragments) {
      expect(
        visibleTexts.any((text) => text.contains(fragment)),
        isFalse,
        reason: 'Did not expect fragment "$fragment" in ${scenario.id}',
      );
    }

    debugPrint('[AI-IT] Scenario end: ${scenario.id}');
  }

  final scenarios = <_ScenarioCase>[
    const _ScenarioCase(
      id: 'S01 AR negation include',
      messages: ['رشحلي عطر صيفي رجالي مفيهوش عود بس فيه فانيليا'],
      expectedFragments: [
        'Men',
        'Season: صيفي',
        'Note: فانيليا',
        'Without: عود',
      ],
    ),
    const _ScenarioCase(
      id: 'S02 AR memory budget',
      messages: [
        'رشحلي عطر صيفي رجالي مفيهوش عود بس فيه فانيليا',
        'وفي حدود 1000',
      ],
      expectedFragments: [
        'Men',
        'Season: صيفي',
        'Note: فانيليا',
        'Without: عود',
        'Under 1000',
      ],
    ),
    const _ScenarioCase(
      id: 'S03 AR replace note',
      expectRecommendation: null,
      messages: ['عايز عطر فيه فانيليا', 'بلاش فانيليا خليه عود'],
      expectedFragments: ['Note: عود', 'Without: فانيليا'],
      absentFragments: ['Note: فانيليا'],
    ),
    const _ScenarioCase(
      id: 'S04 AR women rose',
      messages: ['عايزه عطر نسائي فيه ورد'],
      expectedFragments: ['Women', 'Note: ورد'],
    ),
    const _ScenarioCase(
      id: 'S05 AR last mention precedence',
      messages: ['كنت عايز صيفي بس دلوقتي عايز خريفي رجالي'],
      expectedFragments: ['Men', 'Season: خريفي'],
      absentFragments: ['Season: صيفي'],
    ),
    const _ScenarioCase(
      id: 'S06 AR night formal strong',
      messages: ['عايز عطر رجالي رسمي ليلي فواح'],
      expectedFragments: [
        'Men',
        'Occasion: رسمي',
        'Time: ليلي',
        'Intensity: قوي',
      ],
    ),
    const _ScenarioCase(
      id: 'S07 AR cheaper downshift',
      messages: ['عايز عطر رجالي بحد اقصى 1500', 'عايزه ارخص شوية'],
      expectedFragments: ['Men', 'Under 1500'],
    ),
    const _ScenarioCase(
      id: 'S08 AR vague then clarify',
      messages: ['عايز عطر حلو', 'رجالي وبحد اقصى 1000 ومنعش'],
      expectedFragments: ['Men', 'Under 1000'],
    ),
    const _ScenarioCase(
      id: 'S09 AR impossible no match',
      messages: ['عطر وردي فاكهي للجنسين مائي ب 50 جنيه'],
      expectedFragments: ['Unisex', 'Note: ورد', 'Note: فاكهي', 'Note: مائي'],
      expectRecommendation: null,
    ),
    const _ScenarioCase(
      id: 'S10 AR university all day',
      messages: ['عايز عطر رجالي للجامعة طول اليوم'],
      expectedFragments: ['Men', 'Occasion: جامعة', 'Time: طوال اليوم'],
    ),
    const _ScenarioCase(
      id: 'S11 EN summer budget',
      messages: ['I need a men summer perfume under 1200'],
      expectedFragments: ['Men', 'Season: Summer', 'Under 1200'],
    ),
    const _ScenarioCase(
      id: 'S12 EN vanilla without oud',
      messages: ['Recommend a men summer perfume without oud but with vanilla'],
      expectedFragments: [
        'Men',
        'Season: Summer',
        'Note: Vanilla',
        'Without: Oud',
      ],
    ),
    const _ScenarioCase(
      id: 'S13 EN last mention precedence',
      messages: ['I wanted summer but now autumn men perfume'],
      expectedFragments: ['Men', 'Season: Autumn'],
      absentFragments: ['Season: Summer'],
    ),
    const _ScenarioCase(
      id: 'S14 EN women rose',
      messages: ['I want a women perfume with rose'],
      expectedFragments: ['Women', 'Note: Rose'],
    ),
    const _ScenarioCase(
      id: 'S15 EN night formal strong',
      messages: ['I need a men formal night strong perfume'],
      expectedFragments: [
        'Men',
        'Occasion: Formal',
        'Time: Night',
        'Intensity: Strong',
      ],
    ),
    const _ScenarioCase(
      id: 'S16 EN cheaper downshift',
      messages: ['Men perfume under 1500', 'Make it cheaper'],
      expectedFragments: ['Men', 'Under 850'],
    ),
    const _ScenarioCase(
      id: 'S17 EN replace note',
      expectRecommendation: null,
      messages: ['I want vanilla perfume', 'Replace vanilla with oud'],
      expectedFragments: ['Note: Oud', 'Without: Vanilla'],
      absentFragments: ['Note: Vanilla'],
    ),
    const _ScenarioCase(
      id: 'S18 EN vague then clarify',
      messages: ['I want a nice perfume', 'Men under 1000 fresh'],
      expectedFragments: ['Men', 'Under 1000'],
    ),
    const _ScenarioCase(
      id: 'S19 EN office all day unisex',
      messages: ['I need a unisex office perfume for all day under 900'],
      expectedFragments: [
        'Unisex',
        'Occasion: Office',
        'Time: All Day',
        'Under 900',
      ],
    ),
    const _ScenarioCase(
      id: 'S20 EN woody instead of vanilla',
      expectRecommendation: true,
      messages: ['I need vanilla perfume', 'Instead make it woody'],
      expectedFragments: ['Note: Woody', 'Without: Vanilla'],
      absentFragments: ['Note: Vanilla'],
    ),
  ];

  testWidgets('AI Chat 20 strong scenarios with AI-only logs', (
    WidgetTester tester,
  ) async {
    debugPrint('[AI-IT] Test suite start: 20 strong scenarios');
    await launchAppAndOpenChat(tester);

    for (final scenario in scenarios) {
      await runScenario(tester, scenario);
    }

    debugPrint('[AI-IT] Test suite end: 20 strong scenarios');
  });

  testWidgets('AI Chat smoke through S08 after send fix', (
    WidgetTester tester,
  ) async {
    debugPrint('[AI-IT] Smoke test start: through S08');
    await launchAppAndOpenChat(tester);

    for (final scenario in scenarios.take(8)) {
      await runScenario(tester, scenario);
    }

    debugPrint('[AI-IT] Smoke test end: through S08');
  });

  testWidgets('AI Chat smoke tail S18 to S20', (WidgetTester tester) async {
    debugPrint('[AI-IT] Smoke test start: tail S18-S20');
    await launchAppAndOpenChat(tester);

    for (final scenario in scenarios.skip(17)) {
      await runScenario(tester, scenario);
    }

    debugPrint('[AI-IT] Smoke test end: tail S18-S20');
  });
}
