import 'dart:convert';
import 'package:http/http.dart' as http;
import 'guest_api_service.dart';
import 'auth_service.dart';

class BarTabService {
  static Future<Map<String, String>> get _authHeaders async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> openTab(String tenantId) async {
    final headers = await _authHeaders;
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/$tenantId/bar-tab/open'),
      headers: headers,
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Failed to open bar tab');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> getTab() async {
    final headers = await _authHeaders;
    final res = await http.get(
      Uri.parse('${GuestApiService.baseUrl}/guest/bar-tab'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final body = res.body.trim();
      if (body == 'null' || body.isEmpty) return null;
      return jsonDecode(body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>> addItem(String drinkId, int qty) async {
    final headers = await _authHeaders;
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/bar-tab/add'),
      headers: headers,
      body: jsonEncode({'drinkId': drinkId, 'qty': qty}),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Failed to add item');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> closeTab() async {
    final headers = await _authHeaders;
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/bar-tab/close'),
      headers: headers,
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Failed to close tab');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getHistory() async {
    final headers = await _authHeaders;
    final res = await http.get(
      Uri.parse('${GuestApiService.baseUrl}/guest/bar-tab/history'),
      headers: headers,
    );
    if (res.statusCode >= 400) return [];
    return jsonDecode(res.body) as List;
  }
}
