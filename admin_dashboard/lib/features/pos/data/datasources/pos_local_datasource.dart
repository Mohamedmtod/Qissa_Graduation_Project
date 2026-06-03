import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PosLocalDatasource {
  final SharedPreferences _prefs;

  PosLocalDatasource(this._prefs);

  static const _keyCartItems = 'pos_cart_items';
  static const _keyIdempotencyKey = 'pos_idempotency_key';
  static const _keyIsLocked = 'pos_cart_locked';
  static const _keyPendingPayload = 'pos_pending_payload';

  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    await _prefs.setString(_keyCartItems, jsonEncode(items));
  }

  List<Map<String, dynamic>> getCartItems() {
    final raw = _prefs.getString(_keyCartItems);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveIdempotencyKey(String key) async {
    await _prefs.setString(_keyIdempotencyKey, key);
  }

  String? getIdempotencyKey() {
    return _prefs.getString(_keyIdempotencyKey);
  }

  Future<void> setCartLocked(bool locked) async {
    await _prefs.setBool(_keyIsLocked, locked);
  }

  bool isCartLocked() {
    return _prefs.getBool(_keyIsLocked) ?? false;
  }

  Future<void> savePendingPayload(Map<String, dynamic> payload) async {
    await _prefs.setString(_keyPendingPayload, jsonEncode(payload));
  }

  Map<String, dynamic>? getPendingPayload() {
    final raw = _prefs.getString(_keyPendingPayload);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingSale() async {
    await _prefs.remove(_keyIdempotencyKey);
    await _prefs.remove(_keyPendingPayload);
    await _prefs.remove(_keyIsLocked);
  }
}
