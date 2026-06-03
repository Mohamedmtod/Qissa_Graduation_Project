import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/features/ai_chat/data/models/restock_request_model.dart';

class RestockRequestsRepo {
  RestockRequestsRepo({
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

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Dio _dio;
  final String _workerBaseUrl;

  static const String _defaultWorkerBaseUrl = String.fromEnvironment(
    'ORDERS_WORKER_URL',
    defaultValue: 'https://perfume-orders-worker.qessa-prefume.workers.dev',
  );

  Stream<List<RestockRequestModel>> watchMyRequests(String userId) {
    return _firestore
        .collection('restock_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    RestockRequestModel.fromJson({'id': doc.id, ...doc.data()}),
              )
              .toList(),
        );
  }

  Future<Map<String, String>> fetchProductNamesByIds(Set<String> ids) async {
    if (ids.isEmpty) {
      return const <String, String>{};
    }

    final result = <String, String>{};
    final products = _firestore.collection('products');

    for (final id in ids) {
      final doc = await products.doc(id).get();
      if (!doc.exists) {
        result[id] = id;
        continue;
      }
      final data = doc.data() ?? const <String, dynamic>{};
      final name = (data['name'] ?? '').toString().trim();
      result[id] = name.isEmpty ? id : name;
    }

    return result;
  }

  Future<void> cancelRequest({
    required String userId,
    required RestockRequestModel request,
  }) async {
    if (request.status == RestockRequestStatus.converted) {
      throw StateError('Converted requests cannot be cancelled.');
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != userId) {
      throw StateError('User is not authenticated for cancel request.');
    }

    final idToken = await currentUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Failed to fetch Firebase ID token.');
    }

    try {
      await _dio.post<Map<String, dynamic>>(
        '$_workerBaseUrl/user/restock-requests/${request.id}/cancel',
        data: const <String, dynamic>{},
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw StateError(AuthErrorMessages.networkFailed);
      }
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['error'] ?? data['message'] ?? data['details'];
        if (message is String && message.trim().isNotEmpty) {
          final normalized = message.trim();
          if (normalized == 'Converted requests cannot be cancelled.') {
            throw StateError(normalized);
          }
        }
      }
      throw StateError(WorkerErrorMessages.restockRequestFailed);
    }
  }
}
