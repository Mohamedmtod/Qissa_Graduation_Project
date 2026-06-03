import 'package:firebase_auth/firebase_auth.dart';
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

  const bypassAuthInTests = bool.fromEnvironment(
    'AI_CHAT_BYPASS_AUTH',
    defaultValue: true,
  );

  Finder findChatMessageField() {
    final keyed = find.byKey(const ValueKey('ai_chat_message_input'));
    if (keyed.evaluate().isNotEmpty) return keyed.first;
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

  Future<bool> dismissSessionFeedbackSheetIfPresent(WidgetTester tester) async {
    final rateSheet = find.byKey(const ValueKey('ai_chat_feedback_sheet'));
    final submitFeedback = find.byKey(
      const ValueKey('ai_chat_feedback_submit_button'),
    );
    if (rateSheet.evaluate().isEmpty && submitFeedback.evaluate().isEmpty) {
      return false;
    }

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    if (rateSheet.evaluate().isNotEmpty) {
      await tester.drag(rateSheet.first, const Offset(0, 400));
      await tester.pumpAndSettle();
    }
    return true;
  }

  Future<void> sendChatMessage(WidgetTester tester, String text) async {
    final textFieldFinder = findChatMessageField();

    debugPrint('[AI-IT2] Sending message: $text');
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

    for (var i = 0; i < 1200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final loadingGone = find
          .byType(CircularProgressIndicator)
          .evaluate()
          .isEmpty;
      final inputVisible = textFieldFinder.evaluate().isNotEmpty;
      if (loadingGone && inputVisible) break;
    }

    final visibleTexts = await collectVisibleTexts(tester);
    debugPrint('[AI-IT2] Visible texts after response: $visibleTexts');
  }

  Future<void> startNewChat(WidgetTester tester) async {
    await dismissSessionFeedbackSheetIfPresent(tester);
    await waitFor(tester, findChatMessageField(), maxSeconds: 20);
    debugPrint('[AI-IT2] Started new chat session');
  }

  Future<void> launchAppAndOpenChat(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    if (bypassAuthInTests) {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        await auth.signOut();
        await tester.pumpAndSettle();
      }
      final guestButton = find.byKey(
        const ValueKey('welcome_browse_guest_button'),
      );
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton.last, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    } else {
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
    }

    final aiTab = find.byKey(const ValueKey('nav_tab_2'));
    if (aiTab.evaluate().isNotEmpty) {
      await tester.tap(aiTab.last, warnIfMissed: false);
      await tester.pumpAndSettle();
    } else if (find.text('AI').evaluate().isNotEmpty) {
      await tester.tap(find.text('AI').last, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await waitFor(tester, findChatMessageField(), maxSeconds: 30);
  }

  Future<void> runScenario(WidgetTester tester, _ScenarioCase scenario) async {
    debugPrint('[AI-IT2] Scenario start: ${scenario.id}');
    await startNewChat(tester);

    for (final message in scenario.messages) {
      await sendChatMessage(tester, message);
    }

    final visibleTexts = await collectVisibleTexts(tester);
    debugPrint('[AI-IT2] Scenario final visible texts: $visibleTexts');

    if (scenario.expectRecommendation != null) {
      if (scenario.expectRecommendation!) {
        if (find.byType(RecommendedProductCard).evaluate().isEmpty) {
          debugPrint(
            '[AI-IT2][ISSUE] Expected recommendations for ${scenario.id}',
          );
        }
      } else {
        if (find.byType(RecommendedProductCard).evaluate().isNotEmpty) {
          debugPrint(
            '[AI-IT2][ISSUE] Did not expect recommendations for ${scenario.id}',
          );
        }
      }
    }

    for (final fragment in scenario.expectedFragments) {
      if (!visibleTexts.any((text) => text.contains(fragment))) {
        debugPrint(
          '[AI-IT2][ISSUE] Expected fragment "$fragment" in ${scenario.id}',
        );
      }
    }

    for (final fragment in scenario.absentFragments) {
      if (visibleTexts.any((text) => text.contains(fragment))) {
        debugPrint(
          '[AI-IT2][ISSUE] Did not expect fragment "$fragment" in ${scenario.id}',
        );
      }
    }

    debugPrint('[AI-IT2] Scenario end: ${scenario.id}');
  }

  final scenarios = <_ScenarioCase>[
    const _ScenarioCase(
      id: 'D01 EN men summer under 1200',
      messages: ['I need a men summer perfume under 1200'],
      expectedFragments: ['Men', 'Season: Summer', 'Under 1200'],
    ),
    const _ScenarioCase(
      id: 'D02 EN vanilla without oud',
      messages: ['Recommend a men summer perfume without oud but with vanilla'],
      expectedFragments: [
        'Men',
        'Season: Summer',
        'Note: Vanilla',
        'Without: Oud',
      ],
    ),
    const _ScenarioCase(
      id: 'D03 EN women rose day',
      messages: ['I want a women day perfume with rose'],
      expectedFragments: ['Women', 'Note: Rose'],
    ),
    const _ScenarioCase(
      id: 'D04 EN formal night strong',
      messages: ['I need a men formal night strong perfume'],
      expectedFragments: [
        'Men',
        'Occasion: Formal',
        'Time: Night',
        'Intensity: Strong',
      ],
    ),
    const _ScenarioCase(
      id: 'D05 EN office all day under 1500',
      messages: ['Recommend a unisex office perfume for all day under 1500'],
      expectedFragments: [
        'Unisex',
        'Occasion: Office',
        'Time: All Day',
        'Under 1500',
      ],
    ),
    const _ScenarioCase(
      id: 'D06 EN cheaper follow up',
      messages: ['Men perfume under 1500', 'Make it cheaper'],
      expectedFragments: ['Men', 'Under 1200'],
      absentFragments: ['Under 1500'],
    ),
    const _ScenarioCase(
      id: 'D07 EN replace vanilla with oud',
      messages: ['I want vanilla perfume', 'Replace vanilla with oud'],
      expectedFragments: ['Note: Oud', 'Without: Vanilla'],
      absentFragments: ['Note: Vanilla'],
      expectRecommendation: null,
    ),
    const _ScenarioCase(
      id: 'D08 EN woody instead of vanilla',
      messages: ['I need vanilla perfume', 'Instead make it woody'],
      expectedFragments: ['Note: Woody', 'Without: Vanilla'],
      absentFragments: ['Note: Vanilla'],
      expectRecommendation: null,
    ),
    const _ScenarioCase(
      id: 'D09 EN last mention season',
      messages: ['I wanted summer but now autumn men perfume'],
      expectedFragments: ['Men', 'Season: Autumn'],
      absentFragments: ['Season: Summer'],
    ),
    const _ScenarioCase(
      id: 'D10 EN vague then clarify fresh',
      messages: ['I want a nice perfume', 'Men under 1000 fresh'],
      expectedFragments: ['Men', 'Under 1000', 'Vibe: Fresh'],
    ),
    const _ScenarioCase(
      id: 'D11 EN impossible ultra cheap',
      messages: ['I need a unisex aquatic fruity perfume under 50'],
      expectedFragments: ['Unisex', 'Under 50'],
      expectRecommendation: null,
    ),
    const _ScenarioCase(
      id: 'D12 EN gym fresh under 900',
      messages: ['Recommend a fresh gym perfume for men under 900'],
      expectedFragments: ['Men', 'Vibe: Fresh', 'Under 900'],
    ),
    const _ScenarioCase(
      id: 'D13 EN date sweet night',
      messages: ['I want a sweet men perfume for date night'],
      expectedFragments: ['Men', 'Occasion: Date', 'Time: Night'],
    ),
    const _ScenarioCase(
      id: 'D14 EN winter woody men',
      messages: ['Suggest a woody winter perfume for men'],
      expectedFragments: ['Men', 'Season: Winter', 'Note: Woody'],
    ),
    const _ScenarioCase(
      id: 'D15 EN add budget later',
      messages: [
        'I want a men summer perfume with vanilla',
        'Keep it under 1000',
      ],
      expectedFragments: [
        'Men',
        'Season: Summer',
        'Note: Vanilla',
        'Under 1000',
      ],
    ),
    const _ScenarioCase(
      id: 'D16 EN no floral but musky',
      messages: ['I want a men perfume that is musky but not floral'],
      expectedFragments: ['Men', 'Note: Musk', 'Without: Floral'],
    ),
    const _ScenarioCase(
      id: 'D17 EN unisex office all day under 900',
      expectRecommendation: null,
      messages: ['I need a unisex office perfume for all day under 900'],
      expectedFragments: [
        'Unisex',
        'Occasion: Office',
        'Time: All Day',
        'Under 900',
      ],
    ),
    const _ScenarioCase(
      id: 'D18 EN university all day men',
      messages: ['Recommend a men perfume for university all day'],
      expectedFragments: ['Men', 'Occasion: University', 'Time: All Day'],
    ),
    const _ScenarioCase(
      id: 'D19 EN casual autumn under 1000',
      messages: ['I need a casual autumn perfume for men under 1000'],
      expectedFragments: [
        'Men',
        'Occasion: Casual',
        'Season: Autumn',
        'Under 1000',
      ],
    ),
    const _ScenarioCase(
      id: 'D20 EN stronger follow up',
      messages: ['Recommend a light men perfume', 'Make it stronger'],
      expectedFragments: ['Men', 'Intensity: Light'],
      expectRecommendation: null,
    ),
  ];

  testWidgets('AI Chat 20 distinct scenarios with logs', (
    WidgetTester tester,
  ) async {
    debugPrint('[AI-IT2] Test suite start: 20 distinct scenarios');
    await launchAppAndOpenChat(tester);

    for (final scenario in scenarios) {
      await runScenario(tester, scenario);
    }

    debugPrint('[AI-IT2] Test suite end: 20 distinct scenarios');
  });
}
