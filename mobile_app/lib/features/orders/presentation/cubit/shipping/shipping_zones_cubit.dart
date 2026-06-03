import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/models/shipping_zone_model.dart';
import 'package:perfume_app/features/orders/data/repos/shipping_zones_repo.dart';

part 'shipping_zones_state.dart';

class ShippingZonesCubit extends Cubit<ShippingZonesState> {
  ShippingZonesCubit(this._repo) : super(const ShippingZonesInitial());

  final ShippingZonesRepo _repo;

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> loadZones({bool forceRefresh = false}) async {
    if (state is ShippingZonesLoading) return;
    emit(const ShippingZonesLoading());
    try {
      final zones = await _repo.fetchZones(forceRefresh: forceRefresh);
      emit(ShippingZonesLoaded(zones: zones));
    } catch (e) {
      emit(ShippingZonesError(e.toString()));
    }
  }

  // ── Select a zone ─────────────────────────────────────────────────────────

  /// Called when the user picks a governorate from the dropdown.
  /// Only proceeds if the zone is enabled.
  /// Returns the selected zone (or null if not found / disabled).
  ShippingZoneModel? selectZone(String code) {
    final loaded = state;
    if (loaded is! ShippingZonesLoaded) return null;

    final zone = _find(loaded.zones, code);
    if (zone == null || !zone.enabled) return null;

    emit(loaded.copyWith(selectedZone: zone));
    return zone;
  }

  /// Clears the current selection (e.g. when address changes).
  void clearSelection() {
    final loaded = state;
    if (loaded is ShippingZonesLoaded) {
      emit(loaded.copyWith(clearSelectedZone: true));
    }
  }

  // ── Convenience getters ──────────────────────────────────────────────────

  List<ShippingZoneModel> get enabledZones {
    final loaded = state;
    if (loaded is ShippingZonesLoaded) {
      return loaded.zones.where((z) => z.enabled).toList();
    }
    return const [];
  }

  ShippingZoneModel? zoneForCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final loaded = state;
    if (loaded is! ShippingZonesLoaded) return null;
    return _find(loaded.zones, code);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static ShippingZoneModel? _find(
    List<ShippingZoneModel> zones,
    String code,
  ) {
    final normalised = code.trim().toLowerCase();
    try {
      return zones.firstWhere((z) => z.code == normalised);
    } catch (_) {
      return null;
    }
  }
}
