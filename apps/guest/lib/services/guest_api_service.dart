import 'dart:convert';
import 'package:http/http.dart' as http;

class GuestApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  // Lookup hotel by subdomain
  static Future<Map<String, dynamic>> lookupTenant(String subdomain) async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/tenant?subdomain=$subdomain'),
      headers: _headers,
    );
    if (res.statusCode == 404 || res.statusCode >= 400) {
      throw Exception('Hotel not found');
    }
    return jsonDecode(res.body);
  }

  // Resolve table from QR scan
  static Future<Map<String, dynamic>> getTable(
      String tenantId, int tableNumber) async {
    final res = await http.get(
      Uri.parse('$baseUrl/guest/$tenantId/table/$tableNumber'),
      headers: _headers,
    );
    if (res.statusCode == 404) throw Exception('Table not found');
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');
    return jsonDecode(res.body);
  }

  // Get food menu
  static Future<List<dynamic>> getMenu(String tenantId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/guest/$tenantId/menu'),
      headers: _headers,
    );
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');
    return jsonDecode(res.body) as List;
  }

  // Get drinks menu
  static Future<List<dynamic>> getDrinks(String tenantId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/guest/$tenantId/drinks'),
      headers: _headers,
    );
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');
    return jsonDecode(res.body) as List;
  }

  // Place order
  static Future<Map<String, dynamic>> placeOrder(
      String tenantId, Map<String, dynamic> orderData) async {
    final res = await http.post(
      Uri.parse('$baseUrl/guest/$tenantId/orders'),
      headers: _headers,
      body: jsonEncode(orderData),
    );
    if (res.statusCode >= 400) {
      throw Exception('Order failed: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  // ─── Ticketing ────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getTicketCatalog() async {
    final res = await http.get(
      Uri.parse('$baseUrl/guest/ticket-catalog'),
      headers: _headers,
    );
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');
    return jsonDecode(res.body) as List;
  }

  static Future<Map<String, dynamic>> buyTicket(
    String tenantId, {
    required String ticketType,
    String? guestName,
    String? validDate,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/guest/$tenantId/tickets'),
      headers: _headers,
      body: jsonEncode({
        'ticketType': ticketType,
        'guestName': ?guestName,
        'validDate': ?validDate,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('Purchase failed: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getTicketByToken(String qrToken) async {
    final res = await http.get(
      Uri.parse('$baseUrl/guest/tickets/$qrToken'),
      headers: _headers,
    );
    if (res.statusCode == 404) throw Exception('Ticket not found');
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> validateTicket(String qrToken) async {
    final res = await http.post(
      Uri.parse('$baseUrl/guest/tickets/$qrToken/validate'),
      headers: _headers,
    );
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');
    return jsonDecode(res.body);
  }

  // Poll order status
  static Future<Map<String, dynamic>> trackOrder(String orderId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/guest/orders/$orderId/status'),
      headers: _headers,
    );
    if (res.statusCode == 404) throw Exception('Order not found');
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');
    return jsonDecode(res.body);
  }

  /// Returns { fullyBooked: ["2026-06-15", ...], totalRooms: N }
  static Future<Map<String, dynamic>> getBusyDates(String tenantId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/guest/$tenantId/rooms/busy-dates'),
    );
    if (res.statusCode >= 400) throw Exception('Failed to load availability');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
