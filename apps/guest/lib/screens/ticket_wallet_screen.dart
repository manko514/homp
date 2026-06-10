import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../services/ticket_storage.dart';

class TicketWalletScreen extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const TicketWalletScreen({super.key, required this.ticket});

  static const _statusColors = {
    'ACTIVE':    Color(0xFF4CAF50),
    'USED':      Color(0xFF888EA8),
    'EXPIRED':   Color(0xFFF44336),
    'CANCELLED': Color(0xFFF44336),
  };

  static const _typeIcons = {
    'POOL':    '🏊',
    'GYM':     '🏋️',
    'SPA':     '💆',
    'beach':   '🏖️',
    'FITNESS': '🧘',
    'TENNIS':  '🎾',
  };

  Color get _statusColor =>
      _statusColors[ticket['status']] ?? const Color(0xFF888EA8);

  String get _icon =>
      _typeIcons[ticket['ticketType']] ?? '🎫';

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('MMM d, yyyy  h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'ACTIVE';
    final isActive = status == 'ACTIVE';
    final qrToken = ticket['qrToken'] as String;

    return Scaffold(
      backgroundColor: const Color(0xFF1E2A3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        title: const Text('Your Ticket',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
            onPressed: () async {
              await TicketStorage.remove(qrToken);
              if (context.mounted) Navigator.pop(context);
            },
            tooltip: 'Remove from wallet',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Ticket card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header stripe
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_icon,
                            style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          ticket['ticketType'] as String? ?? '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        if (ticket['guestName'] != null)
                          Text(
                            ticket['guestName'] as String,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dashed divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List.generate(
                        30,
                        (i) => Expanded(
                          child: Container(
                            height: 1,
                            color: i.isEven
                                ? const Color(0xFFEEF0F3)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // QR code
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: qrToken,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                          )
                        else
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  status == 'USED'
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 64,
                                  color: _statusColor,
                                ),
                                const SizedBox(height: 8),
                                Text(status,
                                    style: TextStyle(
                                        color: _statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        if (isActive)
                          const Text(
                            'Show this QR code at the gate',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF888EA8)),
                          ),
                      ],
                    ),
                  ),

                  // Validity info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        _infoRow('Valid From', _fmt(ticket['validFrom'] as String?)),
                        const SizedBox(height: 8),
                        _infoRow('Valid Until', _fmt(ticket['validUntil'] as String?)),
                        if (ticket['usedAt'] != null) ...[
                          const SizedBox(height: 8),
                          _infoRow('Used At', _fmt(ticket['usedAt'] as String?)),
                        ],
                        const SizedBox(height: 8),
                        _infoRow('Price',
                            '\$${double.tryParse(ticket['purchasePrice'].toString())?.toStringAsFixed(2) ?? "—"}'),
                        const SizedBox(height: 8),
                        _infoRow('Token',
                            '${qrToken.substring(0, 8).toUpperCase()}...',
                            mono: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Done / back button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Wallet',
                    style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool mono = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF888EA8))),
        Text(value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E2A3A),
              fontFamily: mono ? 'monospace' : null,
            )),
      ],
    );
  }
}
