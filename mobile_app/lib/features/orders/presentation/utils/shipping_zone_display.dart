import 'dart:ui';

import 'package:perfume_app/core/models/shipping_zone_model.dart';

String shippingZoneDisplayName(ShippingZoneModel zone, Locale locale) {
  if (locale.languageCode == 'en' && zone.governorateEn.trim().isNotEmpty) {
    return zone.governorateEn.trim();
  }
  return zone.governorate.trim();
}

ShippingZoneModel? shippingZoneByCode(
  Iterable<ShippingZoneModel> zones,
  String? code,
) {
  final normalized = code?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final zone in zones) {
    if (zone.code == normalized) return zone;
  }
  return null;
}

String localizedShippingZoneLabel({
  required Locale locale,
  required Iterable<ShippingZoneModel> zones,
  String? shippingZoneCode,
  String? governorateCode,
  String? fallbackLabel,
}) {
  final resolvedZone =
      shippingZoneByCode(zones, shippingZoneCode) ??
      shippingZoneByCode(zones, governorateCode);
  if (resolvedZone != null) {
    return shippingZoneDisplayName(resolvedZone, locale);
  }

  final fallback = fallbackLabel?.trim();
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }

  return '';
}
