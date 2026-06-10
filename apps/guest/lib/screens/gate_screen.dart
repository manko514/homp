import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/guest_api_service.dart';
import 'package:intl/intl.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _processing = false;
  _ScanResult? _result;
  Timer? _resetTimer;

  @override
  void dispose() {
    _ctrl.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() {
      _processing = true;
      _result = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final res = await GuestApiService.validateTicket(raw);
      stopwatch.stop();

      setState(() {
        _result = _ScanResult(
          valid: res['valid'] as bool,
          message: res['message'] as String,
          ticket: res['ticket'] as Map<String, dynamic>?,
          elapsed: stopwatch.elapsedMilliseconds,
        );
      });

      // Auto-reset after 4 seconds so next scan can happen
      _resetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _result = null;
            _processing = false;
          });
          _ctrl.start();
        }
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _result = _ScanResult(
          valid: false,
          message: 'ERROR',
          ticket: null,
          elapsed: stopwatch.elapsedMilliseconds,
        );
        _processing = false;
      });
    }
  }

  void _reset() {
    _resetTimer?.cancel();
    setState(() {
      _result = null;
      _processing = false;
    });
    _ctrl.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gate Scanner',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('STAFF MODE',
                style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 10,
                    letterSpacing: 1.5)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Camera
          if (_result == null)
            MobileScanner(
              controller: _ctrl,
              onDetect: _handleScan,
            ),

          // Result overlay
          if (_result != null)
            _ResultOverlay(result: _result!, onReset: _reset)
          else
            // Scan frame overlay
            IgnorePointer(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Scan frame
                          Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFF4CAF50), width: 3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _processing
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF4CAF50)))
                                : const SizedBox(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _processing
                                ? 'Validating...'
                                : 'Point camera at ticket QR',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanResult {
  final bool valid;
  final String message;
  final Map<String, dynamic>? ticket;
  final int elapsed;

  const _ScanResult({
    required this.valid,
    required this.message,
    this.ticket,
    required this.elapsed,
  });
}

class _ResultOverlay extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onReset;

  const _ResultOverlay({required this.result, required this.onReset});

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final color = result.valid ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final icon = result.valid ? Icons.check_circle : Icons.cancel;
    final ticket = result.ticket;

    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big result icon
          AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: Icon(icon, color: color, size: 60),
            ),
          ),
          const SizedBox(height: 20),

          // Message
          Text(
            result.message,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.elapsed}ms',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Ticket details
          if (ticket != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  _row('Type', ticket['ticketType'] as String? ?? '—'),
                  const SizedBox(height: 6),
                  if (ticket['guestName'] != null)
                    _row('Guest', ticket['guestName'] as String),
                  if (ticket['guestName'] != null) const SizedBox(height: 6),
                  _row('Valid Until', _fmt(ticket['validUntil'] as String?)),
                  if (ticket['usedAt'] != null) ...[
                    const SizedBox(height: 6),
                    _row('Used At', _fmt(ticket['usedAt'] as String?)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 32),

          // Scan next button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Next',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            onPressed: onReset,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
