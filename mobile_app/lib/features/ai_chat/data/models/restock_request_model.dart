import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum RestockContactMethod { email, phone }

enum RestockRequestStatus { pending, notified, converted, cancelled }

class RestockRequestModel extends Equatable {
  const RestockRequestModel({
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
    this.cancelledAt,
    this.lostOpportunityAt,
    this.cohortLabel,
    this.orderId,
  });

  factory RestockRequestModel.fromJson(Map<String, dynamic> json) {
    return RestockRequestModel(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      userId: json['userId']?.toString(),
      contactMethod: _parseContactMethod(json['contactMethod']?.toString()),
      contactValue: json['contactValue']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      createdAt: _readTimestamp(json['createdAt']) ?? DateTime.now(),
      updatedAt: _readTimestamp(json['updatedAt']) ?? DateTime.now(),
      notifiedAt: _readTimestamp(json['notifiedAt']),
      convertedAt: _readTimestamp(json['convertedAt']),
      cancelledAt: _readTimestamp(json['cancelledAt']),
      lostOpportunityAt: _readTimestamp(json['lostOpportunityAt']),
      cohortLabel: json['cohortLabel']?.toString(),
      orderId: json['orderId']?.toString(),
    );
  }

  final String id;
  final String productId;
  final String? userId;
  final RestockContactMethod contactMethod;
  final String contactValue;
  final RestockRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? notifiedAt;
  final DateTime? convertedAt;
  final DateTime? cancelledAt;
  final DateTime? lostOpportunityAt;
  final String? cohortLabel;
  final String? orderId;

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
      'cancelledAt': cancelledAt == null
          ? null
          : Timestamp.fromDate(cancelledAt!),
      'lostOpportunityAt': lostOpportunityAt == null
          ? null
          : Timestamp.fromDate(lostOpportunityAt!),
      'cohortLabel': cohortLabel,
      'orderId': orderId,
    };
  }

  static RestockContactMethod _parseContactMethod(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'phone' => RestockContactMethod.phone,
      _ => RestockContactMethod.email,
    };
  }

  static RestockRequestStatus _parseStatus(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'converted' => RestockRequestStatus.converted,
      'cancelled' => RestockRequestStatus.cancelled,
      'notified' => RestockRequestStatus.notified,
      _ => RestockRequestStatus.pending,
    };
  }

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
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
    cancelledAt,
    lostOpportunityAt,
    cohortLabel,
    orderId,
  ];
}
