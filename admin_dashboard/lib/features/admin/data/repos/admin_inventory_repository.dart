import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_write_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_restock_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_restock_request_receipt.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_inventory_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/staff_taste_intelligence.dart';

abstract class AdminInventoryRepository {
  Future<AdminInventorySnapshot> fetchInventorySnapshot();

  Future<AdminWriteResult<String>> createInventoryItem({
    required String name,
    required String nameAr,
    required String brand,
    required String brandAr,
    required List<String> aliases,
    required List<String> aliasesAr,
    required String description,
    required double price,
    String? size,
    double? salePrice,
    required String collection,
    required int stock,
    required bool isBestSeller,
    required bool isNew,
    required String gender,
    required String season,
    required String time,
    required String occasion,
    required String intensity,
    required String fragranceFamily,
    required List<String> topNotes,
    required List<String> middleNotes,
    required List<String> baseNotes,
    required List<String> tags,
    List<String>? imageUrls,
    String productType = 'simple',
    bool isSellable = true,
    String unitType = 'piece',
    List<ProductVariant> variants = const [],
    Map<String, int> staffTagScores = const {},
    List<String> staffWarnings = const [],
    Map<String, String> staffSalesNotes = const {},
    List<String> similarFamousDna = const [],
    String staffIntelligenceStatus = 'draft',
    bool reviewNeeded = false,
    int staffConfidence = 1,
    double staffDataCoverage = 0,
    int staffTaxonomyVersion = StaffTasteIntelligence.taxonomyVersion,
  });

  Future<List<AdminRestockRequestReceipt>> fetchRestockLogs();

  Future<AdminWriteResult<AdminRestockRequestReceipt>> executeRestock({
    required InventoryItem item,
    required int quantityDelta,
  });
}

class FirestoreAdminInventoryRepository implements AdminInventoryRepository {
  FirestoreAdminInventoryRepository(
    this._service,
    this._securityService,
    this._logger, {
    required AdminObservabilityService observability,
  }) : _observability = observability;

  final AdminInventoryService _service;
  final AdminSecurityService _securityService;
  final AdminActionLogger _logger;
  final AdminObservabilityService _observability;

  @override
  Future<AdminInventorySnapshot> fetchInventorySnapshot() {
    _logger.debug('Fetching inventory snapshot.');
    return _service.fetchInventorySnapshot();
  }

