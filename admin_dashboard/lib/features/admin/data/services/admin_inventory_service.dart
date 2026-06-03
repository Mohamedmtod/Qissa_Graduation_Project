import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_restock_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_restock_request.dart';

abstract class AdminInventoryService {
  Future<AdminInventorySnapshot> fetchInventorySnapshot();

  Future<String> createInventoryItem({
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
    int staffTaxonomyVersion = 1,
    String? staffUpdatedBy,
    int staffReviewCount,
  });

  Future<List<AdminRestockRequest>> fetchPendingRestockRequests();

  Future<AdminInventoryRestockResult> executeRestock(
    String productId,
    int quantityDelta, {
    required String bearerToken,
    required String traceId,
    String? reason,
  });
}
