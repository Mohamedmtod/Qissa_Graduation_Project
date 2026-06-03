import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import 'package:perfume_app/core/models/shipping_zone_model.dart';
import 'package:perfume_app/features/orders/data/models/address_model.dart';
import 'package:perfume_app/features/orders/presentation/cubit/address/address_cubit.dart';
import 'package:perfume_app/features/orders/presentation/cubit/shipping/shipping_zones_cubit.dart';
import 'package:perfume_app/features/orders/presentation/utils/shipping_zone_display.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/core/utils/validator.dart';
import 'package:perfume_app/core/utils/input_formatters.dart';
import 'package:perfume_app/gen/assets.gen.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

typedef AddressNavigationCallback = void Function(BuildContext context);

class AddressPageInfoEntry extends StatefulWidget {
  /// Pre-fill fields when editing an existing address.
  final String? initialId;
  final bool initialIsDefault;
  final String? initialFullName;
  final String? initialPhone;

  /// Legacy city text (used for backward-compat when shippingZoneCode is absent).
  final String? initialCity;
  final String? initialGovernorateCode;
  final String? initialGovernorate;
  final String? initialArea;
  final String? initialStreet;
  final String? initialBuilding;
  final String? initialFloor;
  final String? initialNotes;
  final double? initialMapLatitude;
  final double? initialMapLongitude;
  final String? initialMapRawAddress;

  /// Pre-select a shipping zone (from map picker or stored address).
  final String? initialShippingZoneCode;
  final AddressNavigationCallback? navigateTo;

  const AddressPageInfoEntry({
    super.key,
    this.initialId,
    this.initialIsDefault = false,
    this.initialFullName,
    this.initialPhone,
    this.initialCity,
    this.initialGovernorateCode,
    this.initialGovernorate,
    this.initialArea,
    this.initialStreet,
    this.initialBuilding,
    this.initialFloor,
    this.initialNotes,
    this.initialMapLatitude,
    this.initialMapLongitude,
    this.initialMapRawAddress,
    this.initialShippingZoneCode,
    this.navigateTo,
  });

  @override
  State<AddressPageInfoEntry> createState() => _AddressPageInfoEntryState();
}

