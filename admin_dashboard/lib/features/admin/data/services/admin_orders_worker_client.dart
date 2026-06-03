import 'package:dio/dio.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_order.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_worker_transition_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

class AdminOrdersWorkerClient {
  AdminOrdersWorkerClient({
    required String baseUrl,
    required String workerApiKey,
    required AdminActionLogger logger,
    Dio? dio,
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/$'), ''),
       _workerApiKey = workerApiKey.trim(),
       _logger = logger,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
             ),
           );

  final Dio _dio;
  final String _baseUrl;
  final String _workerApiKey;
  final AdminActionLogger _logger;

  Future<AdminWorkerTransitionResult> transitionOrderStatus({
    required String orderId,
    required AdminOrderStatus fromStatus,
    required AdminOrderStatus toStatus,
    required String bearerToken,
    required String traceId,
    String? reason,
  }) async {
    final path = '$_baseUrl/admin/orders/$orderId/status';
    final headers = <String, Object?>{
      'Authorization': 'Bearer $bearerToken',
      'Content-Type': 'application/json',
      'X-Trace-Id': traceId,
      if (_workerApiKey.isNotEmpty) 'X-Worker-Api-Key': _workerApiKey,
    };
    final body = <String, Object?>{
      'fromStatus': orderStatusToFirestore(fromStatus),
      'toStatus': orderStatusToFirestore(toStatus),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    try {
      _logger.debug(
        'Sending worker status transition request.',
        context: {
          'traceId': traceId,
          'orderId': orderId,
          'path': path,
          'from': orderStatusToFirestore(fromStatus),
          'to': orderStatusToFirestore(toStatus),
        },
      );
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        options: Options(headers: headers),
      );

      final data = response.data;
      if (response.statusCode != 200 || data is! Map<String, dynamic>) {
        throw AdminOperationFailedException(
          AdminLocaleController.globalT(
            'errors.worker.invalidResponse',
            params: {'traceId': traceId},
          ),
        );
      }

      return AdminWorkerTransitionResult.fromJson(data);
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      final workerMessage = _readWorkerMessage(error.response?.data);

      if (code == 401 || code == 403) {
        throw AdminAuthorizationException(
          workerMessage ??
              AdminLocaleController.globalT(
                'errors.worker.notAuthorized',
                params: {'traceId': traceId},
              ),
        );
      }
      if (code == 409) {
        throw AdminPolicyViolationException(
          workerMessage ??
              AdminLocaleController.globalT(
                'errors.worker.policyRejected',
                params: {'traceId': traceId},
              ),
        );
      }
      if (code != null && code >= 500) {
        throw AdminOperationFailedException(
          workerMessage ??
              AdminLocaleController.globalT(
                'errors.worker.unavailable',
                params: {'code': '$code', 'traceId': traceId},
              ),
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw AdminOperationFailedException(
          AdminLocaleController.globalT(
            'errors.worker.network',
            params: {'traceId': traceId},
          ),
        );
      }

      throw AdminOperationFailedException(
        workerMessage ??
            AdminLocaleController.globalT(
              'errors.worker.unexpectedTransition',
              params: {'traceId': traceId},
            ),
      );
    }
  }
}

String? _readWorkerMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    final directMessage = data['message']?.toString();
    if (directMessage != null && directMessage.trim().isNotEmpty) {
      return directMessage.trim();
    }
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final nestedMessage = error['message']?.toString();
      if (nestedMessage != null && nestedMessage.trim().isNotEmpty) {
        return nestedMessage.trim();
      }
    }
  }
  return null;
}
