import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/chat_message_bubble.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

void main() {
  Widget wrap(Widget child, {String locale = 'en'}) {
    return MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('ChatMessageBubble', () {
    testWidgets('loading bubble shows English "Thinking..." when locale is en', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(ChatMessageBubble(message: AIChatMessage.loading()), locale: 'en'),
      );
      await tester.pump();

      expect(find.text('Thinking...'), findsOneWidget);
      expect(find.text('جاري التفكير...'), findsNothing);
    });

    testWidgets('loading bubble shows Arabic "جاري التفكير..." when locale is ar', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(ChatMessageBubble(message: AIChatMessage.loading()), locale: 'ar'),
      );
      await tester.pump();

      expect(find.text('جاري التفكير...'), findsOneWidget);
      expect(find.text('Thinking...'), findsNothing);
    });

    testWidgets('error bubble shows Arabic warning label when locale is ar', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ChatMessageBubble(message: AIChatMessage.error('لا يوجد نتائج')),
          locale: 'ar',
        ),
      );
      await tester.pump();

      expect(find.text('رسالة تنبيهية'), findsOneWidget);
      expect(find.text('Warning'), findsNothing);
    });

    testWidgets('error bubble shows English "Warning" when locale is en', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ChatMessageBubble(message: AIChatMessage.error('No results')),
          locale: 'en',
        ),
      );
      await tester.pump();

      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('رسالة تنبيهية'), findsNothing);
    });
  });
}
