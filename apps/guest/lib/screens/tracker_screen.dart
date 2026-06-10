import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/guest_api_service.dart';
import '../services/offline_queue.dart';
import '../services/utils.dart';
import 'scan_screen.dart';

class TrackerScreen extends StatefulWidget {
  final String orderId;
  final String tenantId;
  final int? tableNumber;
  final bool isRoomService;

  const TrackerScreen({
    super.key,
    required this.orderId,
    required this.tenantId,
    this.tableNumber,
    this.isRoomService = false,
  });

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  int _pendingOffline = 0;
  bool _flushing = false;

  static const _pollInterval = Duration(seconds: 5);

  // Status flow
  static const _statuses = ['PENDING', 'KDS', 'READY', 'SERVED', 'BILLED'];

  static const _statusLabels = {
    'PENDING': 'Order Received',
    'KDS': 'Being Prepared',
    'READY': 'Ready for Pickup / Delivery',
    'SERVED': 'Served',
    'BILLED': 'Completed',
    'CANCELLED': 'Cancelled',
  };

  static const _statusIcons = {
    'PENDING': Icons.receipt_long,
    'KDS': Icons.soup_kitchen,
    'READY': Icons.check_circle,
    'SERVED': Icons.restaurant,
    'BILLED': Icons.task_alt,
    'CANCELLED': Icons.cancel,
  };

  static const _statusColors = {
    'PENDING': Color(0xFF2196F3),
    'KDS': Color(0xFFFF9800),
    'READY': Color(0xFF4CAF50),
    'SERVED': Color(0xFF4CAF50),
    'BILLED': Color(0xFF888EA8),
    'CANCELLED': Color(0xFFF44336),
  };

