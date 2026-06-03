import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';

class MockCartRepo extends Mock implements CartRepo {}

class MockAuthBloc extends Mock implements AuthBloc {}

class MockProductRepo extends Mock implements ProductRepo {}

class MockUser extends Mock implements User {}

void main() {
  late CartCubit cartCubit;
  late MockCartRepo mockCartRepo;
  late MockAuthBloc mockAuthBloc;
  late MockProductRepo mockProductRepo;
  late MockUser mockUser;
  late StreamController<AuthState> authController;
  late StreamController<List<CartItemModel>> cartController;

  ProductModel createTestProduct({int stock = 5, bool isActive = true}) =>
      ProductModel(
        id: 'p1',
        name: 'Perfume 1',
        nameLower: 'perfume 1',
        searchPrefixes: const ['pe', 'per'],
        brand: 'Brand X',
        price: 100.0,
        stock: stock,
        gender: 'unisex',
        season: 'all',
        fragranceFamily: 'floral',
        notes: const ['note1'],
        imageUrls: const ['url'],
        description: 'desc',
        categoryName: 'cat',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        isActive: isActive,
        occasion: 'daily',
        time: 'day',
        intensity: 'medium',
        topNotes: const [],
        middleNotes: const [],
        baseNotes: const [],
        tags: const [],
      );

  setUp(() {
    mockCartRepo = MockCartRepo();
    mockAuthBloc = MockAuthBloc();
    mockProductRepo = MockProductRepo();
    mockUser = MockUser();
    authController = StreamController<AuthState>.broadcast();
    cartController = StreamController<List<CartItemModel>>.broadcast();

    when(() => mockUser.uid).thenReturn('user123');
    when(() => mockAuthBloc.stream).thenAnswer((_) => authController.stream);
    when(() => mockAuthBloc.state).thenReturn(const AuthState.unknown());

    when(
      () => mockCartRepo.streamCart(any()),
    ).thenAnswer((_) => cartController.stream);

    when(
      () => mockCartRepo.mergeGuestCartIntoUser(any()),
    ).thenAnswer((_) async => {});

    cartCubit = CartCubit(
      cartRepo: mockCartRepo,
      authBloc: mockAuthBloc,
      productRepo: mockProductRepo,
    );
  });

  tearDown(() {
    authController.close();
    cartController.close();
    cartCubit.close();
  });

  group('CartCubit Initial State', () {
    test('initial state is CartInitial', () {
      expect(cartCubit.state, isA<CartLoading>());
    });
  });

  group('CartCubit Auth Integration', () {
    blocTest<CartCubit, CartState>(
      'starts listening when user becomes authenticated',
      build: () => cartCubit,
      act: (cubit) {
        when(
          () => mockAuthBloc.state,
        ).thenReturn(AuthState.authenticated(mockUser));
        authController.add(AuthState.authenticated(mockUser));
      },
      expect: () => [isA<CartLoading>()],
      verify: (_) {
        verify(() => mockCartRepo.streamCart('user123')).called(1);
      },
    );

    blocTest<CartCubit, CartState>(
      'listens to guest cart when user is unauthenticated',
      build: () => cartCubit,
      act: (cubit) {
        authController.add(const AuthState.unauthenticated());
      },
      expect: () => [], // No new state is emitted because UID hasn't changed (already guest)
      verify: (_) {
        verify(
          () => mockCartRepo.streamCart(CartRepo.guestCartUserId),
        ).called(1); // Only called once during initialization
      },
    );

    blocTest<CartCubit, CartState>(
      'loads guest cart items after unauthenticated state',
      build: () => cartCubit,
      setUp: () {
        when(
          () => mockProductRepo.fetchProductsByIds(['p1']),
        ).thenAnswer((_) async => [createTestProduct()]);
      },
      act: (cubit) async {
        authController.add(const AuthState.unauthenticated());
        await Future<void>.delayed(Duration.zero);
        cartController.add([
          CartItemModel(
            productId: 'p1',
            name: 'Perfume 1',
            price: 100,
            imageUrl: 'url',
            quantity: 1,
            brand: 'Brand X',
          ),
        ]);
      },
      wait: const Duration(milliseconds: 150),
      expect: () => [
        isA<CartLoaded>()
            .having((s) => s.items, 'items', hasLength(1))
            .having((s) => s.subtotal, 'subtotal', 100.0),
      ],
    );
  });

  group('CartCubit updateQuantity', () {
    setUp(() {
      when(
        () => mockAuthBloc.state,
      ).thenReturn(AuthState.authenticated(mockUser));
      when(
        () => mockProductRepo.streamProductById('p1'),
      ).thenAnswer((_) => Stream.value(createTestProduct()));
    });

    blocTest<CartCubit, CartState>(
      'updates quantity successfully when within stock',
      build: () => cartCubit,
      setUp: () {
        when(
          () => mockCartRepo.updateQuantity(any(), any(), any()),
        ).thenAnswer((_) async => {});
      },
      act: (cubit) => cubit.updateQuantity('p1', 3),
      verify: (_) {
        verify(() => mockCartRepo.updateQuantity('user123', 'p1', 3)).called(1);
      },
    );

    blocTest<CartCubit, CartState>(
      'updates quantity successfully when exactly at stock limit',
      build: () => cartCubit,
      setUp: () {
        when(
          () => mockCartRepo.updateQuantity(any(), any(), any()),
        ).thenAnswer((_) async => {});
      },
      act: (cubit) => cubit.updateQuantity('p1', 5), // stock is 5
      verify: (_) {
        verify(() => mockCartRepo.updateQuantity('user123', 'p1', 5)).called(1);
      },
    );

    blocTest<CartCubit, CartState>(
      'emits CartStockError when exceeding stock',
      build: () => cartCubit,
      act: (cubit) => cubit.updateQuantity('p1', 6), // stock is 5
      expect: () => [
        isA<CartStockError>().having(
          (s) => s.message,
          'message',
          contains('5 items available'),
        ),
      ],
    );

    blocTest<CartCubit, CartState>(
      'removes from cart when quantity is 0',
      build: () => cartCubit,
      setUp: () {
        when(
          () => mockCartRepo.removeFromCart(any(), any()),
        ).thenAnswer((_) async => {});
      },
      act: (cubit) => cubit.updateQuantity('p1', 0),
      verify: (_) {
        verify(() => mockCartRepo.removeFromCart('user123', 'p1')).called(1);
      },
    );

    blocTest<CartCubit, CartState>(
      'ignores negative quantity',
      build: () => cartCubit,
      act: (cubit) => cubit.updateQuantity('p1', -1),
      expect: () => [],
      verify: (_) {
        verifyNever(() => mockCartRepo.updateQuantity(any(), any(), any()));
      },
    );

    blocTest<CartCubit, CartState>(
      'removes hidden products from cart when loaded',
      build: () {
        when(
          () => mockProductRepo.streamProductById('hidden_p1'),
        ).thenAnswer((_) => Stream.value(createTestProduct(isActive: false)));
        when(
          () => mockCartRepo.removeFromCart(any(), any()),
        ).thenAnswer((_) async => {});
        return cartCubit;
      },
      act: (cubit) async {
        when(
          () => mockAuthBloc.state,
        ).thenReturn(AuthState.authenticated(mockUser));
        authController.add(AuthState.authenticated(mockUser));
        await Future<void>.delayed(Duration.zero);
        cartController.add([
          CartItemModel(
            productId: 'hidden_p1',
            name: 'Hidden Perfume',
            price: 100,
            imageUrl: 'url',
            quantity: 1,
            brand: 'Brand',
          ),
        ]);
      },
      wait: const Duration(milliseconds: 150),
      expect: () => [
        isA<CartLoading>(),
        isA<CartLoaded>()
            .having((s) => s.items, 'items', isEmpty)
            .having((s) => s.subtotal, 'subtotal', 0.0),
      ],
      verify: (_) {
        verify(
          () => mockCartRepo.removeFromCart('user123', 'hidden_p1'),
        ).called(1);
      },
    );
  });

  group('CartCubit clearCart', () {
    blocTest<CartCubit, CartState>(
      'calls repo.clearCart and emits empty state',
      build: () => cartCubit,
      setUp: () {
        when(
          () => mockAuthBloc.state,
        ).thenReturn(AuthState.authenticated(mockUser));
        when(() => mockCartRepo.clearCart(any())).thenAnswer((_) async => {});
      },
      act: (cubit) async {
        cubit.initCart();
        await cubit.clearCart();
        // Simulate the stream emitting an empty list after clearing
        cartController.add([]);
      },
      expect: () => [
        isA<CartLoading>(),
        isA<CartLoaded>()
            .having((s) => s.items, 'items', isEmpty)
            .having((s) => s.subtotal, 'subtotal', 0.0),
      ],
      verify: (_) {
        verify(() => mockCartRepo.clearCart('user123')).called(1);
      },
    );
  });

  group('CartCubit Merge Warning', () {
    blocTest<CartCubit, CartState>(
      'emits CartMergeWarning when merge fails during auth state changes',
      build: () => cartCubit,
      setUp: () {
        when(
          () => mockCartRepo.mergeGuestCartIntoUser(any()),
        ).thenThrow(Exception('Merge failed'));
      },
      act: (cubit) {
        when(
          () => mockAuthBloc.state,
        ).thenReturn(AuthState.authenticated(mockUser));
        authController.add(AuthState.authenticated(mockUser));
      },
      expect: () => [
        isA<CartMergeWarning>().having(
          (s) => s.message,
          'message',
          contains('Failed to merge'),
        ),
        isA<CartLoading>(),
      ],
    );
  });
}
