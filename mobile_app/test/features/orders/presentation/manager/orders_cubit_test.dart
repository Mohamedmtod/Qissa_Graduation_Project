import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/orders/data/models/order_model.dart';
import 'package:perfume_app/features/orders/data/repos/order_repo.dart';
import 'package:perfume_app/features/orders/presentation/manager/orders_cubit.dart';

class MockOrderRepo extends Mock implements OrderRepo {}
class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockUser extends Mock implements User {}

void main() {
  late OrdersCubit ordersCubit;
  late MockOrderRepo mockOrderRepo;
  late MockAuthBloc mockAuthBloc;
  late MockUser mockUser;
  late StreamController<OrderQueryResult> controller;

  setUp(() {
    mockOrderRepo = MockOrderRepo();
    mockAuthBloc = MockAuthBloc();
    mockUser = MockUser();
    controller = StreamController<OrderQueryResult>.broadcast();
    
    when(() => mockUser.uid).thenReturn('u1');
    when(() => mockOrderRepo.streamMyOrders(any(), limit: any(named: 'limit')))
        .thenAnswer((_) => controller.stream);
    
    when(() => mockAuthBloc.state).thenReturn(AuthState.authenticated(mockUser));

    ordersCubit = OrdersCubit(
      orderRepo: mockOrderRepo,
      authBloc: mockAuthBloc,
    );
  });

  tearDown(() {
    controller.close();
    ordersCubit.close();
  });

  group('OrdersCubit loadOrders', () {
    blocTest<OrdersCubit, OrdersState>(
      'emits [OrdersLoading, OrdersLoaded] when stream yields data',
      build: () => ordersCubit,
      act: (cubit) {
        cubit.loadOrders();
        controller.add(OrderQueryResult(orders: [
          OrderModel(id: 'o1', userId: 'u1', items: [], total: 10, status: 'p', address: 'a', phone: 'p', paymentMethod: 'c', createdAt: Timestamp.now())
        ]));
      },
      expect: () => [
        isA<OrdersLoading>(),
        isA<OrdersLoaded>(),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'emits [OrdersLoading, OrdersEmpty] when stream is empty',
      build: () => ordersCubit,
      act: (cubit) {
        cubit.loadOrders();
        controller.add(OrderQueryResult(orders: []));
      },
      expect: () => [
        isA<OrdersLoading>(),
        isA<OrdersEmpty>(),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'emits [OrdersLoading, OrdersError] when stream throws error',
      build: () => ordersCubit,
      act: (cubit) {
        cubit.loadOrders();
        controller.addError('Stream Error');
      },
      expect: () => [
        isA<OrdersLoading>(),
        isA<OrdersError>().having((s) => s.message, 'message', contains('Stream Error')),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'emits OrdersError if user is not authenticated',
      build: () => ordersCubit,
      setUp: () {
        when(() => mockAuthBloc.state).thenReturn(const AuthState.unauthenticated());
      },
      act: (cubit) => cubit.loadOrders(),
      expect: () => [
        isA<OrdersError>().having((s) => s.message, 'message', 'User not authenticated'),
      ],
    );
  });

  group('OrdersCubit loadMore', () {
    final initialOrders = [
      OrderModel(id: 'o1', userId: 'u1', items: [], total: 10, status: 'p', address: 'a', phone: 'p', paymentMethod: 'c', createdAt: Timestamp.now())
    ];

    blocTest<OrdersCubit, OrdersState>(
      'emits [OrdersLoadingMore, OrdersLoaded] on successful expansion',
      build: () => ordersCubit,
      seed: () => OrdersLoaded(initialOrders, hasMore: true),
      act: (cubit) {
        cubit.loadMore();
        controller.add(OrderQueryResult(orders: [...initialOrders, initialOrders[0]]));
      },
      expect: () => [
        isA<OrdersLoadingMore>(),
        isA<OrdersLoaded>().having((s) => s.orders.length, 'length', 2),
      ],
    );

    test('loadMore does nothing if hasMore is false', () async {
      ordersCubit.emit(OrdersLoaded(initialOrders, hasMore: false));
      await ordersCubit.loadMore();
      verifyNever(() => mockOrderRepo.streamMyOrders(any(), limit: any(named: 'limit')));
    });

    test('loadMore does nothing if user is null', () async {
      when(() => mockAuthBloc.state).thenReturn(const AuthState.unauthenticated());
      ordersCubit.emit(OrdersLoaded(initialOrders, hasMore: true));
      await ordersCubit.loadMore();
      verifyNever(() => mockOrderRepo.streamMyOrders(any(), limit: any(named: 'limit')));
    });
  });

  group('OrdersCubit.close', () {
    test('cancels stream subscription when closed', () async {
      await ordersCubit.loadOrders();
      expect(controller.hasListener, isTrue);
      await ordersCubit.close();
      expect(controller.hasListener, isFalse);
    });
  });

  group('OrdersCubit cancelPendingOrder', () {
    test('calls orderRepo.cancelOrder', () async {
      when(() => mockOrderRepo.cancelOrder(any())).thenAnswer((_) async => {});
      await ordersCubit.cancelPendingOrder('o123');
      verify(() => mockOrderRepo.cancelOrder('o123')).called(1);
    });
  });
}
