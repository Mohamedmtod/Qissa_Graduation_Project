import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/recommended_product_card.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class MockAIChatCubit extends Mock implements AIChatCubit {}

ProductModel _product({
  required String id,
  required String name,
  required double price,
  double? salePrice,
  String? size,
  String occasion = 'daily',
  String intensity = 'light',
}) {
  final now = Timestamp.fromMillisecondsSinceEpoch(0);
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: buildSearchPrefixes(name),
    brand: 'Brand',
    price: price,
    salePrice: salePrice,
    size: size,
    stock: 5,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: const ['citrus'],
    imageUrls: const ['https://example.com/p.png'],
    description: 'desc',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: occasion,
    time: 'day',
    intensity: intensity,
    topNotes: const ['bergamot'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: const ['fresh'],
  );
}

Widget _wrap({
  required AIChatCubit cubit,
  required RecommendedProduct recommendation,
  bool compact = true,
  double width = 260,
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
      body: Center(
        child: SizedBox(
          width: width,
          child: BlocProvider<AIChatCubit>.value(
            value: cubit,
            child: RecommendedProductCard(
              recommendation: recommendation,
              compact: compact,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _wrapWithRouter({
  required AIChatCubit cubit,
  required RecommendedProduct recommendation,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              child: BlocProvider<AIChatCubit>.value(
                value: cubit,
                child: RecommendedProductCard(
                  recommendation: recommendation,
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => Text(
          'product ${state.pathParameters['id']} ${state.uri.queryParameters['source']}',
        ),
      ),
    ],
  );

  return MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  late MockAIChatCubit mockCubit;

  setUp(() {
    mockCubit = MockAIChatCubit();
    when(
      () => mockCubit.stream,
    ).thenAnswer((_) => const Stream<AIChatState>.empty());
    when(
      () => mockCubit.state,
    ).thenReturn(const AIChatState(language: AIChatLanguage.english));
  });

  testWidgets('does not render variant size in recommendation card', (
    tester,
  ) async {
    final withSize = RecommendedProduct(
      product: _product(
        id: 'p1',
        name: 'With Size',
        price: 1000,
        size: '100 ml',
      ),
      matchScore: 0.9,
      matchLabel: 'Great Match',
      matchReason: 'Fits preferences',
    );

    await tester.pumpWidget(_wrap(cubit: mockCubit, recommendation: withSize));
    await tester.pump();
    expect(find.text('100 ml'), findsNothing);

    final withoutSize = RecommendedProduct(
      product: _product(id: 'p2', name: 'No Size', price: 1000),
      matchScore: 0.9,
      matchLabel: 'Great Match',
      matchReason: 'Fits preferences',
    );

    await tester.pumpWidget(
      _wrap(cubit: mockCubit, recommendation: withoutSize),
    );
    await tester.pump();
    expect(find.text('100 ml'), findsNothing);
  });

  testWidgets(
    'on-sale product shows effective price old price and integer discount',
    (tester) async {
      final recommendation = RecommendedProduct(
        product: _product(
          id: 'p3',
          name: 'Sale Product',
          price: 2000,
          salePrice: 1499,
        ),
        matchScore: 0.9,
        matchLabel: 'Great Match',
        matchReason: 'Fits preferences',
      );

      await tester.pumpWidget(
        _wrap(cubit: mockCubit, recommendation: recommendation),
      );
      await tester.pump();

      expect(find.textContaining('1499'), findsOneWidget);
      expect(find.textContaining('2000'), findsOneWidget);
      expect(find.text('-25%'), findsOneWidget);

      final oldPriceText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((text) => (text.data ?? '').contains('2000'));
      expect(oldPriceText.style?.decoration, TextDecoration.lineThrough);
    },
  );

  testWidgets('non-sale product shows one price and no discount badge', (
    tester,
  ) async {
    final recommendation = RecommendedProduct(
      product: _product(id: 'p4', name: 'Regular Product', price: 1750),
      matchScore: 0.9,
      matchLabel: 'Great Match',
      matchReason: 'Fits preferences',
    );

    await tester.pumpWidget(
      _wrap(cubit: mockCubit, recommendation: recommendation),
    );
    await tester.pump();

    expect(find.textContaining('1750'), findsOneWidget);
    expect(find.text('-25%'), findsNothing);
  });

  testWidgets(
    'shows qualitative match label and hides numeric match percentage',
    (tester) async {
      final recommendation = RecommendedProduct(
        product: _product(id: 'p5', name: 'Label Product', price: 1450),
        matchScore: 0.84,
        matchLabel: 'Great Match',
        matchReason: 'Fits preferences',
      );

      await tester.pumpWidget(
        _wrap(cubit: mockCubit, recommendation: recommendation),
      );
      await tester.pump();

      expect(find.text('Great Match'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    },
  );

  testWidgets('compact card shows match reason under price', (tester) async {
    final recommendation = RecommendedProduct(
      product: _product(id: 'p6', name: 'Reason Product', price: 1450),
      matchScore: 0.84,
      matchLabel: 'Great Match',
      matchReason:
          'Fits preferences. Not exact on: light intensity and office use.',
    );

    await tester.pumpWidget(
      _wrap(cubit: mockCubit, recommendation: recommendation),
    );
    await tester.pump();

    expect(find.textContaining('Fits preferences'), findsOneWidget);
    expect(find.textContaining('Not exact on'), findsOneWidget);

    final reasonText = tester.widget<Text>(
      find.textContaining('Fits preferences'),
    );
    expect(reasonText.maxLines, 3);
    expect(reasonText.style?.fontSize, 11);
  });

  testWidgets('Arabic card displays light intensity as هادي', (tester) async {
    when(
      () => mockCubit.state,
    ).thenReturn(const AIChatState(language: AIChatLanguage.arabic));

    final recommendation = RecommendedProduct(
      product: _product(id: 'p7', name: 'Soft Product', price: 1450),
      matchScore: 0.84,
      matchLabel: 'تطابق جيد',
      matchReason: '',
    );

    await tester.pumpWidget(
      _wrap(
        cubit: mockCubit,
        recommendation: recommendation,
        compact: true,
        width: 320,
      ),
    );
    await tester.pump();

    expect(find.textContaining('هادي'), findsWidgets);
    expect(find.textContaining('خفيف'), findsNothing);
  });

  testWidgets('Arabic card displays office occasion as user-facing copy', (
    tester,
  ) async {
    when(
      () => mockCubit.state,
    ).thenReturn(const AIChatState(language: AIChatLanguage.arabic));

    final recommendation = RecommendedProduct(
      product: _product(
        id: 'p8',
        name: 'Office Product',
        price: 1450,
        occasion: 'office',
      ),
      matchScore: 0.84,
      matchLabel: '\u062a\u0637\u0627\u0628\u0642 \u062c\u064a\u062f',
      matchReason: '',
    );

    await tester.pumpWidget(
      _wrap(
        cubit: mockCubit,
        recommendation: recommendation,
        compact: true,
        width: 320,
      ),
    );
    await tester.pump();

    expect(find.textContaining('\u0644\u0644\u0634\u063a\u0644'), findsWidgets);
    expect(find.textContaining('office'), findsNothing);
  });

  testWidgets('guest can open product details from recommendation card', (
    tester,
  ) async {
    final recommendation = RecommendedProduct(
      product: _product(
        id: 'guest_product',
        name: 'Guest Product',
        price: 1450,
      ),
      matchScore: 0.84,
      matchLabel: 'Great Match',
      matchReason: 'Fits preferences',
    );

    await tester.pumpWidget(
      _wrapWithRouter(cubit: mockCubit, recommendation: recommendation),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('ai_chat_recommendation_card_guest_product')),
    );
    await tester.pumpAndSettle();

    expect(find.text('product guest_product ai_chat'), findsOneWidget);
  });
}