  @override
  Future<AdminWriteResult<String>> createInventoryItem({
    required String name,
    required String nameAr,
    required String brand,
    required String brandAr,
    required List<String> aliases,
    required List<String> aliasesAr,
    required String description,
    required double price,
    String? size,
    double? salePrice,
    required String collection,
    required int stock,
    required bool isBestSeller,
    required bool isNew,
    required String gender,
    required String season,
    required String time,
    required String occasion,
    required String intensity,
    required String fragranceFamily,
    required List<String> topNotes,
    required List<String> middleNotes,
    required List<String> baseNotes,
    required List<String> tags,
    List<String>? imageUrls,
    String productType = 'simple',
    bool isSellable = true,
    String unitType = 'piece',
    List<ProductVariant> variants = const [],
    Map<String, int> staffTagScores = const {},
    List<String> staffWarnings = const [],
    Map<String, String> staffSalesNotes = const {},
    List<String> similarFamousDna = const [],
    String staffIntelligenceStatus = 'draft',
    bool reviewNeeded = false,
    int staffConfidence = 1,
    double staffDataCoverage = 0,
    int staffTaxonomyVersion = StaffTasteIntelligence.taxonomyVersion,
  }) async {
    final traceId = _observability.createTraceId('inventory-create-item');
    final authContext = await _securityService.requireAuthorizedAdminWithToken(
      operation: 'create inventory item',
      traceId: traceId,
    );
    final access = authContext.access;

    final normalizedName = name.trim();
    final normalizedNameAr = nameAr.trim();
    final normalizedBrand = brand.trim();
    final normalizedBrandAr = brandAr.trim();
    final normalizedDescription = description.trim();
    final normalizedCollection = collection.trim();
    final normalizedSize = size?.trim();
    final normalizedGender = gender.trim();
    final normalizedSeason = season.trim();
    final normalizedTime = time.trim();
    final normalizedOccasion = occasion.trim();
    final normalizedIntensity = intensity.trim();
    final normalizedFragranceFamily = fragranceFamily.trim();
    final normalizedTopNotes = topNotes
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final normalizedMiddleNotes = middleNotes
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final normalizedBaseNotes = baseNotes
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final normalizedTags = tags
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final normalizedAliases = aliases
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final normalizedAliasesAr = aliasesAr
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final normalizedImageUrls = (imageUrls ?? <String>[])
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final normalizedStaffTagScores = StaffTasteIntelligence.sanitizeScores(
      staffTagScores,
    );
    final normalizedStaffWarnings = StaffTasteIntelligence.sanitizeWarnings(
      staffWarnings,
    );
    final normalizedStaffSalesNotes = {
      for (final entry in staffSalesNotes.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key.trim(): entry.value.trim(),
    };
    final normalizedSimilarFamousDna = similarFamousDna
        .where(StaffTasteIntelligence.famousDnaTags.contains)
        .toSet()
        .toList(growable: false);
    final calculatedCoverage = StaffTasteIntelligence.calculateCoverage(
      normalizedStaffTagScores,
    );
    final requestedStatus = staffIntelligenceStatus.trim().toLowerCase();
    final isMainAdmin = StaffTasteIntelligence.isMainAdminRole(access.role);
    final effectiveStatus = isMainAdmin
        ? (requestedStatus == 'trusted' || requestedStatus == 'reviewed'
              ? requestedStatus
              : 'draft')
        : 'draft';
    final effectiveReviewNeeded =
        !isMainAdmin && normalizedStaffTagScores.isNotEmpty
        ? true
        : reviewNeeded || effectiveStatus == 'draft';

    if (normalizedName.isEmpty ||
        normalizedBrand.isEmpty ||
        normalizedDescription.isEmpty) {
      throw AdminOperationFailedException('Product name is required.');
    }
    if (normalizedCollection.isEmpty) {
      throw AdminOperationFailedException('Collection is required.');
    }
    if (stock < 0 || price < 0) {
      throw AdminOperationFailedException('Stock must be zero or greater.');
    }
    if (salePrice != null && (salePrice < 0 || salePrice >= price)) {
      throw AdminOperationFailedException(
        'Sale price must be non-negative and lower than price.',
      );
    }
    if (normalizedGender.isEmpty ||
        normalizedSeason.isEmpty ||
        normalizedTime.isEmpty ||
        normalizedOccasion.isEmpty ||
        normalizedIntensity.isEmpty ||
        normalizedFragranceFamily.isEmpty) {
      throw AdminOperationFailedException(
        'Classification fields are required.',
      );
    }

    final productId = await _service.createInventoryItem(
      name: normalizedName,
      nameAr: normalizedNameAr,
      brand: normalizedBrand,
      brandAr: normalizedBrandAr,
      aliases: normalizedAliases,
      aliasesAr: normalizedAliasesAr,
      description: normalizedDescription,
      price: price,
      size: (normalizedSize == null || normalizedSize.isEmpty)
          ? null
          : normalizedSize,
      salePrice: salePrice,
      collection: normalizedCollection,
      stock: stock,
      isBestSeller: isBestSeller,
      isNew: isNew,
      gender: normalizedGender,
      season: normalizedSeason,
      time: normalizedTime,
      occasion: normalizedOccasion,
      intensity: normalizedIntensity,
      fragranceFamily: normalizedFragranceFamily,
      topNotes: normalizedTopNotes,
      middleNotes: normalizedMiddleNotes,
      baseNotes: normalizedBaseNotes,
      tags: normalizedTags,
      imageUrls: normalizedImageUrls,
      productType: productType,
      isSellable: isSellable,
      unitType: unitType,
      variants: variants,
      staffTagScores: normalizedStaffTagScores,
      staffWarnings: normalizedStaffWarnings,
      staffSalesNotes: normalizedStaffSalesNotes,
      similarFamousDna: normalizedSimilarFamousDna,
      staffIntelligenceStatus: effectiveStatus,
      reviewNeeded: effectiveReviewNeeded,
      staffConfidence: staffConfidence.clamp(1, 3),
      staffDataCoverage: calculatedCoverage,
      staffTaxonomyVersion: staffTaxonomyVersion <= 0
          ? StaffTasteIntelligence.taxonomyVersion
          : staffTaxonomyVersion,
      staffUpdatedBy: access.user?.uid,
      staffReviewCount:
          isMainAdmin &&
              (effectiveStatus == 'reviewed' || effectiveStatus == 'trusted')
          ? 1
          : 0,
    );

    _observability.recordAudit(
      AdminAuditEntry(
        traceId: traceId,
        action: 'inventory_item_create',
        actorId: access.user?.uid ?? 'admin_dashboard',
        actorRole: access.role ?? 'admin',
        targetId: productId,
        occurredAt: DateTime.now(),
        outcome: 'success',
        details:
            'name=$normalizedName, brand=$normalizedBrand, collection=$normalizedCollection, stock=$stock, price=$price',
      ),
    );

    return AdminWriteResult(traceId: traceId, data: productId);
  }

  @override
  Future<List<AdminRestockRequestReceipt>> fetchRestockLogs() async {
    _logger.debug('Fetching restock logs.');
    final requests = await _service.fetchPendingRestockRequests();
    final snapshot = await _service.fetchInventorySnapshot();
    final productNames = <String, String>{
      for (final item in snapshot.items) item.id: item.name,
    };

    // Group requests by product to display in UI as receipts/logs
    final grouped = <String, AdminRestockRequestReceipt>{};

    for (final req in requests) {
      final itemName = productNames[req.productId] ?? req.productId;
      if (!grouped.containsKey(req.productId)) {
        grouped[req.productId] = AdminRestockRequestReceipt(
          itemName: itemName,
          requestedUnits: 1,
          queuedAt: req.createdAt,
          message: 'Top demand for $itemName',
        );
      } else {
        final existing = grouped[req.productId]!;
        grouped[req.productId] = AdminRestockRequestReceipt(
          itemName: existing.itemName,
          requestedUnits: existing.requestedUnits + 1,
          queuedAt: req.createdAt.isBefore(existing.queuedAt)
              ? req.createdAt
              : existing.queuedAt,
          message: existing.message,
        );
      }
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) => b.requestedUnits.compareTo(a.requestedUnits));

    return sorted;
  }

