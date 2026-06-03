import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';

import '../../data/models/shipping_zone_model.dart';
import '../../data/services/admin_shipping_zones_service.dart';
import 'admin_shipping_zones_state.dart';

class AdminShippingZonesCubit extends Cubit<AdminShippingZonesState> {
  AdminShippingZonesCubit(this._service) : super(AdminShippingZonesInitial());

  final AdminShippingZonesService _service;

  Future<void> loadZones() async {
    emit(AdminShippingZonesLoading());
    try {
      final zones = await _service.fetchShippingZones();
      emit(AdminShippingZonesLoaded(zones: zones));
    } catch (e) {
      emit(AdminShippingZonesError(e.toString()));
    }
  }

  void updateZoneLocally(ShippingZoneModel updatedZone) {
    if (state is! AdminShippingZonesLoaded) return;
    final currentState = state as AdminShippingZonesLoaded;
    final updatedList = currentState.zones.map((zone) {
      return zone.code == updatedZone.code ? updatedZone : zone;
    }).toList();
    emit(currentState.copyWith(zones: updatedList));
  }

  void addZone(ShippingZoneModel newZone) {
    if (state is! AdminShippingZonesLoaded) return;
    final currentState = state as AdminShippingZonesLoaded;
    if (currentState.zones.any((zone) => zone.code == newZone.code)) {
      emit(AdminShippingZonesError(
        AdminLocaleController.globalT('shippingZones.error.codeExists'),
      ));
      emit(currentState);
      return;
    }
    emit(currentState.copyWith(zones: [...currentState.zones, newZone]));
  }

  void deleteZone(String code) {
    if (state is! AdminShippingZonesLoaded) return;
    final currentState = state as AdminShippingZonesLoaded;
    final updatedList = currentState.zones
        .where((zone) => zone.code != code)
        .toList();
    emit(currentState.copyWith(zones: updatedList));
  }

  Future<void> saveChanges() async {
    if (state is! AdminShippingZonesLoaded) return;
    final currentState = state as AdminShippingZonesLoaded;
    final validationError = _validateZones(currentState.zones);

    if (validationError != null) {
      emit(AdminShippingZonesError(validationError));
      emit(currentState);
      return;
    }

    emit(currentState.copyWith(isSaving: true));

    try {
      await _service.updateShippingZones(currentState.zones);
      emit(AdminShippingZonesSuccess(
        AdminLocaleController.globalT('shippingZones.success.saved'),
      ));
      emit(AdminShippingZonesLoaded(zones: currentState.zones));
    } catch (e) {
      emit(AdminShippingZonesError(
        AdminLocaleController.globalT(
          'shippingZones.error.saveFailed',
          params: {'error': e.toString()},
        ),
      ));
      emit(currentState.copyWith(isSaving: false));
    }
  }

  Future<void> resetToDefaults() async {
    if (state is! AdminShippingZonesLoaded) return;
    final currentState = state as AdminShippingZonesLoaded;
    final validationError = _validateZones(ShippingZoneModel.egyptSeedData);
    if (validationError != null) {
      emit(AdminShippingZonesError(validationError));
      emit(currentState);
      return;
    }

    emit(currentState.copyWith(isSaving: true));
    try {
      await _service.updateShippingZones(ShippingZoneModel.egyptSeedData);
      emit(
        AdminShippingZonesSuccess(
          AdminLocaleController.globalT('shippingZones.success.restored'),
        ),
      );
      emit(AdminShippingZonesLoaded(zones: ShippingZoneModel.egyptSeedData));
    } catch (e) {
      emit(AdminShippingZonesError(
        AdminLocaleController.globalT(
          'shippingZones.error.restoreFailed',
          params: {'error': e.toString()},
        ),
      ));
      emit(currentState.copyWith(isSaving: false));
    }
  }

  Future<void> seedIfEmpty() async {
    try {
      await _service.seedInitialData();
      await loadZones();
    } catch (e) {
      emit(AdminShippingZonesError(
        AdminLocaleController.globalT(
          'shippingZones.error.seedFailed',
          params: {'error': e.toString()},
        ),
      ));
    }
  }

  String? _validateZones(List<ShippingZoneModel> zones) {
    final hasInvalidZone = zones.any(
      (zone) =>
          zone.code.trim().isEmpty ||
          zone.governorate.trim().isEmpty ||
          zone.governorateEn.trim().isEmpty ||
          zone.fee < 0 ||
          zone.hasCorruptedText,
    );
    if (hasInvalidZone) {
      return AdminLocaleController.globalT('shippingZones.validation.corrupted');
    }

    final codes = zones.map((zone) => zone.code).toList();
    if (codes.toSet().length != codes.length) {
      return AdminLocaleController.globalT('shippingZones.validation.duplicateCode');
    }

    final parentCodes = zones
        .where((zone) => zone.parentCode == null)
        .map((zone) => zone.code)
        .toSet();
    final hasMissingParent = zones.any(
      (zone) =>
          zone.parentCode != null &&
          zone.parentCode!.isNotEmpty &&
          !parentCodes.contains(zone.parentCode),
    );
    if (hasMissingParent) {
      return AdminLocaleController.globalT('shippingZones.validation.missingParent');
    }

    final normalizedAliases = <String>{};
    for (final zone in zones) {
      for (final alias in [...zone.aliasesAr, ...zone.aliasesEn]) {
        final normalized = alias.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        if (!normalizedAliases.add(normalized)) {
          return AdminLocaleController.globalT('shippingZones.validation.duplicateAlias');
        }
      }
    }

    return null;
  }
}
