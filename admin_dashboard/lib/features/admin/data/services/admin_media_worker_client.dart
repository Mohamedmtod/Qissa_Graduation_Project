import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_media_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_media_upload_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

class AdminMediaUploadInput {
  const AdminMediaUploadInput({
    required this.folder,
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String folder;
  final String fileName;
  final String contentType;
  final Uint8List bytes;
}

class AdminMediaWorkerClient {
  AdminMediaWorkerClient({
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
               connectTimeout: const Duration(seconds: 12),
               receiveTimeout: const Duration(seconds: 30),
             ),
           );

  final Dio _dio;
  final String _baseUrl;
  final String _workerApiKey;
  final AdminActionLogger _logger;

  Future<AdminMediaPage> listMedia({
    required String bearerToken,
    required String traceId,
    required String folder,
    String? cursor,
    int limit = 60,
  }) async {
    final path = '$_baseUrl/admin/media';
    final headers = _headers(bearerToken, traceId);
    final queryParameters = <String, dynamic>{
      'prefix': folder,
      'limit': limit,
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };

    try {
      _logger.debug(
        'Sending media list request.',
        context: {
          'traceId': traceId,
          'path': path,
          'folder': folder,
          'cursor': cursor,
          'limit': limit,
        },
      );
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      final data = _expectObjectBody(response, traceId);
      final page = AdminMediaPage.fromJson(data);
      final preview = page.items
          .take(3)
          .map(
            (item) =>
                '{key=${item.key}, url=${item.url}, type=${item.contentType}, size=${item.size}}',
          )
          .join(', ');
      _logger.debug(
        'Media list response parsed.',
        context: {
          'traceId': traceId,
          'itemsCount': page.items.length,
          'truncated': page.truncated,
          'cursor': page.cursor,
          'preview': preview,
        },
      );
      return page;
    } on DioException catch (error) {
      throw _mapDioError(error, traceId);
    } on FormatException catch (error) {
      throw AdminOperationFailedException(
        '${AdminLocaleController.globalT('errors.worker.invalidResponse', params: {'traceId': traceId})} (${error.message})',
      );
    }
  }

  Future<AdminMediaUploadResult> uploadMedia({
    required String bearerToken,
    required String traceId,
    required AdminMediaUploadInput input,
  }) async {
    final path = '$_baseUrl/admin/media/upload';
    final headers = _headers(bearerToken, traceId)..remove('Content-Type');
    final formData = FormData.fromMap({
      'folder': input.folder.trim(),
      'filename': input.fileName.trim(),
      'file': MultipartFile.fromBytes(
        input.bytes,
        filename: input.fileName.trim(),
        contentType: DioMediaType.parse(input.contentType),
      ),
    });

    try {
      _logger.debug(
        'Sending media upload request.',
        context: {
          'traceId': traceId,
          'path': path,
          'folder': input.folder,
          'fileName': input.fileName,
          'bytes': input.bytes.length,
          'contentType': input.contentType,
        },
      );
      final response = await _dio.post<dynamic>(
        path,
        data: formData,
        options: Options(headers: headers),
      );
      final data = _expectObjectBody(response, traceId);
      final result = AdminMediaUploadResult.fromJson(data);
      _logger.debug(
        'Media upload response parsed.',
        context: {
          'traceId': traceId,
          'key': result.key,
          'url': result.url,
          'size': result.size,
        },
      );
      return result;
    } on DioException catch (error) {
      throw _mapDioError(error, traceId);
    } on FormatException catch (error) {
      throw AdminOperationFailedException(
        '${AdminLocaleController.globalT('errors.worker.invalidResponse', params: {'traceId': traceId})} (${error.message})',
      );
    }
  }

  Future<void> deleteMedia({
    required String bearerToken,
    required String traceId,
    required String key,
  }) async {
    final normalizedKey = key.trim();
    final encodedSegments = normalizedKey
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    final path = '$_baseUrl/admin/media/$encodedSegments';
    final headers = _headers(bearerToken, traceId);

    try {
      _logger.debug(
        'Sending media delete request.',
        context: {'traceId': traceId, 'path': path, 'key': normalizedKey},
      );
      final response = await _dio.delete<dynamic>(
        path,
        options: Options(headers: headers),
      );
      _expectObjectBody(response, traceId);
    } on DioException catch (error) {
      throw _mapDioError(error, traceId);
    }
  }

  Map<String, Object?> _headers(String bearerToken, String traceId) {
    return <String, Object?>{
      'Authorization': 'Bearer $bearerToken',
      'Content-Type': 'application/json',
      'X-Trace-Id': traceId,
      if (_workerApiKey.isNotEmpty) 'X-Worker-Api-Key': _workerApiKey,
    };
  }

  Map<String, dynamic> _expectObjectBody(
    Response<dynamic> response,
    String traceId,
  ) {
    final data = response.data;
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! > 299 ||
        data is! Map<String, dynamic>) {
      throw AdminOperationFailedException(
        AdminLocaleController.globalT(
          'errors.worker.invalidResponse',
          params: {'traceId': traceId},
        ),
      );
    }
    return data;
  }

  AdminSecurityException _mapDioError(DioException error, String traceId) {
    final statusCode = error.response?.statusCode;
    final workerMessage = _readWorkerMessage(error.response?.data);

    _logger.warning(
      'Media worker request failed.',
      context: {
        'traceId': traceId,
        'statusCode': statusCode,
        'dioType': error.type.name,
        'workerMessage': workerMessage,
      },
    );

    if (statusCode == 401 || statusCode == 403) {
      return AdminAuthorizationException(
        workerMessage ??
            AdminLocaleController.globalT(
              'errors.worker.notAuthorized',
              params: {'traceId': traceId},
            ),
      );
    }
    if (statusCode == 409) {
      return AdminPolicyViolationException(
        workerMessage ??
            AdminLocaleController.globalT(
              'errors.worker.policyRejected',
              params: {'traceId': traceId},
            ),
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return AdminOperationFailedException(
        workerMessage ??
            AdminLocaleController.globalT(
              'errors.worker.unavailable',
              params: {'code': '$statusCode', 'traceId': traceId},
            ),
      );
    }
    if (statusCode == 413) {
      return AdminOperationFailedException(
        workerMessage ?? 'Image file is too large.',
      );
    }
    if (statusCode == 415) {
      return AdminOperationFailedException(
        workerMessage ?? 'Unsupported image format.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return AdminOperationFailedException(
        AdminLocaleController.globalT(
          'errors.worker.network',
          params: {'traceId': traceId},
        ),
      );
    }

    return AdminOperationFailedException(
      workerMessage ??
          AdminLocaleController.globalT(
            'errors.worker.invalidResponse',
            params: {'traceId': traceId},
          ),
    );
  }
}

String? _readWorkerMessage(dynamic data) {
  if (data is Map) {
    final normalized = <String, dynamic>{
      for (final entry in data.entries) entry.key.toString(): entry.value,
    };
    final message = normalized['message']?.toString();
    if (message != null && message.trim().isNotEmpty) {
      return message.trim();
    }
    final error = normalized['error']?.toString();
    if (error != null && error.trim().isNotEmpty) {
      return error.trim();
    }
  }
  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }
  return null;
}
