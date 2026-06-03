import 'package:equatable/equatable.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_feature_highlight.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';

class AdminContentSnapshot extends Equatable {
  const AdminContentSnapshot({
    required this.products,
    required this.banners,
    required this.categories,
    this.businessInfo = const AdminBusinessInfo(),
    this.featuredEditorial,
  });

  final List<ProductEntry> products;
  final List<BannerEntry> banners;
  final List<CategoryEntry> categories;
  final AdminBusinessInfo businessInfo;
  final AdminFeatureHighlight? featuredEditorial;

  @override
  List<Object?> get props => [
    products,
    banners,
    categories,
    businessInfo,
    featuredEditorial,
  ];
}

class AdminBusinessInfo extends Equatable {
  const AdminBusinessInfo({
    this.storeName = '',
    this.addressAr = '',
    this.addressEn = '',
    this.phone = '',
    this.whatsapp = '',
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.websiteUrl = '',
    this.openingHoursAr = '',
    this.openingHoursEn = '',
    this.deliveryInfoAr = '',
    this.deliveryInfoEn = '',
    this.isPublished = false,
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

  factory AdminBusinessInfo.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    String asString(String key) => data[key]?.toString().trim() ?? '';
    return AdminBusinessInfo(
      storeName: asString('storeName'),
      addressAr: asString('addressAr'),
      addressEn: asString('addressEn'),
      phone: asString('phone'),
      whatsapp: asString('whatsapp'),
      facebookUrl: asString('facebookUrl'),
      instagramUrl: asString('instagramUrl'),
      websiteUrl: asString('websiteUrl'),
      openingHoursAr: asString('openingHoursAr'),
      openingHoursEn: asString('openingHoursEn'),
      deliveryInfoAr: asString('deliveryInfoAr'),
      deliveryInfoEn: asString('deliveryInfoEn'),
      isPublished: data['isPublished'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName.trim(),
      'addressAr': addressAr.trim(),
      'addressEn': addressEn.trim(),
      'phone': phone.trim(),
      'whatsapp': whatsapp.trim(),
      'facebookUrl': facebookUrl.trim(),
      'instagramUrl': instagramUrl.trim(),
      'websiteUrl': websiteUrl.trim(),
      'openingHoursAr': openingHoursAr.trim(),
      'openingHoursEn': openingHoursEn.trim(),
      'deliveryInfoAr': deliveryInfoAr.trim(),
      'deliveryInfoEn': deliveryInfoEn.trim(),
      'isPublished': isPublished,
    };
  }

  @override
  List<Object?> get props => [
    storeName,
    addressAr,
    addressEn,
    phone,
    whatsapp,
    facebookUrl,
    instagramUrl,
    websiteUrl,
    openingHoursAr,
    openingHoursEn,
    deliveryInfoAr,
    deliveryInfoEn,
    isPublished,
  ];
}
