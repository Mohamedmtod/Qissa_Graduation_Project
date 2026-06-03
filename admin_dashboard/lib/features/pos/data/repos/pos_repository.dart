import 'package:dio/dio.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import '../datasources/pos_local_datasource.dart';
import '../services/pos_remote_service.dart';

abstract class PosRepository {
  Future<Map<String, dynamic>> openCashSession({required double openingCash, String? notes});
  Future<Map<String, dynamic>> getCurrentCashSession();
  Future<Map<String, dynamic>> closeCashSession({required String sessionId, required double actualCash, String? notes});
  Future<List<InventoryItem>> searchPosProducts();
  Future<Map<String, dynamic>> checkoutSale({
    required String sessionId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String idempotencyKey,
    String? notes,
  });
  Future<Map<String, dynamic>> retryCheckoutSale(Map<String, dynamic> pendingPayload);
  Future<List<Map<String, dynamic>>> getSales();
  Future<Map<String, dynamic>> getSaleDetails(String saleId);
  
  PosLocalDatasource get local;
}

class PosRepositoryImpl implements PosRepository {
  final PosRemoteService _remote;
  final PosLocalDatasource _local;

  PosRepositoryImpl(this._remote, this._local);

  @override
  PosLocalDatasource get local => _local;

  @override
  Future<Map<String, dynamic>> openCashSession({required double openingCash, String? notes}) {
    return _remote.openCashSession(openingCash: openingCash, notes: notes);
  }

  @override
  Future<Map<String, dynamic>> getCurrentCashSession() {
    return _remote.getCurrentCashSession();
  }

  @override
  Future<Map<String, dynamic>> closeCashSession({required String sessionId, required double actualCash, String? notes}) {
    return _remote.closeCashSession(sessionId: sessionId, actualCash: actualCash, notes: notes);
  }

  @override
  Future<List<InventoryItem>> searchPosProducts() async {
    final list = await _remote.searchPosProducts();
    return list.map((json) {
      final id = json['id'] as String;
      final rawVariants = json['variants'] as List?;
      final List<ProductVariant> variantsList;
      if (rawVariants != null && rawVariants.isNotEmpty) {
        variantsList = rawVariants
            .map((v) => ProductVariant.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList();
      } else {
        final rawStock = json['stock'];
        final int units = rawStock is int ? rawStock : (rawStock is double ? rawStock.toInt() : 0);
        variantsList = [
          ProductVariant(
            id: 'default',
            label: (json['size'] as String?) ?? '',
            price: (json['price'] as num?)?.toDouble() ?? 0.0,
            salePrice: (json['salePrice'] as num?)?.toDouble(),
            costPrice: (json['costPrice'] as num?)?.toDouble(),
            unitType: (json['unitType'] as String?) ?? 'piece',
            stock: units.toDouble(),
            isActive: (json['isActive'] as bool?) ?? true,
          )
        ];
      }

      return InventoryItem(
        id: id,
        name: json['name'] as String? ?? 'Unknown',
        collection: json['categoryName'] as String? ?? 'Uncategorized',
        imageUrl: (json['imageUrls'] as List?)?.isNotEmpty == true ? (json['imageUrls'] as List).first as String : '',
        units: json['stock'] is int ? json['stock'] as int : (json['stock'] as num?)?.toInt() ?? 0,
        waitingUsers: 0,
        trend: InventoryTrend.up,
        productType: json['productType'] as String? ?? 'simple',
        isSellable: json['isSellable'] as bool? ?? true,
        unitType: json['unitType'] as String? ?? 'piece',
        variants: variantsList,
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> checkoutSale({
    required String sessionId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String idempotencyKey,
    String? notes,
  }) async {
    final payload = {
      'idempotencyKey': idempotencyKey,
      'sessionId': sessionId,
      'items': items,
      'paymentMethod': paymentMethod,
      if (notes != null) 'notes': notes,
    };

    await _local.saveIdempotencyKey(idempotencyKey);
    await _local.savePendingPayload(payload);

    try {
      final result = await _remote.createPosSale(payload);
      await _local.clearPendingSale();
      return result;
    } catch (e) {
      final isValidationError = e is DioException && 
          e.response != null && 
          (e.response!.statusCode == 400 || 
           e.response!.statusCode == 401 || 
           e.response!.statusCode == 403 || 
           e.response!.statusCode == 409 || 
           e.response!.statusCode == 404);
      
      if (!isValidationError) {
        await _local.setCartLocked(true);
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> retryCheckoutSale(Map<String, dynamic> pendingPayload) async {
    final result = await _remote.createPosSale(pendingPayload);
    await _local.clearPendingSale();
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getSales() {
    return _remote.getSales();
  }

  @override
  Future<Map<String, dynamic>> getSaleDetails(String saleId) {
    return _remote.getSaleDetails(saleId);
  }
}
