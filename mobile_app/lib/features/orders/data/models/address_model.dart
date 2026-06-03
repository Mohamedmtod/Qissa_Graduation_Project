import 'package:cloud_firestore/cloud_firestore.dart';

enum AddressType { address, pickup }

class AddressModel {
  final String id;
  final AddressType type;

  // Personal Info (Common for both types, maybe only Name & Phone needed for pickup)
  final String fullName;
  final String phone;

  // Address Details (Only for AddressType.address)
  /// Kept for display and backward-compat. New code uses [governorate] for logic.
  final String? city;
  final String? area;
  final String? street;
  final String? building;
  final String? floor;
  final String? notes;

  // Pickup Details (Only for AddressType.pickup, e.g., Locker or store name/location)
  final String? pickupLocationId;
  final String? pickupLocationName;

  final bool defaultAddress;
  final DateTime? createdAt;

  // ── Shipping zone fields (added for dynamic shipping fees) ───────────────
  /// Stable zone code, e.g. "cairo", "giza". Null for legacy addresses.
  final String? shippingZoneCode;

  /// Stable governorate code, e.g. "cairo". Null for legacy addresses.
  final String? governorateCode;

  /// Arabic governorate name matching the chosen zone (display + worker).
  final String? governorate;

  /// Stable city/area code. Usually the same value as [shippingZoneCode].
  final String? cityCode;

  final double? mapLatitude;
  final double? mapLongitude;
  final String? mapRawAddress;

  /// Fee snapshotted at address-save time (informational; worker re-validates).
  final double? shippingFeeSnapshot;

  AddressModel({
    required this.id,
    required this.type,
    required this.fullName,
    required this.phone,
    this.city,
    this.area,
    this.street,
    this.building,
    this.floor,
    this.notes,
    this.pickupLocationId,
    this.pickupLocationName,
    this.defaultAddress = false,
    this.createdAt,
    this.shippingZoneCode,
    this.governorateCode,
    this.governorate,
    this.cityCode,
    this.mapLatitude,
    this.mapLongitude,
    this.mapRawAddress,
    this.shippingFeeSnapshot,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'fullName': fullName,
      'phone': phone,
      'city': city,
      'area': area,
      'street': street,
      'building': building,
      'floor': floor,
      'notes': notes,
      'pickupLocationId': pickupLocationId,
      'pickupLocationName': pickupLocationName,
      'defaultAddress': defaultAddress,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime(2000).toIso8601String(),
      // Shipping zone fields
      if (shippingZoneCode != null) 'shippingZoneCode': shippingZoneCode,
      if (governorateCode != null) 'governorateCode': governorateCode,
      if (governorate != null) 'governorate': governorate,
      if (cityCode != null) 'cityCode': cityCode,
      if (mapLatitude != null) 'mapLatitude': mapLatitude,
      if (mapLongitude != null) 'mapLongitude': mapLongitude,
      if (mapRawAddress != null) 'mapRawAddress': mapRawAddress,
      if (shippingFeeSnapshot != null)
        'shippingFeeSnapshot': shippingFeeSnapshot,
    };
  }

  factory AddressModel.fromMap(Map<String, dynamic> map, String docId) {
    return AddressModel(
      id: docId,
      type: AddressType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AddressType.address,
      ),
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      city: map['city'],
      area: map['area'],
      street: map['street'],
      building: map['building'],
      floor: map['floor'],
      notes: map['notes'],
      pickupLocationId: map['pickupLocationId'],
      pickupLocationName: map['pickupLocationName'],
      defaultAddress: map['defaultAddress'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : DateTime(2000),
      // Shipping zone fields – null-safe for legacy docs
      shippingZoneCode: map['shippingZoneCode'] as String?,
      governorateCode: map['governorateCode'] as String?,
      governorate: map['governorate'] as String?,
      cityCode: map['cityCode'] as String?,
      mapLatitude: (map['mapLatitude'] as num?)?.toDouble(),
      mapLongitude: (map['mapLongitude'] as num?)?.toDouble(),
      mapRawAddress: map['mapRawAddress'] as String?,
      shippingFeeSnapshot: (map['shippingFeeSnapshot'] as num?)?.toDouble(),
    );
  }

  factory AddressModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return AddressModel.fromMap(data, snap.id);
  }
}
