part of 'admin_orders_cubit.dart';

class AdminOrdersState extends Equatable {
  const AdminOrdersState({
    this.isLoading = false,
    this.isTransitioning = false,
    this.transitionOrderId,
    this.transitionTargetStatus,
    this.orders = const [],
    this.selectedOrderId,
    this.searchQuery = '',
    this.statusFilter,
    this.dateFilter = AdminOrderDateFilter.all,
    this.currentPage = 1,
    this.pageSize = 25,
    this.hasNextPage = false,
    this.lastDocument,
    this.cursorStack = const [],
    this.loadErrorMessage,
    this.feedbackMessage,
    this.feedbackIsError = false,
  });

  final bool isLoading;
  final bool isTransitioning;
  final String? transitionOrderId;
  final AdminOrderStatus? transitionTargetStatus;
  final List<AdminOrder> orders;
  final String? selectedOrderId;
  final String searchQuery;
  final AdminOrderStatus? statusFilter;
  final AdminOrderDateFilter dateFilter;
  final int currentPage;
  final int pageSize;
  final bool hasNextPage;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> cursorStack;
  final String? loadErrorMessage;
  final String? feedbackMessage;
  final bool feedbackIsError;

  List<AdminOrder> get visibleOrders {
    final query = searchQuery.toLowerCase();
    return orders.where((order) {
      final matchesStatus =
          statusFilter == null || order.status == statusFilter;
      if (!matchesStatus) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchable = [
        order.id,
        order.customer.name,
        order.customer.email,
        order.customer.phone,
        order.location,
        order.paymentMethod,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList(growable: false);
  }

  int get totalPages => hasNextPage ? currentPage + 1 : currentPage;

  int get normalizedCurrentPage => currentPage.clamp(1, totalPages);

  bool get canGoPrevious => normalizedCurrentPage > 1;

  bool get canGoNext => hasNextPage;

  List<AdminOrder> get pagedOrders => visibleOrders;

  AdminOrder? get selectedOrder {
    final id = selectedOrderId;
    if (id == null) {
      return null;
    }

    try {
      return visibleOrders.firstWhere((order) => order.id == id);
    } catch (_) {
      return null;
    }
  }

  AdminOrdersState copyWith({
    bool? isLoading,
    bool? isTransitioning,
    String? transitionOrderId,
    bool clearTransitionOrderId = false,
    AdminOrderStatus? transitionTargetStatus,
    bool clearTransitionTargetStatus = false,
    List<AdminOrder>? orders,
    String? selectedOrderId,
    bool clearSelectedOrderId = false,
    String? searchQuery,
    AdminOrderStatus? statusFilter,
    bool clearStatusFilter = false,
    AdminOrderDateFilter? dateFilter,
    int? currentPage,
    int? pageSize,
    bool? hasNextPage,
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument,
    bool clearLastDocument = false,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? cursorStack,
    String? loadErrorMessage,
    bool clearLoadError = false,
    String? feedbackMessage,
    bool? feedbackIsError,
    bool clearFeedback = false,
  }) {
    return AdminOrdersState(
      isLoading: isLoading ?? this.isLoading,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      transitionOrderId: clearTransitionOrderId
          ? null
          : transitionOrderId ?? this.transitionOrderId,
      transitionTargetStatus: clearTransitionTargetStatus
          ? null
          : transitionTargetStatus ?? this.transitionTargetStatus,
      orders: orders ?? this.orders,
      selectedOrderId: clearSelectedOrderId
          ? null
          : selectedOrderId ?? this.selectedOrderId,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : statusFilter ?? this.statusFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      lastDocument: clearLastDocument
          ? null
          : lastDocument ?? this.lastDocument,
      cursorStack: cursorStack ?? this.cursorStack,
      loadErrorMessage: clearLoadError
          ? null
          : loadErrorMessage ?? this.loadErrorMessage,
      feedbackMessage: clearFeedback
          ? null
          : feedbackMessage ?? this.feedbackMessage,
      feedbackIsError: clearFeedback
          ? false
          : feedbackIsError ?? this.feedbackIsError,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isTransitioning,
    transitionOrderId,
    transitionTargetStatus,
    orders,
    selectedOrderId,
    searchQuery,
    statusFilter,
    dateFilter,
    currentPage,
    pageSize,
    hasNextPage,
    lastDocument,
    cursorStack,
    loadErrorMessage,
    feedbackMessage,
    feedbackIsError,
  ];
}
