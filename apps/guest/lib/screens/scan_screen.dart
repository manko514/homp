import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/guest_api_service.dart';
import 'menu_screen.dart';

class ScanScreen extends StatefulWidget {
  /// When launched from HomeScreen the tenantId is already known.
  /// When launched standalone (cold open) it is read from the QR.
  final String? tenantId;

  const ScanScreen({super.key, this.tenantId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isProcessing = false;
  String? _error;
  final MobileScannerController _ctrl = MobileScannerController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Parse both QR formats:
  ///   JSON:  {"tenantId":"xxx","tableNumber":1}
  ///   URL:   homp://restaurant/table/{tenantId}/{tableNumber}
  ///          homp://restaurant/room/{tenantId}/{roomNumber}
  Map<String, dynamic> _parseQr(String raw) {
    // Try JSON first
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}

    // Try URL format
    // Try URL format: homp://restaurant/table/{tenantId}/{tableNumber}
    // Uri.pathSegments for homp://restaurant/table/tid/1 = ['table','tid','1']
    // because 'restaurant' is parsed as the host, not a path segment
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'homp') {
      final segments = uri.pathSegments; // ['table', tenantId, tableNumber]
      if (segments.length >= 3) {
        final type = segments[0]; // 'table' or 'room'
        final tenantId = segments[1];
        final value = segments[2];
        if (type == 'table') {
          return {'tenantId': tenantId, 'tableNumber': int.tryParse(value) ?? 1};
        } else if (type == 'room') {
          return {'tenantId': tenantId, 'type': 'room_service', 'roomNumber': value};
        }
      }
    }
    throw Exception('Unrecognised QR code format');
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final payload = _parseQr(raw);
      // Prefer tenantId from QR; fall back to one passed from HomeScreen
      final tenantId = (payload['tenantId'] as String?) ?? widget.tenantId;
      final tableNumber = payload['tableNumber'];
      final isRoomService = payload['type'] == 'room_service';
      final roomNumber = payload['roomNumber'] as String?;

      if (tenantId == null) {
        throw Exception('Invalid QR code — missing tenantId');
      }

      String? tableId;
      int? tableNum;

      if (!isRoomService && tableNumber != null) {
        final table = await GuestApiService.getTable(
            tenantId, (tableNumber as num).toInt());
        tableId = table['id'] as String;
        tableNum = table['tableNumber'] as int;
      }

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MenuScreen(
            tenantId: tenantId,
            tableId: tableId,
            tableNumber: tableNum,
            isRoomService: isRoomService,
            roomNumber: roomNumber,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isProcessing = false;
      });
      _ctrl.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera
            MobileScanner(
              controller: _ctrl,
              onDetect: _handleScan,
            ),

            // Dark overlay with hole
            IgnorePointer(
              child: CustomPaint(
                painter: _OverlayPainter(),
                child: const SizedBox.expand(),
              ),
            ),

            // Top header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    const Text(
                      'HOMP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan your table QR code to order',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Processing / Error message
            if (_isProcessing || _error != null)
              Positioned(
                bottom: 40,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: _error != null
                        ? Colors.red.shade800
                        : const Color(0xFF1E2A3A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(Icons.error_outline,
                            color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _isProcessing ? 'Resolving table...' : _error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const holeSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 30;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: holeSize, height: holeSize);

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    // Draw dark overlay excluding the QR hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    canvas.drawPath(path..fillType = PathFillType.evenOdd, paint);

    // Corner brackets
    final bracketPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const bracketLen = 24.0;
    final r = rect.inflate(2);

    // TL
    canvas.drawLine(Offset(r.left, r.top + bracketLen), Offset(r.left, r.top),
        bracketPaint);
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left + bracketLen, r.top),
        bracketPaint);
    // TR
    canvas.drawLine(Offset(r.right - bracketLen, r.top),
        Offset(r.right, r.top), bracketPaint);
    canvas.drawLine(Offset(r.right, r.top),
        Offset(r.right, r.top + bracketLen), bracketPaint);
    // BL
    canvas.drawLine(Offset(r.left, r.bottom - bracketLen),
        Offset(r.left, r.bottom), bracketPaint);
    canvas.drawLine(Offset(r.left, r.bottom),
        Offset(r.left + bracketLen, r.bottom), bracketPaint);
    // BR
    canvas.drawLine(Offset(r.right - bracketLen, r.bottom),
        Offset(r.right, r.bottom), bracketPaint);
    canvas.drawLine(Offset(r.right, r.bottom - bracketLen),
        Offset(r.right, r.bottom), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
