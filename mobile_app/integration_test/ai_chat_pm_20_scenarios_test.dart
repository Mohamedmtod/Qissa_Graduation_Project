import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/recommended_product_card.dart';
import 'package:perfume_app/main.dart' as app;

class PMScenarioCase {
  const PMScenarioCase({
    required this.id,
    required this.category,
    required this.messages,
    this.expectedRecommendation,
  });

  final String id;
  final String category;
  final List<String> messages;
  final bool? expectedRecommendation;
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

    debugPrint('[AI-PM20] Sending message: $text');
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
    debugPrint('[AI-PM20] Visible texts after response: $visibleTexts');
  }

  Future<void> startNewChat(WidgetTester tester) async {
    await dismissSessionFeedbackSheetIfPresent(tester);
    await waitFor(tester, findChatMessageField(), maxSeconds: 20);
    debugPrint('[AI-PM20] Started new chat session');
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

  Future<void> runScenario(WidgetTester tester, PMScenarioCase scenario) async {
    debugPrint('[AI-PM20] Scenario start: ${scenario.id}');
    debugPrint('[AI-PM20] Category: ${scenario.category}');
    await startNewChat(tester);

    for (final message in scenario.messages) {
      await sendChatMessage(tester, message);
    }

    final visibleTexts = await collectVisibleTexts(tester);
    final recommendationCount = find
        .byType(RecommendedProductCard)
        .evaluate()
        .length;

    debugPrint('[AI-PM20] Scenario final visible texts: $visibleTexts');
    debugPrint('[AI-PM20] Recommendation card count: $recommendationCount');

    if (scenario.expectedRecommendation != null) {
      debugPrint(
        '[AI-PM20] Expected recommendation? ${scenario.expectedRecommendation} | actual cards: $recommendationCount',
      );
    }

    expect(findChatMessageField(), findsOneWidget);
    debugPrint('[AI-PM20] Scenario end: ${scenario.id}');
  }

  final scenarios = <PMScenarioCase>[
    const PMScenarioCase(
      id: 'PM01 direct request',
      category: 'Happy Path',
      messages: ['عايز عطر رجالي للصيف يكون منعش.'],
    ),
    const PMScenarioCase(
      id: 'PM02 note selection',
      category: 'Happy Path',
      messages: ['محتاج عطر نسائي فيه ريحة ورد وياسمين.'],
    ),
    const PMScenarioCase(
      id: 'PM03 general preference',
      category: 'Happy Path',
      messages: ['عايز عطر Unisex ينفع استخدام يومي.'],
    ),
    const PMScenarioCase(
      id: 'PM04 strict budget university',
      category: 'Hard Constraints',
      messages: ['عايز عطر للجامعة ميزانيتي آخرها 800 جنيه.'],
    ),
    const PMScenarioCase(
      id: 'PM05 impossible luxury under 200',
      category: 'Hard Constraints',
      messages: ['عايز أفخم عطر عود ملوكي عندكم وتكون ميزانيته تحت 200 جنيه.'],
    ),
    const PMScenarioCase(
      id: 'PM06 strict negation no oud no wood',
      category: 'Hard Constraints',
      messages: ['رشحلي عطر شتوي بس من غير أي ريحة عود أو خشب نهائي.'],
    ),
    const PMScenarioCase(
      id: 'PM07 exact budget 1500',
      category: 'Hard Constraints',
      messages: ['معايا 1500 جنيه بالظبط، إيه أحسن خيار؟'],
    ),
    const PMScenarioCase(
      id: 'PM08 gym practical',
      category: 'Lifestyle & Vibes',
      messages: ['محتاج عطر أروح بيه الجيم وميخنقش اللي جنبي.'],
    ),
    const PMScenarioCase(
      id: 'PM09 date night',
      category: 'Lifestyle & Vibes',
      messages: ['عايز عطر Date night يكون جذاب ومسائي.'],
    ),
    const PMScenarioCase(
      id: 'PM10 gift for father',
      category: 'Lifestyle & Vibes',
      messages: [
        'عايز عطر هدية لوالدي في عيد ميلاده، هو بيحب الحاجات الكلاسيك.',
      ],
    ),
    const PMScenarioCase(
      id: 'PM11 last mention precedence',
      category: 'Conversational Memory',
      messages: ['عايز عطر صيفي.', 'لا غيّر رأيي، خليه شتوي أحسن.'],
    ),
    const PMScenarioCase(
      id: 'PM12 refining cheaper than 1000',
      category: 'Conversational Memory',
      messages: ['رشحلي عطر بالعود.', 'طيب هاتلي حاجة منهم أرخص من 1000 جنيه.'],
    ),
    const PMScenarioCase(
      id: 'PM13 replace vanilla with musk',
      category: 'Conversational Memory',
      messages: [
        'عايز عطر رسمي فيه فانيليا.',
        'شيل الفانيليا خالص وحط مكانها مسك.',
      ],
    ),
    const PMScenarioCase(
      id: 'PM14 very vague',
      category: 'Conversational Flow',
      messages: ['عايز عطر حلو.'],
    ),
    const PMScenarioCase(
      id: 'PM15 best perfume open question',
      category: 'Conversational Flow',
      messages: ['إيه أحسن عطر عندكم في المحل؟'],
    ),
    const PMScenarioCase(
      id: 'PM16 contradictory request',
      category: 'Conversational Flow',
      messages: [
        'عايز عطر رجالي ونسائي في نفس الوقت، يكون خفيف جداً بس ريحته قوية جداً.',
      ],
    ),
    const PMScenarioCase(
      id: 'PM17 off-topic iphone',
      category: 'Edge Cases & Localization',
      messages: ['تليفوني الآيفون باظ، أعمل إيه؟'],
    ),
    const PMScenarioCase(
      id: 'PM18 english woody under 1500',
      category: 'Edge Cases & Localization',
      messages: ['I need a woody perfume for men under 1500 EGP.'],
    ),
    const PMScenarioCase(
      id: 'PM19 franco mixed language',
      category: 'Edge Cases & Localization',
      messages: ['عايز عطر sweet للـ office يكون long lasting.'],
    ),
    const PMScenarioCase(
      id: 'PM20 imaginary shawarma watermelon',
      category: 'Edge Cases & Localization',
      messages: ['عايز عطر بريحة البطيخ المالح والشاورما.'],
    ),
  ];

  testWidgets('PM 20 AI chat scenarios with logs', (WidgetTester tester) async {
    debugPrint('[AI-PM20] Test suite start: 20 PM scenarios');
    await launchAppAndOpenChat(tester);

    for (final scenario in scenarios) {
      await runScenario(tester, scenario);
    }

    debugPrint('[AI-PM20] Test suite end: 20 PM scenarios');
  });
}
