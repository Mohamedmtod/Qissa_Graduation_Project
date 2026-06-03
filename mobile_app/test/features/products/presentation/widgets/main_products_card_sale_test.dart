import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/wishlist/data/repos/wishlist_repo.dart';
import 'package:perfume_app/features/wishlist/presentation/manager/wishlist_cubit.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/cards.dart';

class MockWishlistRepo extends Mock implements WishlistRepo {}

class MockAuthBloc extends Mock implements AuthBloc {}

class MockProductRepo extends Mock implements ProductRepo {}

class MockCartRepo extends Mock implements CartRepo {}

class MockEventRepo extends Mock implements EventRepo {}

class MockCartCubit extends MockCubit<CartState> implements CartCubit {}

ProductModel _product({
  required String id,
  required String name,
  required double price,
  double? salePrice,
  String? size,
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
    occasion: 'daily',
    time: 'day',
    intensity: 'light',
    topNotes: const ['bergamot'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: const ['fresh'],
  );
}

Widget _wrap({
  required ProductModel product,
  required WishlistCubit wishlistCubit,
}) {
  final cartCubit = MockCartCubit();
  when(
    () => cartCubit.state,
  ).thenReturn(CartLoaded(items: const [], subtotal: 0));
  when(
    () => cartCubit.stream,
  ).thenAnswer((_) => const Stream<CartState>.empty());

  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<CartRepo>.value(value: MockCartRepo()),
      RepositoryProvider<EventRepo>.value(value: MockEventRepo()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<WishlistCubit>.value(value: wishlistCubit),
            BlocProvider<CartCubit>.value(value: cartCubit),
          ],
          child: MainProductsCard(product: product, scale: 0.5),
        ),
      ),
    ),
  );
}

Widget _wrapWithCart({
  required ProductModel product,
  required WishlistCubit wishlistCubit,
  required CartCubit cartCubit,
  required MockCartRepo cartRepo,
  required MockEventRepo eventRepo,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<CartRepo>.value(value: cartRepo),
      RepositoryProvider<EventRepo>.value(value: eventRepo),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<WishlistCubit>.value(value: wishlistCubit),
            BlocProvider<CartCubit>.value(value: cartCubit),
          ],
          child: MainProductsCard(product: product, scale: 0.5),
        ),
      ),
    ),
  );
}

