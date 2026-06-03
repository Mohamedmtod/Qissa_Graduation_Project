import 'package:perfume_app/core/models/shipping_zone_model.dart';

enum DeliveryLocationMatchConfidence { exact, alias, fallback, unmatched }

class DeliveryLocationMatchResult {
  const DeliveryLocationMatchResult({
    required this.confidence,
    this.governorate,
    this.cityZone,
  });

  final DeliveryLocationMatchConfidence confidence;
  final ShippingZoneModel? governorate;
  final ShippingZoneModel? cityZone;

  bool get hasReliableShippingZone =>
      cityZone != null &&
      (confidence == DeliveryLocationMatchConfidence.exact ||
          confidence == DeliveryLocationMatchConfidence.alias);
}

class ParsedMapAddress {
  const ParsedMapAddress({required this.displayName, required this.address});

  final String displayName;
  final Map<String, dynamic> address;

  String get street => _firstString(['road', 'pedestrian', 'footway']);

  String get building => _firstString(['house_number', 'building']);

  String get city => _firstString([
    'suburb',
    'neighbourhood',
    'quarter',
    'city_district',
    'residential',
    'city',
    'town',
    'village',
  ]);

  String get area => _firstString([
    'suburb',
    'neighbourhood',
    'quarter',
    'city_district',
    'residential',
    'state_district',
    'county',
    'municipality',
    'district',
    'town',
  ]);

  List<String> get governorateCandidates => _strings([
    'state',
    'county',
    'state_district',
    'municipality',
    'city',
    'town',
    'village',
  ]);

  List<String> get cityCandidates => _strings([
    'suburb',
    'neighbourhood',
    'quarter',
    'city_district',
    'residential',
    'city',
    'town',
    'village',
    'state_district',
    'county',
    'municipality',
    'district',
  ]);

  String _firstString(List<String> keys) {
    for (final value in _strings(keys)) {
      return value;
    }
    return '';
  }

  List<String> _strings(List<String> keys) {
    final values = <String>[];
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) {
        values.add(value.trim());
      }
    }
    return values;
  }
}

class DeliveryLocationMatcher {
  const DeliveryLocationMatcher(this.zones);

  final List<ShippingZoneModel> zones;

  DeliveryLocationMatchResult match(ParsedMapAddress parsed) {
    final enabled = zones.where((zone) => zone.enabled).toList();
    final governorates = enabled.where((zone) => zone.isGovernorate).toList();
    final cities = enabled.where((zone) => zone.isCityZone).toList();

    final governorateMatch = _bestMatch(
      governorates,
      parsed.governorateCandidates,
    );
    final governorate = governorateMatch?.zone;

    final scopedCities = governorate == null
        ? cities
        : cities.where((zone) => zone.parentCode == governorate.code).toList();
    final cityMatch = _bestMatch(scopedCities, parsed.cityCandidates);

    if (cityMatch != null) {
      return DeliveryLocationMatchResult(
        confidence: cityMatch.confidence,
        governorate:
            governorate ??
            _findGovernorateForCity(enabled, cityMatch.zone.parentCode),
        cityZone: cityMatch.zone,
      );
    }

    if (governorateMatch != null) {
      return DeliveryLocationMatchResult(
        confidence: DeliveryLocationMatchConfidence.fallback,
        governorate: governorate,
      );
    }

    return const DeliveryLocationMatchResult(
      confidence: DeliveryLocationMatchConfidence.unmatched,
    );
  }

  ShippingZoneModel? _findGovernorateForCity(
    List<ShippingZoneModel> enabled,
    String? parentCode,
  ) {
    if (parentCode == null || parentCode.isEmpty) return null;
    for (final zone in enabled) {
      if (zone.code == parentCode && zone.isGovernorate) return zone;
    }
    return null;
  }

  _ZoneMatch? _bestMatch(
    List<ShippingZoneModel> candidates,
    List<String> inputs,
  ) {
    for (final input in inputs) {
      for (final zone in candidates) {
        if (_isExact(zone, input)) {
          return _ZoneMatch(zone, DeliveryLocationMatchConfidence.exact);
        }
      }
    }

    for (final input in inputs) {
      for (final zone in candidates) {
        if (_isAlias(zone, input)) {
          return _ZoneMatch(zone, DeliveryLocationMatchConfidence.alias);
        }
      }
    }

    return null;
  }

  bool _isExact(ShippingZoneModel zone, String input) {
    final q = ShippingZoneModel.normalise(input);
    if (q.isEmpty) return false;
    return zone.searchableNames.any(
      (name) => ShippingZoneModel.normalise(name) == q,
    );
  }

  bool _isAlias(ShippingZoneModel zone, String input) {
    final q = ShippingZoneModel.normalise(input);
    if (q.isEmpty) return false;
    return zone.searchableNames.any((name) {
      final candidate = ShippingZoneModel.normalise(name);
      return candidate.isNotEmpty &&
          (candidate.contains(q) || q.contains(candidate));
    });
  }
}

class _ZoneMatch {
  const _ZoneMatch(this.zone, this.confidence);

  final ShippingZoneModel zone;
  final DeliveryLocationMatchConfidence confidence;
}
