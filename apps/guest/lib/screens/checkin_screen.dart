import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/booking_service.dart';
import '../services/nfc_service.dart';

class CheckinScreen extends StatefulWidget {
  final Map<String, dynamic> reservation;

  const CheckinScreen({super.key, required this.reservation});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  bool _loading = false;
  bool _checkedIn = false;
  String? _digitalKey;
  String? _error;

  // NFC write state
  bool _nfcWriting = false;
  bool _nfcDone    = false;
  bool _nfcAvail   = false;

  static String _keyPref(String reservationId) => 'digital_key_$reservationId';

  @override
  void initState() {
    super.initState();
    NfcService.instance.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvail = v);
    });
    // Load cached digital key so the QR works offline after a prior check-in.
    _loadCachedKey();
  }

  Future<void> _loadCachedKey() async {
    final resId = widget.reservation['id'] as String?;
    if (resId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_keyPref(resId));
    if (cached != null && mounted) {
      setState(() {
        _digitalKey = cached;
        _checkedIn  = true;
      });
    }
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return DateFormat('EEE, MMM d yyyy  h:mm a').format(d.toLocal());
  }

  Future<void> _writeNfc() async {
    if (_digitalKey == null) return;
    setState(() { _nfcWriting = true; _error = null; });
    try {
      await NfcService.instance.writeRoomKey(
        keyToken: _digitalKey!,
        onWaiting: () {
          // NFC session started — show overlay.
          if (!mounted) return;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1E2A3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Icon(Icons.nfc, color: Color(0xFF4CAF50), size: 52),
                  const SizedBox(height: 16),
                  const Text('Hold Near Key Card',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Place your phone against the blank hotel key card provided at reception.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: () {
                      NfcService.instance.cancelWrite();
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (mounted) {
        Navigator.of(context).pop(); // close dialog
        setState(() { _nfcDone = true; });
      }
    } catch (e) {
      if (mounted) {
        try { Navigator.of(context).pop(); } catch (_) {}
        setState(() => _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('Unsupported operation: ', ''));
      }
    } finally {
      if (mounted) setState(() => _nfcWriting = false);
    }
  }

  Future<void> _doCheckIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await BookingService.checkIn(widget.reservation['id'] as String);
      final key = res['digitalKey'] as String?;
      setState(() {
        _checkedIn  = true;
        _digitalKey = key;
      });
      // Persist the key locally so it works offline on re-open.
      if (key != null) {
        final resId = widget.reservation['id'] as String?;
        if (resId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyPref(resId), key);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.reservation['room'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: const Color(0xFF1E2A3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        title: const Text('Digital Check-In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _checkedIn ? _successView(room) : _confirmView(room),
      ),
    );
  }

  Widget _confirmView(Map<String, dynamic>? room) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.hotel, color: Color(0xFF4CAF50), size: 64),
        const SizedBox(height: 16),
        const Text('Ready to Check In?',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Tap the button to complete your digital check-in and receive your room key.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
        const SizedBox(height: 32),

        // Reservation summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              _infoRow('Room', room != null ? '${room['type']} — ${room['roomNumber']}' : '—'),
              const Divider(height: 18, color: Colors.white12),
              _infoRow('Floor', room?['floor']?.toString() ?? '—'),
              const Divider(height: 18, color: Colors.white12),
              _infoRow('Check-in', _fmt(widget.reservation['checkIn'] as String?)),
              const Divider(height: 18, color: Colors.white12),
              _infoRow('Check-out', _fmt(widget.reservation['checkOut'] as String?)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Flexible(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
              ],
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _loading ? null : _doCheckIn,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.login),
            label: Text(_loading ? 'Checking In…' : 'Complete Check-In',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _successView(Map<String, dynamic>? room) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 16),
        const Text('Welcome!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Room ${room?['roomNumber'] ?? '—'} is yours.',
            style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 32),

        // Digital key QR
        if (_digitalKey != null) ...[
          const Text('YOUR DIGITAL ROOM KEY',
              style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                QrImageView(data: _digitalKey!, size: 200, version: QrVersions.auto, backgroundColor: Colors.white),
                const SizedBox(height: 12),
                Text(_digitalKey!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF888EA8))),
                const SizedBox(height: 8),
                const Text('Show this at reception or tap NFC terminal',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // NFC write button — shown only when NFC is available on the device.
          if (_nfcAvail)
            _nfcDone
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                      SizedBox(width: 8),
                      Text('NFC Key Written!',
                          style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _nfcWriting ? null : _writeNfc,
                      icon: _nfcWriting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.nfc, size: 20),
                      label: Text(_nfcWriting ? 'Waiting for card…' : 'Write NFC Room Key',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Flexible(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              ]),
            ),
          ],

          const SizedBox(height: 24),
        ],

        // Tips
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('During Your Stay', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _tip(Icons.room_service, 'Order room service from the Home tab'),
              _tip(Icons.receipt_long, 'View your running bill in My Bookings'),
              _tip(Icons.logout, 'Check out digitally when ready'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to My Bookings'),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}
