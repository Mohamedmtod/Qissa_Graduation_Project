import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Arabic ARB files expose the same localization keys', () {
    final en = _loadArb('lib/l10n/app_en.arb');
    final ar = _loadArb('lib/l10n/app_ar.arb');

    final enKeys = _messageKeys(en);
    final arKeys = _messageKeys(ar);

    expect(arKeys.difference(enKeys), isEmpty, reason: 'Arabic-only keys found.');
    expect(enKeys.difference(arKeys), isEmpty, reason: 'English-only keys found.');
  });

  test('defense-critical screens have localized keys in both languages', () {
    final enKeys = _messageKeys(_loadArb('lib/l10n/app_en.arb'));
    final arKeys = _messageKeys(_loadArb('lib/l10n/app_ar.arb'));
    final requiredKeys = <String>{
      'btnLogin',
      'btnRegister',
      'btnForgotPassword',
      'labelCategories',
      'btnAddToCart',
      'msgEmptyCart',
      'labelMyOrders',
      'labelHello',
      'labelAIChatTitle',
      'msgProductLoadFailed',
      'labelResetPassword',
    };

    for (final key in requiredKeys) {
      expect(enKeys, contains(key), reason: 'Missing English key: $key');
      expect(arKeys, contains(key), reason: 'Missing Arabic key: $key');
    }
  });
}

Map<String, dynamic> _loadArb(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path does not exist.');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Set<String> _messageKeys(Map<String, dynamic> arb) {
  return arb.keys
      .where((key) => !key.startsWith('@') && key != '@@locale')
      .toSet();
}
