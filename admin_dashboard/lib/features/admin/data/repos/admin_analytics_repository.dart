import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_write_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_finance_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/business_config_model.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_analytics_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

abstract class AdminAnalyticsRepository {
  Future<AdminDashboardSnapshot> fetchDashboardSnapshot();

  Future<AdminFinanceSnapshot> fetchFinanceSnapshot();
  Future<BusinessConfigModel> fetchBusinessConfig();
  Future<AdminWriteResult<void>> saveBusinessConfig(BusinessConfigModel config);
}

class LocalAdminAnalyticsRepository implements AdminAnalyticsRepository {
  LocalAdminAnalyticsRepository(
    this._service, {
    required AdminSecurityService securityService,
    AdminActionLogger? logger,
    required AdminObservabilityService observability,
  }) : _securityService = securityService,
       _logger = logger,
       _observability = observability;

  final AdminAnalyticsService _service;
  final AdminSecurityService _securityService;
  final AdminActionLogger? _logger;
  final AdminObservabilityService _observability;

  @override
  Future<AdminDashboardSnapshot> fetchDashboardSnapshot() {
    return _service.fetchDashboardSnapshot();
  }

  @override
  Future<AdminFinanceSnapshot> fetchFinanceSnapshot() {
    return _service.fetchFinanceSnapshot();
  }

  @override
  Future<BusinessConfigModel> fetchBusinessConfig() {
    return _service.fetchBusinessConfig();
  }

  @override
  Future<AdminWriteResult<void>> saveBusinessConfig(
    BusinessConfigModel config,
  ) async {
    final traceId = _observability.createTraceId('analytics-business-config');
    var actorId = 'anonymous';
    var actorRole = 'unknown';

    try {
      final auth = await _securityService.requireAuthorizedAdminWithToken(
        operation: 'save analytics business config',
        traceId: traceId,
      );
      actorId = auth.access.user?.uid ?? 'unknown_admin';
      actorRole = auth.access.role ?? 'admin';
      validateBusinessConfig(config);

      _logger?.info(
        'Saving analytics business config.',
        context: {'traceId': traceId, 'actorId': actorId},
      );

      await _service.saveBusinessConfig(config);
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: traceId,
          action: 'analytics_business_config_save',
          actorId: actorId,
          actorRole: actorRole,
          targetId: 'settings/business_config',
          occurredAt: DateTime.now(),
          outcome: 'success',
          details:
              'server=${config.serverCosts} manufacturing=${config.manufacturingCosts} other=${config.otherFixedCosts}',
        ),
      );
      return AdminWriteResult<void>(data: null, traceId: traceId);
    } catch (error) {
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: traceId,
          action: 'analytics_business_config_save',
          actorId: actorId,
          actorRole: actorRole,
          targetId: 'settings/business_config',
          occurredAt: DateTime.now(),
          outcome: error is AdminSecurityException ? 'blocked' : 'failed',
          details: error.toString(),
        ),
      );
      rethrow;
    }
  }
}