class _AddressPageInfoEntryState extends State<AddressPageInfoEntry> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _areaController;
  late final TextEditingController _addressController;
  late final TextEditingController _buildingController;
  late final TextEditingController _floorController;
  late final TextEditingController _notesController;
  bool _isDefault = false;

  /// The currently selected shipping zone from the dropdown.
  ShippingZoneModel? _selectedGovernorate;
  ShippingZoneModel? _selectedZone;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.initialFullName ?? '',
    );
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _areaController = TextEditingController(text: widget.initialArea ?? '');
    _addressController = TextEditingController(
      text: widget.initialStreet ?? '',
    );
    _buildingController = TextEditingController(
      text: widget.initialBuilding ?? '',
    );
    _floorController = TextEditingController(text: widget.initialFloor ?? '');
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
    _isDefault = widget.initialIsDefault;

    // Pre-select zone from stored code OR legacy city name.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final zonesState = context.read<ShippingZonesCubit>().state;
      if (zonesState is ShippingZonesLoaded) {
        _tryPreSelectZone(zonesState.zones);
      }
    });
  }

  void _tryPreSelectZone(List<ShippingZoneModel> zones) {
    // Prefer explicit code.
    final code = widget.initialShippingZoneCode;
    if (code != null && code.isNotEmpty) {
      try {
        final zone = zones.firstWhere((z) => z.code == code);
        final governorate = zone.isGovernorate
            ? zone
            : _findGovernorateForZone(zones, zone.parentCode);
        setState(() {
          _selectedGovernorate = governorate;
          _selectedZone = zone;
        });
        return;
      } catch (_) {}
    }

    final governorateCode = widget.initialGovernorateCode;
    if (governorateCode != null && governorateCode.isNotEmpty) {
      try {
        final governorate = zones.firstWhere((z) => z.code == governorateCode);
        setState(() => _selectedGovernorate = governorate);
      } catch (_) {}
    }

    // Fallback: match legacy/map strings when the picker could not return
    // a reliable shippingZoneCode.
    final cityCandidates = <String>[
      widget.initialCity ?? '',
      widget.initialArea ?? '',
      widget.initialStreet ?? '',
      widget.initialMapRawAddress ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();
    if (cityCandidates.isNotEmpty) {
      final scopedZones = _selectedGovernorate == null
          ? zones
          : zones
                .where(
                  (z) =>
                      z.code == _selectedGovernorate!.code ||
                      z.parentCode == _selectedGovernorate!.code,
                )
                .toList();
      for (final candidate in cityCandidates) {
        try {
          final zone = scopedZones.firstWhere(
            (z) => z.matchesCityName(candidate),
          );
          final governorate = zone.isGovernorate
              ? zone
              : _findGovernorateForZone(zones, zone.parentCode);
          setState(() {
            _selectedGovernorate ??= governorate;
            _selectedZone = zone.isCityZone ? zone : _selectedZone;
          });
          return;
        } catch (_) {}
      }
    }
  }

  ShippingZoneModel? _findGovernorateForZone(
    List<ShippingZoneModel> zones,
    String? parentCode,
  ) {
    if (parentCode == null || parentCode.isEmpty) return null;
    try {
      return zones.firstWhere((z) => z.code == parentCode && z.isGovernorate);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Lottie header ──
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: Lottie.asset(
                      Assets.animations.locationAnimation,
                      repeat: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CustomTextStyle(
                    text: AppLocalizations.of(context).msgWhereDeliver,
                    fontsize: 15,
                    bold: false,
                    textColor: darkGray,
                  ),
                ],
              ),
            ),

            // ── Form ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ── Personal info section ──
                      _SectionCard(
                        title: AppLocalizations.of(context).labelPersonalInfo,
                        children: [
                          _buildField(
                            controller: _fullNameController,
                            label: AppLocalizations.of(context).labelFullName,
                            hint: AppLocalizations.of(context).hintName,
                            icon: Icons.person_outline,
                            validator: nameValidator,
                            inputFormatters: [CustomInputFormatters.name],
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _phoneController,
                            label: AppLocalizations.of(
                              context,
                            ).labelPhoneNumber,
                            hint: AppLocalizations.of(context).hintPhone,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: phoneValidator,
                            inputFormatters: [CustomInputFormatters.digitsOnly],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Address details section ──
                      _SectionCard(
                        title: AppLocalizations.of(context).labelAddressDetails,
                        children: [
                          // ── Governorate Dropdown (dynamic from Firestore) ──
                          BlocBuilder<ShippingZonesCubit, ShippingZonesState>(
                            builder: (context, zonesState) {
                              final l10n = AppLocalizations.of(context);
                              if (zonesState is ShippingZonesLoading ||
                                  zonesState is ShippingZonesInitial) {
                                return Container(
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final enabledZones =
                                  zonesState is ShippingZonesLoaded
                                  ? zonesState.enabledZones
                                  : <ShippingZoneModel>[];
                              final locale = Localizations.localeOf(context);
                              final governorates = enabledZones
                                  .where((zone) => zone.isGovernorate)
                                  .toList();

                              if (_selectedGovernorate == null &&
                                  _selectedZone == null &&
                                  zonesState is ShippingZonesLoaded) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted ||
                                      _selectedGovernorate != null ||
                                      _selectedZone != null) {
                                    return;
                                  }
                                  _tryPreSelectZone(zonesState.zones);
                                });
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<ShippingZoneModel>(
                                    key: ValueKey(
                                      'gov-${_selectedGovernorate?.code}',
                                    ),
                                    initialValue:
                                        _selectedGovernorate != null &&
                                            governorates.any(
                                              (z) =>
                                                  z.code ==
                                                  _selectedGovernorate!.code,
                                            )
                                        ? governorates.firstWhere(
                                            (z) =>
                                                z.code ==
                                                _selectedGovernorate!.code,
                                          )
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: AppLocalizations.of(
                                        context,
                                      ).addressGovernorate,
                                      prefixIcon: Icon(
                                        Icons.map_outlined,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 22,
                                      ),
                                      labelStyle: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: darkGray,
                                      ),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: red,
                                          width: 1,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: red,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    isExpanded: true,
                                    items: governorates
                                        .map(
                                          (zone) => DropdownMenuItem(
                                            value: zone,
                                            child: Text(
                                              shippingZoneDisplayName(
                                                zone,
                                                locale,
                                              ),
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 14,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (zone) {
                                      final cityOptions = _cityOptionsFor(
                                        enabledZones,
                                        zone,
                                      );
                                      setState(() {
                                        _selectedGovernorate = zone;
                                        _selectedZone = cityOptions.length == 1
                                            ? cityOptions.first
                                            : null;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return AppLocalizations.of(
                                          context,
                                        ).addressErrGovernorateRequired;
                                      }
                                      return null;
                                    },
                                    hint: Text(
                                      AppLocalizations.of(
                                        context,
                                      ).addressSelectGovernorate,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  // ── Fee chip ──
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<ShippingZoneModel>(
                                    key: ValueKey(
                                      'city-${_selectedGovernorate?.code}-${_selectedZone?.code}',
                                    ),
                                    initialValue:
                                        _selectedZone != null &&
                                            _cityOptionsFor(
                                              enabledZones,
                                              _selectedGovernorate,
                                            ).any(
                                              (z) =>
                                                  z.code == _selectedZone!.code,
                                            )
                                        ? _cityOptionsFor(
                                            enabledZones,
                                            _selectedGovernorate,
                                          ).firstWhere(
                                            (z) =>
                                                z.code == _selectedZone!.code,
                                          )
                                        : null,
                                    decoration: _dropdownDecoration(
                                      l10n.labelCity,
                                      Icons.location_city_outlined,
                                    ),
                                    isExpanded: true,
                                    items:
                                        _cityOptionsFor(
                                              enabledZones,
                                              _selectedGovernorate,
                                            )
                                            .map(
                                              (zone) => DropdownMenuItem(
                                                value: zone,
                                                child: Text(
                                                  shippingZoneDisplayName(
                                                    zone,
                                                    locale,
                                                  ),
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 14,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: _selectedGovernorate == null
                                        ? null
                                        : (zone) {
                                            setState(() {
                                              _selectedZone = zone;
                                            });
                                          },
                                    validator: (value) {
                                      if (value == null) {
                                        return l10n.labelCity;
                                      }
                                      return null;
                                    },
                                    hint: Text(
                                      l10n.hintCity,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  if (_selectedZone != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.local_shipping_outlined,
                                            size: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${l10n.labelShippingFee}: ${_selectedZone!.fee.toStringAsFixed(0)} ${l10n.labelPrice('')}',
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12,
                                              color: darkGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _areaController,
                            label: AppLocalizations.of(
                              context,
                            ).labelAreaDistrict,
                            hint: AppLocalizations.of(context).hintArea,
                            icon: Icons.map_outlined,
                            validator: requiredFieldValidator,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _addressController,
                            label: AppLocalizations.of(
                              context,
                            ).labelStreetDetailed,
                            hint: AppLocalizations.of(
                              context,
                            ).hintSearchMapOrManual,
                            icon: Icons.room_outlined,
                            validator: requiredFieldValidator,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  controller: _buildingController,
                                  label: AppLocalizations.of(
                                    context,
                                  ).labelBuilding,
                                  hint: AppLocalizations.of(
                                    context,
                                  ).hintBuilding,
                                  icon: Icons.apartment_outlined,
                                  validator: requiredFieldValidator,
                                  inputFormatters: [
                                    CustomInputFormatters.address,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildField(
                                  controller: _floorController,
                                  label: AppLocalizations.of(
                                    context,
                                  ).labelFloorApt,
                                  hint: AppLocalizations.of(context).hintFloor,
                                  icon: Icons.stairs_outlined,
                                  validator: requiredFieldValidator,
                                  inputFormatters: [
                                    CustomInputFormatters.address,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Extra notes section ──
                      _SectionCard(
                        title: AppLocalizations.of(
                          context,
                        ).labelAdditionalNotes,
                        children: [
                          _buildField(
                            controller: _notesController,
                            label: AppLocalizations.of(
                              context,
                            ).labelDeliveryNotesOptional,
                            hint: AppLocalizations.of(
                              context,
                            ).hintDeliveryNotesEx,
                            icon: Icons.notes_outlined,
                            maxLines: 3,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Default switch ──
                      _SectionCard(
                        title: AppLocalizations.of(context).labelSettingsTitle,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: CustomTextStyle(
                              text: AppLocalizations.of(
                                context,
                              ).labelSetAsDefaultAddress,
                              fontsize: 14,
                              bold: false,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                            ),
                            value: _isDefault,
                            activeTrackColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                            activeThumbColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            onChanged: (val) {
                              setState(() => _isDefault = val);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // ── Save button ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                height: 55,
                child: BlocConsumer<AddressCubit, AddressState>(
                  listener: (context, state) {
                    final l10n = AppLocalizations.of(context);
                    if (state.status == AddressStatus.success) {
                      AppSnackBar.showSuccess(
                        context,
                        l10n.msgAddressSavedSuccessfully,
                      );
                      context.read<AddressCubit>().clearStatus();
                      // 1. Close the bottom sheet safely
                      if (context.canPop()) context.pop();

                      // 2. Safely call custom navigation if needed
                      if (widget.navigateTo != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          widget.navigateTo!(context);
                        });
                      }
                    } else if (state.status == AddressStatus.error) {
                      AppSnackBar.showError(
                        context,
                        resolveUserFacingMessage(
                          context,
                          state.message,
                          fallback: l10n.msgAddressSaveFailedGeneric,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    return ElevatedButton(
                      onPressed: state.status == AddressStatus.loading
                          ? null
                          : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: state.status == AddressStatus.loading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                strokeWidth: 2,
                              ),
                            )
                          : CustomTextStyle(
                              text: AppLocalizations.of(context).btnSaveAddress,
                              fontsize: 16,
                              bold: true,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  Helpers
  // ──────────────────────────────────────────────

  // _openMapForAddress removed because it is no longer used.

  List<ShippingZoneModel> _cityOptionsFor(
    List<ShippingZoneModel> zones,
    ShippingZoneModel? governorate,
  ) {
    if (governorate == null) return const [];
    final children = zones
        .where((zone) => zone.parentCode == governorate.code && zone.enabled)
        .toList();
    if (children.isNotEmpty) return children;
    return governorate.enabled ? [governorate] : const [];
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: 22,
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        color: darkGray,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: red, width: 1.5),
      ),
    );
  }

  AddressModel _buildAddressModel() {
    final governorate =
        _selectedGovernorate ??
        (_selectedZone?.isGovernorate == true ? _selectedZone : null);
    return AddressModel(
      id: widget.initialId ?? '',
      type: AddressType.address,
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      city: _selectedZone?.governorate ?? widget.initialCity ?? '',
      area: _areaController.text.trim(),
      street: _addressController.text.trim(),
      building: _buildingController.text.trim(),
      floor: _floorController.text.trim(),
      notes: _notesController.text.trim(),
      defaultAddress: _isDefault,
      // Shipping zone fields
      shippingZoneCode: _selectedZone?.code,
      governorateCode: governorate?.code ?? widget.initialGovernorateCode,
      governorate: governorate?.governorate ?? widget.initialGovernorate,
      cityCode: _selectedZone?.code,
      mapLatitude: widget.initialMapLatitude,
      mapLongitude: widget.initialMapLongitude,
      mapRawAddress: widget.initialMapRawAddress,
      shippingFeeSnapshot: _selectedZone?.fee,
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final addressModel = _buildAddressModel();

    if (widget.initialId != null) {
      context.read<AddressCubit>().updateAddress(addressModel);
    } else {
      context.read<AddressCubit>().addAddress(addressModel);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: darkGray,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: Colors.grey.shade400,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  Section Card — groups fields with a title
// ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextStyle(
            text: title,
            fontsize: 16,
            bold: true,
            textColor: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class SavedAddress extends StatelessWidget {
  final AddressNavigationCallback? navigateTo;

  const SavedAddress({super.key, this.navigateTo});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 0.8, // قللها/زوّدها لحد ما الفراغ يختفي
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Lottie.asset(
                    Assets.animations.locationAnimation,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            CustomTextStyle(
              text: AppLocalizations.of(context).msgWhereDeliver,
              fontsize: 15,
              bold: false,
              textColor: darkGray,
            ),
          ],
        ),
        SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: () async {
              final Map<String, dynamic>? selectedData = await context
                  .push<Map<String, dynamic>>('/location-picker');
              if (selectedData != null && context.mounted) {
                await openAddressSheet(
                  context,
                  initialCity: selectedData['city'],
                  initialGovernorateCode: selectedData['governorateCode'],
                  initialGovernorate: selectedData['governorate'],
                  initialArea: selectedData['area'],
                  initialStreet: selectedData['street'],
                  initialBuilding: selectedData['building'],
                  initialShippingZoneCode: selectedData['shippingZoneCode'],
                  initialMapLatitude: selectedData['mapLatitude'] as double?,
                  initialMapLongitude: selectedData['mapLongitude'] as double?,
                  initialMapRawAddress: selectedData['mapRawAddress'],
                  navigateTo: navigateTo,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(20),

              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              shadowColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.primary,
                  size: 25,
                ),
                const SizedBox(width: 12),
                CustomTextStyle(
                  text: AppLocalizations.of(context).btnAddNewAddress,
                  fontsize: 14,
                  bold: false,
                  textColor: Theme.of(context).colorScheme.onSurface,
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),

        // add saved addresses here in the future
        BlocBuilder<AddressCubit, AddressState>(
          builder: (context, state) {
            if (state.status == AddressStatus.loading &&
                state.addresses.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final addresses = state.addresses;
            final zonesState = context.watch<ShippingZonesCubit>().state;
            final zones = zonesState is ShippingZonesLoaded
                ? zonesState.zones
                : const <ShippingZoneModel>[];
            final locale = Localizations.localeOf(context);
            if (addresses.isEmpty && state.status == AddressStatus.loaded) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(AppLocalizations.of(context).msgNoSavedAddresses),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final address = addresses[index];
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.home_outlined,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: CustomTextStyle(
                            text: address.fullName,
                            fontsize: 16,
                            bold: true,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            maxLines: 1,
                          ),
                        ),
                        if (address.defaultAddress)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context).labelDefault,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),

                        CustomTextStyle(
                          bold: false,
                          fontsize: 13,
                          textColor: darkGray,
                          text: AppLocalizations.of(context)
                              .labelFullAddressStrings(
                                address.street ?? '',
                                localizedShippingZoneLabel(
                                  locale: locale,
                                  zones: zones,
                                  shippingZoneCode:
                                      address.cityCode ??
                                      address.shippingZoneCode,
                                  fallbackLabel: [address.city, address.area]
                                      .whereType<String>()
                                      .where((part) => part.trim().isNotEmpty)
                                      .join(', '),
                                ),
                                localizedShippingZoneLabel(
                                  locale: locale,
                                  zones: zones,
                                  shippingZoneCode: address.shippingZoneCode,
                                  governorateCode: address.governorateCode,
                                  fallbackLabel: address.governorate,
                                ),
                              ),
                          maxLines: 1,
                          textOverflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),
                        CustomTextStyle(
                          bold: false,
                          fontsize: 13,
                          textColor: darkGray,
                          text: address.phone,
                          maxLines: 1,
                          textOverflow: TextOverflow.ellipsis,
                        ),
                        if (!address.defaultAddress) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              context.read<AddressCubit>().setDefaultAddress(
                                address.id,
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context).btnSetAsDefault,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: AppLocalizations.of(context).btnEdit,
                          onPressed: () {
                            openAddressSheet(
                              context,
                              initialId: address.id,
                              initialIsDefault: address.defaultAddress,
                              initialFullName: address.fullName,
                              initialPhone: address.phone,
                              initialCity: address.city,
                              initialGovernorateCode: address.governorateCode,
                              initialGovernorate: address.governorate,
                              initialArea: address.area,
                              initialStreet: address.street,
                              initialBuilding: address.building,
                              initialFloor: address.floor,
                              initialNotes: address.notes,
                              initialShippingZoneCode: address.shippingZoneCode,
                              initialMapLatitude: address.mapLatitude,
                              initialMapLongitude: address.mapLongitude,
                              initialMapRawAddress: address.mapRawAddress,
                              navigateTo: navigateTo,
                            );
                          },
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _showDeleteConfirmation(context, address.id);
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      // User selected an address from the list
                      Navigator.pop(context, address.toMap());
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, String addressId) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: CustomTextStyle(
          text: l10n.titleDeleteAddress,
          fontsize: 18,
          bold: true,
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
        content: CustomTextStyle(
          text: l10n.msgConfirmDeleteAddress,
          fontsize: 14,
          bold: false,
          textColor: darkGray,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.btnCancel,
              style: const TextStyle(color: darkGray),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<AddressCubit>().deleteAddress(addressId);
              Navigator.pop(ctx);
            },
            child: Text(
              l10n.btnDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>?> openAddressSheetPage(
  BuildContext context, {
  AddressNavigationCallback? navigateTo,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true, // عشان ياخد مساحة كبيرة
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent, // نخلي الشكل Rounded حلو
    builder: (ctx) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(ctx),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.75, // يبدأ بـ 75% من الشاشة
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return AddressPageContent(navigateTo: navigateTo);
            },
          ),
        ],
      );
    },
  );
}

class AddressPageContent extends StatelessWidget {
  final AddressNavigationCallback? navigateTo;
  final bool showPickupTab;

  const AddressPageContent({
    super.key,
    this.navigateTo,
    this.showPickupTab = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showPickupTab) {
      return Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLowest),
        child: Column(
          children: [
            const SizedBox(height: 18),
            Expanded(child: SavedAddress(navigateTo: navigateTo)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 18),

            // Tabs زي Address / Locker
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
                labelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
                tabs: [
                  Tab(text: AppLocalizations.of(context).labelTabAddress),
                  Tab(text: AppLocalizations.of(context).labelTabPickup),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                children: [
                  SavedAddress(navigateTo: navigateTo),
                  Center(
                    child: Text(
                      AppLocalizations.of(context).msgPickupContentPlaceholder,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddressPage extends StatelessWidget {
  final AddressNavigationCallback? navigateTo;
  final bool showPickupTab;

  const AddressPage({super.key, this.navigateTo, this.showPickupTab = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: CustomTextStyle(
          bold: true,
          fontsize: 20,
          textColor: Theme.of(context).colorScheme.onSurface,
          text: AppLocalizations.of(context).labelAddress,
        ),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/MainLayout');
            }
          },
        ),
      ),
      body: AddressPageContent(
        navigateTo: navigateTo,
        showPickupTab: showPickupTab,
      ),
    );
  }
}

Future<void> openAddressSheet(
  BuildContext context, {
  String? initialId,
  bool initialIsDefault = false,
  String? initialFullName,
  String? initialPhone,
  String? initialCity,
  String? initialGovernorateCode,
  String? initialGovernorate,
  String? initialArea,
  String? initialStreet,
  String? initialBuilding,
  String? initialFloor,
  String? initialNotes,
  String? initialShippingZoneCode,
  double? initialMapLatitude,
  double? initialMapLongitude,
  String? initialMapRawAddress,
  AddressNavigationCallback? navigateTo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // عشان ياخد مساحة كبيرة
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent, // نخلي الشكل Rounded حلو
    builder: (ctx) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(ctx),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.75, // يبدأ بـ 75% من الشاشة
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 18),

                    Expanded(
                      child: AddressPageInfoEntry(
                        initialId: initialId,
                        initialIsDefault: initialIsDefault,
                        initialFullName: initialFullName,
                        initialPhone: initialPhone,
                        initialCity: initialCity,
                        initialGovernorateCode: initialGovernorateCode,
                        initialGovernorate: initialGovernorate,
                        initialArea: initialArea,
                        initialStreet: initialStreet,
                        initialBuilding: initialBuilding,
                        initialFloor: initialFloor,
                        initialNotes: initialNotes,
                        initialShippingZoneCode: initialShippingZoneCode,
                        initialMapLatitude: initialMapLatitude,
                        initialMapLongitude: initialMapLongitude,
                        initialMapRawAddress: initialMapRawAddress,
                        navigateTo: navigateTo,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    },
  );
}
