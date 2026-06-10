import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'guest_api_service.dart';

/// Stores pending guest orders when offline and flushes them when reconnected.
class OfflineQueue {
  static const _key = 'guest_offline_queue';

  /// Add an order payload to the queue.
  static Future<void> enqueue(
      String tenantId, Map<String, dynamic> orderData) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final List<dynamic> queue =
        raw != null ? jsonDecode(raw) as List : [];
    queue.add({'tenantId': tenantId, 'orderData': orderData});
    await prefs.setString(_key, jsonEncode(queue));
  }

  /// Returns pending order count.
  static Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return 0;
    return (jsonDecode(raw) as List).length;
  }

  /// Flush all queued orders. Returns list of placed order IDs.
  /// On partial failure, keeps failed entries and rethrows the last error.
  static Future<List<String>> flush() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];

    final List<dynamic> queue = jsonDecode(raw) as List;
    if (queue.isEmpty) return [];

    final placed = <String>[];
    final failed = <dynamic>[];

    for (final entry in queue) {
      try {
        final tenantId = entry['tenantId'] as String;
        final orderData = entry['orderData'] as Map<String, dynamic>;
        final order = await GuestApiService.placeOrder(tenantId, orderData);
        placed.add(order['id'] as String);
      } catch (_) {
        failed.add(entry);
      }
    }

    if (failed.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(failed));
    }

    return placed;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
