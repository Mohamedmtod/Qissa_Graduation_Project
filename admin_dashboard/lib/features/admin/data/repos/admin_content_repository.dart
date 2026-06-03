import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_write_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_content_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_content_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

abstract class AdminContentRepository {
  Future<AdminContentSnapshot> fetchContentSnapshot({int? productLimit});

  Future<AdminWriteResult<void>> createProduct(AdminProductUpsertInput input);
  Future<AdminWriteResult<void>> updateProduct(
    String productId,
    AdminProductUpsertInput input,
  );
  Future<AdminWriteResult<void>> setProductVisibility(
    String productId, {
    required bool visible,
  });
  Future<AdminWriteResult<void>> archiveProduct(String productId);

  Future<AdminWriteResult<void>> createBanner(AdminBannerUpsertInput input);
  Future<AdminWriteResult<void>> updateBanner(
    String bannerId,
    AdminBannerUpsertInput input,
  );
  Future<AdminWriteResult<void>> deleteBanner(String bannerId);
  Future<AdminWriteResult<void>> reorderBanners(List<String> orderedIds);

  Future<AdminWriteResult<void>> createCategory(AdminCategoryUpsertInput input);
  Future<AdminWriteResult<void>> updateCategory(
    String categoryId,
    AdminCategoryUpsertInput input,
  );
  Future<AdminWriteResult<void>> deleteCategory(String categoryId);
  Future<AdminWriteResult<void>> setCategoryVisibility(
    String categoryId, {
    required bool visible,
  });
  Future<AdminWriteResult<void>> reorderCategories(List<String> orderedIds);
  Future<AdminWriteResult<void>> updateBusinessInfo(AdminBusinessInfo input);
  Future<AdminWriteResult<int>> recomputeProductPublicStats();
}

class FirestoreAdminContentRepository implements AdminContentRepository {
  FirestoreAdminContentRepository(
    this._service,
    this._securityService,
    this._logger, {
    required AdminObservabilityService observability,
  }) : _observability = observability;

  final AdminContentService _service;
  final AdminSecurityService _securityService;
  final AdminActionLogger _logger;
  final AdminObservabilityService _observability;

  @override
  Future<AdminContentSnapshot> fetchContentSnapshot({int? productLimit}) {
    return _service.fetchContentSnapshot(
      productLimit: productLimit ?? AdminContentService.defaultProductPageSize,
    );
  }

  @override
  Future<AdminWriteResult<void>> createProduct(AdminProductUpsertInput input) {
    return _secureWrite(
      operation: 'create content product',
      action: 'content_product_create',
      targetId: input.name,
      execute: () => _service.createProduct(input),
    );
  }

  @override
  Future<AdminWriteResult<void>> updateProduct(
    String productId,
    AdminProductUpsertInput input,
  ) {
    return _secureWrite(
      operation: 'update content product',
      action: 'content_product_update',
      targetId: productId,
      execute: () => _service.updateProduct(productId, input),
    );
  }

  @override
  Future<AdminWriteResult<void>> setProductVisibility(
    String productId, {
    required bool visible,
  }) {
    return _secureWrite(
      operation: 'set content product visibility',
      action: 'content_product_visibility',
      targetId: productId,
      execute: () => _service.setProductVisibility(productId, visible: visible),
      details: visible ? 'visible' : 'hidden',
    );
  }

  @override
  Future<AdminWriteResult<void>> archiveProduct(String productId) {
    return _secureWrite(
      operation: 'archive content product',
      action: 'content_product_archive',
      targetId: productId,
      execute: () => _service.archiveProduct(productId),
    );
  }

  @override
  Future<AdminWriteResult<void>> createBanner(AdminBannerUpsertInput input) {
    return _secureWrite(
      operation: 'create content banner',
      action: 'content_banner_create',
      targetId: input.title,
      execute: () => _service.createBanner(input),
    );
  }

  @override
  Future<AdminWriteResult<void>> updateBanner(
    String bannerId,
    AdminBannerUpsertInput input,
  ) {
    return _secureWrite(
      operation: 'update content banner',
      action: 'content_banner_update',
      targetId: bannerId,
      execute: () => _service.updateBanner(bannerId, input),
    );
  }

  @override
  Future<AdminWriteResult<void>> deleteBanner(String bannerId) {
    return _secureWrite(
      operation: 'delete content banner',
      action: 'content_banner_delete',
      targetId: bannerId,
      execute: () => _service.deleteBanner(bannerId),
    );
  }

