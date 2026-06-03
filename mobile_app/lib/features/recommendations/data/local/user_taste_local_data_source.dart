import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class UserTasteLocalDataSource {
  Future<Map<String, dynamic>> getTasteProfileMap(String userId);
  Future<void> saveTasteProfileMap(String userId, Map<String, dynamic> profileMap);
  Future<void> clear(String userId);
}

class SharedPreferencesUserTasteLocalDataSource
    implements UserTasteLocalDataSource {
  static const String _tasteProfileKeyPrefix = 'behavioral_taste_profile_v1';

  String _tasteProfileKey(String userId) {
    return '$_tasteProfileKeyPrefix::$userId';
  }

  @override
  Future<Map<String, dynamic>> getTasteProfileMap(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tasteProfileKey(userId));
      if (raw == null || raw.trim().isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Future<void> saveTasteProfileMap(
    String userId,
    Map<String, dynamic> profileMap,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tasteProfileKey(userId), jsonEncode(profileMap));
    } catch (_) {
      // Keep behavioral tracking non-blocking.
    }
  }

  @override
  Future<void> clear(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tasteProfileKey(userId));
    } catch (_) {
      // Keep behavioral tracking non-blocking.
    }
  }
}
