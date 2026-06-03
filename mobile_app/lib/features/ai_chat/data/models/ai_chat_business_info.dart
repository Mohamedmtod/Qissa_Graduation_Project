import 'package:cloud_firestore/cloud_firestore.dart';

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

bool _asBool(dynamic value) => value == true;

class AIChatBusinessInfo {
  const AIChatBusinessInfo({
    required this.storeName,
    required this.addressAr,
    required this.addressEn,
    required this.phone,
    required this.whatsapp,
    required this.facebookUrl,
    required this.instagramUrl,
    required this.websiteUrl,
    required this.openingHoursAr,
    required this.openingHoursEn,
    required this.deliveryInfoAr,
    required this.deliveryInfoEn,
    required this.isPublished,
  });

  final String storeName;
  final String addressAr;
  final String addressEn;
  final String phone;
  final String whatsapp;
  final String facebookUrl;
  final String instagramUrl;
  final String websiteUrl;
  final String openingHoursAr;
  final String openingHoursEn;
  final String deliveryInfoAr;
  final String deliveryInfoEn;
  final bool isPublished;

  bool get hasAddress => addressAr.isNotEmpty || addressEn.isNotEmpty;
  bool get hasContact =>
      phone.isNotEmpty ||
      whatsapp.isNotEmpty ||
      facebookUrl.isNotEmpty ||
      instagramUrl.isNotEmpty ||
      websiteUrl.isNotEmpty;
  bool get hasOpeningHours =>
      openingHoursAr.isNotEmpty || openingHoursEn.isNotEmpty;
  bool get hasDeliveryInfo =>
      deliveryInfoAr.isNotEmpty || deliveryInfoEn.isNotEmpty;

  bool get hasAnyPublicInfo =>
      isPublished &&
      (hasAddress || hasContact || hasOpeningHours || hasDeliveryInfo);

  factory AIChatBusinessInfo.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return AIChatBusinessInfo(
      storeName: _asString(data['storeName']),
      addressAr: _asString(data['addressAr']),
      addressEn: _asString(data['addressEn']),
      phone: _asString(data['phone']),
      whatsapp: _asString(data['whatsapp']),
      facebookUrl: _asString(data['facebookUrl']),
      instagramUrl: _asString(data['instagramUrl']),
      websiteUrl: _asString(data['websiteUrl']),
      openingHoursAr: _asString(data['openingHoursAr']),
      openingHoursEn: _asString(data['openingHoursEn']),
      deliveryInfoAr: _asString(data['deliveryInfoAr']),
      deliveryInfoEn: _asString(data['deliveryInfoEn']),
      isPublished: data.containsKey('isPublished')
          ? _asBool(data['isPublished'])
          : false,
    );
  }
}

class AIChatProductPublicStats {
  const AIChatProductPublicStats({
    required this.productId,
    required this.soldQty30d,
    required this.soldQty90d,
    required this.soldQtyAllTime,
    this.lastComputedAt,
  });

  final String productId;
  final int soldQty30d;
  final int soldQty90d;
  final int soldQtyAllTime;
  final Timestamp? lastComputedAt;

  bool get hasSalesSignal =>
      soldQty30d > 0 || soldQty90d > 0 || soldQtyAllTime > 0;

  factory AIChatProductPublicStats.fromMap({
    required String documentId,
    required Map<String, dynamic> map,
  }) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    return AIChatProductPublicStats(
      productId: _asString(map['productId']).isEmpty
          ? documentId
          : _asString(map['productId']),
      soldQty30d: asInt(map['soldQty30d']),
      soldQty90d: asInt(map['soldQty90d']),
      soldQtyAllTime: asInt(map['soldQtyAllTime']),
      lastComputedAt: map['lastComputedAt'] is Timestamp
          ? map['lastComputedAt'] as Timestamp
          : null,
    );
  }
}
