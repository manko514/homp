import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists purchased ticket QR tokens locally so guests can view their wallet offline.
class TicketStorage {
  static const _key = 'guest_tickets';

  static Future<void> save(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final List<dynamic> list = raw != null ? jsonDecode(raw) as List : [];

    // Avoid duplicates
    list.removeWhere((t) => t['qrToken'] == ticket['qrToken']);
    list.insert(0, ticket);

    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> remove(String qrToken) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .where((t) => t['qrToken'] != qrToken)
        .toList();
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<void> updateStatus(String qrToken, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).map((t) {
      if (t['qrToken'] == qrToken) {
        return {...t as Map<String, dynamic>, 'status': status};
      }
      return t;
    }).toList();
    await prefs.setString(_key, jsonEncode(list));
  }
}
