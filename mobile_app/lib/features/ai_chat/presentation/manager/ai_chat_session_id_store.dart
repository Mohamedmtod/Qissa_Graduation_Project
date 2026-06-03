import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class AIChatSessionIdStore {
  const AIChatSessionIdStore();

  static const String _baseKey = 'ai_chat_last_session_id';

  String _keyFor(String? userId) {
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) return _baseKey;
    return '$_baseKey::$normalizedUserId';
  }

  Future<void> save(String sessionId, {String? userId}) async {
    final normalized = sessionId.trim();
    if (normalized.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFor(userId), normalized);
    } catch (error, stackTrace) {
      log(
        'Failed to save AI chat session id.',
        name: 'AIChatSessionIdStore',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<String?> load({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedKey = _keyFor(userId);
      var value = prefs.getString(scopedKey)?.trim();
      if ((value == null || value.isEmpty) && scopedKey != _baseKey) {
        value = prefs.getString(_baseKey)?.trim();
        if (value != null && value.isNotEmpty) {
          await prefs.setString(scopedKey, value);
          await prefs.remove(_baseKey);
        }
      }
      return value == null || value.isEmpty ? null : value;
    } catch (error, stackTrace) {
      log(
        'Failed to load AI chat session id.',
        name: 'AIChatSessionIdStore',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> clear({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(userId));
    } catch (error, stackTrace) {
      log(
        'Failed to clear AI chat session id.',
        name: 'AIChatSessionIdStore',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
