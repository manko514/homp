import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ticket_storage.dart';
import '../services/guest_api_service.dart';
import 'buy_ticket_screen.dart';
import 'ticket_wallet_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  final String tenantId;

  const MyTicketsScreen({super.key, required this.tenantId});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _refreshing = false;

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
    'BEACH':   '🏖️',
    'FITNESS': '🧘',
    'TENNIS':  '🎾',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) setState(() => _refreshing = true);
    final local = await TicketStorage.loadAll();

    // Refresh statuses from server
    final updated = <Map<String, dynamic>>[];
    for (final t in local) {
      try {
        final fresh = await GuestApiService.getTicketByToken(
            t['qrToken'] as String);
        await TicketStorage.updateStatus(
            t['qrToken'] as String, fresh['status'] as String);
        updated.add(fresh);
      } catch (_) {
        updated.add(t);
      }
    }

    setState(() {
      _tickets = updated;
      _loading = false;
      _refreshing = false;
    });
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        title: const Text('My Tickets',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _load(refresh: true),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎫',
                          style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      const Text('No tickets yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E2A3A))),
                      const SizedBox(height: 6),
                      const Text('Buy a ticket to get started',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF888EA8))),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Buy Ticket'),
                        onPressed: _goToBuy,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._tickets.map((t) => _TicketCard(
                            ticket: t,
                            icon: _typeIcons[t['ticketType']] ?? '🎫',
                            statusColor: _statusColors[t['status']] ??
                                const Color(0xFF888EA8),
                            fmtDate: _fmt,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TicketWalletScreen(ticket: t),
                              ),
                            ).then((_) => _load()),
                          )),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buy Ticket'),
        onPressed: _goToBuy,
      ),
    );
  }

  void _goToBuy() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BuyTicketScreen(tenantId: widget.tenantId)),
    ).then((_) => _load());
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final String icon;
  final Color statusColor;
  final String Function(String?) fmtDate;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.icon,
    required this.statusColor,
    required this.fmtDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'ACTIVE';
    final isActive = status == 'ACTIVE';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? statusColor.withValues(alpha: 0.3)
                : const Color(0xFFEEF0F3),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Left color stripe
            Container(
              width: 6,
              height: 80,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Icon
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ticket['ticketType'] as String? ?? '—',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2A3A),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              )),
                        ),
                        const SizedBox(width: 14),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Valid until ${fmtDate(ticket['validUntil'] as String?)}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888EA8)),
                    ),
                    if (ticket['guestName'] != null)
                      Text(
                        ticket['guestName'] as String,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF888EA8)),
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
