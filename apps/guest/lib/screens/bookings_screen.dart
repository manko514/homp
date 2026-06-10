import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/booking_service.dart';
import 'checkin_screen.dart';
import 'bill_screen.dart';
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<dynamic> _bookings = [];
  bool _loading = true;
  bool _isOffline = false;
  String? _error;

  static const _cacheKey = 'bookings_cache';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _isOffline = false; });
    try {
      final data = await BookingService.getMyBookings();
      // Persist for offline viewing.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      setState(() { _bookings = data; });
    } catch (_) {
      // Network failed — try cached data.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        setState(() {
          _bookings  = jsonDecode(raw) as List;
          _isOffline = true;
        });
      } else {
        setState(() => _error = 'No internet connection and no cached bookings available.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return DateFormat('MMM d, yyyy').format(d.toLocal());
  }

  /// Returns the DateTime when online check-in becomes available:
  /// hotel standard check-in is 3 PM, window opens 2 hours before = 1 PM.
  /// Returns null if checkInIso cannot be parsed.
  DateTime? _checkInWindowOpens(String? checkInIso) {
    if (checkInIso == null) return null;
    final date = DateTime.tryParse(checkInIso);
    if (date == null) return null;
    // 3 PM check-in time − 2 h = 1 PM on the check-in date
    final checkInAt3pm = DateTime(date.year, date.month, date.day, 15, 0);
    return checkInAt3pm.subtract(const Duration(hours: 2));
  }

  /// Human-readable label for when the window opens.
  String _fmtWindow(DateTime opens) {
    final now = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final openDay  = DateTime(opens.year, opens.month, opens.day);
    final timeStr  = DateFormat('h:mm a').format(opens);
    if (openDay == today)    return 'Check-in opens at $timeStr today';
    if (openDay == tomorrow) return 'Check-in opens at $timeStr tomorrow';
    return 'Check-in opens ${DateFormat('MMM d').format(opens)} at $timeStr';
  }

  static const _statusColors = {
    'PENDING':    Color(0xFFFF9800),
    'CONFIRMED':  Color(0xFF2196F3),
    'CHECKED_IN': Color(0xFF4CAF50),
    'CHECKED_OUT':Color(0xFF888EA8),
    'CANCELLED':  Color(0xFFF44336),
    'NO_SHOW':    Color(0xFFF44336),
  };

  static const _statusIcons = {
    'PENDING':    Icons.hourglass_empty,
    'CONFIRMED':  Icons.check_circle_outline,
    'CHECKED_IN': Icons.hotel,
    'CHECKED_OUT':Icons.logout,
    'CANCELLED':  Icons.cancel,
    'NO_SHOW':    Icons.person_off,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        title: const Text('My Bookings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : Column(
                  children: [
                    if (_isOffline)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFFF9800),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: const Row(children: [
                          Icon(Icons.wifi_off, color: Colors.white, size: 14),
                          SizedBox(width: 8),
                          Text('Offline — showing cached bookings',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    Expanded(
                      child: _bookings.isEmpty
                          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.hotel, size: 56, color: Color(0xFFDDDDDD)),
                              const SizedBox(height: 16),
                              const Text('No bookings yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                              const SizedBox(height: 6),
                              const Text('Book a room to get started', style: TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
                            ]))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _bookings.length,
                                itemBuilder: (ctx, i) => _bookingCard(_bookings[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> res) {
    final status = res['status'] as String? ?? 'CONFIRMED';
    final room   = res['room'] as Map<String, dynamic>?;
    final color  = _statusColors[status] ?? const Color(0xFF888EA8);
    final icon   = _statusIcons[status] ?? Icons.hotel;

    final windowOpens   = _checkInWindowOpens(res['checkIn'] as String?);
    final inWindow      = windowOpens != null && DateTime.now().isAfter(windowOpens);
    final canCheckIn    = status == 'CONFIRMED' && inWindow;
    final showWindowMsg = status == 'CONFIRMED' && !inWindow && windowOpens != null;
    final canCheckOut   = status == 'CHECKED_IN';
    final canViewBill   = status == 'CHECKED_IN' || status == 'CHECKED_OUT';
    final canRebook     = status == 'CHECKED_OUT' || status == 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room != null ? '${room['type']} — Room ${room['roomNumber']}' : 'Room Booking',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A)),
                      ),
                      Text('Floor ${room?['floor'] ?? '—'}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.replaceAll('_', ' '),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),

          // Dates + amount
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.login, size: 14, color: Color(0xFF888EA8)),
                    const SizedBox(width: 6),
                    Text('Check-in', style: const TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
                    const Spacer(),
                    Text(_fmt(res['checkIn'] as String?),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.logout, size: 14, color: Color(0xFF888EA8)),
                    const SizedBox(width: 6),
                    Text('Check-out', style: const TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
                    const Spacer(),
                    Text(_fmt(res['checkOut'] as String?),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                    Text('\$${double.tryParse(res['totalAmount'].toString())?.toStringAsFixed(2) ?? "—"}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                  ],
                ),
              ],
            ),
          ),

          // Pre-arrival window message
          if (showWindowMsg)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.schedule, size: 14, color: Color(0xFF2196F3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fmtWindow(windowOpens),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF2196F3), fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
            ),

          // Action buttons
          if (canCheckIn || canCheckOut || canViewBill || canRebook)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (canCheckIn)
                        Expanded(
                          child: _actionBtn('Digital Check-In', Icons.login, const Color(0xFF4CAF50), () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => CheckinScreen(reservation: res),
                            )).then((_) => _load());
                          }),
                        ),
                      if (canCheckOut) ...[
                        Expanded(
                          child: _actionBtn('View Bill', Icons.receipt_long, const Color(0xFF2196F3), () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => BillScreen(reservationId: res['id'] as String),
                            )).then((_) => _load());
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionBtn('Check Out', Icons.logout, const Color(0xFFFF9800), () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => BillScreen(reservationId: res['id'] as String, checkingOut: true),
                            )).then((_) => _load());
                          }),
                        ),
                      ],
                      if (canViewBill && !canCheckOut)
                        Expanded(
                          child: _actionBtn('View Bill', Icons.receipt_long, const Color(0xFF888EA8), () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => BillScreen(reservationId: res['id'] as String),
                            ));
                          }),
                        ),
                    ],
                  ),
                  // Re-book in one tap
                  if (canRebook) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showRebookSheet(res),
                        icon: const Icon(Icons.replay, size: 16),
                        label: const Text('Re-book Same Room', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showRebookSheet(Map<String, dynamic> original) {
    DateTime checkIn  = DateTime.now().add(const Duration(days: 7));
    DateTime checkOut = DateTime.now().add(const Duration(days: 9));
    bool rebooking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final nights = checkOut.difference(checkIn).inDays;
          final rate = double.tryParse(original['totalAmount']?.toString() ?? '0') ?? 0;
          // Estimate: same rate per night
          final origNights = (() {
            final ci = DateTime.tryParse(original['checkIn'] ?? '');
            final co = DateTime.tryParse(original['checkOut'] ?? '');
            if (ci == null || co == null) return 1;
            return co.difference(ci).inDays.clamp(1, 999);
          })();
          final ratePerNight = origNights > 0 ? rate / origNights : rate;
          final newTotal = ratePerNight * nights;

          Future<void> pickDate(bool isCI) async {
            final first = isCI ? DateTime.now() : checkIn.add(const Duration(days: 1));
            final picked = await showDatePicker(
              context: ctx,
              initialDate: isCI ? checkIn : checkOut,
              firstDate: first,
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF4CAF50))),
                child: child!,
              ),
            );
            if (picked == null) return;
            setS(() {
              if (isCI) {
                checkIn = picked;
                if (checkOut.isBefore(checkIn.add(const Duration(days: 1)))) {
                  checkOut = checkIn.add(const Duration(days: 1));
                }
              } else {
                checkOut = picked;
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Re-book Same Room', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                const SizedBox(height: 4),
                Text('${original['room']?['type'] ?? ''} — Room ${original['room']?['roomNumber'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
                const SizedBox(height: 20),

                Row(children: [
                  Expanded(child: _datePickerTile('CHECK-IN', checkIn, () => pickDate(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _datePickerTile('CHECK-OUT', checkOut, () => pickDate(false))),
                ]),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('$nights night${nights != 1 ? "s" : ""} estimated',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A))),
                    Text('\$${newTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                  ]),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: rebooking ? null : () async {
                      setS(() => rebooking = true);
                      try {
                        await BookingService.rebook(
                          original['id'] as String,
                          checkIn: checkIn.toIso8601String(),
                          checkOut: checkOut.toIso8601String(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _load();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Room re-booked successfully! ✓'), behavior: SnackBarBehavior.floating),
                        );
                      } catch (e) {
                        setS(() => rebooking = false);
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
                              behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: rebooking
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Re-book', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _datePickerTile(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today, size: 13, color: Color(0xFF888EA8)),
            const SizedBox(width: 6),
            Text(DateFormat('MMM d, yyyy').format(date),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
          ]),
        ]),
      ),
    );
  }
}
