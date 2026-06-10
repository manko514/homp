import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import '../services/guest_api_service.dart';
import 'room_booking_screen.dart';

class RoomsScreen extends StatefulWidget {
  final String tenantId;
  final String hotelName;

  const RoomsScreen({super.key, required this.tenantId, required this.hotelName});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  DateTime _checkIn  = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 2));
  List<dynamic> _rooms = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  // Availability calendar: set of "yyyy-MM-dd" strings that are fully booked
  Set<String> _fullyBooked = {};

  @override
  void initState() {
    super.initState();
    _loadBusyDates();
  }

  Future<void> _loadBusyDates() async {
    try {
      final data = await GuestApiService.getBusyDates(widget.tenantId);
      final dates = (data['fullyBooked'] as List?)?.cast<String>() ?? [];
      setState(() => _fullyBooked = dates.toSet());
    } catch (_) {
      // Non-critical — date picker still works without blocked dates
    }
  }

  bool _isBooked(DateTime day) {
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _fullyBooked.contains(key);
  }

  Future<void> _pickDate(bool isCheckIn) async {
    final first = isCheckIn ? DateTime.now() : _checkIn.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn ? _checkIn : _checkOut,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: isCheckIn ? (day) => !_isBooked(day) : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4CAF50),
            onSurface: Color(0xFF1E2A3A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (_checkOut.isBefore(_checkIn.add(const Duration(days: 1)))) {
          _checkOut = _checkIn.add(const Duration(days: 1));
        }
      } else {
        _checkOut = picked;
      }
    });
  }

  Future<void> _search() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rooms = await BookingService.getAvailableRooms(
        widget.tenantId,
        checkIn: _checkIn.toIso8601String(),
        checkOut: _checkOut.toIso8601String(),
      );
      setState(() { _rooms = rooms; _searched = true; });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _nights => _checkOut.difference(_checkIn).inDays;
  String _fmt(DateTime d) => DateFormat('EEE, MMM d').format(d);

  static const _typeColors = {
    'STANDARD': Color(0xFF2196F3),
    'DELUXE':   Color(0xFF9C27B0),
    'SUITE':    Color(0xFFFF9800),
    'VILLA':    Color(0xFF4CAF50),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Rooms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.hotelName, style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF50))),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date picker panel
          Container(
            color: const Color(0xFF1E2A3A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _dateTile('CHECK IN', _checkIn, () => _pickDate(true))),
                    Container(width: 1, height: 52, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 12)),
                    Expanded(child: _dateTile('CHECK OUT', _checkOut, () => _pickDate(false))),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search, color: Colors.white),
                        onPressed: _loading ? null : _search,
                        tooltip: 'Search',
                      ),
                    ),
                  ],
                ),
                if (_searched)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$_nights night${_nights != 1 ? "s" : ""}  •  ${_rooms.length} room${_rooms.length != 1 ? "s" : ""} available',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _error != null
                ? _centeredMsg(Icons.error_outline, _error!, Colors.red)
                : !_searched
                    ? _centeredMsg(Icons.hotel, 'Select dates and tap Search', const Color(0xFF888EA8))
                    : _rooms.isEmpty
                        ? _centeredMsg(Icons.bed, 'No rooms available for these dates', const Color(0xFF888EA8))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _rooms.length,
                            itemBuilder: (ctx, i) => _roomCard(_rooms[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white60, size: 14),
              const SizedBox(width: 6),
              Text(_fmt(date), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _centeredMsg(IconData icon, String msg, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(fontSize: 14, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final type    = room['type'] as String? ?? 'STANDARD';
    final rate    = double.tryParse(room['baseRate'].toString()) ?? 0;
    final total   = double.tryParse(room['totalPrice'].toString()) ?? 0;
    final color   = _typeColors[type.toUpperCase()] ?? const Color(0xFF2196F3);
    final amenities = (room['amenities'] as List?)?.cast<String>() ?? [];
    final photos  = (room['photos'] as List?)?.cast<String>() ?? [];

    void goToBooking() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomBookingScreen(
          room: room, tenantId: widget.tenantId,
          hotelName: widget.hotelName,
          checkIn: _checkIn, checkOut: _checkOut,
        ),
      ),
    );

    return GestureDetector(
      onTap: goToBooking,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEF0F3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo carousel (or colour placeholder) ────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: photos.isNotEmpty
                  ? SizedBox(
                      height: 160,
                      child: PageView.builder(
                        itemCount: photos.length,
                        itemBuilder: (_, i) => Image.network(
                          photos[i],
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stk) => _photoPlaceholder(color, type),
                        ),
                      ),
                    )
                  : _photoPlaceholder(color, type),
            ),

            // ── Room info row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(type, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                          const SizedBox(width: 8),
                          Text('Room ${room['roomNumber'] ?? '—'}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
                        ]),
                        Text('Floor ${room['floor'] ?? '—'}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
                      ],
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('\$${rate.toStringAsFixed(0)}/night',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                    Text('Total \$${total.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),

            // Amenities chips
            if (amenities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: amenities.take(5).map((a) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEEF0F3)),
                    ),
                    child: Text(a, style: const TextStyle(fontSize: 10, color: Color(0xFF1E2A3A))),
                  )).toList(),
                ),
              ),
            const SizedBox(height: 12),

            // Book button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: goToBooking,
                  child: Text('Book for \$${total.toStringAsFixed(0)}  •  $_nights night${_nights != 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder(Color color, String type) => Container(
    height: 160,
    color: color.withValues(alpha: 0.10),
    child: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bed, size: 48, color: color.withValues(alpha: 0.5)),
        const SizedBox(height: 6),
        Text(type, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
