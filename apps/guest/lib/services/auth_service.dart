import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'guest_api_service.dart';

class AuthService {
  static const _tokenKey = 'guest_token';
  static const _userKey  = 'guest_user';

  // ─── Token helpers ─────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // ─── Auth API calls ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
    String tenantId, {
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/$tenantId/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Registration failed');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _saveSession(data['token'] as String, data['user'] as Map<String, dynamic>);
    return data;
  }

  static Future<Map<String, dynamic>> login(
    String tenantId, {
    String? email,
    String? phone,
    required String password,
  }) async {
    final body = <String, dynamic>{'password': password};
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;

    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/$tenantId/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Login failed');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _saveSession(data['token'] as String, data['user'] as Map<String, dynamic>);
    return data;
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('${GuestApiService.baseUrl}/guest/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 400) throw Exception('Failed to load profile');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    final res = await http.patch(
      Uri.parse('${GuestApiService.baseUrl}/guest/me'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (res.statusCode >= 400) throw Exception('Failed to update profile');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getLoyalty() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('${GuestApiService.baseUrl}/guest/loyalty'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 400) throw Exception('Failed to load loyalty');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getWallet() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('${GuestApiService.baseUrl}/guest/wallet'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 400) throw Exception('Failed to load wallet');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> debitWallet({
    required String tenantId,
    required double amount,
    String? note,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/wallet/debit'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'tenantId': tenantId, 'amount': amount, 'note': ?note}),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Payment failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> socialLogin(
    String tenantId, {
    required String provider,
    required String idToken,
  }) async {
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/$tenantId/social'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'provider': provider, 'idToken': idToken}),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Social login failed');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _saveSession(data['token'] as String, data['user'] as Map<String, dynamic>);
    return data;
  }

  static Future<void> saveFcmToken(String token) async {
    final authToken = await getToken();
    if (authToken == null) return;
    await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/fcm-token'),
      headers: {'Authorization': 'Bearer $authToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );
  }

  static Future<Map<String, dynamic>> topUpWallet({
    required String tenantId,
    required double amount,
    required String method,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/wallet/topup'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'tenantId': tenantId, 'amount': amount, 'method': method}),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Top-up failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
