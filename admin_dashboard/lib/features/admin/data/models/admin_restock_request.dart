import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum AdminRestockStatus { pending, notified, converted, cancelled }

enum AdminRestockContactMethod { email, phone }

class AdminRestockRequest extends Equatable {
  const AdminRestockRequest({
    required this.id,
    required this.productId,
    required this.contactMethod,
    required this.contactValue,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.notifiedAt,
    this.convertedAt,
    this.orderId,
    this.cancelledAt,
    this.lostOpportunityAt,
    this.cohortLabel,
  });

  factory AdminRestockRequest.fromJson(Map<String, dynamic> data) {
    final rawStatus = data['status'] as String?;
    final AdminRestockStatus status = switch (rawStatus?.toLowerCase().trim()) {
      'pending' => AdminRestockStatus.pending,
      'notified' => AdminRestockStatus.notified,
      'converted' => AdminRestockStatus.converted,
      'cancelled' => AdminRestockStatus.cancelled,
      _ => AdminRestockStatus.pending,
    };
    final rawContactMethod = data['contactMethod'] as String?;
    final contactMethod = switch (rawContactMethod?.toLowerCase().trim()) {
      'phone' => AdminRestockContactMethod.phone,
      _ => AdminRestockContactMethod.email,
    };

    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final updatedAt = data['updatedAt'] is Timestamp
        ? (data['updatedAt'] as Timestamp).toDate()
        : createdAt;

    final notifiedAt = data['notifiedAt'] is Timestamp
        ? (data['notifiedAt'] as Timestamp).toDate()
        : null;
    final convertedAt = data['convertedAt'] is Timestamp
        ? (data['convertedAt'] as Timestamp).toDate()
        : null;
    final cancelledAt = data['cancelledAt'] is Timestamp
        ? (data['cancelledAt'] as Timestamp).toDate()
        : null;
    final lostOpportunityAt = data['lostOpportunityAt'] is Timestamp
        ? (data['lostOpportunityAt'] as Timestamp).toDate()
        : null;

    return AdminRestockRequest(
      id: (data['id'] as String?) ?? '',
      productId: (data['productId'] as String?) ?? '',
      userId: data['userId'] as String?,
      contactMethod: contactMethod,
      contactValue: (data['contactValue'] as String?) ?? '',
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      notifiedAt: notifiedAt,
      convertedAt: convertedAt,
      orderId: data['orderId'] as String?,
      cancelledAt: cancelledAt,
      lostOpportunityAt: lostOpportunityAt,
      cohortLabel: data['cohortLabel'] as String?,
    );
  }

  final String id;
  final String productId;
  final String? userId;
  final AdminRestockContactMethod contactMethod;
  final String contactValue;
  final AdminRestockStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? notifiedAt;
  final DateTime? convertedAt;
  final String? orderId;
  final DateTime? cancelledAt;
  final DateTime? lostOpportunityAt;
  final String? cohortLabel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'productId': productId,
      'userId': userId,
      'contactMethod': contactMethod.name,
      'contactValue': contactValue,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'notifiedAt': notifiedAt == null ? null : Timestamp.fromDate(notifiedAt!),
      'convertedAt': convertedAt == null
          ? null
          : Timestamp.fromDate(convertedAt!),
      'orderId': orderId,
      'cancelledAt': cancelledAt == null
          ? null
          : Timestamp.fromDate(cancelledAt!),
      'lostOpportunityAt': lostOpportunityAt == null
          ? null
          : Timestamp.fromDate(lostOpportunityAt!),
      'cohortLabel': cohortLabel,
    };
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    userId,
    contactMethod,
    contactValue,
    status,
    createdAt,
    updatedAt,
    notifiedAt,
    convertedAt,
    orderId,
    cancelledAt,
    lostOpportunityAt,
    cohortLabel,
  ];
}
