import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/recommended_product_card.dart';
import 'package:perfume_app/main.dart' as app;

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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Helper to wait for a widget
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

  /// Sends a text message to the AI Chat.
  Future<void> sendChatMessage(WidgetTester tester, String text) async {
    final textFieldFinder = findChatMessageField();
    final sendButtonFinder = find.byIcon(Icons.send_rounded);

    debugPrint('[AI-IT] Sending message: $text');
    expect(
      textFieldFinder,
      findsOneWidget,
      reason: 'The test must type into the chat message box, not feedback.',
    );

    await tester.enterText(textFieldFinder, text);
    await tester.pumpAndSettle(); // Wait for text
    await tester.tap(sendButtonFinder);

    // Wait for AI response (network + model latency can vary).
    await waitFor(
      tester,
      find.byType(CircularProgressIndicator),
      maxSeconds: 5,
    );
    await tester.pumpAndSettle(const Duration(seconds: 6));
    await waitFor(tester, sendButtonFinder, maxSeconds: 20);
    final visibleTexts = find
        .byType(Text)
        .evaluate()
        .map((element) => element.widget)
        .whereType<Text>()
        .map((widget) => widget.data?.trim())
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .take(20)
        .toList();
    debugPrint('[AI-IT] Visible texts after response: $visibleTexts');
    debugPrint('[AI-IT] Response completed for message: $text');
  }

  /// Clears the chat session to simulate a 'New Chat'.
  Future<void> startNewChat(WidgetTester tester) async {
    final refreshIcon = find.byIcon(Icons.refresh);
    if (refreshIcon.evaluate().isNotEmpty) {
      await tester.tap(refreshIcon);
      await tester.pumpAndSettle();
    }
  }

  /// Boilerplate to start the app, get through splash, login, and open AI Chat
  Future<void> launchAppAndOpenChat(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Wait for app to be ready (either Welcome or MainLayout)
    await tester.pump(const Duration(seconds: 2));

    // 1. Check if we are on Welcome Page by looking for "Log in" text
    final welcomeLoginBtn = find.text('Log in');
    if (welcomeLoginBtn.evaluate().isNotEmpty) {
      await tester.tap(welcomeLoginBtn.last);
      await tester.pumpAndSettle();
    }

    // 2. We should be on LoginPage now (wait for Email field)
    final emailFieldBase = find.byType(TextFormField);
    await waitFor(tester, emailFieldBase);

    if (emailFieldBase.evaluate().length >= 2) {
      final emailField = emailFieldBase.first;
      await tester.enterText(emailField, 'm123m@mm.mmm');

      final passField = emailFieldBase.at(1);
      await tester.enterText(passField, 'M123m@mm.mmm');
      await tester.pumpAndSettle();

      // Tap login submit button
      final submitLogin = find.text('Log in').last;
      await tester.tap(submitLogin);

      // Wait for Firebase Auth network request to finish (wait for 'AI' tab to appear)
      final aiTab = find.text('AI');
      await waitFor(tester, aiTab);
    }

    // 3. We are on MainLayout. Tap the 'AI' bottom nav icon
    final aiTab = find.text('AI');
    if (aiTab.evaluate().isNotEmpty) {
      await tester.tap(aiTab.last); // Tap the last one to resolve ambiguity
      await tester.pumpAndSettle();
    }
  }

  // ===========================================================================
  // ARABIC SCENARIOS (AR-01 to AR-10)
  // ===========================================================================

  group('AI Chat Arabic Scenarios', () {
    testWidgets('AR-00 - Colloquial negation plus memory accumulation', (
      WidgetTester tester,
    ) async {
      debugPrint('[AI-IT] Scenario start: AR-00');
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(
        tester,
        'رشحلي عطر صيفي رجالي مفيهوش عود بس فيه فانيليا',
      );
      expect(find.byType(RecommendedProductCard), findsWidgets);

      await sendChatMessage(tester, 'وفي حدود 1000');
      expect(find.byType(RecommendedProductCard), findsWidgets);
      debugPrint('[AI-IT] Scenario end: AR-00');
    });
    testWidgets('AR-01 (New Chat) - ترشيح طبيعي', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عايز عطر رجالي صيفي فريش بحد اقصى 1200');

      // Verify recommendations appeared
      expect(find.textContaining('رجالي'), findsWidgets);
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('AR-02 & AR-03 - رسالة غامضة ثم إكمال السؤال', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      // AR-02: Vague input
      await sendChatMessage(tester, 'عايز عطر حلو');

      // Bot should ask a clarifying question, no cards yet
      expect(find.byType(Card), findsNothing);

      // AR-03: Continue on same chat
      await sendChatMessage(tester, 'رجالي وبحد اقصى 1000 وعايزه منعش');

      // Now it should recommend
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('AR-04 & AR-05 - متابعة باسم منتج وبالضمير', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      // Trigger recommendation first
      await sendChatMessage(tester, 'عايز عطر صيفي ب 1000');

      // AR-04: Ask by product name
      await sendChatMessage(tester, 'قولي اكتر عن Campus Citrus Drive');
      expect(find.textContaining('Campus'), findsWidgets);

      // AR-05: Ask using pronoun 'it' indicating context continuation
      await sendChatMessage(tester, 'هل ينفع للجامعة؟');
      // Verify app didn't crash and text was rendered
      expect(find.textContaining('الجامعة'), findsWidgets);
    });

    testWidgets('AR-06 - مقارنة بالترتيب', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عطر رجالي ب 1500');
      await sendChatMessage(tester, 'قارن بين الاول والثاني');

      // Output should answer with a comparison
      expect(
        find.byType(Card),
        findsWidgets,
      ); // previous cards still exist usually
    });

    testWidgets('AR-07 - مقارنة بالأسماء', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عطر رجالي ب 1500');
      await sendChatMessage(
        tester,
        'قارن بين Campus Citrus Drive و Cedar Class 01',
      );
      // Should handle explicit names resolution
    });

    testWidgets('AR-08 - استبدال نوتة', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عايز عطر فيه فانيليا');
      await sendChatMessage(tester, 'بدال الفانيليا خليها خشب');

      // Ensure 'خشب' (Woody) tag is present
      expect(find.textContaining('خشب'), findsWidgets);
    });

    testWidgets('AR-09 - طلب أرخص (Budget downshift)', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عايز عطر رجالي بحد اقصى 1500');
      await sendChatMessage(tester, 'عايزه ارخص شوية');

      // The budget preference should shrink, checking for numbers below 1500
      expect(find.textContaining('حتى 1500'), findsNothing);
    });

    testWidgets('AR-10 - حماية false positives (with vs it)', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عطر صيفي رجالي');
      await sendChatMessage(tester, 'I want something with vanilla');

      // Shouldn't crash or confuse 'with' as a pronoun for comparison
    });

    testWidgets('AR-12 - آخر ذكر يفوز في الـ Parser', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'كنت عايز صيفي بس دلوقتي عايز خريفي');

      // Verify autumn chip is present and summer chip is NOT present
      expect(find.textContaining('خريف'), findsWidgets);
      expect(find.textContaining('صيف'), findsNothing);
    });

    testWidgets('AR-13 - فلتر الجندر الصارم', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عايزة عطر نسائي فيه ورد');

      // Recommendations should not include any male-only perfumes.
      // E.g. 'رجالي' chip or text shouldn't be in the new cards
      expect(find.textContaining('رجالي'), findsNothing);
    });

    testWidgets('AR-14 & AR-15 - متابعة بالاسم والضمير', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عطر رجالي صيفي بحد أقصى 1200');

      // Generic follow up that should be handled as answer not recommend
      await sendChatMessage(tester, 'قولي أكتر عن الأول');

      // Follow up with pronoun in same context
      await sendChatMessage(tester, 'هل ينفع للجامعة؟');

      // App should not crash and should render bot answers
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('AR-16 & AR-17 - متابعة بالترتيب (الأول، الأخير)', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عطر رجالي صيفي بحد أقصى 1200');
      await sendChatMessage(tester, 'قولي أكتر عن الأول');
      await sendChatMessage(tester, 'اعرفني اكتر عن الأخير');
    });

    testWidgets('AR-18 - حماية False Positive (مع)', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عطر رجالي صيفي');
      await sendChatMessage(tester, 'عايز حاجة مع فانيليا');

      // This should trigger a new recommendation, thus adding 'فانيليا' to preferences
      expect(find.textContaining('فانيليا'), findsWidgets);
    });

    testWidgets('AR-19 & AR-20 - المقارنة', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عطر رجالي صيفي');
      await sendChatMessage(tester, 'قارن بين الأول والتاني');
    });

    testWidgets('AR-22 - لا توجد نتائج noMatch', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'عطر وردي فاكهي للجنسين مائي بـ 50 جنيه');

      // This should return a generic "please adjust budget/notes" text
      // without formatting it as a red error (so no "رسالة تنبيهية" error title)
      expect(find.textContaining('رسالة تنبيهية'), findsNothing);
    });
  });

  // ===========================================================================
  // ENGLISH SCENARIOS (EN-01 to EN-10)
  // ===========================================================================

  group('AI Chat English Scenarios', () {
    testWidgets('EN-01 (New Chat) - Standard Recommendation', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(
        tester,
        'I need a fresh men summer perfume under 1200',
      );

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets(
      'EN-02 & EN-03 - Vague Input -> Bot asks first -> Clarification',
      (WidgetTester tester) async {
        await launchAppAndOpenChat(tester);
        await startNewChat(tester);

        // EN-02
        await sendChatMessage(tester, 'I want a nice perfume');
        expect(find.byType(Card), findsNothing); // Should ask, not recommend

        // EN-03
        await sendChatMessage(tester, 'Men, budget 1000, fresh and clean');
        expect(find.byType(Card), findsWidgets);
      },
    );

    testWidgets('EN-04 & EN-05 - Follow-up by Product Name & Pronoun', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(
        tester,
        'I need a fresh men summer perfume under 1200',
      );

      // EN-04
      await sendChatMessage(tester, 'Tell me more about Campus Citrus Drive');

      // EN-05
      await sendChatMessage(tester, 'Is it good for university?');
    });

    testWidgets('EN-06 - Compare by Order', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'Perfume for men under 1500');
      await sendChatMessage(tester, 'Compare first and second');
    });

    testWidgets('EN-07 - Compare by Explicit Names', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'Perfume for men under 1500');
      await sendChatMessage(
        tester,
        'Compare Campus Citrus Drive and Cedar Class 01',
      );
    });

    testWidgets('EN-08 - Note Replacement Logic', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'I want vanilla notes');
      await sendChatMessage(tester, 'Replace vanilla with woody notes');

      expect(find.textContaining('woody'), findsWidgets);
    });

    testWidgets('EN-09 - Cheaper Request', (WidgetTester tester) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'Men perfume under 1500');
      await sendChatMessage(tester, 'Make it cheaper');

      expect(find.textContaining('Under 1500'), findsNothing);
    });

    testWidgets('EN-10 - False Positive Guard (with vs it)', (
      WidgetTester tester,
    ) async {
      await launchAppAndOpenChat(tester);
      await startNewChat(tester);

      await sendChatMessage(tester, 'Fresh summer perfume');
      await sendChatMessage(tester, 'I want something with vanilla');
    });
  });
}
