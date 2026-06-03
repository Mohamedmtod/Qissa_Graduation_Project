import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLocaleController extends ChangeNotifier {
  AdminLocaleController({Locale? initialLocale, AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle,
      _locale = _normalizeLocale(initialLocale ?? const Locale('ar', 'EG')) {
    Intl.defaultLocale = _locale.toLanguageTag();
    _activeLocale = _locale;
    _loadStringsForLocale(_locale);
  }

  static const List<Locale> supportedLocales = [
    Locale('ar', 'EG'),
    Locale('en', 'US'),
  ];

  final AssetBundle _bundle;
  Locale _locale;
  Map<String, String> _strings = const {};
  Map<String, String> _fallbackStrings = const {};
  bool _isReady = false;

  static Map<String, String> _activeStrings = const {};
  static Map<String, String> _activeFallbackStrings = const {};
  static Locale _activeLocale = const Locale('ar', 'EG');

  Locale get locale => _locale;
  bool get isReady => _isReady;

  bool get isArabic => _locale.languageCode.toLowerCase() == 'ar';

  static bool get isGlobalArabic =>
      _activeLocale.languageCode.toLowerCase() == 'ar';

  String t(String key, {String? fallback, Map<String, String>? params}) {
    return _resolve(
      _strings,
      key,
      fallback: fallback,
      params: params,
      fallbackSource: _fallbackStrings,
    );
  }

  String resolve(String keyOrRaw, {Map<String, String>? params}) {
    if (_strings.containsKey(keyOrRaw)) {
      return t(keyOrRaw, params: params);
    }
    return _resolveParams(keyOrRaw, params);
  }

  static String globalT(
    String key, {
    String? fallback,
    Map<String, String>? params,
  }) {
    return _resolve(
      _activeStrings,
      key,
      fallback: fallback,
      params: params,
      fallbackSource: _activeFallbackStrings,
    );
  }

  static String globalResolve(String keyOrRaw, {Map<String, String>? params}) {
    if (_activeStrings.containsKey(keyOrRaw)) {
      return globalT(keyOrRaw, params: params);
    }
    return _resolveParams(keyOrRaw, params);
  }

  Future<void> updateLocale(Locale locale, {bool forceReload = false}) async {
    final normalized = _normalizeLocale(locale);
    if (_locale == normalized && !forceReload) {
      return;
    }
    _locale = normalized;
    Intl.defaultLocale = normalized.toLanguageTag();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_language_code', normalized.languageCode);
    } catch (e, stackTrace) {
      debugPrint('[admin][locale][save_failed] error=$e, stack=$stackTrace');
    }
    await _loadStringsForLocale(normalized);
  }

  Future<void> reload() async {
    await _loadStringsForLocale(_locale);
  }

  Future<void> _loadStringsForLocale(Locale locale) async {
    final languageCode = locale.languageCode.toLowerCase();
    final fileName = languageCode == 'ar' ? 'ar' : 'en';

    try {
      final fallback = await _readDictionary('en');
      final localized = fileName == 'en'
          ? fallback
          : await _readDictionary(fileName);
      final filteredLocalized = localized.map((key, value) {
        return MapEntry(key, value.trim());
      })..removeWhere((_, value) => value.isEmpty || _looksCorrupted(value));
      _fallbackStrings = fallback;
      _strings = {...fallback, ...filteredLocalized};
    } catch (_) {
      _strings = const {};
      _fallbackStrings = const {};
    }
    _activeLocale = locale;
    _activeStrings = _strings;
    _activeFallbackStrings = _fallbackStrings;
    _isReady = true;
    notifyListeners();
  }

  Future<Map<String, String>> _readDictionary(String fileName) async {
    final jsonString = await _bundle.loadString(
      'assets/i18n/$fileName.json',
      cache: false,
    );
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  static Locale _normalizeLocale(Locale locale) {
    final languageCode = locale.languageCode.toLowerCase();
    if (languageCode == 'ar') {
      return const Locale('ar', 'EG');
    }
    return const Locale('en', 'US');
  }

  static String _resolve(
    Map<String, String> source,
    String key, {
    String? fallback,
    Map<String, String>? params,
    Map<String, String>? fallbackSource,
  }) {
    var value = source[key] ?? fallbackSource?[key] ?? fallback ?? key;
    return _resolveParams(value, params);
  }

  static String _resolveParams(String value, Map<String, String>? params) {
    if (params == null || params.isEmpty) {
      return value;
    }
    var resolved = value;
    params.forEach((paramKey, paramValue) {
      resolved = resolved.replaceAll('{$paramKey}', paramValue);
    });
    return resolved;
  }

  static bool _looksCorrupted(String value) {
    // Arabic mojibake frequently lands as Cyrillic/Windows-1252 artifacts.
    // Treat those values like missing translations so English fallback remains
    // visible instead of rendering broken, oversized UI text.
    return RegExp(r'[РШЩ�]').hasMatch(value);
  }
}
