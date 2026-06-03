import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/orders/data/services/delivery_location_matcher.dart';
import 'package:perfume_app/features/orders/presentation/cubit/shipping/shipping_zones_cubit.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _pickedLocation;
  bool _isLoading = true;
  bool _isFetchingAddress = false;

  static const _logTag = 'LocationPickerPage';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _getUserLocation();
    });
  }

  void _log(String message) {
    debugPrint('[$_logTag] $message');
  }

  // 1. Get user location via GPS
  Future<void> _getUserLocation() async {
    final l10n = AppLocalizations.of(context);
    _log('Starting location lookup');

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _log('Location services enabled: $serviceEnabled');
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showErrorSnackBar(l10n.msgLocationServicesDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      _log('Current permission: $permission');
      if (permission == LocationPermission.denied) {
        _log('Requesting location permission');
        permission = await Geolocator.requestPermission();
        _log('Permission after request: $permission');
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showErrorSnackBar(l10n.msgLocationPermissionDenied);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _log('Permission denied forever');
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showErrorSnackBar(l10n.msgLocationPermissionPermanentlyDenied);
        return;
      }

      _log('Fetching current position');
      Position? position;

      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
        _log(
          'Current position resolved: ${position.latitude}, ${position.longitude}',
        );
      } on TimeoutException catch (_) {
        _log('Current position request timed out, trying last known position');
      }

      position ??= await Geolocator.getLastKnownPosition();
      if (position != null) {
        _log('Using position: ${position.latitude}, ${position.longitude}');
      } else {
        _log('No current or last known position available');
        throw Exception('No location data available');
      }

      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position!.latitude, position.longitude);
        _pickedLocation = _currentLocation;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _log('Location lookup failed: $e');
      debugPrintStack(label: '[$_logTag] Stack trace', stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar(l10n.msgEnableGpsAndPermissions);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    AppSnackBar.showError(context, message);
  }

  void _moveToMyLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16.0);
      setState(() {
        _pickedLocation = _currentLocation;
      });
    }
  }

  // 2. Convert picked point to address using Dio and OpenStreetMap
  Future<void> _getAddressAndReturn() async {
    if (_pickedLocation == null) return;

    setState(() => _isFetchingAddress = true);
    final l10n = AppLocalizations.of(context);
    _log(
      'Reverse geocoding location: ${_pickedLocation!.latitude}, ${_pickedLocation!.longitude}',
    );

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': _pickedLocation!.latitude,
          'lon': _pickedLocation!.longitude,
          'accept-language': 'en,ar',
        },
        options: Options(
          headers: {
            'User-Agent': 'PerfumeApp/1.0', // ضروري للخدمة المجانية
          },
        ),
      );

      _log('Reverse geocoding response status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        if (!mounted) return;
        final rawAddress = response.data['address'];
        final addressData = rawAddress is Map
            ? Map<String, dynamic>.from(rawAddress)
            : <String, dynamic>{};
        final displayName = (response.data['display_name'] ?? '').toString();
        _log('Resolved address: $displayName');
        final parsedMapAddress = ParsedMapAddress(
          displayName: displayName,
          address: addressData,
        );
        final zonesState = context.read<ShippingZonesCubit>().state;
        final zones = zonesState is ShippingZonesLoaded
            ? zonesState.zones
            : context.read<ShippingZonesCubit>().enabledZones;
        final match = DeliveryLocationMatcher(zones).match(parsedMapAddress);
        final governorate = match.governorate;
        final cityZone = match.cityZone;

        final Map<String, dynamic> parsedAddress = {
          'fullAddress': displayName,
          'mapRawAddress': displayName,
          'mapLatitude': _pickedLocation!.latitude,
          'mapLongitude': _pickedLocation!.longitude,
          if (governorate != null) 'governorateCode': governorate.code,
          if (governorate != null) 'governorate': governorate.governorate,
          if (match.hasReliableShippingZone && cityZone != null)
            'shippingZoneCode': cityZone.code,
          if (match.hasReliableShippingZone && cityZone != null)
            'cityCode': cityZone.code,
          if (match.hasReliableShippingZone && cityZone != null)
            'shippingFeeSnapshot': cityZone.fee,
          'city': match.hasReliableShippingZone && cityZone != null
              ? cityZone.governorate
              : parsedMapAddress.city,
          'street': parsedMapAddress.street,
          'building': parsedMapAddress.building,
          'area': parsedMapAddress.area,
        };
        await Navigator.of(context).maybePop(parsedAddress);
      } else {
        throw Exception(l10n.msgAddressLookupFailed);
      }
    } catch (e, stackTrace) {
      _log('Reverse geocoding failed: $e');
      debugPrintStack(
        label: '[$_logTag] Reverse geocoding stack',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showErrorSnackBar(l10n.msgAddressLookupFailed);
      await Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.labelPickDeliveryLocation),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentLocation == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    l10n.msgEnableGpsAndPermissions,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _getUserLocation();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.btnTryAgain),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 16.0,
                    // Move pin when user taps map
                    onTap: (tapPosition, point) {
                      setState(() {
                        _pickedLocation = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.perfume_app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_pickedLocation != null)
                          Marker(
                            point: _pickedLocation!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'myLocationBtn',
                    onPressed: _moveToMyLocation,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              if (_isFetchingAddress || _pickedLocation == null) {
                return;
              } else {
                _getAddressAndReturn();
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isFetchingAddress
                ?  SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onSurface,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    l10n.btnConfirmLocation,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
