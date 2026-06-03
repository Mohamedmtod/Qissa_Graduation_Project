import '../models/shipping_zone_model.dart';
import '../repos/admin_shipping_zones_repository.dart';
import 'admin_security_service.dart';
import '../../../../core/observability/admin_observability_service.dart';

/// Auditable shipping zones service with security checks.
class AdminShippingZonesService {
  const AdminShippingZonesService(
    this._repository,
    this._security,
    this._observability,
  );

  final AdminShippingZonesRepository _repository;
  final AdminSecurityService _security;
  final AdminObservabilityService _observability;

  /// Fetch all shipping zones with authorization.
  Future<List<ShippingZoneModel>> fetchShippingZones({String? traceId}) async {
    final operationId = traceId ?? _observability.createTraceId('fetch-zones');

    try {
      // Check authorization
      final access = await _security.requireAuthorizedAdmin(
        operation: 'fetch_shipping_zones',
        traceId: operationId,
      );

      // Fetch zones from repository
      final zones = await _repository.getShippingZones();

      // Record successful fetch
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: operationId,
          action: 'fetch_shipping_zones',
          actorId: access.user?.uid ?? 'admin_console',
          actorRole: access.role ?? 'admin',
          targetId: 'shipping_zones',
          occurredAt: DateTime.now(),
          outcome: 'success',
          details: 'Fetched ${zones.length} shipping zones',
        ),
      );

      return zones;
    } on AdminSecurityException catch (e) {
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: operationId,
          action: 'fetch_shipping_zones',
          actorId: 'admin_console',
          actorRole: 'admin',
          targetId: 'shipping_zones',
          occurredAt: DateTime.now(),
          outcome: 'blocked',
          details: e.toString(),
        ),
      );
      rethrow;
    } catch (e) {
      // Record failure
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: operationId,
          action: 'fetch_shipping_zones',
          actorId: 'admin_console',
          actorRole: 'admin',
          targetId: 'shipping_zones',
          occurredAt: DateTime.now(),
          outcome: 'failed',
          details: 'Error: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  /// Update shipping zones with authorization and audit.
  Future<void> updateShippingZones(
    List<ShippingZoneModel> zones, {
    String? traceId,
  }) async {
    final operationId = traceId ?? _observability.createTraceId('update-zones');
    var actorId = 'admin_console';
    var actorRole = 'admin';

    try {
      final access = await _security.requireAuthorizedAdminWithToken(
        operation: 'update_shipping_zones',
        traceId: operationId,
      );
      actorId = access.access.user?.uid ?? actorId;
      actorRole = access.access.role ?? actorRole;

      // Validate input
      if (zones.isEmpty) {
        throw AdminPolicyViolationException('Cannot save empty zones list');
      }

      // Check for corrupted zones
      final corrupted = zones.where((z) => z.hasCorruptedText).toList();
      if (corrupted.isNotEmpty) {
        throw AdminPolicyViolationException(
          'Found ${corrupted.length} zones with corrupted text',
        );
      }

      // Update zones in repository
      await _repository.updateShippingZones(zones, traceId: operationId);

      _observability.recordAudit(
        AdminAuditEntry(
          traceId: operationId,
          action: 'update_shipping_zones',
          actorId: actorId,
          actorRole: actorRole,
          targetId: 'shipping_zones',
          occurredAt: DateTime.now(),
          outcome: 'success',
          details: 'Updated ${zones.length} zones',
        ),
      );
    } catch (e) {
      // Record failure - catches all exceptions including security/policy ones
      final outcome = e is AdminSecurityException ? 'blocked' : 'failed';
      final details = e is AdminPolicyViolationException
          ? 'Policy violation: invalid zones'
          : e.toString();

      _observability.recordAudit(
        AdminAuditEntry(
          traceId: operationId,
          action: 'update_shipping_zones',
          actorId: actorId,
          actorRole: actorRole,
          targetId: 'shipping_zones',
          occurredAt: DateTime.now(),
          outcome: outcome,
          details: details,
        ),
      );
      rethrow;
    }
  }

  /// Seed initial data with authorization.
  Future<void> seedInitialData({String? traceId}) async {
    final operationId = traceId ?? _observability.createTraceId('seed-zones');

    try {
      // Check authorization
      final access = await _security.requireAuthorizedAdmin(
        operation: 'seed_shipping_zones',
        traceId: operationId,
      );

      // Seed repository
      await _repository.seedInitialData();

      // Record seed operation
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: operationId,
          action: 'seed_shipping_zones',
          actorId: access.user?.uid ?? 'admin_console',
          actorRole: access.role ?? 'admin',
          targetId: 'shipping_zones',
          occurredAt: DateTime.now(),
          outcome: 'success',
          details: 'Seeded initial shipping zones',
        ),
      );
    } on AdminSecurityException catch (e) {
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: operationId,
          action: 'seed_shipping_zones',
          actorId: 'admin_console',
          actorRole: 'admin',
          targetId: 'shipping_zones',
          occurredAt: DateTime.now(),
          outcome: 'blocked',
          details: e.toString(),
        ),
      );
      rethrow;
    } catch (e) {
      // Record failure
      _observability.recordAudit(
        AdminAuditEntry(
          traceId: operationId,
          action: 'seed_shipping_zones',
          actorId: 'admin_console',
          actorRole: 'admin',
          targetId: 'shipping_zones',
          occurredAt: DateTime.now(),
          outcome: 'failed',
          details: 'Error: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }
}
