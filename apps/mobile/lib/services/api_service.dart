import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Web/emulator: localhost:3001
  // Real Android phone: use your PC's local IP
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.0.216:3001',
  );

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static bool get isLoggedIn => _token != null;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // Lookup tenant by subdomain
  static Future<Map<String, dynamic>> lookupTenant(String subdomain) async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/tenant?subdomain=$subdomain'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) throw Exception('Tenant not found');
    return jsonDecode(res.body);
  }

  // Login
  static Future<Map<String, dynamic>> login(
      String email, String password, String tenantId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'tenantId': tenantId}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Login failed: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  // GET
  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');
    return jsonDecode(res.body);
  }

  // POST
  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}: ${res.body}');
    return jsonDecode(res.body);
  }

  // PATCH
  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}: ${res.body}');
    return jsonDecode(res.body);
  }
}
