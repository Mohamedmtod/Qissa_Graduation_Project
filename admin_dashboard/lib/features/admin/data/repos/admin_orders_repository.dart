import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_write_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_order.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_firestore_orders_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_orders_worker_client.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

abstract class AdminOrdersRepository {
  Future<AdminOrdersPage> fetchOrdersPage({
    required int pageSize,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
    AdminOrderStatus? statusFilter,
    AdminOrderDateFilter dateFilter = AdminOrderDateFilter.all,
    String searchQuery = '',
  });

  Future<AdminWriteResult<AdminOrder>> transitionOrder({
    required AdminOrder order,
    required AdminOrderStatus nextStatus,
    String actorId = 'admin_dashboard',
    AdminTimelineActorRole actorRole = AdminTimelineActorRole.admin,
    AdminTimelineSource source = AdminTimelineSource.adminDashboard,
  });
}

class AdminOrdersPage {
  const AdminOrdersPage({
    required this.orders,
    required this.hasNextPage,
    required this.lastDocument,
  });

  final List<AdminOrder> orders;
  final bool hasNextPage;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class FirestoreAdminOrdersRepository implements AdminOrdersRepository {
  FirestoreAdminOrdersRepository(
    this._firestoreService,
    this._workerClient,
    this._securityService,
    this._logger, {
    required AdminObservabilityService observability,
    required this.ordersWorkerBaseUrl,
    required this.useWorkerTransitions,
  }) : _observability = observability;

  final FirestoreAdminOrdersService _firestoreService;
  final AdminOrdersWorkerClient _workerClient;
  final AdminSecurityService _securityService;
  final AdminActionLogger _logger;
  final AdminObservabilityService _observability;
  final String ordersWorkerBaseUrl;
  final bool useWorkerTransitions;

  @override
  Future<AdminOrdersPage> fetchOrdersPage({
    required int pageSize,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
    AdminOrderStatus? statusFilter,
    AdminOrderDateFilter dateFilter = AdminOrderDateFilter.all,
    String searchQuery = '',
  }) async {
    _logger.debug(
      'Fetching orders page from Firestore.',
      context: {
        'ordersWorkerBaseUrl': ordersWorkerBaseUrl,
        'pageSize': pageSize,
        'statusFilter': statusFilter?.name ?? 'all',
        'dateFilter': dateFilter.name,
        'hasCursor': startAfter != null,
        'hasSearch': searchQuery.trim().isNotEmpty,
      },
    );
    final page = await _firestoreService.fetchOrdersPage(
      pageSize: pageSize,
      startAfter: startAfter,
      statusFilter: statusFilter,
      dateFilter: dateFilter,
      searchQuery: searchQuery,
    );
    return AdminOrdersPage(
      orders: page.orders,
      hasNextPage: page.hasNextPage,
      lastDocument: page.lastDocument,
    );
  }

  @override
  Future<AdminWriteResult<AdminOrder>> transitionOrder({
    required AdminOrder order,
    required AdminOrderStatus nextStatus,
    String actorId = 'admin_dashboard',
    AdminTimelineActorRole actorRole = AdminTimelineActorRole.admin,
    AdminTimelineSource source = AdminTimelineSource.adminDashboard,
  }) async {
    final traceId = _observability.createTraceId('order-transition');
    final authContext = await _securityService.requireAuthorizedAdminWithToken(
      operation: 'transition order statuses',
      traceId: traceId,
    );
    final access = authContext.access;
    _logger.info(
      'Requested order status transition.',
      context: {
        'traceId': traceId,
        'orderId': order.id,
        'fromStatus': order.status.name,
        'nextStatus': nextStatus.name,
        'actorId': actorId,
        'endpoint': ordersWorkerBaseUrl,
      },
    );

    final decision = validateAdminOrderTransition(
      current: order.status,
      next: nextStatus,
    );
    if (!decision.isAllowed) {
      _logger.warning(
        'Blocked invalid order transition.',
        context: {
          'traceId': traceId,
          'orderId': order.id,
          'fromStatus': order.status.name,
          'nextStatus': nextStatus.name,
          'reason': decision.reason ?? 'unknown',
        },
      );
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: traceId,
          action: 'order_status_transition',
          actorId: access.user?.uid ?? actorId,
          actorRole: access.role ?? actorRole.name,
          targetId: order.id,
          occurredAt: DateTime.now(),
          outcome: 'blocked',
          details: decision.reason,
        ),
      );
      throw AdminPolicyViolationException(
        decision.reason ??
            AdminLocaleController.globalT(
              'errors.orders.policyRejectedByStateMachine',
            ),
      );
    }

    if (!useWorkerTransitions) {
      throw AdminOperationFailedException(
        AdminLocaleController.globalT(
          'errors.orders.workerTransitionsDisabled',
          params: {'traceId': traceId},
        ),
      );
    }

    try {
      final result = await _workerClient.transitionOrderStatus(
        orderId: order.id,
        fromStatus: order.status,
        toStatus: nextStatus,
        bearerToken: authContext.idToken,
        traceId: traceId,
      );
      final syncedOrder = await _firestoreService.fetchOrderById(order.id);
      if (syncedOrder == null) {
        throw AdminOperationFailedException(
          AdminLocaleController.globalT(
            'errors.orders.syncedOrderMissing',
            params: {'traceId': traceId},
          ),
        );
      }

      _logger.info(
        'Order status transition applied by worker.',
        context: {
          'traceId': traceId,
          'orderId': order.id,
          'fromStatus': order.status.name,
          'toStatus': nextStatus.name,
          'endpoint': ordersWorkerBaseUrl,
          'workerFrom': result.fromStatus,
          'workerTo': result.toStatus,
          'restocked': result.restocked,
        },
      );
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: traceId,
          action: 'order_status_transition',
          actorId: access.user?.uid ?? actorId,
          actorRole: access.role ?? actorRole.name,
          targetId: order.id,
          occurredAt: DateTime.now(),
          outcome: 'success',
          details:
              '${order.status.name} -> ${nextStatus.name} (worker: ${result.fromStatus} -> ${result.toStatus})',
        ),
      );

      return AdminWriteResult(data: syncedOrder, traceId: traceId);
    } on AdminSecurityException catch (error) {
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: traceId,
          action: 'order_status_transition',
          actorId: access.user?.uid ?? actorId,
          actorRole: access.role ?? actorRole.name,
          targetId: order.id,
          occurredAt: DateTime.now(),
          outcome: error is AdminPolicyViolationException
              ? 'blocked'
              : 'failed',
          details: error.message,
        ),
      );
      rethrow;
    }
  }
}
