import 'dart:convert';
import 'package:http/http.dart' as http;
import 'guest_api_service.dart';
import 'auth_service.dart';

class BookingService {
  static Future<Map<String, String>> get _authHeaders async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> getAvailableRooms(
    String tenantId, {
    required String checkIn,
    required String checkOut,
  }) async {
    final uri = Uri.parse(
      '${GuestApiService.baseUrl}/guest/$tenantId/rooms?checkIn=$checkIn&checkOut=$checkOut',
    );
    final res = await http.get(uri);
    if (res.statusCode >= 400) throw Exception('Failed to load rooms');
    return jsonDecode(res.body) as List;
  }

  static Future<Map<String, dynamic>> createBooking(
    String tenantId, {
    required String roomId,
    required String checkIn,
    required String checkOut,
    String? notes,
    Map<String, dynamic>? addOns,
  }) async {
    final headers = await _authHeaders;
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/$tenantId/bookings'),
      headers: headers,
      body: jsonEncode({
        'roomId': roomId,
        'checkIn': checkIn,
        'checkOut': checkOut,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (addOns != null && addOns.isNotEmpty) 'addOns': addOns,
      }),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Booking failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getMyBookings() async {
    final headers = await _authHeaders;
    final res = await http.get(
      Uri.parse('${GuestApiService.baseUrl}/guest/bookings'),
      headers: headers,
    );
    if (res.statusCode >= 400) throw Exception('Failed to load bookings');
    return jsonDecode(res.body) as List;
  }

  static Future<Map<String, dynamic>> checkIn(String reservationId) async {
    final headers = await _authHeaders;
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/bookings/$reservationId/checkin'),
      headers: headers,
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Check-in failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getBill(String reservationId) async {
    final headers = await _authHeaders;
    final res = await http.get(
      Uri.parse('${GuestApiService.baseUrl}/guest/bookings/$reservationId/bill'),
      headers: headers,
    );
    if (res.statusCode >= 400) throw Exception('Failed to load bill');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> checkOut(String reservationId) async {
    final headers = await _authHeaders;
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/bookings/$reservationId/checkout'),
      headers: headers,
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Check-out failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> rebook(
    String reservationId, {
    required String checkIn,
    required String checkOut,
  }) async {
    final headers = await _authHeaders;
    final res = await http.post(
      Uri.parse('${GuestApiService.baseUrl}/guest/bookings/$reservationId/rebook'),
      headers: headers,
      body: jsonEncode({'checkIn': checkIn, 'checkOut': checkOut}),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Re-book failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String getReceiptUrl(String reservationId) {
    return '${GuestApiService.baseUrl}/guest/bookings/$reservationId/receipt';
  }
}
