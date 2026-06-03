import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/home/presentation/manager/home_cubit.dart';
import 'package:perfume_app/features/home/presentation/manager/home_state.dart';
import 'package:perfume_app/features/home/presentation/pages/home_page.dart';
import 'package:perfume_app/features/home/presentation/manager/layout_cubit.dart';
import 'package:perfume_app/features/orders/presentation/cubit/address/address_cubit.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/products/presentation/manager/product_details_cubit.dart';
import 'package:perfume_app/features/products/presentation/manager/product_details_state.dart';
import 'package:perfume_app/features/products/presentation/manager/recently_viewed_cubit.dart';
import 'package:perfume_app/features/products/presentation/pages/product_details_page.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/recommendations/presentation/widgets/behavioral_recommendations_section.dart';
import 'package:perfume_app/features/wishlist/presentation/manager/wishlist_cubit.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class MockHomeCubit extends MockCubit<HomeState> implements HomeCubit {}

class MockRecentlyViewedCubit extends MockCubit<RecentlyViewedState>
    implements RecentlyViewedCubit {}

class MockProductDetailsCubit extends MockCubit<ProductDetailsState>
    implements ProductDetailsCubit {}

class MockAddressCubit extends MockCubit<AddressState>
    implements AddressCubit {}

class MockWishlistCubit extends MockCubit<WishlistState>
    implements WishlistCubit {}

class MockCartCubit extends MockCubit<CartState> implements CartCubit {}

class MockProductRepo extends Mock implements ProductRepo {}

class MockUserTasteRepo extends Mock implements UserTasteRepo {}

class MockCartRepo extends Mock implements CartRepo {}

class MockEventRepo extends Mock implements EventRepo {}

ProductModel _product() {
  final ts = Timestamp.fromMillisecondsSinceEpoch(1);
  return ProductModel(
    id: 'p1',
    name: 'Perfume',
    nameLower: 'perfume',
    searchPrefixes: buildSearchPrefixes('Perfume'),
    brand: 'Brand',
    price: 1000,
    stock: 3,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: const ['citrus'],
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
    tags: const ['fresh'],
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: child,
      ),
    ),
  );
}

void main() {
  testWidgets('HomePage includes BehavioralRecommendationsSection', (
    tester,
  ) async {
    final homeCubit = MockHomeCubit();
    final recentlyViewedCubit = MockRecentlyViewedCubit();
    final addressCubit = MockAddressCubit();
    final wishlistCubit = MockWishlistCubit();
    final cartCubit = MockCartCubit();
    final productRepo = MockProductRepo();
    final userTasteRepo = MockUserTasteRepo();
    final cartRepo = MockCartRepo();
    final eventRepo = MockEventRepo();

    when(() => homeCubit.state).thenReturn(
      HomeSuccess(
        banners: const [],
        categories: const [],
        flashSaleProducts: <ProductModel>[_product()],
      ),
    );
    when(
      () => homeCubit.stream,
    ).thenAnswer((_) => const Stream<HomeState>.empty());

    when(() => recentlyViewedCubit.state).thenReturn(RecentlyViewedInitial());
    when(
      () => recentlyViewedCubit.stream,
    ).thenAnswer((_) => const Stream<RecentlyViewedState>.empty());

    when(() => addressCubit.state).thenReturn(AddressState());
    when(
      () => addressCubit.stream,
    ).thenAnswer((_) => const Stream<AddressState>.empty());
    when(() => addressCubit.loadAddresses()).thenReturn(null);
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
    ).thenAnswer((_) async => <ProductModel>[_product()]);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ProductRepo>.value(value: productRepo),
          RepositoryProvider<UserTasteRepo>.value(value: userTasteRepo),
          RepositoryProvider<CartRepo>.value(value: cartRepo),
          RepositoryProvider<EventRepo>.value(value: eventRepo),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<HomeCubit>.value(value: homeCubit),
            BlocProvider<RecentlyViewedCubit>.value(value: recentlyViewedCubit),
            BlocProvider<AddressCubit>.value(value: addressCubit),
            BlocProvider<WishlistCubit>.value(value: wishlistCubit),
            BlocProvider<CartCubit>.value(value: cartCubit),
          ],
          child: _app(const HomePage()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final recommendationsSection = find.byKey(
      homeBehavioralRecommendationsSectionKey,
    );

    await tester.scrollUntilVisible(
      recommendationsSection,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(recommendationsSection, findsOneWidget);
  });

  testWidgets('ProductDetailsPage includes BehavioralRecommendationsSection', (
    tester,
  ) async {
    final productDetailsCubit = MockProductDetailsCubit();
    final productRepo = MockProductRepo();
    final userTasteRepo = MockUserTasteRepo();
    final cartRepo = MockCartRepo();
    final eventRepo = MockEventRepo();
    final addressCubit = MockAddressCubit();
    final wishlistCubit = MockWishlistCubit();
    final cartCubit = MockCartCubit();

    when(
      () => productDetailsCubit.state,
    ).thenReturn(ProductDetailsSuccess(product: _product()));
    when(
      () => productDetailsCubit.stream,
    ).thenAnswer((_) => const Stream<ProductDetailsState>.empty());

    when(
      () => userTasteRepo.getTopNotes(
        limit: any(named: 'limit'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => const <String>[]);
    when(
      () => productRepo.fetchAICatalog(),
    ).thenAnswer((_) async => <ProductModel>[_product()]);
    when(() => addressCubit.state).thenReturn(AddressState());
    when(
      () => addressCubit.stream,
    ).thenAnswer((_) => const Stream<AddressState>.empty());
    when(() => addressCubit.loadAddresses()).thenReturn(null);
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

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ProductRepo>.value(value: productRepo),
          RepositoryProvider<UserTasteRepo>.value(value: userTasteRepo),
          RepositoryProvider<CartRepo>.value(value: cartRepo),
          RepositoryProvider<EventRepo>.value(value: eventRepo),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ProductDetailsCubit>.value(value: productDetailsCubit),
            BlocProvider<LayoutCubit>(create: (_) => LayoutCubit()),
            BlocProvider<AddressCubit>.value(value: addressCubit),
            BlocProvider<WishlistCubit>.value(value: wishlistCubit),
            BlocProvider<CartCubit>.value(value: cartCubit),
          ],
          child: _app(const ProductDetailsPage(productId: 'p1')),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(BehavioralRecommendationsSection), findsOneWidget);
  });
}
