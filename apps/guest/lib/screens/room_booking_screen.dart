import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import 'bookings_screen.dart';

class RoomBookingScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  final String tenantId;
  final String hotelName;
  final DateTime checkIn;
  final DateTime checkOut;

  const RoomBookingScreen({
    super.key,
    required this.room,
    required this.tenantId,
    required this.hotelName,
    required this.checkIn,
    required this.checkOut,
  });

  @override
  State<RoomBookingScreen> createState() => _RoomBookingScreenState();
}

// Available add-ons with prices
const _kAddOns = {
  'Airport Transfer': 25.0,
  'Early Check-In':  30.0,
  'Late Check-Out':  30.0,
  'Breakfast (x2)':  15.0,
  'City Tour':       45.0,
};

class _RoomBookingScreenState extends State<RoomBookingScreen> {
  final _notesCtrl = TextEditingController();
  bool _booking = false;
  String? _error;
  final Set<String> _selectedAddOns = {};

  int get _nights => widget.checkOut.difference(widget.checkIn).inDays;
  double get _rate => double.tryParse(widget.room['baseRate'].toString()) ?? 0;
  double get _addOnTotal => _selectedAddOns.fold(0.0, (s, k) => s + (_kAddOns[k] ?? 0));
  double get _total => _rate * _nights + _addOnTotal;

  String _fmt(DateTime d) => DateFormat('EEE, MMM d yyyy').format(d);

  Future<void> _book() async {
    setState(() { _booking = true; _error = null; });
    try {
      await BookingService.createBooking(
        widget.tenantId,
        roomId: widget.room['id'] as String,
        checkIn: widget.checkIn.toIso8601String(),
        checkOut: widget.checkOut.toIso8601String(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        addOns: _selectedAddOns.isEmpty ? null :
            { for (final k in _selectedAddOns) k: _kAddOns[k] },
      );
      if (!mounted) return;
      // Show success then go to bookings
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Booking Confirmed!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
              const SizedBox(height: 8),
              Text('Room ${widget.room['roomNumber']} is reserved for $_nights night${_nights != 1 ? "s" : ""}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
              const SizedBox(height: 8),
              Text('${_fmt(widget.checkIn)} → ${_fmt(widget.checkOut)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
              const SizedBox(height: 20),
              const Text('🎉 Loyalty points earned!',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const BookingsScreen()),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text('View My Bookings'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type  = widget.room['type'] as String? ?? 'STANDARD';
    final amenities = (widget.room['amenities'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        title: const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Flexible(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),

            // Room info card
            _card(children: [
              Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2A3A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bed, color: Color(0xFF1E2A3A), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                        Text('Room ${widget.room['roomNumber']}  •  Floor ${widget.room['floor']}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
                      ],
                    ),
                  ),
                ],
              ),
              if (amenities.isNotEmpty) ...[
                const Divider(height: 20),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: amenities.map((a) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEEF0F3)),
                    ),
                    child: Text(a, style: const TextStyle(fontSize: 11, color: Color(0xFF1E2A3A))),
                  )).toList(),
                ),
              ],
            ]),
            const SizedBox(height: 14),

            // Dates
            _card(children: [
              _row('Check-in', _fmt(widget.checkIn), Icons.login),
              const Divider(height: 16),
              _row('Check-out', _fmt(widget.checkOut), Icons.logout),
              const Divider(height: 16),
              _row('Duration', '$_nights night${_nights != 1 ? "s" : ""}', Icons.nights_stay),
            ]),
            const SizedBox(height: 14),

            // Add-ons
            _card(children: [
              const Text('ADD-ONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.2)),
              const SizedBox(height: 4),
              const Text('Optional extras for your stay', style: TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
              const SizedBox(height: 10),
              ..._kAddOns.entries.map((e) {
                final sel = _selectedAddOns.contains(e.key);
                return CheckboxListTile(
                  value: sel,
                  onChanged: (v) => setState(() => v! ? _selectedAddOns.add(e.key) : _selectedAddOns.remove(e.key)),
                  title: Text(e.key, style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A))),
                  subtitle: Text('+\$${e.value.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 11, color: sel ? const Color(0xFF4CAF50) : const Color(0xFF888EA8), fontWeight: FontWeight.w600)),
                  secondary: Icon(
                    switch (e.key) {
                      'Airport Transfer' => Icons.local_taxi,
                      'Early Check-In'   => Icons.wb_sunny,
                      'Late Check-Out'   => Icons.nightlight,
                      'Breakfast (x2)'   => Icons.free_breakfast,
                      _                  => Icons.tour,
                    },
                    color: sel ? const Color(0xFF4CAF50) : const Color(0xFF888EA8),
                    size: 20,
                  ),
                  activeColor: const Color(0xFF4CAF50),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),
            ]),
            const SizedBox(height: 14),

            // Pricing
            _card(children: [
              _amountRow('\$${_rate.toStringAsFixed(0)} × $_nights night${_nights != 1 ? "s" : ""}', _rate * _nights),
              if (_selectedAddOns.isNotEmpty) ...[
                const SizedBox(height: 6),
                ..._selectedAddOns.map((k) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _amountRow(k, _kAddOns[k] ?? 0),
                )),
              ],
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                Text('\$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Color(0xFF4CAF50), size: 14),
                    const SizedBox(width: 6),
                    Text('Earn ${(_total * 10).toStringAsFixed(0)} loyalty points',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Special requests
            _card(children: [
              const Text('Special Requests (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. late check-in, high floor preferred, extra pillows…',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Payment note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.payment, color: Color(0xFF2196F3), size: 16),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Payment at reception on check-in. We accept cash, card, and mobile money.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2196F3)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _booking ? null : _book,
            child: _booking
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Confirm Booking  •  \$${_total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _row(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF888EA8)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
      ],
    );
  }

  Widget _amountRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
        Text('\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A))),
      ],
    );
  }
}