  @override
  Future<AdminWriteResult<AdminRestockRequestReceipt>> executeRestock({
    required InventoryItem item,
    required int quantityDelta,
  }) async {
    final traceId = _observability.createTraceId('inventory-restock');
    final authContext = await _securityService.requireAuthorizedAdminWithToken(
      operation: 'adjust inventory and notify users when needed',
      traceId: traceId,
    );
    final access = authContext.access;

    if (quantityDelta == 0) {
      throw AdminOperationFailedException(
        'Inventory adjustment must not be zero.',
      );
    }

    _logger.info(
      'Executing inventory adjustment via worker.',
      context: {
        'traceId': traceId,
        'itemName': item.name,
        'quantityDelta': quantityDelta,
        'waitingUsers': item.waitingUsers,
      },
    );

    final restockResult = await _service.executeRestock(
      item.id,
      quantityDelta,
      bearerToken: authContext.idToken,
      traceId: traceId,
      reason: 'admin_restock',
    );

    _observability.recordAudit(
      AdminAuditEntry(
        traceId: traceId,
        action: 'inventory_restock_execute',
        actorId: access.user?.uid ?? 'admin_dashboard',
        actorRole: access.role ?? 'admin',
        targetId: item.id,
        occurredAt: DateTime.now(),
        outcome: 'success',
        details:
            'quantityDelta=$quantityDelta, waitingUsersNotified=${restockResult.notifiedCount}, stock=${restockResult.stock}',
      ),
    );

    return AdminWriteResult(
      traceId: traceId,
      data: AdminRestockRequestReceipt(
        itemName: item.name,
        requestedUnits: quantityDelta.abs(),
        queuedAt: DateTime.now(),
        message: _buildRestockMessage(item, restockResult),
      ),
    );
  }

  String _buildRestockMessage(
    InventoryItem item,
    AdminInventoryRestockResult result,
  ) {
    final notificationsMessage = result.delta > 0 && result.notifiedCount > 0
        ? ' ${result.notifiedCount} request(s) marked as notified.'
        : '';
    final action = result.delta > 0 ? 'Added' : 'Removed';
    return '$action ${result.delta.abs()} units ${result.delta > 0 ? 'to' : 'from'} ${item.name}. Current stock: ${result.stock}.$notificationsMessage';
  }
}
