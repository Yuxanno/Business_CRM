import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Fast two-tier snapshot cache (in-memory Map + SharedPreferences) for instant
/// UI startup and zero-lag tab switching regardless of network speed.
class LocalCache {
  LocalCache._();

  static const _prefix = 'cache_snap_';
  static final Map<String, Map<String, dynamic>> _mem = {};

  static Future<Map<String, dynamic>?> readMap(String key) async {
    final hit = _mem[key];
    if (hit != null) return hit;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      Map<String, dynamic>? map;
      if (decoded is Map<String, dynamic>) {
        map = decoded;
      } else if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
      if (map != null) {
        _mem[key] = map;
      }
      return map;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeMap(String key, Map<String, dynamic> data) async {
    _mem[key] = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      unawaited(prefs.setString('$_prefix$key', jsonEncode(data)));
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    _mem.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
