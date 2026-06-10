import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StaffApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.0.216:3001',
  );

  // ─── Token Management ─────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('staff_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_token', token);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_user', jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('staff_user');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('staff_token');
    await prefs.remove('staff_user');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> lookupTenant(String subdomain) async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/tenant?subdomain=${Uri.encodeComponent(subdomain)}'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Hotel not found');
  }

  static Future<Map<String, dynamic>> login(String email, String password, String tenantId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'tenantId': tenantId}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Login failed');
  }

  // ─── FCM Token ────────────────────────────────────────────────────────────────

  static Future<void> saveFcmToken(String token) async {
    await http.post(
      Uri.parse('$baseUrl/notifications/token'),
      headers: await _headers(),
      body: jsonEncode({'token': token}),
    );
  }

  // ─── Attendance ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> clockIn({double? lat, double? lng}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/staff/clock-in'),
      headers: await _headers(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Clock-in failed');
  }

  static Future<Map<String, dynamic>> clockOut({double? lat, double? lng}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/staff/clock-out'),
      headers: await _headers(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Clock-out failed');
  }

  static Future<Map<String, dynamic>?> getTodayAttendance() async {
    final res = await http.get(
      Uri.parse('$baseUrl/staff/attendance/today'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final body = res.body.trim();
      if (body == 'null' || body.isEmpty) return null;
      return jsonDecode(body) as Map<String, dynamic>?;
    }
    return null;
  }

  // ─── Housekeeper ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getHousekeeperRooms() async {
    final res = await http.get(
      Uri.parse('$baseUrl/staff/housekeeper/rooms'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load rooms');
  }

  static Future<void> markRoomCleaning(String roomId) async {
    await http.patch(
      Uri.parse('$baseUrl/staff/housekeeper/rooms/$roomId/cleaning'),
      headers: await _headers(),
    );
  }

  static Future<void> markRoomClean(String roomId) async {
    await http.patch(
      Uri.parse('$baseUrl/staff/housekeeper/rooms/$roomId/clean'),
      headers: await _headers(),
    );
  }

  // ─── Waiter ───────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getWaiterOrders() async {
    final res = await http.get(
      Uri.parse('$baseUrl/staff/waiter/orders'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load orders');
  }

  // ─── Bartender ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getBartenderSummary() async {
    final res = await http.get(
      Uri.parse('$baseUrl/staff/bartender/summary'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load bartender summary');
  }
}
