import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/core/models/shipping_zone_model.dart';
import 'package:perfume_app/features/orders/data/services/delivery_location_matcher.dart';

void main() {
  const zones = [
    ShippingZoneModel(
      code: 'cairo',
      governorate: 'القاهرة',
      governorateEn: 'Cairo',
      fee: 50,
      enabled: true,
      aliasesEn: ['Cairo Governorate'],
    ),
    ShippingZoneModel(
      code: 'cairo_nasr_city',
      governorate: 'مدينة نصر',
      governorateEn: 'Nasr City',
      fee: 50,
      enabled: true,
      parentCode: 'cairo',
      aliasesEn: ['Nasr', 'Qesm Awal Nasr City'],
      aliasesAr: ['مدينة نصر'],
    ),
    ShippingZoneModel(
      code: 'cairo_new_cairo',
      governorate: 'القاهرة الجديدة',
      governorateEn: 'New Cairo',
      fee: 50,
      enabled: true,
      parentCode: 'cairo',
      aliasesAr: ['التجمع'],
    ),
  ];

  test('matches Nasr City to Cairo governorate and city zone', () {
    final result = const DeliveryLocationMatcher(zones).match(
      const ParsedMapAddress(
        displayName: 'Nasr City, Cairo Governorate, Egypt',
        address: {
          'state': 'Cairo Governorate',
          'suburb': 'Nasr City',
          'road': 'Mostafa El Nahas',
          'house_number': '12',
        },
      ),
    );

    expect(result.confidence, DeliveryLocationMatchConfidence.exact);
    expect(result.governorate?.code, 'cairo');
    expect(result.cityZone?.code, 'cairo_nasr_city');
    expect(result.hasReliableShippingZone, isTrue);
  });

  test('falls back to governorate when city is unclear', () {
    final result = const DeliveryLocationMatcher(zones).match(
      const ParsedMapAddress(
        displayName: 'Cairo Governorate, Egypt',
        address: {'state': 'Cairo Governorate'},
      ),
    );

    expect(result.confidence, DeliveryLocationMatchConfidence.fallback);
    expect(result.governorate?.code, 'cairo');
    expect(result.cityZone, isNull);
    expect(result.hasReliableShippingZone, isFalse);
  });

  test('matches Arabic city aliases', () {
    final result = const DeliveryLocationMatcher(zones).match(
      const ParsedMapAddress(
        displayName: 'التجمع، القاهرة',
        address: {'state': 'القاهرة', 'suburb': 'التجمع'},
      ),
    );

    expect(result.cityZone?.code, 'cairo_new_cairo');
    expect(result.hasReliableShippingZone, isTrue);
  });

  test('returns unmatched for unknown map names', () {
    final result = const DeliveryLocationMatcher(zones).match(
      const ParsedMapAddress(
        displayName: 'Unknown Place',
        address: {'state': 'Unknown', 'suburb': 'Nowhere'},
      ),
    );

    expect(result.confidence, DeliveryLocationMatchConfidence.unmatched);
    expect(result.governorate, isNull);
    expect(result.cityZone, isNull);
  });
}
