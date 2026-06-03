import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/orders/data/models/order_model.dart';
import 'package:perfume_app/features/orders/data/repos/order_repo.dart';
import 'package:perfume_app/features/orders/presentation/manager/order_cubit.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';

class MockOrderRepo extends Mock implements OrderRepo {}

class MockEventRepo extends Mock implements EventRepo {}

class MockUserTasteRepo extends Mock implements UserTasteRepo {}

void main() {
  late OrderCubit orderCubit;
  late MockOrderRepo mockOrderRepo;
  late MockEventRepo mockEventRepo;
  late MockUserTasteRepo mockUserTasteRepo;

  final cartItems = [
    CartItemModel(
      productId: 'p1',
      name: 'Perfume 1',
      price: 150.0,
      imageUrl: 'url1',
      quantity: 2,
      brand: 'Brand A',
      notes: const ['citrus', 'musk'],
    ),
  ];

  setUpAll(() {
    registerFallbackValue(EventType.view);
    registerFallbackValue(
      OrderModel(
        id: '',
        userId: '',
        items: [],
        total: 0,
        status: 'pending',
        address: '',
        phone: '',
        paymentMethod: '',
        createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
      ),
    );
  });

  setUp(() {
    mockOrderRepo = MockOrderRepo();
    mockEventRepo = MockEventRepo();
    mockUserTasteRepo = MockUserTasteRepo();
    orderCubit = OrderCubit(
      orderRepo: mockOrderRepo,
      eventRepo: mockEventRepo,
      userTasteRepo: mockUserTasteRepo,
    );
  });

  tearDown(() {
    orderCubit.close();
  });

  group('OrderCubit placeOrder', () {
    const userId = 'user123';
    const total = 300.0;
    const address = '123 Street';
    const phone = '0123456789';
    const paymentMethod = 'cash';

    blocTest<OrderCubit, OrderState>(
      'emits [OrderLoading, OrderRequestCreated] when successful',
      build: () => orderCubit,
      setUp: () {
        when(
          () => mockOrderRepo.createOrder(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer(
          (_) async => CreatedOrderResult(
            orderId: 'order_abc',
            orderCode: 'QA-ABC12345',
          ),
        );
        when(
          () => mockEventRepo.logOrderRequest(
            orderId: any(named: 'orderId'),
            total: any(named: 'total'),
            itemCount: any(named: 'itemCount'),
            items: any(named: 'items'),
          ),
        ).thenAnswer((_) async => {});
        when(
          () => mockUserTasteRepo.recordEvent(
            eventType: any(named: 'eventType'),
            notes: any(named: 'notes'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => {});
      },
      act: (cubit) => cubit.placeOrder(
        userId: userId,
        cartItems: cartItems,
        total: total,
        address: address,
        phone: phone,
        paymentMethod: paymentMethod,
      ),
      wait: const Duration(milliseconds: 20),
      expect: () => [
        isA<OrderLoading>(),
        isA<OrderRequestCreated>()
            .having((s) => s.orderId, 'orderId', 'order_abc')
            .having((s) => s.orderCode, 'orderCode', 'QA-ABC12345'),
      ],
      verify: (_) {
        // Verify mapping
        final capturedOrder =
            verify(
                  () => mockOrderRepo.createOrder(
                    captureAny(),
                    idempotencyKey: any(named: 'idempotencyKey'),
                  ),
                ).captured.first
                as OrderModel;
        expect(capturedOrder.userId, userId);
        expect(capturedOrder.items.length, 1);
        expect(capturedOrder.items.first.productId, 'p1');
        expect(capturedOrder.items.first.priceSnapshot, 150.0);
        expect(capturedOrder.items.first.quantity, 2);
        expect(capturedOrder.orderSource, 'app');

        // Verify event logging
        verify(
          () => mockEventRepo.logOrderRequest(
            orderId: 'order_abc',
            total: total,
            itemCount: 1,
            items: any(named: 'items'),
          ),
        ).called(1);
        verify(
          () => mockUserTasteRepo.recordEvent(
            eventType: EventType.purchase,
            notes: const ['citrus', 'musk'],
            userId: userId,
          ),
        ).called(1);
      },
    );

    blocTest<OrderCubit, OrderState>(
      'still emits OrderRequestCreated if event logging fails',
      build: () => orderCubit,
      setUp: () {
        when(
          () => mockOrderRepo.createOrder(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer(
          (_) async => CreatedOrderResult(
            orderId: 'order_abc',
            orderCode: 'QA-ABC12345',
          ),
        );
        when(
          () => mockEventRepo.logOrderRequest(
            orderId: any(named: 'orderId'),
            total: any(named: 'total'),
            itemCount: any(named: 'itemCount'),
            items: any(named: 'items'),
          ),
        ).thenThrow(Exception('Logging failed'));
      },
      act: (cubit) => cubit.placeOrder(
        userId: userId,
        cartItems: cartItems,
        total: total,
        address: address,
        phone: phone,
        paymentMethod: paymentMethod,
      ),
      wait: const Duration(milliseconds: 20),
      expect: () => [isA<OrderLoading>(), isA<OrderRequestCreated>()],
    );

    blocTest<OrderCubit, OrderState>(
      'emits [OrderLoading, OrderError] with correct message format when orderRepo fails',
      build: () => orderCubit,
      setUp: () {
        when(
          () => mockOrderRepo.createOrder(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenThrow(Exception('Worker error'));
      },
      act: (cubit) => cubit.placeOrder(
        userId: userId,
        cartItems: cartItems,
        total: total,
        address: address,
        phone: phone,
        paymentMethod: paymentMethod,
      ),
      expect: () => [
        isA<OrderLoading>(),
        isA<OrderError>().having(
          (s) => s.message,
          'message',
          'Failed to place order: Worker error',
        ),
      ],
      verify: (_) {
        // Verify that event logging was NOT called because createOrder failed
        verifyNever(
          () => mockEventRepo.logOrderRequest(
            orderId: any(named: 'orderId'),
            total: any(named: 'total'),
            itemCount: any(named: 'itemCount'),
            items: any(named: 'items'),
          ),
        );
        verifyNever(
          () => mockUserTasteRepo.recordEvent(
            eventType: any(named: 'eventType'),
            notes: any(named: 'notes'),
            userId: any(named: 'userId'),
          ),
        );
      },
    );

    blocTest<OrderCubit, OrderState>(
      'reuses the same idempotency key when the same checkout attempt is retried',
      build: () => orderCubit,
      setUp: () {
        var calls = 0;
        when(
          () => mockOrderRepo.createOrder(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async {
          calls += 1;
          if (calls == 1) {
            throw Exception('timeout');
          }
          return CreatedOrderResult(
            orderId: 'order_retry',
            orderCode: 'QA-RETRY01',
          );
        });
        when(
          () => mockEventRepo.logOrderRequest(
            orderId: any(named: 'orderId'),
            total: any(named: 'total'),
            itemCount: any(named: 'itemCount'),
            items: any(named: 'items'),
          ),
        ).thenAnswer((_) async => {});
        when(
          () => mockUserTasteRepo.recordEvent(
            eventType: any(named: 'eventType'),
            notes: any(named: 'notes'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => {});
      },
      act: (cubit) async {
        await cubit.placeOrder(
          userId: userId,
          cartItems: cartItems,
          total: total,
          address: address,
          phone: phone,
          paymentMethod: paymentMethod,
        );
        await cubit.placeOrder(
          userId: userId,
          cartItems: cartItems,
          total: total,
          address: address,
          phone: phone,
          paymentMethod: paymentMethod,
        );
      },
      wait: const Duration(milliseconds: 20),
      expect: () => [
        isA<OrderLoading>(),
        isA<OrderError>(),
        isA<OrderLoading>(),
        isA<OrderRequestCreated>(),
      ],
      verify: (_) {
        final keys = verify(
          () => mockOrderRepo.createOrder(
            any(),
            idempotencyKey: captureAny(named: 'idempotencyKey'),
          ),
        ).captured.cast<String>().toList();
        expect(keys, hasLength(2));
        expect(keys.first, equals(keys.last));
      },
    );

    blocTest<OrderCubit, OrderState>(
      'uses a new idempotency key when checkout payload changes after failure',
      build: () => orderCubit,
      setUp: () {
        when(
          () => mockOrderRepo.createOrder(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenThrow(Exception('timeout'));
      },
      act: (cubit) async {
        await cubit.placeOrder(
          userId: userId,
          cartItems: cartItems,
          total: total,
          address: address,
          phone: phone,
          paymentMethod: paymentMethod,
        );
        await cubit.placeOrder(
          userId: userId,
          cartItems: cartItems,
          total: total,
          address: '$address Apt 2',
          phone: phone,
          paymentMethod: paymentMethod,
        );
      },
      expect: () => [
        isA<OrderLoading>(),
        isA<OrderError>(),
        isA<OrderLoading>(),
        isA<OrderError>(),
      ],
      verify: (_) {
        final keys = verify(
          () => mockOrderRepo.createOrder(
            any(),
            idempotencyKey: captureAny(named: 'idempotencyKey'),
          ),
        ).captured.cast<String>().toList();
        expect(keys, hasLength(2));
        expect(keys.first, isNot(equals(keys.last)));
      },
    );

    group('Event Mapping Specifics', () {
      blocTest<OrderCubit, OrderState>(
        'logs correct data format to EventRepo',
        build: () => orderCubit,
        setUp: () {
          when(
            () => mockOrderRepo.createOrder(
              any(),
              idempotencyKey: any(named: 'idempotencyKey'),
            ),
          ).thenAnswer(
            (_) async =>
                CreatedOrderResult(orderId: 'o1', orderCode: 'QA-00000001'),
          );
          when(
            () => mockEventRepo.logOrderRequest(
              orderId: any(named: 'orderId'),
              total: any(named: 'total'),
              itemCount: any(named: 'itemCount'),
              items: any(named: 'items'),
            ),
          ).thenAnswer((_) async => {});
          when(
            () => mockUserTasteRepo.recordEvent(
              eventType: any(named: 'eventType'),
              notes: any(named: 'notes'),
              userId: any(named: 'userId'),
            ),
          ).thenAnswer((_) async => {});
        },
        act: (cubit) => cubit.placeOrder(
          userId: userId,
          cartItems: cartItems,
          total: total,
          address: address,
          phone: phone,
          paymentMethod: paymentMethod,
        ),
        wait: const Duration(milliseconds: 20),
        verify: (_) {
          final capturedItems =
              verify(
                    () => mockEventRepo.logOrderRequest(
                      orderId: any(named: 'orderId'),
                      total: any(named: 'total'),
                      itemCount: any(named: 'itemCount'),
                      items: captureAny(named: 'items'),
                    ),
                  ).captured.first
                  as List<Map<String, dynamic>>;

          expect(capturedItems.length, 1);
          expect(capturedItems.first['productId'], 'p1');
          expect(capturedItems.first['name'], 'Perfume 1');
          expect(capturedItems.first['quantity'], 2);
          expect(capturedItems.first['priceSnapshot'], 150.0);
        },
      );

      blocTest<OrderCubit, OrderState>(
        'passes restock_alert referral source through to the order model',
        build: () => orderCubit,
        setUp: () {
          when(
            () => mockOrderRepo.createOrder(
              any(),
              idempotencyKey: any(named: 'idempotencyKey'),
            ),
          ).thenAnswer(
            (_) async =>
                CreatedOrderResult(orderId: 'o1', orderCode: 'QA-00000001'),
          );
          when(
            () => mockEventRepo.logOrderRequest(
              orderId: any(named: 'orderId'),
              total: any(named: 'total'),
              itemCount: any(named: 'itemCount'),
              items: any(named: 'items'),
            ),
          ).thenAnswer((_) async => {});
          when(
            () => mockUserTasteRepo.recordEvent(
              eventType: any(named: 'eventType'),
              notes: any(named: 'notes'),
              userId: any(named: 'userId'),
            ),
          ).thenAnswer((_) async => {});
        },
        act: (cubit) => cubit.placeOrder(
          userId: userId,
          cartItems: cartItems,
          total: total,
          address: address,
          phone: phone,
          paymentMethod: paymentMethod,
          referralSource: 'restock_alert',
          restockRequestId: 'req_123',
        ),
        wait: const Duration(milliseconds: 20),
        verify: (_) {
          final capturedOrder =
              verify(
                    () => mockOrderRepo.createOrder(
                      captureAny(),
                      idempotencyKey: any(named: 'idempotencyKey'),
                    ),
                  ).captured.first
                  as OrderModel;
          expect(capturedOrder.orderSource, 'restock_alert');
          expect(
            capturedOrder.attributionMetadata?['restockRequestId'],
            'req_123',
          );
        },
      );
    });
  });
}
