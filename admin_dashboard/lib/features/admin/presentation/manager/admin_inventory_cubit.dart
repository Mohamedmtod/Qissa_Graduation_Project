import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_restock_request_receipt.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_inventory_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

class AdminInventoryState extends Equatable {
  const AdminInventoryState({
    this.isLoading = false,
    this.snapshot,
    this.restockLogs,
    this.lowStockOnly = false,
    this.loadErrorMessage,
    this.feedbackMessage,
    this.searchQuery = '',
  });

  final bool isLoading;
  final AdminInventorySnapshot? snapshot;
  final List<AdminRestockRequestReceipt>? restockLogs;
  final bool lowStockOnly;
  final String? loadErrorMessage;
  final String? feedbackMessage;
  final String searchQuery;

  List<InventoryItem> get items => snapshot?.items ?? const [];

  List<InventoryItem> get visibleItems {
    final query = searchQuery.trim().toLowerCase();
    return items.where((item) {
      if (lowStockOnly && !item.lowStock) {
        return false;
      }
      if (query.isNotEmpty) {
        return item.name.toLowerCase().contains(query) ||
            item.collection.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  int get lowStockCount => items.where((item) => item.lowStock).length;

  int get outOfStockCount => items.where((item) => item.units <= 0).length;

  AdminInventoryState copyWith({
    bool? isLoading,
    AdminInventorySnapshot? snapshot,
    bool clearSnapshot = false,
    List<AdminRestockRequestReceipt>? restockLogs,
    bool? lowStockOnly,
    String? loadErrorMessage,
    bool clearLoadError = false,
    String? feedbackMessage,
    bool clearFeedback = false,
    String? searchQuery,
  }) {
    return AdminInventoryState(
      isLoading: isLoading ?? this.isLoading,
      snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
      restockLogs: restockLogs ?? this.restockLogs,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      loadErrorMessage: clearLoadError
          ? null
          : loadErrorMessage ?? this.loadErrorMessage,
      feedbackMessage: clearFeedback
          ? null
          : feedbackMessage ?? this.feedbackMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    snapshot,
    restockLogs,
    lowStockOnly,
    loadErrorMessage,
    feedbackMessage,
    searchQuery,
  ];
}

class AdminInventoryCubit extends Cubit<AdminInventoryState> {
  AdminInventoryCubit(this._repository) : super(const AdminInventoryState());

  final AdminInventoryRepository _repository;

  Future<void> loadInventory() async {
    emit(
      state.copyWith(
        isLoading: true,
        clearFeedback: true,
        clearLoadError: true,
      ),
    );
    try {
      final snapshot = await _repository.fetchInventorySnapshot();
      emit(state.copyWith(isLoading: false, snapshot: snapshot));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          clearSnapshot: true,
          loadErrorMessage: AdminLocaleController.globalT(
            'errors.inventory.loadFailed',
          ),
        ),
      );
    }
  }

  void setLowStockOnly(bool value) {
    emit(state.copyWith(lowStockOnly: value, clearFeedback: true));
  }

  void toggleLowStockOnly() {
    setLowStockOnly(!state.lowStockOnly);
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query, clearFeedback: true));
  }

  Future<void> createInventoryItem({
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
  }) async {
    final normalizedName = name.trim();
    final normalizedNameAr = nameAr.trim();
    final normalizedBrand = brand.trim();
    final normalizedBrandAr = brandAr.trim();
    final normalizedDescription = description.trim();
    final normalizedCollection = collection.trim();
    final normalizedSize = size?.trim();

    if (normalizedName.isEmpty ||
        normalizedBrand.isEmpty ||
        normalizedDescription.isEmpty ||
        normalizedCollection.isEmpty ||
        stock < 0 ||
        price < 0 ||
        (salePrice != null && (salePrice < 0 || salePrice >= price))) {
      emit(
        state.copyWith(
          feedbackMessage: AdminLocaleController.globalT(
            'errors.inventory.createProductInvalidInput',
          ),
        ),
      );
      return;
    }

    try {
      final result = await _repository.createInventoryItem(
        name: normalizedName,
        nameAr: normalizedNameAr,
        brand: normalizedBrand,
        brandAr: normalizedBrandAr,
        aliases: aliases,
        aliasesAr: aliasesAr,
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
        gender: gender,
        season: season,
        time: time,
        occasion: occasion,
        intensity: intensity,
        fragranceFamily: fragranceFamily,
        topNotes: topNotes,
        middleNotes: middleNotes,
        baseNotes: baseNotes,
        tags: tags,
        imageUrls: imageUrls,
        productType: productType,
        isSellable: isSellable,
        unitType: unitType,
        variants: variants,
        staffTagScores: staffTagScores,
        staffWarnings: staffWarnings,
        staffSalesNotes: staffSalesNotes,
        similarFamousDna: similarFamousDna,
        staffIntelligenceStatus: staffIntelligenceStatus,
        reviewNeeded: reviewNeeded,
        staffConfidence: staffConfidence,
        staffDataCoverage: staffDataCoverage,
        staffTaxonomyVersion: staffTaxonomyVersion,
      );

      emit(
        state.copyWith(
          feedbackMessage: AdminLocaleController.globalT(
            'inventory.feedback.createSuccess',
            params: {'name': normalizedName, 'traceId': result.traceId},
          ),
        ),
      );

      await loadInventory();
    } on AdminSecurityException catch (error) {
      emit(state.copyWith(feedbackMessage: error.message));
    } catch (e) {
      emit(
        state.copyWith(
          feedbackMessage: AdminLocaleController.globalT(
            'errors.inventory.createProductFailed',
            params: {'error': e.toString()},
          ),
        ),
      );
    }
  }

  Future<void> executeRestock(InventoryItem item, int quantityDelta) async {
    if (quantityDelta == 0) {
      emit(
        state.copyWith(
          feedbackMessage: AdminLocaleController.globalT(
            'errors.inventory.zeroAdjustmentNotAllowed',
          ),
        ),
      );
      return;
    }

    try {
      final result = await _repository.executeRestock(
        item: item,
        quantityDelta: quantityDelta,
      );
      _emitRestockFeedback(result.data, result.traceId);
      // Refresh inventory after mutation to reflect new stock
      await loadInventory();
    } on AdminSecurityException catch (error) {
      emit(state.copyWith(feedbackMessage: error.message));
    } catch (e) {
      emit(
        state.copyWith(
          feedbackMessage: AdminLocaleController.globalT(
            'errors.inventory.executeRestockFailed',
            params: {'error': e.toString()},
          ),
        ),
      );
    }
  }

  Future<void> loadRestockLogs() async {
    try {
      final logs = await _repository.fetchRestockLogs();
      emit(state.copyWith(restockLogs: logs));
    } catch (e) {
      emit(
        state.copyWith(
          feedbackMessage: AdminLocaleController.globalT(
            'errors.inventory.logsFailed',
            params: {'error': e.toString()},
          ),
        ),
      );
    }
  }

  void clearFeedback() {
    emit(state.copyWith(clearFeedback: true));
  }

  void _emitRestockFeedback(
    AdminRestockRequestReceipt receipt,
    String traceId,
  ) {
    emit(
      state.copyWith(
        feedbackMessage: AdminLocaleController.globalT(
          'inventory.feedback.restockSuccess',
          params: {'message': receipt.message, 'traceId': traceId},
        ),
      ),
    );
  }
}
