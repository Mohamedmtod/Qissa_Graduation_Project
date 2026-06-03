import 'package:shared_preferences/shared_preferences.dart';

abstract class RecentlyViewedLocalDataSource {
  Future<List<String>> getRecentlyViewedIds();
  Future<void> saveRecentlyViewedIds(List<String> ids);
  Future<void> clear();
}

class SharedPreferencesRecentlyViewedLocalDataSource
    implements RecentlyViewedLocalDataSource {
  static const String _recentlyViewedKey = 'recently_viewed_product_ids';

  @override
  Future<List<String>> getRecentlyViewedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_recentlyViewedKey);
      return stored == null ? <String>[] : List<String>.from(stored);
    } catch (_) {
      return <String>[];
    }
  }

  @override
  Future<void> saveRecentlyViewedIds(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentlyViewedKey, ids);
    } catch (_) {
      // Ignore local persistence failures to keep app flow stable.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentlyViewedKey);
    } catch (_) {
      // Ignore local persistence failures to keep app flow stable.
    }
  }
}