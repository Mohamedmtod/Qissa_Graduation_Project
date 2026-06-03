import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_write_result.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_content_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_content_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_content_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';

enum AdminContentView { products, banners, categories, storeInfo }

class AdminContentState extends Equatable {
  const AdminContentState({
    this.isLoading = false,
    this.isLoadingMoreProducts = false,
    this.snapshot,
    this.errorMessage,
    this.feedbackMessage,
    this.view = AdminContentView.products,
    this.productLimit = AdminContentService.defaultProductPageSize,
    this.canLoadMoreProducts = false,
    this.searchQuery = '',
  });

  final bool isLoading;
  final bool isLoadingMoreProducts;
  final AdminContentSnapshot? snapshot;
  final String? errorMessage;
  final String? feedbackMessage;
  final AdminContentView view;
  final int productLimit;
  final bool canLoadMoreProducts;
  final String searchQuery;

  List<ProductEntry> get visibleProducts {
    final products = snapshot?.products ?? const [];
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((p) => p.title.toLowerCase().contains(query)).toList();
  }

  List<BannerEntry> get visibleBanners {
    final banners = snapshot?.banners ?? const [];
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return banners;
    return banners.where((b) {
      final t = b.title.toLowerCase();
      if (t.contains(query)) return true;
      // Also try to match translated slot
      final slotStr = b.slot.toString().toLowerCase();
      return slotStr.contains(query);
    }).toList();
  }

