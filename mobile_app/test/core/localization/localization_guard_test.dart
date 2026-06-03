import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization Guard Tests', () {
    test('app_en.arb and app_ar.arb must have exactly the same keys', () async {
      final enFile = File('lib/l10n/app_en.arb');
      final arFile = File('lib/l10n/app_ar.arb');

      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb missing');
      expect(arFile.existsSync(), isTrue, reason: 'app_ar.arb missing');

      final enJson = json.decode(enFile.readAsStringSync()) as Map<String, dynamic>;
      final arJson = json.decode(arFile.readAsStringSync()) as Map<String, dynamic>;

      final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
      final arKeys = arJson.keys.where((k) => !k.startsWith('@')).toSet();

      final missingInAr = enKeys.difference(arKeys);
      final missingInEn = arKeys.difference(enKeys);

      expect(missingInAr, isEmpty, reason: 'Keys present in EN but missing in AR: $missingInAr');
      expect(missingInEn, isEmpty, reason: 'Keys present in AR but missing in EN: $missingInEn');
    });
  });
}
