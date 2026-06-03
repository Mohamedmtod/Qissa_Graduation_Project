import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/features/orders/data/models/order_model.dart';
import 'package:perfume_app/features/orders/data/repos/order_repo.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockDio extends Mock implements Dio {}

void main() {
  late OrderRepo orderRepo;
  late MockFirestore mockFirestore;
  late MockAuth mockAuth;
  late MockUser mockUser;
  late MockDio mockDio;
  const String workerUrl = 'https://test-worker.dev';

  setUp(() {
    mockFirestore = MockFirestore();
    mockAuth = MockAuth();
    mockUser = MockUser();
    mockDio = MockDio();

    orderRepo = OrderRepo(
      firestore: mockFirestore,
      auth: mockAuth,
      dio: mockDio,
      workerBaseUrl: workerUrl,
    );

    registerFallbackValue(Options());
  });

  group('OrderRepo Preconditions', () {
    test('throws Exception if workerBaseUrl is empty', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      // ALWAYS pass mockFirestore to avoid FirebaseFirestore.instance
      final repo = OrderRepo(
        auth: mockAuth,
        firestore: mockFirestore,
        workerBaseUrl: '',
      );

      try {
        await repo.createOrder(
          OrderModel(
            id: '',
            userId: 'u1',
            items: [],
            total: 0,
            status: 'p',
            address: 'a',
            phone: 'p',
            paymentMethod: 'c',
            createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
          ),
        );
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains('ORDERS_WORKER_URL is not configured'));
      }
    });

    test('throws Exception if user is not authenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      try {
        await orderRepo.createOrder(
          OrderModel(
            id: '',
            userId: 'u1',
            items: [],
            total: 0,
            status: 'p',
            address: 'a',
            phone: 'p',
            paymentMethod: 'c',
            createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
          ),
        );
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains('User is not authenticated'));
      }
    });

    test('throws Exception if idToken fetch fails', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => null);

      try {
        await orderRepo.createOrder(
          OrderModel(
            id: '',
            userId: 'u1',
            items: [],
            total: 0,
            status: 'p',
            address: 'a',
            phone: 'p',
            paymentMethod: 'c',
            createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
          ),
        );
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains('Failed to fetch Firebase ID token'));
      }
    });
  });

  group('OrderRepo.createOrder', () {
    final testOrder = OrderModel(
      id: '',
      userId: 'u1',
      items: [],
      total: 10,
      status: 'p',
      address: 'addr',
      phone: '123',
      paymentMethod: PaymentMethodCodes.cashOnDelivery,
      createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
    );

    setUp(() {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'fake-token');
    });

    test('returns orderId on success (200 OK)', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {'orderId': 'new-order-123'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final result = await orderRepo.createOrder(testOrder);
      expect(result.orderId, 'new-order-123');

      final captured =
          verify(
                () => mockDio.post<Map<String, dynamic>>(
                  any(),
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.first
              as Map<String, dynamic>;

      expect(captured['idempotencyKey'], isNotNull);
      expect(captured['idempotencyKey'], isNotEmpty);
      expect(captured['idempotencyKey'], startsWith('u1_'));
    });

    test('includes orderSource in payload', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {'orderId': 'new-order-123'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final orderWithSource = OrderModel(
        id: '',
        userId: 'u1',
        items: [],
        total: 10,
        status: 'p',
        address: 'addr',
        phone: '123',
        paymentMethod: PaymentMethodCodes.cashOnDelivery,
        orderSource: 'ai_chat',
        createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
      );

      await orderRepo.createOrder(orderWithSource);

      final captured =
          verify(
                () => mockDio.post<Map<String, dynamic>>(
                  any(),
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.first
              as Map<String, dynamic>;

      expect(captured['orderSource'], 'ai_chat');
    });

    test('throws Exception on Worker error (e.g. 409 Conflict)', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          response: Response(
            data: {'error': 'Order already exists'},
            statusCode: 409,
            requestOptions: RequestOptions(path: ''),
          ),
          requestOptions: RequestOptions(path: ''),
        ),
      );

      try {
        await orderRepo.createOrder(testOrder);
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains('Order already exists'));
      }
    });

    test('throws Exception on Network/Timeout error', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.connectionTimeout,
          message: 'Connection Timeout',
          requestOptions: RequestOptions(path: ''),
        ),
      );

      try {
        await orderRepo.createOrder(testOrder);
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains(AuthErrorMessages.networkFailed));
      }
    });

    test('does not expose internal Worker error details', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          response: Response(
            data: {'error': 'Missing SERVICE_ACCOUNT_JSON secret'},
            statusCode: 500,
            requestOptions: RequestOptions(path: ''),
          ),
          requestOptions: RequestOptions(path: ''),
        ),
      );

      try {
        await orderRepo.createOrder(testOrder);
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains(WorkerErrorMessages.orderRequestFailed));
        expect(e.toString(), isNot(contains('SERVICE_ACCOUNT_JSON')));
      }
    });

    test('throws Exception if orderId is missing in response', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      try {
        await orderRepo.createOrder(testOrder);
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains('Worker response missing orderId'));
      }
    });
  });

  group('OrderRepo.cancelOrder', () {
    setUp(() {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'fake-token');
    });

    test('completes on success', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async =>
            Response(statusCode: 200, requestOptions: RequestOptions(path: '')),
      );

      await expectLater(orderRepo.cancelOrder('o1'), completes);
    });

    test('throws Exception on 403 Forbidden', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          response: Response(
            data: {'details': 'Not your order'},
            statusCode: 403,
            requestOptions: RequestOptions(path: ''),
          ),
          requestOptions: RequestOptions(path: ''),
        ),
      );

      try {
        await orderRepo.cancelOrder('o1');
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains(WorkerErrorMessages.orderRequestFailed));
        expect(e.toString(), isNot(contains('Not your order')));
      }
    });
  });
}
