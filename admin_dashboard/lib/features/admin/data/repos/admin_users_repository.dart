import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_write_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_user_record.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_users_worker_client.dart';

abstract class AdminUsersRepository {
  Stream<List<AdminUserRecord>> watchUsers();

  Future<AdminWriteResult<AdminUserRoleUpdateResult>> updateUserRole({
    required AdminUserRecord user,
    required String role,
  });
}

class FirestoreAdminUsersRepository implements AdminUsersRepository {
  FirestoreAdminUsersRepository(
    this._workerClient,
    this._securityService,
    this._logger, {
    required AdminObservabilityService observability,
    FirebaseFirestore? firestore,
  }) : _observability = observability,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final AdminUsersWorkerClient _workerClient;
  final AdminSecurityService _securityService;
  final AdminActionLogger _logger;
  final AdminObservabilityService _observability;

  @override
  Stream<List<AdminUserRecord>> watchUsers() {
    return _firestore.collection('users').limit(200).snapshots().map((
      snapshot,
    ) {
      final users = snapshot.docs
          .map(AdminUserRecord.fromDoc)
          .toList(growable: false);
      return users.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Future<AdminWriteResult<AdminUserRoleUpdateResult>> updateUserRole({
    required AdminUserRecord user,
    required String role,
  }) async {
    final traceId = _observability.createTraceId('user-role-update');
    var actorUid = 'anonymous';
    var actorRole = 'unknown';
    var targetRole = role.trim().toLowerCase();
    var auditRecorded = false;

    try {
      final normalizedRole = _normalizeRole(role);
      targetRole = normalizedRole;
      final authContext = await _securityService
          .requireAuthorizedAdminWithToken(
            operation: 'update user role',
            traceId: traceId,
          );
      actorUid = authContext.access.user?.uid ?? 'unknown_admin';
      actorRole = authContext.access.role ?? 'admin';

      if (user.id == actorUid && normalizedRole != 'admin') {
        final message = AdminLocaleController.globalT(
          'users.role.selfDemoteBlocked',
          params: {'traceId': traceId},
          fallback: 'You cannot remove your own admin access.',
        );
        _observability.recordAudit(
          AdminAuditEntry(
            traceId: traceId,
            action: 'admin_user_role_update',
            actorId: actorUid,
            actorRole: actorRole,
            targetId: user.id,
            occurredAt: DateTime.now(),
            outcome: 'blocked',
            details: 'self-demotion blocked',
          ),
        );
        auditRecorded = true;
        throw AdminPolicyViolationException(message);
      }

      if (user.role == normalizedRole) {
        final result = AdminUserRoleUpdateResult(
          ok: true,
          uid: user.id,
          role: normalizedRole,
          traceId: traceId,
        );
        _observability.recordAudit(
          AdminAuditEntry(
            traceId: traceId,
            action: 'admin_user_role_update',
            actorId: actorUid,
            actorRole: actorRole,
            targetId: user.id,
            occurredAt: DateTime.now(),
            outcome: 'success',
            details: 'role unchanged role=$normalizedRole',
          ),
        );
        auditRecorded = true;
        return AdminWriteResult(data: result, traceId: traceId);
      }

      _logger.info(
        'Requested user role update.',
        context: {
          'traceId': traceId,
          'targetUid': user.id,
          'oldRole': user.role,
          'newRole': normalizedRole,
        },
      );

      final result = await _workerClient.updateUserRole(
        uid: user.id,
        role: normalizedRole,
        bearerToken: authContext.idToken,
        traceId: traceId,
      );

      _logger.info(
        'User role update applied by worker.',
        context: {
          'traceId': result.traceId,
          'targetUid': result.uid,
          'newRole': result.role,
        },
      );

      _observability.recordAudit(
        AdminAuditEntry(
          traceId: result.traceId,
          action: 'admin_user_role_update',
          actorId: actorUid,
          actorRole: actorRole,
          targetId: user.id,
          occurredAt: DateTime.now(),
          outcome: 'success',
          details: 'role ${user.role} -> ${result.role}',
        ),
      );
      auditRecorded = true;

      return AdminWriteResult(data: result, traceId: result.traceId);
    } catch (error) {
      if (auditRecorded) {
        rethrow;
      }
      final outcome =
          error is AdminAuthorizationException ||
              error is AdminPolicyViolationException
          ? 'blocked'
          : 'failed';
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: traceId,
          action: 'admin_user_role_update',
          actorId: actorUid,
          actorRole: actorRole,
          targetId: user.id,
          occurredAt: DateTime.now(),
          outcome: outcome,
          details: 'targetRole=$targetRole error=$error',
        ),
      );
      rethrow;
    }
  }

  String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'user' || normalized == 'admin') {
      return normalized;
    }
    throw AdminPolicyViolationException(
      AdminLocaleController.globalT(
        'users.role.invalid',
        params: {'role': role},
        fallback: 'Role must be user or admin.',
      ),
    );
  }
}
