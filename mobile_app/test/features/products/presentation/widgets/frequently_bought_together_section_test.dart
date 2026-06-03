import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/products/data/models/frequent_recommendation_model.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/frequent_recommendation_repo.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/products/presentation/widgets/frequently_bought_together_section.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class MockFrequentRecommendationRepo extends Mock
    implements FrequentRecommendationRepo {}

class MockProductRepo extends Mock implements ProductRepo {}

void main() {
  late MockFrequentRecommendationRepo recommendationRepo;
  late MockProductRepo productRepo;

  ProductModel createProduct(String id, {String? name}) => ProductModel(
    id: id,
    name: name ?? 'Product $id',
    nameLower: (name ?? 'Product $id').toLowerCase(),
    searchPrefixes: const [],
    brand: 'Brand',
    price: 100,
    stock: 10,
    gender: 'unisex',
    season: 'all',
    fragranceFamily: 'woody',
    notes: const [],
    imageUrls: const [],
    description: 'desc',
    categoryName: 'Perfumes',
    createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
    updatedAt: Timestamp.fromMillisecondsSinceEpoch(0),
    occasion: '',
    time: '',
    intensity: '',
    topNotes: const [],
    middleNotes: const [],
    baseNotes: const [],
    tags: const [],
  );

  FrequentRecommendationModel createRecommendation({
    required String triggerId,
    required List<RecommendedProductRule> products,
  }) => FrequentRecommendationModel(
    triggerProductId: triggerId,
    recommendedProducts: products,
    updatedAt: null,
    source: 'test',
  );

  Widget wrap(Widget child) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrequentRecommendationRepo>.value(
          value: recommendationRepo,
        ),
        RepositoryProvider<ProductRepo>.value(value: productRepo),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  Widget wrapWithRouter(Widget child) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) => Text(
            'product ${state.pathParameters['id']} ${state.uri.queryParameters['source']}',
          ),
        ),
      ],
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FrequentRecommendationRepo>.value(
          value: recommendationRepo,
        ),
        RepositoryProvider<ProductRepo>.value(value: productRepo),
      ],
      child: MaterialApp.router(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    recommendationRepo = MockFrequentRecommendationRepo();
    productRepo = MockProductRepo();
  });

  testWidgets('shows shimmer skeleton while recommendations are loading', (
    tester,
  ) async {
    final completer = Completer<FrequentRecommendationModel?>();

    when(
      () => recommendationRepo.fetchByTriggerProductId('trigger_1'),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      wrap(const FrequentlyBoughtTogetherSection(productId: 'trigger_1')),
    );

    expect(find.byKey(const Key('fbt_loading_skeleton')), findsOneWidget);
    expect(find.text('Frequently Bought Together'), findsNothing);
  });

  testWidgets(
    'hides the section completely when there is no recommendation history',
    (tester) async {
      when(
        () => recommendationRepo.fetchByTriggerProductId('new_product'),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        wrap(const FrequentlyBoughtTogetherSection(productId: 'new_product')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fbt_loading_skeleton')), findsNothing);
      expect(find.text('Frequently Bought Together'), findsNothing);
    },
  );

  testWidgets(
    'ignores dangling references and renders only existing products',
    (tester) async {
      when(
        () => recommendationRepo.fetchByTriggerProductId('trigger_2'),
      ).thenAnswer(
        (_) async => createRecommendation(
          triggerId: 'trigger_2',
          products: const [
            RecommendedProductRule(
              productId: 'existing_1',
              confidence: 0.7,
              support: 0.2,
              lift: 1.5,
            ),
            RecommendedProductRule(
              productId: 'deleted_1',
              confidence: 0.6,
              support: 0.15,
              lift: 1.3,
            ),
          ],
        ),
      );

      when(
        () => productRepo.fetchProductsByIds(['existing_1', 'deleted_1']),
      ).thenAnswer(
        (_) async => [createProduct('existing_1', name: 'Existing')],
      );

      await tester.pumpWidget(
        wrap(const FrequentlyBoughtTogetherSection(productId: 'trigger_2')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Frequently Bought Together'), findsOneWidget);
      expect(find.text('Existing'), findsOneWidget);
      expect(find.text('Product deleted_1'), findsNothing);
      expect(find.byType(InkWell), findsOneWidget);
    },
  );

  testWidgets('guest can open product details from FBT recommendation card', (
    tester,
  ) async {
    when(
      () => recommendationRepo.fetchByTriggerProductId('trigger_3'),
    ).thenAnswer(
      (_) async => createRecommendation(
        triggerId: 'trigger_3',
        products: const [
          RecommendedProductRule(
            productId: 'guest_fbt',
            confidence: 0.7,
            support: 0.2,
            lift: 1.5,
          ),
        ],
      ),
    );

    when(
      () => productRepo.fetchProductsByIds(['guest_fbt']),
    ).thenAnswer((_) async => [createProduct('guest_fbt', name: 'Guest FBT')]);

    await tester.pumpWidget(
      wrapWithRouter(
        const FrequentlyBoughtTogetherSection(productId: 'trigger_3'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guest FBT'));
    await tester.pumpAndSettle();

    expect(find.text('product guest_fbt fbt'), findsOneWidget);
  });
}
