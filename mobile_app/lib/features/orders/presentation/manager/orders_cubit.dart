import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/orders/data/repos/order_repo.dart';
import 'package:perfume_app/features/orders/data/models/order_model.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';

abstract class OrdersState {}

class OrdersInitial extends OrdersState {}

class OrdersLoading extends OrdersState {}

class OrdersLoaded extends OrdersState {
  final List<OrderModel> orders;
  final bool hasMore;
  OrdersLoaded(this.orders, {this.hasMore = false});
}

class OrdersLoadingMore extends OrdersState {
  final List<OrderModel> currentOrders;
  OrdersLoadingMore(this.currentOrders);
}

class OrdersEmpty extends OrdersState {}

class OrdersError extends OrdersState {
  final String message;
  OrdersError(this.message);
}

class OrdersCubit extends Cubit<OrdersState> {
  final OrderRepo orderRepo;
  final AuthBloc authBloc;

  StreamSubscription<OrderQueryResult>? _subscription;
  bool _isLoadingMore = false;
  int _currentLimit = 10;

  OrdersCubit({
    required this.orderRepo,
    required this.authBloc,
  }) : super(OrdersInitial());

  // ── Start listening to orders ──────────────────────────────────
  Future<void> loadOrders() async {
    final user = authBloc.state.user;
    if (user == null) {
      emit(OrdersError('User not authenticated'));
      return;
    }

    _currentLimit = 10;
    _listenWithLimit(user.uid, _currentLimit);
  }

  void _listenWithLimit(String uid, int limit, {bool isLoadMore = false}) {
    if (!isLoadMore) {
      _isLoadingMore = false;
      emit(OrdersLoading());
    }

    _subscription?.cancel();
    _subscription = orderRepo.streamMyOrders(uid, limit: limit).listen(
      (result) {
        _isLoadingMore = false;
        if (result.orders.isEmpty) {
          emit(OrdersEmpty());
        } else {
          emit(OrdersLoaded(
            result.orders,
            hasMore: result.orders.length >= limit,
          ));
        }
      },
      onError: (e) {
        _isLoadingMore = false;
        emit(OrdersError('Failed to load orders: ${e.toString()}'));
      },
    );
  }

  // ── Load more (pagination via stream limit expansion) ──────────
  Future<void> loadMore() async {
    if (_isLoadingMore) return;

    final cur = state;
    if (cur is! OrdersLoaded || !cur.hasMore) return;

    final user = authBloc.state.user;
    if (user == null) return;

    _isLoadingMore = true;
    _currentLimit += 10;

    emit(OrdersLoadingMore(cur.orders));
    _listenWithLimit(user.uid, _currentLimit, isLoadMore: true);
  }

  Future<void> cancelPendingOrder(String orderId) async {
    await orderRepo.cancelOrder(orderId);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

