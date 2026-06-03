part of 'shipping_zones_cubit.dart';

sealed class ShippingZonesState {
  const ShippingZonesState();
}

final class ShippingZonesInitial extends ShippingZonesState {
  const ShippingZonesInitial();
}

final class ShippingZonesLoading extends ShippingZonesState {
  const ShippingZonesLoading();
}

final class ShippingZonesLoaded extends ShippingZonesState {
  const ShippingZonesLoaded({
    required this.zones,
    this.selectedZone,
  });

  /// All zones (enabled + disabled) from Firestore.
  final List<ShippingZoneModel> zones;

  /// The zone the user has currently selected in the address form.
  final ShippingZoneModel? selectedZone;

  List<ShippingZoneModel> get enabledZones =>
      zones.where((z) => z.enabled).toList();

  double get selectedFee => selectedZone?.fee ?? 0.0;

  ShippingZonesLoaded copyWith({
    List<ShippingZoneModel>? zones,
    ShippingZoneModel? selectedZone,
    bool clearSelectedZone = false,
  }) {
    return ShippingZonesLoaded(
      zones: zones ?? this.zones,
      selectedZone: clearSelectedZone ? null : (selectedZone ?? this.selectedZone),
    );
  }
}

final class ShippingZonesError extends ShippingZonesState {
  const ShippingZonesError(this.message);
  final String message;
}
