import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_order.dart';

/// Service that reads orders directly from Firestore.
///
/// Maps raw Firestore documents (written by the orders worker) to [AdminOrder]
/// models used by the admin dashboard. Handles:
/// - Status string → [AdminOrderStatus] enum mapping
/// - Money normalization across legacy and new schemas
/// - Missing fields gracefully (no customer object, string address, no timeline)
class FirestoreAdminOrdersService {
  FirestoreAdminOrdersService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const int defaultOrderPageSize = 25;

  Future<FirestoreAdminOrdersPage> fetchOrdersPage({
    int pageSize = defaultOrderPageSize,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
    AdminOrderStatus? statusFilter,
    AdminOrderDateFilter dateFilter = AdminOrderDateFilter.all,
    String searchQuery = '',
  }) async {
    final safePageSize = pageSize.clamp(1, 100);
    final normalizedSearch = searchQuery.trim();

    if (normalizedSearch.isNotEmpty) {
      final order = await fetchOrderById(normalizedSearch);
      final matches =
          order != null &&
          _matchesStatus(order, statusFilter) &&
          _matchesDate(order.createdAt, dateFilter);
      return FirestoreAdminOrdersPage(
        orders: matches ? <AdminOrder>[order] : const <AdminOrder>[],
        hasNextPage: false,
        lastDocument: null,
      );
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where(
        'status',
        isEqualTo: orderStatusToFirestore(statusFilter),
      );
    }

    final dateRange = _dateRangeForFilter(dateFilter);
    if (dateRange != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(dateRange.end));
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.limit(safePageSize + 1).get();
    final pageDocs = snapshot.docs.take(safePageSize).toList(growable: false);
    return FirestoreAdminOrdersPage(
      orders: pageDocs
          .map((doc) => _mapDocToAdminOrder(doc.id, doc.data()))
          .toList(growable: false),
      hasNextPage: snapshot.docs.length > safePageSize,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  Future<List<AdminOrder>> fetchOrders({
    int limit = defaultOrderPageSize,
    int? maxOrders,
  }) async {
    final page = await fetchOrdersPage(pageSize: maxOrders ?? limit);
    return page.orders;
  }

  Future<AdminOrder?> fetchOrderById(String orderId) async {
    final snapshot = await _firestore.collection('orders').doc(orderId).get();
    if (!snapshot.exists) {
      return null;
    }
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return _mapDocToAdminOrder(snapshot.id, data);
  }

  AdminOrder _mapDocToAdminOrder(String docId, Map<String, dynamic> data) {
    // --- Status ---
    final status = parseOrderStatus(data['status'] as String?);

    // --- Money: prefer v1+ fields (minor units), fallback to legacy major units ---
    final rawTotalAmount = data['totalAmount'];
    final rawLegacyTotal = data['total'];
    final totalAmount = rawTotalAmount != null
        ? normalizeMoneyToMinorUnits(rawTotalAmount, preferMinorUnits: true)
        : normalizeMoneyToMinorUnits(rawLegacyTotal, preferMinorUnits: false);

    // --- Items → AdminOrderProduct ---
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final products = rawItems.map((item) {
      final map = item as Map<String, dynamic>? ?? {};
      final rawUnitPrice = map['unitPrice'];
      final rawSnapshotPrice = map['priceSnapshot'] ?? map['price'];
      final unitPrice = rawUnitPrice != null
          ? normalizeMoneyToMinorUnits(rawUnitPrice, preferMinorUnits: true)
          : normalizeMoneyToMinorUnits(
              rawSnapshotPrice,
              preferMinorUnits: false,
            );

      return AdminOrderProduct(
        name: (map['name'] as String?) ?? 'Product',
        imageUrl: '', // Worker doesn't store image URLs in order items
        sku: (map['productId'] as String?) ?? '',
        quantity: (map['quantity'] as int?) ?? 1,
        unitPrice: unitPrice,
      );
    }).toList();

    // --- Customer: orders don't have a customer object ---
    // We use what's available from the order document
    final userId = (data['userId'] as String?) ?? '';
    final phone = (data['phone'] as String?) ?? '';
    final customer = AdminOrderCustomer(
      name: _resolveCustomerName(userId),
      email: '',
      phone: phone,
      avatarUrl: '',
      verified: false,
    );

    // --- Address: stored as a flat string in Firestore ---
    final rawAddress = (data['address'] as String?) ?? '';
    final address = AdminOrderAddress(
      recipient: customer.name,
      line1: rawAddress,
      city: '',
      region: '',
      country: '',
      postalCode: '',
    );

    // --- CreatedAt ---
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final orderSource = (data['orderSource'] ?? 'app').toString();
    final attributionMetadata = data['attributionMetadata'] is Map
        ? Map<String, dynamic>.from(data['attributionMetadata'] as Map)
        : null;

    // --- Location: derive from address or use a default ---
    final location = rawAddress.isNotEmpty ? rawAddress : 'Unknown location';

    // --- Payment method ---
    final paymentMethod = _resolvePaymentMethodLabel(
      data['paymentMethod'] as String?,
    );

    final timeline = _timelineFromData(data, createdAt, status);

    return AdminOrder(
      id: docId,
      customer: customer,
      location: location,
      address: address,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      status: status,
      products: products,
      createdAt: createdAt,
      timeline: timeline,
      orderSource: orderSource,
      attributionMetadata: attributionMetadata,
    );
  }
}

List<AdminOrderTimelineEntry> _timelineFromData(
  Map<String, dynamic> data,
  DateTime createdAt,
  AdminOrderStatus status,
) {
  final rawTimeline = data['timeline'];
  if (rawTimeline is List) {
    final entries =
        rawTimeline
            .whereType<Map<dynamic, dynamic>>()
            .map((entry) => _timelineEntryFromMap(entry))
            .whereType<AdminOrderTimelineEntry>()
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (entries.isNotEmpty) {
      return entries;
    }
  }

  final fallback = <AdminOrderTimelineEntry>[
    AdminOrderTimelineEntry(
      actorId: 'system_storefront',
      actorRole: AdminTimelineActorRole.system,
      source: AdminTimelineSource.storefront,
      occurredAt: createdAt,
      note: 'Order created.',
      toStatus: AdminOrderStatus.pending,
    ),
  ];

  if (status != AdminOrderStatus.pending) {
    final updatedBy = (data['updatedBy'] as String?) ?? 'system';
    fallback.insert(
      0,
      AdminOrderTimelineEntry(
        actorId: updatedBy,
        actorRole: AdminTimelineActorRole.system,
        source: AdminTimelineSource.workerSystem,
        occurredAt: data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate()
            : createdAt,
        note: 'Status updated to ${adminOrderStatusLabel(status)}.',
        fromStatus: AdminOrderStatus.pending,
        toStatus: status,
      ),
    );
  }

  return fallback;
}

AdminOrderTimelineEntry? _timelineEntryFromMap(Map<dynamic, dynamic> raw) {
  final occurredAt = _timestampOrNull(raw['occurredAt'])?.toDate();
  if (occurredAt == null) {
    return null;
  }
  final note = (raw['note'] ?? '').toString().trim();
  return AdminOrderTimelineEntry(
    actorId: (raw['actorId'] ?? 'system').toString(),
    actorRole: _timelineActorRole(raw['actorRole']),
    source: _timelineSource(raw['source']),
    occurredAt: occurredAt,
    note: note.isEmpty ? 'Order status updated.' : note,
    fromStatus: _parseOrderStatusOrNull(raw['fromStatus']?.toString()),
    toStatus: _parseOrderStatusOrNull(raw['toStatus']?.toString()),
  );
}

AdminOrderStatus? _parseOrderStatusOrNull(String? raw) {
  try {
    return parseOrderStatus(raw);
  } catch (_) {
    return null;
  }
}

AdminTimelineActorRole _timelineActorRole(dynamic raw) {
  return switch (raw?.toString().trim().toLowerCase()) {
    'customer' => AdminTimelineActorRole.customer,
    'admin' => AdminTimelineActorRole.admin,
    'warehouse' => AdminTimelineActorRole.warehouse,
    'courier' => AdminTimelineActorRole.courier,
    _ => AdminTimelineActorRole.system,
  };
}

AdminTimelineSource _timelineSource(dynamic raw) {
  return switch (raw?.toString().trim().toLowerCase()) {
    'storefront' => AdminTimelineSource.storefront,
    'admin_dashboard' || 'admindashboard' => AdminTimelineSource.adminDashboard,
    _ => AdminTimelineSource.workerSystem,
  };
}

Timestamp? _timestampOrNull(dynamic value) {
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  return null;
}

class FirestoreAdminOrdersPage {
  const FirestoreAdminOrdersPage({
    required this.orders,
    required this.hasNextPage,
    required this.lastDocument,
  });

  final List<AdminOrder> orders;
  final bool hasNextPage;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class _DateRange {
  const _DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

_DateRange? _dateRangeForFilter(AdminOrderDateFilter filter) {
  final now = DateTime.now();
  return switch (filter) {
    AdminOrderDateFilter.all => null,
    AdminOrderDateFilter.today => _DateRange(
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    ),
    AdminOrderDateFilter.thisWeek => _DateRange(
      DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    ),
    AdminOrderDateFilter.thisMonth => _DateRange(
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ),
  };
}

bool _matchesStatus(AdminOrder order, AdminOrderStatus? statusFilter) {
  return statusFilter == null || order.status == statusFilter;
}

bool _matchesDate(DateTime createdAt, AdminOrderDateFilter filter) {
  final range = _dateRangeForFilter(filter);
  if (range == null) return true;
  return !createdAt.isBefore(range.start) && createdAt.isBefore(range.end);
}

String _resolveCustomerName(String userId) {
  if (userId.isEmpty) {
    return AdminLocaleController.globalT(
      'orders.customerUnknown',
      fallback: 'Customer',
    );
  }

  final shortId = userId.substring(0, userId.length > 6 ? 6 : userId.length);
  return AdminLocaleController.globalT(
    'orders.customerNumber',
    fallback: 'Customer #{id}',
    params: {'id': shortId},
  );
}

String _resolvePaymentMethodLabel(String? rawPaymentMethod) {
  final method = rawPaymentMethod?.trim() ?? '';
  if (method.isEmpty) {
    return AdminLocaleController.globalT(
      'orders.paymentMethod.cod',
      fallback: 'Cash on Delivery',
    );
  }

  final normalized = method.toLowerCase();
  if (normalized == 'cash on delivery' ||
      normalized == 'cod' ||
      method == 'الدفع عند الاستلام') {
    return AdminLocaleController.globalT(
      'orders.paymentMethod.cod',
      fallback: 'Cash on Delivery',
    );
  }

  return AdminLocaleController.globalResolve(method);
}

/// Normalizes a money field into minor units (piasters).
///
/// Legacy payloads (e.g. `total`, `priceSnapshot`) were often major units,
/// while v1+ fields (`totalAmount`, `unitPrice`) are minor units.
int normalizeMoneyToMinorUnits(dynamic raw, {required bool preferMinorUnits}) {
  if (raw == null) {
    return 0;
  }

  if (raw is int) {
    return preferMinorUnits ? raw : raw * 100;
  }

  if (raw is double) {
    if (preferMinorUnits && raw == raw.roundToDouble()) {
      return raw.toInt();
    }
    return (raw * 100).round();
  }

  if (raw is String) {
    final normalized = raw.replaceAll(',', '').trim();
    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      return 0;
    }
    if (preferMinorUnits && parsed == parsed.roundToDouble()) {
      return parsed.toInt();
    }
    return (parsed * 100).round();
  }

  return 0;
}