CartItemModel _cartItem({required String productId, required int quantity}) {
  return CartItemModel(
    productId: productId,
    name: 'Item',
    price: 100,
    imageUrl: 'https://example.com/p.png',
    quantity: quantity,
    brand: 'Brand',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      CartItemModel(
        productId: 'fallback',
        name: 'fallback',
        price: 0,
        imageUrl: '',
        quantity: 1,
        brand: 'fallback',
      ),
    );
  });

  late WishlistCubit wishlistCubit;
  late MockAuthBloc authBloc;
  late MockCartCubit cartCubit;
  late MockCartRepo cartRepo;
  late MockEventRepo eventRepo;

  setUp(() {
    authBloc = MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthState.unauthenticated());
    when(
      () => authBloc.stream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());

    cartCubit = MockCartCubit();
    when(
      () => cartCubit.stream,
    ).thenAnswer((_) => const Stream<CartState>.empty());
    when(
      () => cartCubit.state,
    ).thenReturn(CartLoaded(items: const [], subtotal: 0));
    when(() => cartCubit.updateQuantity(any(), any())).thenAnswer((_) async {});
    when(() => cartCubit.removeFromCart(any())).thenAnswer((_) async {});

    cartRepo = MockCartRepo();
    eventRepo = MockEventRepo();
    when(
      () => cartRepo.addToCart(any(), any(), maxStock: any(named: 'maxStock')),
    ).thenAnswer((_) async {});
    when(
      () => eventRepo.logAddToCart(
        productId: any(named: 'productId'),
        name: any(named: 'name'),
        price: any(named: 'price'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async {});

    wishlistCubit = WishlistCubit(
      wishlistRepo: MockWishlistRepo(),
      authBloc: authBloc,
      productRepo: MockProductRepo(),
    );
  });

  tearDown(() async {
    await wishlistCubit.close();
  });

  testWidgets('does not render variant size in product grid card', (
    tester,
  ) async {
    final product = _product(
      id: 'p1',
      name: 'With Size',
      price: 1000,
      size: '100 ml',
    );

    await tester.pumpWidget(
      _wrap(product: product, wishlistCubit: wishlistCubit),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('100 ml'), findsNothing);
  });

  testWidgets('uses a static image instead of a slider in product grid card', (
    tester,
  ) async {
    final product = _product(id: 'p1a', name: 'Static Image', price: 1000);

    await tester.pumpWidget(
      _wrap(product: product, wishlistCubit: wishlistCubit),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('on-sale product card shows effective old and discount prices', (
    tester,
  ) async {
    final product = _product(
      id: 'p2',
      name: 'Sale Item',
      price: 2000,
      salePrice: 1499,
    );

    await tester.pumpWidget(
      _wrap(product: product, wishlistCubit: wishlistCubit),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('1499'), findsOneWidget);
    expect(find.textContaining('2000'), findsOneWidget);
    expect(find.text('-25%'), findsOneWidget);
  });

  testWidgets('non-sale product card shows only one price', (tester) async {
    final product = _product(id: 'p3', name: 'Regular', price: 1750);

    await tester.pumpWidget(
      _wrap(product: product, wishlistCubit: wishlistCubit),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('1750'), findsOneWidget);
    expect(find.text('-25%'), findsNothing);
  });

  testWidgets('shows plus button when product is not in cart', (tester) async {
    when(
      () => cartCubit.state,
    ).thenReturn(CartLoaded(items: const [], subtotal: 0));

    final product = _product(id: 'p4', name: 'No Cart Item', price: 1000);
    await tester.pumpWidget(
      _wrapWithCart(
        product: product,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart), findsNothing);
  });

  testWidgets('shows cart icon and quantity when item quantity is 1', (
    tester,
  ) async {
    final product = _product(id: 'p5', name: 'Qty One', price: 1000);
    when(() => cartCubit.state).thenReturn(
      CartLoaded(
        items: [_cartItem(productId: product.id, quantity: 1)],
        subtotal: 100,
      ),
    );

    await tester.pumpWidget(
      _wrapWithCart(
        product: product,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('shows remove icon when item quantity is more than 1', (
    tester,
  ) async {
    final product = _product(id: 'p6', name: 'Qty Two', price: 1000);
    when(() => cartCubit.state).thenReturn(
      CartLoaded(
        items: [_cartItem(productId: product.id, quantity: 2)],
        subtotal: 200,
      ),
    );

    await tester.pumpWidget(
      _wrapWithCart(
        product: product,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('pressing plus for cart item uses updateQuantity not addToCart', (
    tester,
  ) async {
    final product = _product(id: 'p7', name: 'Update Qty', price: 1000);
    when(() => cartCubit.state).thenReturn(
      CartLoaded(
        items: [_cartItem(productId: product.id, quantity: 1)],
        subtotal: 100,
      ),
    );

    await tester.pumpWidget(
      _wrapWithCart(
        product: product,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
      ),
    );
    await tester.pump();

    final addIcons = find.byIcon(Icons.add);
    expect(addIcons, findsOneWidget);
    await tester.tap(addIcons.first);
    await tester.pump();

    verify(() => cartCubit.updateQuantity(product.id, 2)).called(1);
    verifyNever(
      () => cartRepo.addToCart(any(), any(), maxStock: any(named: 'maxStock')),
    );
  });

  testWidgets('pressing cart icon at quantity 1 removes item', (tester) async {
    final product = _product(id: 'p8', name: 'Remove Item', price: 1000);
    when(() => cartCubit.state).thenReturn(
      CartLoaded(
        items: [_cartItem(productId: product.id, quantity: 1)],
        subtotal: 100,
      ),
    );

    await tester.pumpWidget(
      _wrapWithCart(
        product: product,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();

    verify(() => cartCubit.removeFromCart(product.id)).called(1);
  });

  testWidgets('pressing remove at quantity 2 decreases quantity', (
    tester,
  ) async {
    final product = _product(id: 'p9', name: 'Decrease Qty', price: 1000);
    when(() => cartCubit.state).thenReturn(
      CartLoaded(
        items: [_cartItem(productId: product.id, quantity: 2)],
        subtotal: 200,
      ),
    );

    await tester.pumpWidget(
      _wrapWithCart(
        product: product,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    verify(() => cartCubit.updateQuantity(product.id, 1)).called(1);
  });

  testWidgets('guest user can add item to guest cart on first plus tap', (
    tester,
  ) async {
    final product = _product(id: 'p10', name: 'Guest', price: 1000);
    when(
      () => cartCubit.state,
    ).thenReturn(CartLoaded(items: const [], subtotal: 0));

    await tester.pumpWidget(
      _wrapWithCart(
        product: product,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    verify(
      () => cartRepo.addToCart(
        CartRepo.guestCartUserId,
        any(),
        maxStock: product.defaultVariant.stock,
      ),
    ).called(1);
  });

  testWidgets('stock limit shows same error message and keeps UI stable', (
    tester,
  ) async {
    final product = _product(id: 'p11', name: 'Stock Limit', price: 1000);
    when(() => cartCubit.state).thenReturn(
      CartLoaded(
        items: [_cartItem(productId: product.id, quantity: 5)],
        subtotal: 500,
      ),
    );

    await tester.pumpWidget(
      _wrapWithCart(
        product: product,
        wishlistCubit: wishlistCubit,
        cartCubit: cartCubit,
        cartRepo: cartRepo,
        eventRepo: eventRepo,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Only 5 items available in stock.'), findsOneWidget);
    verifyNever(() => cartCubit.updateQuantity(product.id, 6));
  });
}