  @override
  void initState() {
    super.initState();
    _fetch();
    _startPolling();
    _checkOfflineQueue();
    _listenConnectivity();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      final status = _order?['status'];
      // Stop polling on terminal states
      if (status == 'BILLED' || status == 'CANCELLED') {
        _pollTimer?.cancel();
        return;
      }
      await _fetch(silent: true);
    });
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final order = await GuestApiService.trackOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _checkOfflineQueue() async {
    final count = await OfflineQueue.pendingCount();
    if (mounted) setState(() => _pendingOffline = count);
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) async {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline && _pendingOffline > 0 && !_flushing) {
        setState(() => _flushing = true);
        try {
          await OfflineQueue.flush();
          await _checkOfflineQueue();
        } finally {
          if (mounted) setState(() => _flushing = false);
        }
      }
    });
  }

  String _elapsed() {
    final createdAt = _order?['createdAt'];
    if (createdAt == null) return '';
    final created = DateTime.tryParse(createdAt as String);
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }

  /// Estimated time remaining based on status + order placed time
  String? _eta() {
    final status = _order?['status'] as String?;
    if (status == null || status == 'SERVED' || status == 'BILLED' || status == 'CANCELLED') return null;

    final createdAt = _order?['createdAt'];
    if (createdAt == null) return null;
    final created = DateTime.tryParse(createdAt as String);
    if (created == null) return null;

    // ETA windows: PENDING → 5 min, KDS → 15 min, READY → 2 min (delivery)
    final targetMinutes = switch (status) {
      'PENDING' => 5,
      'KDS'     => 15,
      'READY'   => 2,
      _         => 0,
    };
    if (targetMinutes == 0) return null;

    final eta = created.add(Duration(minutes: targetMinutes));
    final remaining = eta.difference(DateTime.now());

    if (remaining.isNegative) return 'Any moment now';
    if (remaining.inMinutes < 1) return 'Less than 1 min';
    return '~${remaining.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final status = _order?['status'] as String? ?? 'PENDING';
    final isCancelled = status == 'CANCELLED';
    final isBilled = status == 'BILLED';
    final isDone = isCancelled || isBilled;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Tracker',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            if (widget.tableNumber != null)
              Text('Table ${widget.tableNumber}',
                  style: const TextStyle(
                      color: Color(0xFF4CAF50), fontSize: 11)),
            if (widget.isRoomService)
              const Text('Room Service',
                  style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11)),
          ],
        ),
        actions: [
          if (!_loading && !isDone)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _fetch(),
            ),
        ],
      ),
      body: _loading && _order == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _order == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _fetch,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Offline queue banner
                        if (_pendingOffline > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFFF9800)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off,
                                    color: Color(0xFFFF9800), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _flushing
                                        ? 'Syncing $_pendingOffline queued order(s)...'
                                        : '$_pendingOffline order(s) queued offline. Will sync on reconnect.',
                                    style: const TextStyle(
                                        color: Color(0xFFFF9800),
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Status card
                        _statusCard(status),
                        const SizedBox(height: 8),

                        // ETA chip
                        if (_eta() != null)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFFF9800)),
                                const SizedBox(width: 6),
                                Text('ETA: ${_eta()}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF9800))),
                              ]),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Progress stepper
                        if (!isCancelled) _stepper(status),
                        if (!isCancelled) const SizedBox(height: 16),

                        // Order summary
                        _orderSummary(),
                        const SizedBox(height: 16),

                        // Done — new order button
                        if (isDone)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan to Order Again',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ScanScreen()),
                                (route) => false,
                              ),
                            ),
                          ),

                        // Live indicator (polling)
                        if (!isDone)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('Live tracking — updates every 5s',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF888EA8))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _statusCard(String status) {
    final color = _statusColors[status] ?? const Color(0xFF888EA8);
    final label = _statusLabels[status] ?? status;
    final icon = _statusIcons[status] ?? Icons.info;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Order #${widget.orderId.substring(0, 8).toUpperCase()}  •  ${_elapsed()}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888EA8)),
          ),
        ],
      ),
    );
  }

  Widget _stepper(String currentStatus) {
    final currentIdx =
        _statuses.indexOf(currentStatus).clamp(0, _statuses.length - 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Column(
        children: List.generate(_statuses.length, (i) {
          final s = _statuses[i];
          final isDone = i < currentIdx;
          final isCurrent = i == currentIdx;
          final isUpcoming = i > currentIdx;
          final color = isCurrent
              ? _statusColors[s] ?? const Color(0xFF4CAF50)
              : isDone
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFCDD1E0);

          return Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isUpcoming
                          ? Colors.transparent
                          : color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color,
                          width: isCurrent ? 2.5 : 1.5),
                    ),
                    child: isDone
                        ? const Icon(Icons.check,
                            size: 14, color: Color(0xFF4CAF50))
                        : Icon(
                            _statusIcons[s] ?? Icons.circle,
                            size: 14,
                            color: isUpcoming
                                ? const Color(0xFFCDD1E0)
                                : color,
                          ),
                  ),
                  if (i < _statuses.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      color: i < currentIdx
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEEF0F3),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom:
                          i < _statuses.length - 1 ? 28 : 0),
                  child: Text(
                    _statusLabels[s] ?? s,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isUpcoming
                          ? const Color(0xFFCDD1E0)
                          : isCurrent
                              ? color
                              : const Color(0xFF1E2A3A),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _orderSummary() {
    final items =
        (_order?['orderItems'] as List<dynamic>?) ?? [];
    final drinkItems =
        (_order?['drinkItems'] as List<dynamic>?) ?? [];
    final total = toDouble(_order?['total']);
    final notes = _order?['notes'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Summary',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2A3A))),
          const SizedBox(height: 12),
          ...items.map((item) {
            final name = item['menuItem']?['name'] as String? ?? '—';
            final qty = item['qty'] as int? ?? 1;
            final price = toDouble(item['menuItem']?['price']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$qty× $name',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1E2A3A))),
                  Text(
                      '\$${(price * qty).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF888EA8))),
                ],
              ),
            );
          }),
          ...drinkItems.map((d) {
            final name = d['name'] as String? ?? '—';
            final qty = d['qty'] as int? ?? 1;
            final price = toDouble(d['price']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_bar,
                          size: 14, color: Color(0xFF9C27B0)),
                      const SizedBox(width: 4),
                      Text('$qty× $name',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF1E2A3A))),
                    ],
                  ),
                  Text('\$${(price * qty).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF888EA8))),
                ],
              ),
            );
          }),
          if (notes != null && notes.isNotEmpty) ...[
            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note_outlined,
                    size: 14, color: Color(0xFF888EA8)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(notes,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF888EA8))),
                ),
              ],
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2A3A))),
              Text('\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50))),
            ],
          ),
        ],
      ),
    );
  }
}
