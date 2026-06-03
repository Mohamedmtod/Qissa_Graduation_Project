import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/core/models/shipping_zone_model.dart';

/// Firestore path constants for the shipping zones config document.
class _ShippingZonesPaths {
  static const collection = 'config';
  static const document = 'shipping_zones';
  static const zonesField = 'zones';
}

/// Repository that reads delivery zone configuration from Firestore.
///
/// The document `/config/shipping_zones` is publicly readable (Firestore rules)
/// and can only be written by admin via the Admin Dashboard.
///
/// Results are cached in-memory for [_cacheTtl] to avoid repeated Firestore
/// reads on every page navigation.
class ShippingZonesRepo {
  ShippingZonesRepo({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _cacheTtl = Duration(minutes: 30);

  List<ShippingZoneModel>? _cache;
  DateTime? _cacheExpiry;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore
          .collection(_ShippingZonesPaths.collection)
          .doc(_ShippingZonesPaths.document);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetches enabled and disabled zones (all), with caching.
  Future<List<ShippingZoneModel>> fetchZones({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && _cacheExpiry != null) {
      if (DateTime.now().isBefore(_cacheExpiry!)) {
        return _cache!;
      }
    }

    final snapshot = await _docRef.get();
    final zones = _parseZones(snapshot.data());
    _cache = zones;
    _cacheExpiry = DateTime.now().add(_cacheTtl);
    return zones;
  }

  /// Returns only zones where [ShippingZoneModel.enabled] == true.
  Future<List<ShippingZoneModel>> fetchEnabledZones({
    bool forceRefresh = false,
  }) async {
    final all = await fetchZones(forceRefresh: forceRefresh);
    return all.where((z) => z.enabled).toList();
  }

  /// Finds the zone matching [code] (case-insensitive). Returns null if missing.
  Future<ShippingZoneModel?> findZoneByCode(String code) async {
    final all = await fetchZones();
    final normalised = code.trim().toLowerCase();
    try {
      return all.firstWhere((z) => z.code == normalised);
    } catch (_) {
      return null;
    }
  }

  /// Attempts to auto-match [cityName] (from reverse geocoding) to a zone.
  /// Returns null if no match found.
  Future<ShippingZoneModel?> matchCityName(String cityName) async {
    if (cityName.trim().isEmpty) return null;
    final all = await fetchZones();
    try {
      return all.firstWhere((z) => z.matchesCityName(cityName));
    } catch (_) {
      return null;
    }
  }

  /// Invalidates the in-memory cache so next call refetches from Firestore.
  void invalidateCache() {
    _cache = null;
    _cacheExpiry = null;
  }

  // ── Parsing helpers ──────────────────────────────────────────────────────

  static List<ShippingZoneModel> _parseZones(Map<String, dynamic>? data) {
    if (data == null) return List.of(kEgyptianGovernorates);

    final raw = data[_ShippingZonesPaths.zonesField];
    if (raw is! List || raw.isEmpty) {
      return List.of(kEgyptianGovernorates);
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(ShippingZoneModel.fromMap)
        .toList();
  }
}
