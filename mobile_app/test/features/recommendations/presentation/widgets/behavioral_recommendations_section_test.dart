import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/user_taste_profile.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/recommendations/presentation/widgets/behavioral_recommendations_section.dart';
import 'package:perfume_app/features/wishlist/presentation/manager/wishlist_cubit.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class MockProductRepo extends Mock implements ProductRepo {}

class MockUserTasteRepo extends Mock implements UserTasteRepo {}

class MockCartRepo extends Mock implements CartRepo {}

class MockEventRepo extends Mock implements EventRepo {}

class MockWishlistCubit extends MockCubit<WishlistState>
    implements WishlistCubit {}

class MockCartCubit extends MockCubit<CartState> implements CartCubit {}

ProductModel _product(
  String id, {
  List<String> notes = const ['citrus'],
  List<String> tags = const ['fresh'],
}) {
  final ts = Timestamp.fromMillisecondsSinceEpoch(1);
  return ProductModel(
    id: id,
    name: 'Perfume $id',
    nameLower: 'perfume $id',
    searchPrefixes: buildSearchPrefixes('Perfume $id'),
    brand: 'Brand',
    price: 1000,
    stock: 3,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: 'desc',
    categoryName: 'Perfume',
    createdAt: ts,
    updatedAt: ts,
    occasion: 'daily',
    time: 'day',
    intensity: 'light',
    topNotes: const ['bergamot'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: tags,
  );
}

Widget _wrap({
  required ProductRepo productRepo,
  required UserTasteRepo userTasteRepo,
  required CartRepo cartRepo,
  required EventRepo eventRepo,
  required WishlistCubit wishlistCubit,
  required CartCubit cartCubit,
  required Locale locale,
  String? excludeProductId,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<ProductRepo>.value(value: productRepo),
      RepositoryProvider<UserTasteRepo>.value(value: userTasteRepo),
      RepositoryProvider<CartRepo>.value(value: cartRepo),
      RepositoryProvider<EventRepo>.value(value: eventRepo),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<WishlistCubit>.value(value: wishlistCubit),
        BlocProvider<CartCubit>.value(value: cartCubit),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BehavioralRecommendationsSection(
            excludeProductId: excludeProductId,
          ),
        ),
      ),
    ),
  );
}