  @override
  Future<AdminWriteResult<void>> reorderBanners(List<String> orderedIds) {
    return _secureWrite(
      operation: 'reorder content banners',
      action: 'content_banner_reorder',
      targetId: 'banner_collection',
      execute: () => _service.reorderBanners(orderedIds),
      details: orderedIds.join(','),
    );
  }

  @override
  Future<AdminWriteResult<void>> createCategory(
    AdminCategoryUpsertInput input,
  ) {
    return _secureWrite(
      operation: 'create content category',
      action: 'content_category_create',
      targetId: input.name,
      execute: () => _service.createCategory(input),
    );
  }

  @override
  Future<AdminWriteResult<void>> updateCategory(
    String categoryId,
    AdminCategoryUpsertInput input,
  ) {
    return _secureWrite(
      operation: 'update content category',
      action: 'content_category_update',
      targetId: categoryId,
      execute: () => _service.updateCategory(categoryId, input),
    );
  }

  @override
  Future<AdminWriteResult<void>> deleteCategory(String categoryId) {
    return _secureWrite(
      operation: 'delete content category',
      action: 'content_category_delete',
      targetId: categoryId,
      execute: () => _service.deleteCategory(categoryId),
    );
  }

  @override
  Future<AdminWriteResult<void>> setCategoryVisibility(
    String categoryId, {
    required bool visible,
  }) {
    return _secureWrite(
      operation: 'set content category visibility',
      action: 'content_category_visibility',
      targetId: categoryId,
      execute: () =>
          _service.setCategoryVisibility(categoryId, visible: visible),
      details: visible ? 'visible' : 'hidden',
    );
  }

  @override
  Future<AdminWriteResult<void>> reorderCategories(List<String> orderedIds) {
    return _secureWrite(
      operation: 'reorder content categories',
      action: 'content_category_reorder',
      targetId: 'category_collection',
      execute: () => _service.reorderCategories(orderedIds),
      details: orderedIds.join(','),
    );
  }

  @override
  Future<AdminWriteResult<void>> updateBusinessInfo(AdminBusinessInfo input) {
    return _secureWrite(
      operation: 'update store business info',
      action: 'content_business_info_update',
      targetId: 'config/business_info',
      execute: () => _service.updateBusinessInfo(input),
    );
  }

  @override
  Future<AdminWriteResult<int>> recomputeProductPublicStats() async {
    final traceId = _observability.createTraceId(
      'content_product_stats_recompute',
    );
    final auth = await _securityService.requireAuthorizedAdminWithToken(
      operation: 'recompute product public stats',
      traceId: traceId,
    );
    _logger.info(
      'Recomputing product public stats.',
      context: {
        'traceId': traceId,
        'action': 'content_product_stats_recompute',
      },
    );
    final count = await _service.recomputeProductPublicStats();
    _observability.recordAudit(
      AdminAuditEntry(
        traceId: traceId,
        action: 'content_product_stats_recompute',
        actorId: auth.access.user?.uid ?? 'admin_dashboard',
        actorRole: auth.access.role ?? 'admin',
        targetId: 'product_public_stats',
        occurredAt: DateTime.now(),
        outcome: 'success',
        details: 'updated=$count',
      ),
    );
    return AdminWriteResult<int>(data: count, traceId: traceId);
  }

  Future<AdminWriteResult<void>> _secureWrite({
    required String operation,
    required String action,
    required String targetId,
    required Future<void> Function() execute,
    String? details,
  }) async {
    final traceId = _observability.createTraceId(action);
    final auth = await _securityService.requireAuthorizedAdminWithToken(
      operation: operation,
      traceId: traceId,
    );
    _logger.info(
      'Executing admin content write.',
      context: {'traceId': traceId, 'action': action, 'targetId': targetId},
    );
    await execute();
    _observability.recordAudit(
      AdminAuditEntry(
        traceId: traceId,
        action: action,
        actorId: auth.access.user?.uid ?? 'admin_dashboard',
        actorRole: auth.access.role ?? 'admin',
        targetId: targetId,
        occurredAt: DateTime.now(),
        outcome: 'success',
        details: details,
      ),
    );
    return AdminWriteResult<void>(data: null, traceId: traceId);
  }
}
