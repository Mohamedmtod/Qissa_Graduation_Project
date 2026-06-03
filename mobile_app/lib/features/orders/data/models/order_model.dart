import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_item_model.dart';

class OrderModel {
  final String id; // Firestore document ID
  final String userId;
  final List<OrderItemModel> items;
  final double subtotal;
  final double shippingFee;
  final double discount;
  final double total;
  // Shared worker/admin statuses: pending / order_processing / out_for_delivery / delivered / cancelled
  final String status;
  final String? failureReason;
  final String address;
  final String phone;
  final String paymentMethod;
  final String? notes;
  final Timestamp createdAt;
  final String? orderCode;
  final String? shippingZoneCode;
  final String? shippingGovernorate;
  final String? shippingGovernorateEn;
  // Shared attribution source: app / ai_chat / restock_alert
  final String orderSource;
  final Map<String, dynamic>? attributionMetadata;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    this.subtotal = 0,
    this.shippingFee = 0,
    this.discount = 0,
    required this.total,
    required this.status,
    this.failureReason,
    required this.address,
    required this.phone,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.orderCode,
    this.shippingZoneCode,
    this.shippingGovernorate,
    this.shippingGovernorateEn,
    this.orderSource = 'app',
    this.attributionMetadata,
  });

  OrderModel copyWith({
    String? id,
    String? userId,
    List<OrderItemModel>? items,
    double? subtotal,
    double? shippingFee,
    double? discount,
    double? total,
    String? status,
    String? failureReason,
    String? address,
    String? phone,
    String? paymentMethod,
    String? notes,
    Timestamp? createdAt,
    String? orderCode,
    String? shippingZoneCode,
    String? shippingGovernorate,
    String? shippingGovernorateEn,
    String? orderSource,
    Map<String, dynamic>? attributionMetadata,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      shippingFee: shippingFee ?? this.shippingFee,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      status: status ?? this.status,
      failureReason: failureReason ?? this.failureReason,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      orderCode: orderCode ?? this.orderCode,
      shippingZoneCode: shippingZoneCode ?? this.shippingZoneCode,
      shippingGovernorate: shippingGovernorate ?? this.shippingGovernorate,
      shippingGovernorateEn:
          shippingGovernorateEn ?? this.shippingGovernorateEn,
      orderSource: orderSource ?? this.orderSource,
      attributionMetadata: attributionMetadata ?? this.attributionMetadata,
    );
  }

  factory OrderModel.fromMap({
    required Map<String, dynamic> map,
    required String documentId,
  }) {
    return OrderModel(
      id: documentId,
      userId: map['userId'] ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItemModel.fromMap(e))
          .toList(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      shippingFee: (map['shippingFee'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      failureReason: map['failureReason'],
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'Cash on Delivery',
      notes: map['notes'],
      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt']
          : Timestamp.now(),
      orderCode: map['orderCode'] is String ? map['orderCode'] : null,
      shippingZoneCode: map['shippingZoneCode'] is String
          ? map['shippingZoneCode']
          : null,
      shippingGovernorate: map['shippingGovernorate'] is String
          ? map['shippingGovernorate']
          : null,
      shippingGovernorateEn: map['shippingGovernorateEn'] is String
          ? map['shippingGovernorateEn']
          : null,
      orderSource: map['orderSource'] ?? 'app',
      attributionMetadata: map['attributionMetadata'] is Map
          ? Map<String, dynamic>.from(map['attributionMetadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'discount': discount,
      'total': total,
      'status': status,
      'failureReason': failureReason,
      'address': address,
      'phone': phone,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdAt': createdAt,
      if (orderCode != null) 'orderCode': orderCode,
      if (shippingZoneCode != null) 'shippingZoneCode': shippingZoneCode,
      if (shippingGovernorate != null)
        'shippingGovernorate': shippingGovernorate,
      if (shippingGovernorateEn != null)
        'shippingGovernorateEn': shippingGovernorateEn,
      'orderSource': orderSource,
      if (attributionMetadata != null)
        'attributionMetadata': attributionMetadata,
    };
  }
}
