import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/features/orders/data/models/order_model.dart';

/// Bundles orders with a pagination cursor.
class OrderQueryResult {
  final List<OrderModel> orders;
  final DocumentSnapshot? lastDocument;

  OrderQueryResult({required this.orders, this.lastDocument});
}

class CreatedOrderResult {
  final String orderId;
  final String? orderCode;

  CreatedOrderResult({required this.orderId, this.orderCode});
}

class OrderRepo {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Dio _dio;
  final String _workerBaseUrl;

  static const String _defaultWorkerBaseUrl = String.fromEnvironment(
    'ORDERS_WORKER_URL',
    defaultValue: 'https://perfume-orders-worker.qessa-prefume.workers.dev',
  );

  OrderRepo({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Dio? dio,
    String? workerBaseUrl,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _dio = dio ?? Dio(),
       _workerBaseUrl = (workerBaseUrl ?? _defaultWorkerBaseUrl)
           .trim()
           .replaceAll(RegExp(r'/$'), '');

  // Fetch orders: paginated one-time read.
  Future<OrderQueryResult> fetchMyOrders(
    String uid, {
    DocumentSnapshot? startAfterDocument,
    int limit = 10,
  }) async {
    Query query = _firestore
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.get();

    final orders = snapshot.docs
        .map(
          (doc) => OrderModel.fromMap(
            map: doc.data() as Map<String, dynamic>,
            documentId: doc.id,
          ),
        )
        .toList();

    return OrderQueryResult(
      orders: orders,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }

  // Stream orders: paginated realtime listener.
  Stream<OrderQueryResult> streamMyOrders(String uid, {int limit = 10}) {
    Query query = _firestore
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return query.snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map(
            (doc) => OrderModel.fromMap(
              map: doc.data() as Map<String, dynamic>,
              documentId: doc.id,
            ),
          )
          .toList();

      return OrderQueryResult(
        orders: orders,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    });
  }

  String _buildWorkerUrl(String path) => '$_workerBaseUrl$path';

  String _buildIdempotencyKey(String uid) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${uid}_$now';
  }

  String _extractWorkerError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return AuthErrorMessages.networkFailed;
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['error'] ?? data['message'] ?? data['details'];
      if (message is String && message.trim().isNotEmpty) {
        final normalized = message.trim();
        if (normalized == 'Unsupported payment method') {
          return normalized;
        }
        if (e.response?.statusCode == 409) {
          return 'Order already exists';
        }
      }
    }
    return WorkerErrorMessages.orderRequestFailed;
  }

  Future<String> _requireIdToken() async {
    if (_workerBaseUrl.isEmpty) {
      throw Exception(
        'ORDERS_WORKER_URL is not configured. Run with --dart-define=ORDERS_WORKER_URL=https://<your-worker>.workers.dev',
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to fetch Firebase ID token');
    }

    return idToken;
  }

  // Create order via Cloudflare Worker. Firestore write is done by the worker.
  Future<CreatedOrderResult> createOrder(
    OrderModel order, {
    String? idempotencyKey,
    String? shippingZoneCode,
    String? shippingGovernorate,
    double? clientShippingFee,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }
    final idToken = await _requireIdToken();
    if (order.paymentMethod != PaymentMethodCodes.cashOnDelivery) {
      throw Exception('Unsupported payment method');
    }

    final payload = <String, dynamic>{
      'idempotencyKey': _normalizeIdempotencyKey(idempotencyKey, user.uid),
      'items': order.items
          .map(
            (item) => {
              'productId': item.productId,
              'variantId': item.variantId,
              'quantity': item.quantity,
            },
          )
          .toList(),
      'address': order.address,
      'phone': order.phone,
      'paymentMethod': order.paymentMethod,
      'orderSource': order.orderSource,
      if (order.attributionMetadata != null)
        'attributionMetadata': order.attributionMetadata,
      if (order.notes != null && order.notes!.trim().isNotEmpty)
        'notes': order.notes!.trim(),
      // Shipping zone data for server-side validation & fee computation.
      if (shippingZoneCode != null && shippingZoneCode.isNotEmpty)
        'shippingZoneCode': shippingZoneCode,
      if (shippingGovernorate != null && shippingGovernorate.isNotEmpty)
        'shippingGovernorate': shippingGovernorate,
      // clientShippingFee is informational only; worker ignores it for pricing.
      ...?clientShippingFee == null
          ? null
          : {'clientShippingFee': clientShippingFee},
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _buildWorkerUrl('/orders'),
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

      final body = response.data ?? <String, dynamic>{};
      final orderId = body['orderId'];
      if (orderId is String && orderId.trim().isNotEmpty) {
        final orderCode = body['orderCode'];
        return CreatedOrderResult(
          orderId: orderId.trim(),
          orderCode: orderCode is String && orderCode.trim().isNotEmpty
              ? orderCode.trim()
              : null,
        );
      }

      throw Exception('Worker response missing orderId');
    } on DioException catch (e) {
      throw Exception(_extractWorkerError(e));
    }
  }

  // Cancel an order through Cloudflare Worker.
  Future<void> cancelOrder(String orderId) async {
    if (orderId.trim().isEmpty) {
      throw Exception('orderId is required');
    }

    final idToken = await _requireIdToken();

    try {
      await _dio.post<Map<String, dynamic>>(
        _buildWorkerUrl('/orders/$orderId/cancel'),
        data: const <String, dynamic>{},
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );
    } on DioException catch (e) {
      throw Exception(_extractWorkerError(e));
    }
  }

  // Stream a specific order.
  Stream<OrderModel> getOrderStream(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map(
          (doc) => OrderModel.fromMap(
            map: doc.data() as Map<String, dynamic>,
            documentId: doc.id,
          ),
        );
  }

  String _normalizeIdempotencyKey(String? idempotencyKey, String uid) {
    final normalized = idempotencyKey?.trim();
    if (normalized != null && normalized.length >= 8) {
      return normalized;
    }
    return _buildIdempotencyKey(uid);
  }
}
