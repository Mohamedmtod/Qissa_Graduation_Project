import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';

bool _isArabicLocale() {
  return AdminLocaleController.isGlobalArabic;
}

enum AdminOrderStatus {
  pending,
  orderProcessing,
  outForDelivery,
  delivered,
  cancelled,
}

enum AdminTimelineActorRole { customer, admin, system, warehouse, courier }

enum AdminTimelineSource { storefront, adminDashboard, workerSystem }

enum AdminOrderDateFilter { all, today, thisWeek, thisMonth }

class AdminOrderCustomer extends Equatable {
  const AdminOrderCustomer({
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.verified,
  });

  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
  final bool verified;

  @override
  List<Object?> get props => [name, email, phone, avatarUrl, verified];
}

class AdminOrderAddress extends Equatable {
  const AdminOrderAddress({
    required this.recipient,
    required this.line1,
    required this.city,
    required this.region,
    required this.country,
    required this.postalCode,
  });

  final String recipient;
  final String line1;
  final String city;
  final String region;
  final String country;
  final String postalCode;

  String get formatted => '$line1, $city, $region, $country, $postalCode';

  @override
  List<Object?> get props => [
    recipient,
    line1,
    city,
    region,
    country,
    postalCode,
  ];
}

class AdminOrderProduct extends Equatable {
  const AdminOrderProduct({
    required this.name,
    required this.imageUrl,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final String imageUrl;
  final String sku;
  final int quantity;
  final int unitPrice;

  int get subtotal => quantity * unitPrice;

  @override
  List<Object?> get props => [name, imageUrl, sku, quantity, unitPrice];
}

class AdminOrderTimelineEntry extends Equatable {
  const AdminOrderTimelineEntry({
    required this.actorId,
    required this.actorRole,
    required this.source,
    required this.occurredAt,
    required this.note,
    this.fromStatus,
    this.toStatus,
  });

  final String actorId;
  final AdminTimelineActorRole actorRole;
  final AdminTimelineSource source;
  final DateTime occurredAt;
  final String note;
  final AdminOrderStatus? fromStatus;
  final AdminOrderStatus? toStatus;

  @override
  List<Object?> get props => [
    actorId,
    actorRole,
    source,
    occurredAt,
    note,
    fromStatus,
    toStatus,
  ];
}

class AdminOrder extends Equatable {
  const AdminOrder({
    required this.id,
    required this.customer,
    required this.location,
    required this.address,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    required this.products,
    required this.createdAt,
    required this.timeline,
    this.orderSource = 'app',
    this.attributionMetadata,
  });

  final String id;
  final AdminOrderCustomer customer;
  final String location;
  final AdminOrderAddress address;
  final int totalAmount;
  final String paymentMethod;
  final AdminOrderStatus status;
  final List<AdminOrderProduct> products;
  final DateTime createdAt;
  final List<AdminOrderTimelineEntry> timeline;
  final String orderSource;
  final Map<String, dynamic>? attributionMetadata;

  AdminOrder copyWith({
    AdminOrderStatus? status,
    List<AdminOrderTimelineEntry>? timeline,
    String? orderSource,
    Map<String, dynamic>? attributionMetadata,
  }) {
    return AdminOrder(
      id: id,
      customer: customer,
      location: location,
      address: address,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      products: products,
      createdAt: createdAt,
      timeline: timeline ?? this.timeline,
      orderSource: orderSource ?? this.orderSource,
      attributionMetadata: attributionMetadata ?? this.attributionMetadata,
    );
  }

  String get formattedTotal => formatMoney(totalAmount);

  @override
  List<Object?> get props => [
    id,
    customer,
    location,
    address,
    totalAmount,
    paymentMethod,
    status,
    products,
    createdAt,
    timeline,
    orderSource,
    attributionMetadata,
  ];
}

class OrderTransitionDecision extends Equatable {
  const OrderTransitionDecision._({
    required this.isAllowed,
    required this.reason,
  });

  const OrderTransitionDecision.allowed()
    : this._(isAllowed: true, reason: null);

  const OrderTransitionDecision.rejected(String reason)
    : this._(isAllowed: false, reason: reason);

  final bool isAllowed;
  final String? reason;

  @override
  List<Object?> get props => [isAllowed, reason];
}

OrderTransitionDecision validateAdminOrderTransition({
  required AdminOrderStatus current,
  required AdminOrderStatus next,
}) {
  if (current == next) {
    return OrderTransitionDecision.rejected(
      AdminLocaleController.globalT(
        'orders.transition.alreadyInStatus',
        params: {'status': adminOrderStatusLabel(current)},
      ),
    );
  }

  final allowed = switch (current) {
    AdminOrderStatus.pending => {
      AdminOrderStatus.orderProcessing,
      AdminOrderStatus.cancelled,
    },
    AdminOrderStatus.orderProcessing => {
      AdminOrderStatus.outForDelivery,
      AdminOrderStatus.cancelled,
    },
    AdminOrderStatus.outForDelivery => {AdminOrderStatus.delivered},
    AdminOrderStatus.delivered => <AdminOrderStatus>{},
    AdminOrderStatus.cancelled => <AdminOrderStatus>{},
  };

  if (allowed.contains(next)) {
    return const OrderTransitionDecision.allowed();
  }

  final allowedLabels = allowed.isEmpty
      ? AdminLocaleController.globalT('orders.transition.noAllowedAfter')
      : AdminLocaleController.globalT(
          'orders.transition.allowedPath',
          params: {'path': allowed.map(adminOrderStatusLabel).join(' / ')},
        );

  return OrderTransitionDecision.rejected(
    AdminLocaleController.globalT(
      'orders.transition.cannotMove',
      params: {
        'from': adminOrderStatusLabel(current),
        'to': adminOrderStatusLabel(next),
        'allowed': allowedLabels,
      },
    ),
  );
}

String adminOrderStatusLabel(AdminOrderStatus status) {
  return switch (status) {
    AdminOrderStatus.pending => AdminLocaleController.globalT(
      'orders.status.pending',
    ),
    AdminOrderStatus.orderProcessing => AdminLocaleController.globalT(
      'orders.status.processing',
    ),
    AdminOrderStatus.outForDelivery => AdminLocaleController.globalT(
      'orders.status.outForDelivery',
    ),
    AdminOrderStatus.delivered => AdminLocaleController.globalT(
      'orders.status.delivered',
    ),
    AdminOrderStatus.cancelled => AdminLocaleController.globalT(
      'orders.status.cancelled',
    ),
  };
}

/// Maps a raw Firestore status string to [AdminOrderStatus].
/// Throws [FormatException] for unrecognized values.
AdminOrderStatus parseOrderStatus(String? raw) {
  return switch (raw?.toLowerCase().trim()) {
    'pending' => AdminOrderStatus.pending,
    'order_processing' => AdminOrderStatus.orderProcessing,
    'out_for_delivery' => AdminOrderStatus.outForDelivery,
    'delivered' => AdminOrderStatus.delivered,
    'cancelled' => AdminOrderStatus.cancelled,
    _ => throw FormatException('Unsupported order status: ${raw ?? "null"}'),
  };
}

/// Converts [AdminOrderStatus] to its Firestore string representation.
String orderStatusToFirestore(AdminOrderStatus status) {
  return switch (status) {
    AdminOrderStatus.pending => 'pending',
    AdminOrderStatus.orderProcessing => 'order_processing',
    AdminOrderStatus.outForDelivery => 'out_for_delivery',
    AdminOrderStatus.delivered => 'delivered',
    AdminOrderStatus.cancelled => 'cancelled',
  };
}

String adminTimelineActorRoleLabel(AdminTimelineActorRole role) {
  return switch (role) {
    AdminTimelineActorRole.customer => AdminLocaleController.globalT(
      'orders.timeline.actor.customer',
    ),
    AdminTimelineActorRole.admin => AdminLocaleController.globalT(
      'orders.timeline.actor.admin',
    ),
    AdminTimelineActorRole.system => AdminLocaleController.globalT(
      'orders.timeline.actor.system',
    ),
    AdminTimelineActorRole.warehouse => AdminLocaleController.globalT(
      'orders.timeline.actor.warehouse',
    ),
    AdminTimelineActorRole.courier => AdminLocaleController.globalT(
      'orders.timeline.actor.courier',
    ),
  };
}

String adminTimelineSourceLabel(AdminTimelineSource source) {
  return switch (source) {
    AdminTimelineSource.storefront => AdminLocaleController.globalT(
      'orders.timeline.source.storefront',
    ),
    AdminTimelineSource.adminDashboard => AdminLocaleController.globalT(
      'orders.timeline.source.adminDashboard',
    ),
    AdminTimelineSource.workerSystem => AdminLocaleController.globalT(
      'orders.timeline.source.workerSystem',
    ),
  };
}

String adminOrderDateFilterLabel(AdminOrderDateFilter filter) {
  return switch (filter) {
    AdminOrderDateFilter.all => AdminLocaleController.globalT(
      'orders.dateFilter.all',
    ),
    AdminOrderDateFilter.today => AdminLocaleController.globalT(
      'orders.dateFilter.today',
    ),
    AdminOrderDateFilter.thisWeek => AdminLocaleController.globalT(
      'orders.dateFilter.thisWeek',
    ),
    AdminOrderDateFilter.thisMonth => AdminLocaleController.globalT(
      'orders.dateFilter.thisMonth',
    ),
  };
}

String formatMoney(int valueMinor) {
  final isArabic = _isArabicLocale();
  final formatter = NumberFormat.currency(
    locale: isArabic ? 'ar_EG' : 'en_US',
    symbol: AdminLocaleController.globalT('currency.symbol'),
    decimalDigits: 2,
  );
  return formatter.format(valueMinor / 100);
}

String formatTimelineDate(DateTime value) {
  final isArabic = _isArabicLocale();
  final formatter = DateFormat(
    isArabic ? 'd MMM y، h:mm a' : 'd MMM y, h:mm a',
    isArabic ? 'ar_EG' : 'en_US',
  );
  return formatter.format(value);
}
