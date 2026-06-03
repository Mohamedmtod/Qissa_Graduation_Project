import 'dart:typed_data';

import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_write_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_media_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_media_upload_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_media_worker_client.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

enum AdminMediaFolder {
  products('products'),
  banners('banners'),
  categories('categories'),
  general('general');

  const AdminMediaFolder(this.apiValue);
  final String apiValue;
}

abstract class AdminMediaRepository {
  Future<AdminMediaPage> listMedia({
    required AdminMediaFolder folder,
    String? cursor,
    int limit = 60,
  });

  Future<AdminWriteResult<AdminMediaUploadResult>> uploadMedia({
    required AdminMediaFolder folder,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  });

  Future<AdminWriteResult<void>> deleteMedia({required String key});
}

class WorkerAdminMediaRepository implements AdminMediaRepository {
  WorkerAdminMediaRepository(
    this._workerClient,
    this._securityService,
    this._logger, {
    required AdminObservabilityService observability,
  }) : _observability = observability;

  final AdminMediaWorkerClient _workerClient;
  final AdminSecurityService _securityService;
  final AdminActionLogger _logger;
  final AdminObservabilityService _observability;

  @override
  Future<AdminMediaPage> listMedia({
    required AdminMediaFolder folder,
    String? cursor,
    int limit = 60,
  }) async {
    final traceId = _observability.createTraceId('media-list');
    final authContext = await _securityService.requireAuthorizedAdminWithToken(
      operation: 'list media assets',
      traceId: traceId,
    );

    _logger.info(
      'Fetching media page.',
      context: {
        'traceId': traceId,
        'folder': folder.apiValue,
        'cursor': cursor,
        'limit': limit,
      },
    );

    final result = await _workerClient.listMedia(
      bearerToken: authContext.idToken,
      traceId: traceId,
      folder: folder.apiValue,
      cursor: cursor,
      limit: limit,
    );

    _observability.recordAudit(
      AdminAuditEntry(
        traceId: traceId,
        action: 'media_list',
        actorId: authContext.access.user?.uid ?? 'admin_dashboard',
        actorRole: authContext.access.role ?? 'admin',
        targetId: folder.apiValue,
        occurredAt: DateTime.now(),
        outcome: 'success',
        details:
            'items=${result.items.length}, truncated=${result.truncated}, cursor=${result.cursor ?? 'null'}',
      ),
    );

    return result;
  }

  @override
  Future<AdminWriteResult<AdminMediaUploadResult>> uploadMedia({
    required AdminMediaFolder folder,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final traceId = _observability.createTraceId('media-upload');
    final authContext = await _securityService.requireAuthorizedAdminWithToken(
      operation: 'upload media asset',
      traceId: traceId,
    );

    final normalizedName = fileName.trim();
    final normalizedType = contentType.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      throw const AdminOperationFailedException('File name is required.');
    }
    if (normalizedType.isEmpty) {
      throw const AdminOperationFailedException('Content type is required.');
    }
    if (bytes.isEmpty) {
      throw const AdminOperationFailedException('File bytes are empty.');
    }

    _logger.info(
      'Uploading media asset.',
      context: {
        'traceId': traceId,
        'folder': folder.apiValue,
        'fileName': normalizedName,
        'contentType': normalizedType,
        'bytes': bytes.length,
      },
    );

    final uploadResult = await _workerClient.uploadMedia(
      bearerToken: authContext.idToken,
      traceId: traceId,
      input: AdminMediaUploadInput(
        folder: folder.apiValue,
        fileName: normalizedName,
        contentType: normalizedType,
        bytes: bytes,
      ),
    );

    _observability.recordAudit(
      AdminAuditEntry(
        traceId: traceId,
        action: 'media_upload',
        actorId: authContext.access.user?.uid ?? 'admin_dashboard',
        actorRole: authContext.access.role ?? 'admin',
        targetId: uploadResult.key,
        occurredAt: DateTime.now(),
        outcome: 'success',
        details:
            'folder=${folder.apiValue}, size=${uploadResult.size}, url=${uploadResult.url}',
      ),
    );

    return AdminWriteResult(data: uploadResult, traceId: traceId);
  }

  @override
  Future<AdminWriteResult<void>> deleteMedia({required String key}) async {
    final traceId = _observability.createTraceId('media-delete');
    final authContext = await _securityService.requireAuthorizedAdminWithToken(
      operation: 'delete media asset',
      traceId: traceId,
    );

    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      throw const AdminOperationFailedException('Media key is required.');
    }

    _logger.info(
      'Deleting media asset.',
      context: {'traceId': traceId, 'key': normalizedKey},
    );

    await _workerClient.deleteMedia(
      bearerToken: authContext.idToken,
      traceId: traceId,
      key: normalizedKey,
    );

    _observability.recordAudit(
      AdminAuditEntry(
        traceId: traceId,
        action: 'media_delete',
        actorId: authContext.access.user?.uid ?? 'admin_dashboard',
        actorRole: authContext.access.role ?? 'admin',
        targetId: normalizedKey,
        occurredAt: DateTime.now(),
        outcome: 'success',
      ),
    );

    return AdminWriteResult<void>(data: null, traceId: traceId);
  }
}
