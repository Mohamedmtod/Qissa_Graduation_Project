import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_write_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_ai_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_ai_insights_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

abstract class AdminAiInsightsRepository {
  Future<AdminAiInsightsSnapshot> fetchInsightsSnapshot();
  Future<AdminWriteResult<void>> queueModelTraining();
  Future<AdminWriteResult<void>> saveSessionAnnotation({
    required String sessionId,
    required String note,
  });
}

class LocalAdminAiInsightsRepository implements AdminAiInsightsRepository {
  LocalAdminAiInsightsRepository(
    this._service, {
    required AdminSecurityService securityService,
    AdminActionLogger? logger,
    required AdminObservabilityService observability,
  }) : _securityService = securityService,
       _logger = logger,
       _observability = observability;

  final AdminAiInsightsService _service;
  final AdminSecurityService _securityService;
  final AdminActionLogger? _logger;
  final AdminObservabilityService _observability;

  @override
  Future<AdminAiInsightsSnapshot> fetchInsightsSnapshot() {
    return _service.fetchInsightsSnapshot();
  }

  @override
  Future<AdminWriteResult<void>> queueModelTraining() {
    return _secureAiWrite(
      operation: 'queue AI model training',
      action: 'ai_model_training_queue',
      targetId: 'ai_model_training_jobs',
      execute: (_) => _service.queueModelTraining(),
    );
  }

  @override
  Future<AdminWriteResult<void>> saveSessionAnnotation({
    required String sessionId,
    required String note,
  }) {
    return _secureAiWrite(
      operation: 'save AI session annotation',
      action: 'ai_session_annotation_save',
      targetId: sessionId.trim().isEmpty ? 'unknown_session' : sessionId.trim(),
      execute: (actorId) => _service.saveSessionAnnotation(
        sessionId: sessionId.trim(),
        note: note.trim(),
        actorId: actorId,
      ),
      validate: () {
        final normalizedSessionId = sessionId.trim();
        final normalizedNote = note.trim();
        if (normalizedSessionId.isEmpty) {
          throw const AdminPolicyViolationException('Session id is required.');
        }
        if (normalizedNote.isEmpty || normalizedNote.length > 2000) {
          throw const AdminPolicyViolationException(
            'Annotation note must be between 1 and 2000 characters.',
          );
        }
      },
      successDetails: () => 'noteLength=${note.trim().length}',
    );
  }

  Future<AdminWriteResult<void>> _secureAiWrite({
    required String operation,
    required String action,
    required String targetId,
    required Future<void> Function(String actorId) execute,
    void Function()? validate,
    String? Function()? successDetails,
  }) async {
    final traceId = _observability.createTraceId(action);
    var actorId = 'anonymous';
    var actorRole = 'unknown';

    try {
      final auth = await _securityService.requireAuthorizedAdminWithToken(
        operation: operation,
        traceId: traceId,
      );
      actorId = auth.access.user?.uid ?? 'unknown_admin';
      actorRole = auth.access.role ?? 'admin';
      validate?.call();

      _logger?.info(
        'Executing admin AI write.',
        context: {
          'traceId': traceId,
          'action': action,
          'targetId': targetId,
          'actorId': actorId,
        },
      );

      await execute(actorId);
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: traceId,
          action: action,
          actorId: actorId,
          actorRole: actorRole,
          targetId: targetId,
          occurredAt: DateTime.now(),
          outcome: 'success',
          details: successDetails?.call(),
        ),
      );
      return AdminWriteResult<void>(data: null, traceId: traceId);
    } catch (error) {
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: traceId,
          action: action,
          actorId: actorId,
          actorRole: actorRole,
          targetId: targetId,
          occurredAt: DateTime.now(),
          outcome: error is AdminSecurityException ? 'blocked' : 'failed',
          details: error.toString(),
        ),
      );
      rethrow;
    }
  }
}
