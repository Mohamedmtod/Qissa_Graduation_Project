import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/chat_message_bubble.dart';
import 'package:perfume_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const bypassAuthInTests = bool.fromEnvironment(
    'AI_CHAT_BYPASS_AUTH',
    defaultValue: true,
  );
  const testEmail = String.fromEnvironment(
    'AI_CHAT_TEST_EMAIL',
    defaultValue: 'm123m@mm.mmm',
  );
  const testPassword = String.fromEnvironment(
    'AI_CHAT_TEST_PASSWORD',
    defaultValue: 'M123m@mm.mmm',
  );

  Finder chatInput() {
    final keyed = find.byKey(const ValueKey('ai_chat_message_input'));
    if (keyed.evaluate().isNotEmpty) return keyed.first;
    return find
        .byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.textInputAction == TextInputAction.send &&
              widget.maxLines == 4,
          description: 'AI chat input',
        )
        .first;
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int maxSeconds = 20,
  }) async {
    for (var i = 0; i < maxSeconds * 10; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
  }

  AIChatMessage? lastBotMessage() {
    final messages = find
        .byType(ChatMessageBubble)
        .evaluate()
        .map((element) => element.widget)
        .whereType<ChatMessageBubble>()
        .map((bubble) => bubble.message)
        .where((message) => message.isFromBot && !message.isLoading)
        .toList();
    if (messages.isEmpty) return null;
    return messages.last;
  }

  Future<void> bootstrapAuthAndOpenChat(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    final auth = FirebaseAuth.instance;
    if (bypassAuthInTests) {
      if (auth.currentUser != null) await auth.signOut();
      await tester.pumpAndSettle();
      final guestButton = find.byKey(
        const ValueKey('welcome_browse_guest_button'),
      );
      if (guestButton.evaluate().isNotEmpty) {
        await tester.tap(guestButton.last, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    } else if (auth.currentUser == null) {
      await auth.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
      await tester.pumpAndSettle();
    }

    final aiTab = find.byKey(const ValueKey('nav_tab_2'));
    await waitFor(tester, aiTab);
    await tester.tap(aiTab.last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await waitFor(tester, chatInput());
  }

  Future<void> sendProbeMessage(WidgetTester tester) async {
    final input = chatInput();
    final previousBubbleCount = find.byType(ChatMessageBubble).evaluate().length;
    await tester.ensureVisible(input);
    await tester.tap(input, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      input,
      'Recommend a light summer perfume for women under 1500 EGP',
    );
    await tester.pump(const Duration(milliseconds: 300));

    final sendButton = find.byKey(const ValueKey('ai_chat_send_button'));
    if (sendButton.evaluate().isNotEmpty) {
      await tester.tap(sendButton, warnIfMissed: false);
    } else {
      await tester.testTextInput.receiveAction(TextInputAction.send);
    }

    for (var i = 0; i < 1800; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final loadingGone = find
          .byKey(const ValueKey('ai_chat_loading_spinner'))
          .evaluate()
          .isEmpty;
      final hasNewBubble =
          find.byType(ChatMessageBubble).evaluate().length >
          previousBubbleCount;
      if (loadingGone && hasNewBubble) return;
    }
  }

  testWidgets('Gate -1 worker v2 metadata is present', (tester) async {
    await bootstrapAuthAndOpenChat(tester);
    await sendProbeMessage(tester);

    final message = lastBotMessage();
    final authMode = bypassAuthInTests ? 'guest' : 'authenticated';
    debugPrint(
      '[AI-GATE-V2] authMode=$authMode '
      'source=${message?.responseSource} '
      'prompt=${message?.promptVersion} '
      'provider=${message?.provider} '
      'model=${message?.modelId} '
      'failure=${message?.workerFailureReason}',
    );

    expect(message, isNotNull);
    final bot = message!;
    expect(bot.promptVersion, 'chat_v2_structured_commands');
    expect(bot.provider, isNotNull);
    expect(bot.modelId, isNotNull);
    expect(bot.workerFailureReason, isNull);
    expect(
      bot.responseSource,
      isNot(anyOf(contains('local_fallback'), contains('auth_required'))),
    );
  });
}
