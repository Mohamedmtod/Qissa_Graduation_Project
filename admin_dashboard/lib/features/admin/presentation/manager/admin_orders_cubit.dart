import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_order.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_orders_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

part 'admin_orders_state.dart';

class AdminOrdersCubit extends Cubit<AdminOrdersState> {
  AdminOrdersCubit(this._repository) : super(const AdminOrdersState());

  final AdminOrdersRepository _repository;
  Timer? _searchDebounce;
  int _firstPageRequestId = 0;

  Future<void> loadOrders() async {
    final requestId = ++_firstPageRequestId;
    emit(
      state.copyWith(
        isLoading: true,
        clearFeedback: true,
        clearLoadError: true,
      ),
    );
    try {
      final page = await _repository.fetchOrdersPage(
        pageSize: state.pageSize,
        statusFilter: state.statusFilter,
        dateFilter: state.dateFilter,
        searchQuery: state.searchQuery,
      );
      if (requestId != _firstPageRequestId || isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          orders: page.orders,
          selectedOrderId: page.orders.isEmpty ? null : page.orders.first.id,
          clearSelectedOrderId: page.orders.isEmpty,
          currentPage: 1,
          hasNextPage: page.hasNextPage,
          lastDocument: page.lastDocument,
          clearLastDocument: page.lastDocument == null,
          cursorStack: const [],
        ),
      );
    } catch (_) {
      if (requestId != _firstPageRequestId || isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          orders: const [],
          selectedOrderId: null,
          loadErrorMessage: AdminLocaleController.globalT(
            'errors.orders.loadFailed',
          ),
        ),
      );
    }
  }

  void setSearchQuery(String query) {
    final normalized = query.trim();
    if (normalized == state.searchQuery) {
      return;
    }
    _searchDebounce?.cancel();
    emit(state.copyWith(searchQuery: normalized, currentPage: 1));

    if (normalized.isNotEmpty && normalized.length < 3) {
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!isClosed) {
        unawaited(loadOrders());
      }
    });
  }

  void setStatusFilter(AdminOrderStatus? status) {
    _searchDebounce?.cancel();
    emit(state.copyWith(statusFilter: status, currentPage: 1));
    unawaited(loadOrders());
  }

  void setDateFilter(AdminOrderDateFilter filter) {
    _searchDebounce?.cancel();
    emit(state.copyWith(dateFilter: filter, currentPage: 1));
    unawaited(loadOrders());
  }

  void clearFilters() {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        searchQuery: '',
        clearStatusFilter: true,
        dateFilter: AdminOrderDateFilter.all,
        currentPage: 1,
        clearFeedback: true,
      ),
    );
    unawaited(loadOrders());
  }

  void selectOrder(String orderId) {
    emit(state.copyWith(selectedOrderId: orderId, clearFeedback: true));
  }

  Future<void> nextPage() async {
    final cursor = state.lastDocument;
    if (!state.canGoNext || cursor == null) {
      return;
    }
    emit(state.copyWith(isLoading: true, clearFeedback: true));
    try {
      final page = await _repository.fetchOrdersPage(
        pageSize: state.pageSize,
        startAfter: cursor,
        statusFilter: state.statusFilter,
        dateFilter: state.dateFilter,
        searchQuery: state.searchQuery,
      );
      emit(
        state.copyWith(
          isLoading: false,
          orders: page.orders,
          selectedOrderId: page.orders.isEmpty ? null : page.orders.first.id,
          clearSelectedOrderId: page.orders.isEmpty,
          currentPage: state.currentPage + 1,
          hasNextPage: page.hasNextPage,
          lastDocument: page.lastDocument,
          clearLastDocument: page.lastDocument == null,
          cursorStack: [...state.cursorStack, cursor],
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          loadErrorMessage: AdminLocaleController.globalT(
            'errors.orders.loadFailed',
          ),
        ),
      );
    }
  }

  Future<void> previousPage() async {
    if (!state.canGoPrevious) {
      return;
    }
    final nextStack = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
      state.cursorStack,
    );
    if (nextStack.isNotEmpty) {
      nextStack.removeLast();
    }
    final startAfter = nextStack.isEmpty ? null : nextStack.last;
    emit(state.copyWith(isLoading: true, clearFeedback: true));
    try {
      final page = await _repository.fetchOrdersPage(
        pageSize: state.pageSize,
        startAfter: startAfter,
        statusFilter: state.statusFilter,
        dateFilter: state.dateFilter,
        searchQuery: state.searchQuery,
      );
      emit(
        state.copyWith(
          isLoading: false,
          orders: page.orders,
          selectedOrderId: page.orders.isEmpty ? null : page.orders.first.id,
          clearSelectedOrderId: page.orders.isEmpty,
          currentPage: state.currentPage - 1,
          hasNextPage: page.hasNextPage,
          lastDocument: page.lastDocument,
          clearLastDocument: page.lastDocument == null,
          cursorStack: nextStack,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          loadErrorMessage: AdminLocaleController.globalT(
            'errors.orders.loadFailed',
          ),
        ),
      );
    }
  }

  void dismissFeedback() {
    emit(state.copyWith(clearFeedback: true));
  }

  Future<void> attemptTransition(AdminOrderStatus nextStatus) async {
    final selected = state.selectedOrder;
    if (selected == null || state.isTransitioning) {
      return;
    }

    emit(
      state.copyWith(
        isTransitioning: true,
        transitionOrderId: selected.id,
        transitionTargetStatus: nextStatus,
        clearFeedback: true,
      ),
    );

    try {
      final result = await _repository.transitionOrder(
        order: selected,
        nextStatus: nextStatus,
      );
      final updated = result.data;
      final updatedOrders = state.orders
          .map((order) => order.id == updated.id ? updated : order)
          .toList();

      emit(
        state.copyWith(
          isTransitioning: false,
          clearTransitionOrderId: true,
          clearTransitionTargetStatus: true,
          orders: updatedOrders,
          feedbackMessage: AdminLocaleController.globalT(
            'orders.feedback.transitionSuccess',
            params: {
              'id': selected.id,
              'status': adminOrderStatusLabel(nextStatus),
              'traceId': result.traceId,
            },
          ),
          feedbackIsError: false,
        ),
      );
    } on AdminSecurityException catch (error) {
      emit(
        state.copyWith(
          isTransitioning: false,
          clearTransitionOrderId: true,
          clearTransitionTargetStatus: true,
          feedbackMessage: _transitionErrorMessage(error),
          feedbackIsError: true,
        ),
      );
    }
  }

  String _transitionErrorMessage(AdminSecurityException error) {
    if (error is AdminAuthorizationException) {
      return AdminLocaleController.globalT(
        'orders.feedback.authorizationFailed',
        params: {'message': error.message},
      );
    }
    if (error is AdminPolicyViolationException) {
      return AdminLocaleController.globalT(
        'orders.feedback.policyBlocked',
        params: {'message': error.message},
      );
    }
    if (error is AdminOperationFailedException) {
      return AdminLocaleController.globalT(
        'orders.feedback.workerFailed',
        params: {'message': error.message},
      );
    }
    return error.message;
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