Widget _wrapWithRouter({
  required ProductRepo productRepo,
  required UserTasteRepo userTasteRepo,
  required CartRepo cartRepo,
  required EventRepo eventRepo,
  required WishlistCubit wishlistCubit,
  required CartCubit cartCubit,
  required Locale locale,
  String? excludeProductId,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: BehavioralRecommendationsSection(
            excludeProductId: excludeProductId,
          ),
        ),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            Text('product ${state.pathParameters['id']}'),
      ),
    ],
  );

  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<ProductRepo>.value(value: productRepo),
      RepositoryProvider<UserTasteRepo>.value(value: userTasteRepo),
      RepositoryProvider<CartRepo>.value(value: cartRepo),
      RepositoryProvider<EventRepo>.value(value: eventRepo),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<WishlistCubit>.value(value: wishlistCubit),
        BlocProvider<CartCubit>.value(value: cartCubit),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  Future<AppLocalizations> loadL10n(Locale locale) async {
    return AppLocalizations.delegate.load(locale);
  }

  testWidgets('shows localized English fallback title', (tester) async {
    final productRepo = MockProductRepo();
    final userTasteRepo = MockUserTasteRepo();
    final cartRepo = MockCartRepo();
    final eventRepo = MockEventRepo();
    final wishlistCubit = MockWishlistCubit();
    final cartCubit = MockCartCubit();

    when(
      () => wishlistCubit.state,
    ).thenReturn(WishlistLoaded(items: const [], products: const []));
    when(
      () => wishlistCubit.stream,
    ).thenAnswer((_) => const Stream<WishlistState>.empty());
    when(() => wishlistCubit.isWishlisted(any())).thenReturn(false);
    when(
      () => cartCubit.state,
    ).thenReturn(CartLoaded(items: const [], subtotal: 0));
    when(
      () => cartCubit.stream,
    ).thenAnswer((_) => const Stream<CartState>.empty());

    when(
      () => userTasteRepo.getTopNotes(
        limit: any(named: 'limit'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => const <String>[]);
    when(
      () => productRepo.fetchAICatalog(),
    ).thenAnswer((_) async => <ProductModel>[_product('p1')]);

    await tester.pumpWidget(
      _wrap(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        locale: const Locale('en'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = await loadL10n(const Locale('en'));
    expect(find.text(l10n.labelFallbackRecommendationsTitle), findsOneWidget);
  });

  testWidgets('hides section when no results', (tester) async {
    final productRepo = MockProductRepo();
    final userTasteRepo = MockUserTasteRepo();
    final cartRepo = MockCartRepo();
    final eventRepo = MockEventRepo();
    final wishlistCubit = MockWishlistCubit();
    final cartCubit = MockCartCubit();

    when(
      () => wishlistCubit.state,
    ).thenReturn(WishlistLoaded(items: const [], products: const []));
    when(
      () => wishlistCubit.stream,
    ).thenAnswer((_) => const Stream<WishlistState>.empty());
    when(() => wishlistCubit.isWishlisted(any())).thenReturn(false);
    when(
      () => cartCubit.state,
    ).thenReturn(CartLoaded(items: const [], subtotal: 0));
    when(
      () => cartCubit.stream,
    ).thenAnswer((_) => const Stream<CartState>.empty());

    when(
      () => userTasteRepo.getTopNotes(
        limit: any(named: 'limit'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => const <String>[]);
    when(
      () => productRepo.fetchAICatalog(),
    ).thenAnswer((_) async => <ProductModel>[]);

    await tester.pumpWidget(
      _wrap(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        locale: const Locale('en'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = await loadL10n(const Locale('en'));
    expect(find.text(l10n.labelFallbackRecommendationsTitle), findsNothing);
  });

  testWidgets('shows behavioral title and excludes current product', (
    tester,
  ) async {
    final productRepo = MockProductRepo();
    final userTasteRepo = MockUserTasteRepo();
    final cartRepo = MockCartRepo();
    final eventRepo = MockEventRepo();
    final wishlistCubit = MockWishlistCubit();
    final cartCubit = MockCartCubit();

    when(
      () => wishlistCubit.state,
    ).thenReturn(WishlistLoaded(items: const [], products: const []));
    when(
      () => wishlistCubit.stream,
    ).thenAnswer((_) => const Stream<WishlistState>.empty());
    when(() => wishlistCubit.isWishlisted(any())).thenReturn(false);
    when(
      () => cartCubit.state,
    ).thenReturn(CartLoaded(items: const [], subtotal: 0));
    when(
      () => cartCubit.stream,
    ).thenAnswer((_) => const Stream<CartState>.empty());

    when(
      () => userTasteRepo.getTopNotes(
        limit: any(named: 'limit'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => const ['citrus']);
    when(
      () => userTasteRepo.getTasteProfile(userId: any(named: 'userId')),
    ).thenAnswer(
      (_) async => const UserTasteProfile(noteScores: {'citrus': 10}),
    );
    when(() => productRepo.fetchAICatalog()).thenAnswer(
      (_) async => <ProductModel>[_product('excluded'), _product('p2')],
    );

    await tester.pumpWidget(
      _wrap(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        locale: const Locale('ar'),
        excludeProductId: 'excluded',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = await loadL10n(const Locale('ar'));
    expect(find.text(l10n.labelBehavioralRecommendationsTitle), findsOneWidget);
    expect(find.text('Perfume excluded'), findsNothing);
    expect(find.text('Perfume p2'), findsOneWidget);
  });

  testWidgets('shows fallback title when behavioral has no matches', (
    tester,
  ) async {
    final productRepo = MockProductRepo();
    final userTasteRepo = MockUserTasteRepo();
    final cartRepo = MockCartRepo();
    final eventRepo = MockEventRepo();
    final wishlistCubit = MockWishlistCubit();
    final cartCubit = MockCartCubit();

    when(
      () => wishlistCubit.state,
    ).thenReturn(WishlistLoaded(items: const [], products: const []));
    when(
      () => wishlistCubit.stream,
    ).thenAnswer((_) => const Stream<WishlistState>.empty());
    when(() => wishlistCubit.isWishlisted(any())).thenReturn(false);
    when(
      () => cartCubit.state,
    ).thenReturn(CartLoaded(items: const [], subtotal: 0));
    when(
      () => cartCubit.stream,
    ).thenAnswer((_) => const Stream<CartState>.empty());

    when(
      () => userTasteRepo.getTopNotes(
        limit: any(named: 'limit'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => const ['citrus']);
    when(
      () => userTasteRepo.getTasteProfile(userId: any(named: 'userId')),
    ).thenAnswer(
      (_) async => const UserTasteProfile(noteScores: {'citrus': 10}),
    );
    when(() => productRepo.fetchAICatalog()).thenAnswer(
      (_) async => <ProductModel>[
        _product('p1', notes: const ['amber'], tags: const ['woody']),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        locale: const Locale('en'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = await loadL10n(const Locale('en'));
    expect(find.text(l10n.labelFallbackRecommendationsTitle), findsOneWidget);
    expect(find.text(l10n.labelBehavioralRecommendationsTitle), findsNothing);
  });

  testWidgets(
    'excludes current product in fallback when behavioral has no matches',
    (tester) async {
      final productRepo = MockProductRepo();
      final userTasteRepo = MockUserTasteRepo();
      final cartRepo = MockCartRepo();
      final eventRepo = MockEventRepo();
      final wishlistCubit = MockWishlistCubit();
      final cartCubit = MockCartCubit();

      when(
        () => wishlistCubit.state,
      ).thenReturn(WishlistLoaded(items: const [], products: const []));
      when(
        () => wishlistCubit.stream,
      ).thenAnswer((_) => const Stream<WishlistState>.empty());
      when(() => wishlistCubit.isWishlisted(any())).thenReturn(false);
      when(
        () => cartCubit.state,
      ).thenReturn(CartLoaded(items: const [], subtotal: 0));
      when(
        () => cartCubit.stream,
      ).thenAnswer((_) => const Stream<CartState>.empty());

      when(
        () => userTasteRepo.getTopNotes(
          limit: any(named: 'limit'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => const ['citrus']);
      when(
        () => userTasteRepo.getTasteProfile(userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => const UserTasteProfile(noteScores: {'citrus': 10}),
      );
      when(() => productRepo.fetchAICatalog()).thenAnswer(
        (_) async => <ProductModel>[
          _product('excluded', notes: const ['amber'], tags: const ['woody']),
          _product('p2', notes: const ['musk'], tags: const ['powdery']),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          productRepo: productRepo,
          userTasteRepo: userTasteRepo,
          cartRepo: cartRepo,
          eventRepo: eventRepo,
          wishlistCubit: wishlistCubit,
          cartCubit: cartCubit,
          locale: const Locale('en'),
          excludeProductId: 'excluded',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final l10n = await loadL10n(const Locale('en'));
      expect(find.text(l10n.labelFallbackRecommendationsTitle), findsOneWidget);
      expect(find.text('Perfume excluded'), findsNothing);
      expect(find.text('Perfume p2'), findsOneWidget);
    },
  );

  testWidgets(
    'guest can open product details from fallback recommendation card',
    (tester) async {
      final productRepo = MockProductRepo();
      final userTasteRepo = MockUserTasteRepo();
      final cartRepo = MockCartRepo();
      final eventRepo = MockEventRepo();
      final wishlistCubit = MockWishlistCubit();
      final cartCubit = MockCartCubit();

      when(
        () => wishlistCubit.state,
      ).thenReturn(WishlistLoaded(items: const [], products: const []));
      when(
        () => wishlistCubit.stream,
      ).thenAnswer((_) => const Stream<WishlistState>.empty());
      when(() => wishlistCubit.isWishlisted(any())).thenReturn(false);
      when(
        () => cartCubit.state,
      ).thenReturn(CartLoaded(items: const [], subtotal: 0));
      when(
        () => cartCubit.stream,
      ).thenAnswer((_) => const Stream<CartState>.empty());

      when(
        () => userTasteRepo.getTopNotes(
          limit: any(named: 'limit'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => const <String>[]);
      when(
        () => productRepo.fetchAICatalog(),
      ).thenAnswer((_) async => <ProductModel>[_product('guest_rec')]);

      await tester.pumpWidget(
        _wrapWithRouter(
          productRepo: productRepo,
          userTasteRepo: userTasteRepo,
          cartRepo: cartRepo,
          eventRepo: eventRepo,
          wishlistCubit: wishlistCubit,
          cartCubit: cartCubit,
          locale: const Locale('en'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Perfume guest_rec'));
      await tester.pumpAndSettle();

      expect(find.text('product guest_rec'), findsOneWidget);
    },
  );
}
