import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_auth_repository.dart';
import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';

abstract class AdminSecurityException implements Exception {
  const AdminSecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminAuthorizationException extends AdminSecurityException {
  const AdminAuthorizationException(super.message);
}

class AdminPolicyViolationException extends AdminSecurityException {
  const AdminPolicyViolationException(super.message);
}

class AdminOperationFailedException extends AdminSecurityException {
  const AdminOperationFailedException(super.message);
}

class AdminAuthorizationContext {
  const AdminAuthorizationContext({
    required this.access,
    required this.idToken,
  });

  final AdminAccessSnapshot access;
  final String idToken;
}

class AdminSecurityService {
  const AdminSecurityService(
    this._authRepository,
    this._logger,
    this._observability,
  );

  final AdminAuthRepository _authRepository;
  final AdminActionLogger _logger;
  final AdminObservabilityService _observability;

  Future<AdminAccessSnapshot> requireAuthorizedAdmin({
    required String operation,
    String? traceId,
  }) async {
    _logger.debug(
      'Authorizing admin action.',
      context: {'operation': operation},
    );
    final access = await _authRepository.resolveAccess(forceRefresh: true);
    if (access.status == AdminAccessStatus.authorized) {
      _logger.info(
        'Admin action authorized.',
        context: {
          'operation': operation,
          'uid': access.user?.uid ?? 'unknown',
          'role': access.role ?? 'unknown',
        },
      );
      return access;
    }

    final message = switch (access.status) {
      AdminAccessStatus.unauthenticated => AdminLocaleController.globalT(
        'errors.security.loginRequired',
        params: {'operation': operation},
      ),
      AdminAccessStatus.unauthorized => AdminLocaleController.globalT(
        'errors.security.adminRoleRequired',
      ),
      AdminAccessStatus.recoverableFailure => AdminLocaleController.globalT(
        'errors.auth.accessCheckRecoverable',
        params: {'code': access.errorCode ?? 'network'},
      ),
      AdminAccessStatus.authorized => '',
    };
    _logger.warning(
      'Blocked unauthorized admin action.',
      context: {
        'operation': operation,
        'status': access.status.name,
        'role': access.role ?? 'unknown',
      },
    );
    _observability.recordAudit(
      AdminAuditEntry(
        traceId: traceId ?? _observability.createTraceId(operation),
        action: operation,
        actorId: access.user?.uid ?? 'anonymous',
        actorRole: access.role ?? access.status.name,
        targetId: 'admin_console',
        occurredAt: DateTime.now(),
        outcome: 'blocked',
        details: message,
      ),
    );

    throw AdminAuthorizationException(message);
  }

  Future<AdminAuthorizationContext> requireAuthorizedAdminWithToken({
    required String operation,
    String? traceId,
  }) async {
    final access = await requireAuthorizedAdmin(
      operation: operation,
      traceId: traceId,
    );
    // The access check already forced a fresh token, so reuse the cached token here
    // instead of triggering a second network refresh on every write.
    final token = await access.user?.getIdToken();
    if (token == null || token.trim().isEmpty) {
      final message = AdminLocaleController.globalT(
        'errors.security.idTokenRequired',
        params: {'operation': operation},
      );
      throw AdminAuthorizationException(message);
    }
    return AdminAuthorizationContext(access: access, idToken: token);
  }
}