  List<CategoryEntry> get visibleCategories {
    final categories = snapshot?.categories ?? const [];
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return categories;
    return categories.where((c) {
      final name = c.name.toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  AdminContentState copyWith({
    bool? isLoading,
    bool? isLoadingMoreProducts,
    AdminContentSnapshot? snapshot,
    bool clearSnapshot = false,
    String? errorMessage,
    bool clearError = false,
    String? feedbackMessage,
    bool clearFeedback = false,
    AdminContentView? view,
    int? productLimit,
    bool? canLoadMoreProducts,
    String? searchQuery,
  }) {
    return AdminContentState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMoreProducts:
          isLoadingMoreProducts ?? this.isLoadingMoreProducts,
      snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      feedbackMessage: clearFeedback
          ? null
          : feedbackMessage ?? this.feedbackMessage,
      view: view ?? this.view,
      productLimit: productLimit ?? this.productLimit,
      canLoadMoreProducts: canLoadMoreProducts ?? this.canLoadMoreProducts,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isLoadingMoreProducts,
    snapshot,
    errorMessage,
    feedbackMessage,
    view,
    productLimit,
    canLoadMoreProducts,
    searchQuery,
  ];
}

class AdminContentCubit extends Cubit<AdminContentState> {
  AdminContentCubit(this._repository, {AdminActionLogger? logger})
    : _logger = logger,
      super(const AdminContentState());

  final AdminContentRepository _repository;
  final AdminActionLogger? _logger;

  Future<void> loadContent() async {
    emit(
      state.copyWith(isLoading: true, clearError: true, clearFeedback: true),
    );
    try {
      final snapshot = await _repository.fetchContentSnapshot(
        productLimit: state.productLimit,
      );
      emit(
        state.copyWith(
          isLoading: false,
          snapshot: snapshot,
          canLoadMoreProducts: snapshot.products.length >= state.productLimit,
        ),
      );
    } catch (error, stackTrace) {
      _logger?.error(
        '[AdminContentCubit] loadContent FAILED.',
        context: {
          'errorType': error.runtimeType.toString(),
          'errorMessage': error.toString(),
          'stackTrace': stackTrace.toString().split('\n').take(8).join(' | '),
        },
      );
      // ignore: avoid_print — temporary debug until root cause is identified
      // ignore: flutter_style_todos
      // TODO: remove after debugging
      // dart:developer is already used by AdminActionLogger so we just print here
      // as a guaranteed fallback even if logger is null.
      // ignore: avoid_print
      print('[AdminContentCubit][ERROR] loadContent failed\n'
          'Type   : ${error.runtimeType}\n'
          'Message: $error\n'
          'Stack  :\n$stackTrace');
      emit(
        state.copyWith(
          isLoading: false,
          clearSnapshot: true,
          errorMessage: AdminLocaleController.globalT(
            'errors.content.loadFailed',
          ),
        ),
      );
    }
  }

  Future<void> loadMoreProducts() async {
    if (state.isLoadingMoreProducts || !state.canLoadMoreProducts) {
      return;
    }
    final nextLimit =
        state.productLimit + AdminContentService.defaultProductPageSize;
    emit(state.copyWith(isLoadingMoreProducts: true, clearFeedback: true));
    try {
      final snapshot = await _repository.fetchContentSnapshot(
        productLimit: nextLimit,
      );
      emit(
        state.copyWith(
          isLoadingMoreProducts: false,
          snapshot: snapshot,
          productLimit: nextLimit,
          canLoadMoreProducts: snapshot.products.length >= nextLimit,
        ),
      );
    } catch (error, stackTrace) {
      _logger?.error(
        '[AdminContentCubit] loadMoreProducts FAILED.',
        context: {
          'errorType': error.runtimeType.toString(),
          'errorMessage': error.toString(),
        },
      );
      // ignore: avoid_print
      print('[AdminContentCubit][ERROR] loadMoreProducts failed\n'
          'Type   : ${error.runtimeType}\n'
          'Message: $error\n'
          'Stack  :\n$stackTrace');
      emit(
        state.copyWith(
          isLoadingMoreProducts: false,
          feedbackMessage: AdminLocaleController.globalT(
            'errors.content.loadFailed',
          ),
        ),
      );
    }
  }

  Future<bool> createProduct(AdminProductUpsertInput input) {
    return _runWrite(
      () => _repository.createProduct(input),
      fallbackError: 'Failed to create product.',
    );
  }

  Future<bool> updateProduct(String productId, AdminProductUpsertInput input) {
    return _runWrite(
      () => _repository.updateProduct(productId, input),
      fallbackError: 'Failed to update product.',
    );
  }

  Future<void> setProductVisibility(String productId, bool visible) async {
    await _runWrite(
      () => _repository.setProductVisibility(productId, visible: visible),
      fallbackError: 'Failed to update product visibility.',
    );
  }

  Future<void> archiveProduct(String productId) async {
    await _runWrite(
      () => _repository.archiveProduct(productId),
      fallbackError: 'Failed to archive product.',
    );
  }

  Future<void> createBanner(AdminBannerUpsertInput input) async {
    await _runWrite(
      () => _repository.createBanner(input),
      fallbackError: 'Failed to create banner.',
    );
  }

  Future<void> updateBanner(
    String bannerId,
    AdminBannerUpsertInput input,
  ) async {
    await _runWrite(
      () => _repository.updateBanner(bannerId, input),
      fallbackError: 'Failed to update banner.',
    );
  }

  Future<void> deleteBanner(String bannerId) async {
    await _runWrite(
      () => _repository.deleteBanner(bannerId),
      fallbackError: 'Failed to delete banner.',
    );
  }

  Future<void> reorderBanners(List<String> orderedIds) async {
    await _runWrite(
      () => _repository.reorderBanners(orderedIds),
      fallbackError: 'Failed to reorder banners.',
    );
  }

  Future<void> createCategory(AdminCategoryUpsertInput input) async {
    await _runWrite(
      () => _repository.createCategory(input),
      fallbackError: 'Failed to create category.',
    );
  }

  Future<void> updateCategory(
    String categoryId,
    AdminCategoryUpsertInput input,
  ) async {
    await _runWrite(
      () => _repository.updateCategory(categoryId, input),
      fallbackError: 'Failed to update category.',
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    await _runWrite(
      () => _repository.deleteCategory(categoryId),
      fallbackError: 'Failed to delete category.',
    );
  }

  Future<void> setCategoryVisibility(String categoryId, bool visible) async {
    await _runWrite(
      () => _repository.setCategoryVisibility(categoryId, visible: visible),
      fallbackError: 'Failed to update category visibility.',
    );
  }

  Future<void> reorderCategories(List<String> orderedIds) async {
    await _runWrite(
      () => _repository.reorderCategories(orderedIds),
      fallbackError: 'Failed to reorder categories.',
    );
  }

  Future<void> updateBusinessInfo(AdminBusinessInfo input) async {
    await _runWrite(
      () => _repository.updateBusinessInfo(input),
      fallbackError: 'Failed to update store info.',
    );
  }

  Future<void> recomputeProductPublicStats() async {
    try {
      final result = await _repository.recomputeProductPublicStats();
      emit(
        state.copyWith(
          feedbackMessage:
              'Product sales stats updated for ${result.data} products. Trace: ${result.traceId}',
        ),
      );
      await loadContent();
    } on AdminSecurityException catch (error) {
      emit(state.copyWith(feedbackMessage: error.message));
    } catch (_) {
      emit(
        state.copyWith(
          feedbackMessage: 'Failed to recompute product sales stats.',
        ),
      );
    }
  }

  void setView(AdminContentView view) {
    emit(state.copyWith(view: view, clearFeedback: true));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query, clearFeedback: true));
  }

  void clearFeedback() {
    emit(state.copyWith(clearFeedback: true));
  }

  Future<bool> _runWrite(
    Future<AdminWriteResult<void>> Function() action, {
    required String fallbackError,
  }) async {
    try {
      final result = await action();
      emit(
        state.copyWith(
          feedbackMessage: 'Saved successfully. Trace: ${result.traceId}',
        ),
      );
      await loadContent();
      return true;
    } on AdminSecurityException catch (error) {
      emit(state.copyWith(feedbackMessage: error.message));
      return false;
    } catch (error, stackTrace) {
      _logger?.error(
        '[AdminContentCubit] write operation FAILED: $fallbackError',
        context: {
          'errorType': error.runtimeType.toString(),
          'errorMessage': error.toString(),
        },
      );
      // ignore: avoid_print
      print('[AdminContentCubit][ERROR] write failed: $fallbackError\n'
          'Type   : ${error.runtimeType}\n'
          'Message: $error\n'
          'Stack  :\n$stackTrace');
      emit(state.copyWith(feedbackMessage: fallbackError));
      return false;
    }
  }
}
