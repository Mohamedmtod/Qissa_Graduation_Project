import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/chat_message_bubble.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/recommended_product_card.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class _MockAIChatCubit extends Mock implements AIChatCubit {}

ProductModel _product({
  required String id,
  required String name,
  required double price,
  List<String> notes = const ['musk', 'fresh'],
}) {
  final now = Timestamp.fromMillisecondsSinceEpoch(0);
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: buildSearchPrefixes(name),
    brand: 'Brand',
    price: price,
    stock: 5,
    gender: 'women',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: 'Safe product.',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: 'daily',
    time: 'day',
    intensity: 'medium',
    topNotes: const ['bergamot'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: const ['fresh'],
  );
}

RecommendedProduct _recommendation(ProductModel product) {
  return RecommendedProduct(
    product: product,
    matchScore: 0.86,
    matchLabel: 'Great Match',
    matchReason: 'Fresh safe match within budget.',
    exactBudget: 1000,
  );
}

Widget _contractHarness({
  required AIChatCubit cubit,
  required AIChatMessage message,
  required List<String> chips,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<AIChatCubit>.value(
        value: cubit,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                children: [
                  for (final chip in chips)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Chip(label: Text(chip)),
                    ),
                ],
              ),
              ChatMessageBubble(
                message: message,
                recommendationWidget: Column(
                  children: [
                    for (final recommendation in message.recommendedProducts)
                      RecommendedProductCard(
                        recommendation: recommendation,
                        compact: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

List<String> _visibleText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .where((text) => text.isNotEmpty)
      .toList(growable: false);
}

void _expectNoMojibake(WidgetTester tester) {
  final visible = _visibleText(tester).join('\n');
  expect(visible, isNot(contains('Щ')));
  expect(visible, isNot(contains('Ð')));
  expect(visible, isNot(contains('Ø')));
  expect(visible, isNot(contains('Ù')));
  expect(visible, isNot(contains('Ã')));
  expect(visible, isNot(contains('�')));
  expect(visible, isNot(contains('????')));
}

void main() {
  late _MockAIChatCubit cubit;

  setUp(() {
    cubit = _MockAIChatCubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => cubit.state,
    ).thenReturn(const AIChatState(language: AIChatLanguage.english));
  });

  testWidgets(
    'renders final guarded cards chips Arabic copy and prices without mojibake',
    (tester) async {
      final safe = _recommendation(
        _product(id: 'safe', name: 'Safe Musk', price: 900),
      );
      final message = AIChatMessage.botRecommendation(
        content: 'تمام، دي ترشيحات آمنة داخل الميزانية.',
        products: [safe],
        responseSource: 'ai_worker_v2',
        promptVersion: 'chat_v2_structured_commands',
        provider: 'openrouter',
        modelId: 'qwen/qwen3-32b',
      );

      await tester.pumpWidget(
        _contractHarness(
          cubit: cubit,
          message: message,
          chips: const ['Women', 'Under 1000', 'Fresh'],
        ),
      );
      await tester.pump();

      expect(find.textContaining('ترشيحات آمنة'), findsOneWidget);
      expect(find.text('Women'), findsOneWidget);
      expect(find.text('Under 1000'), findsOneWidget);
      expect(find.text('Fresh'), findsOneWidget);
      expect(find.textContaining('Safe Musk'), findsOneWidget);
      expect(find.textContaining('900'), findsOneWidget);
      _expectNoMojibake(tester);
    },
  );

  testWidgets('does not render products removed by final guard', (
    tester,
  ) async {
    final safe = _recommendation(
      _product(id: 'safe', name: 'Safe Musk', price: 900),
    );
    final blocked = _recommendation(
      _product(
        id: 'blocked',
        name: 'Blocked Vanilla',
        price: 850,
        notes: const ['vanilla'],
      ),
    );

    final guardedMessage = AIChatMessage.botRecommendation(
      content: 'Guarded result.',
      products: [safe],
      responseSource: 'ai_worker_v2',
    );

    await tester.pumpWidget(
      _contractHarness(
        cubit: cubit,
        message: guardedMessage,
        chips: const ['No vanilla'],
      ),
    );
    await tester.pump();

    expect(find.textContaining(safe.product.name), findsOneWidget);
    expect(find.textContaining(blocked.product.name), findsNothing);
    expect(find.textContaining('vanilla'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai_chat_recommendation_card_safe')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ai_chat_recommendation_card_blocked')),
      findsNothing,
    );
  });
}
