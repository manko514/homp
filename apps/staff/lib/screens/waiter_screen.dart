import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/staff_api_service.dart';

class WaiterScreen extends StatefulWidget {
  const WaiterScreen({super.key});

  @override
  State<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends State<WaiterScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadOrders());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    try {
      final data = await StaffApiService.getWaiterOrders();
      if (mounted) setState(() { _orders = data; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'KDS': return Colors.blue;
      case 'READY': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING': return '⏳ Pending';
      case 'KDS': return '👨‍🍳 In Kitchen';
      case 'READY': return '✅ Ready';
      default: return status;
    }
  }

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('hh:mm a').format(dt);
  }

  Duration _age(String iso) {
    return DateTime.now().difference(DateTime.parse(iso).toLocal());
  }

  String _fmtAge(Duration d) {
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: _error != null
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadOrders, child: const Text('Retry')),
                      ],
                    ))
                  : _orders.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text('No active orders', style: TextStyle(fontSize: 18, color: Colors.grey)),
                                  SizedBox(height: 4),
                                  Text('Pull to refresh', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _orders.length,
                          itemBuilder: (ctx, i) => _buildOrderCard(_orders[i]),
                        ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadOrders,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'PENDING';
    final tableNum = (order['table'] as Map?)? ['tableNumber'];
    final isRoom = order['isRoomService'] == true;
    final roomNum = order['roomNumber'] as String?;
    final notes = order['notes'] as String?;
    final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0.0;
    final createdAt = order['createdAt'] as String? ?? '';
    final age = createdAt.isNotEmpty ? _age(createdAt) : Duration.zero;
    final items = order['orderItems'] as List? ?? [];
    final drinkItems = order['drinkItems'] as List? ?? [];

    // Highlight orders that are READY — they need serving
    final isReady = status == 'READY';
    final isOld = age.inMinutes > 20 && status != 'READY';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isReady
            ? const BorderSide(color: Colors.green, width: 2)
            : isOld
                ? const BorderSide(color: Colors.orange, width: 1.5)
                : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  isRoom ? Icons.hotel : Icons.table_restaurant,
                  color: _statusColor(status),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isRoom ? 'Room ${roomNum ?? "?"}' : 'Table $tableNum',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order time
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      createdAt.isNotEmpty ? _fmtTime(createdAt) : '--',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    if (isOld)
                      Text(
                        '⚠️ ${_fmtAge(age)}',
                        style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                      )
                    else
                      Text(_fmtAge(age), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Food items
                if (items.isNotEmpty) ...[
                  const Text('🍽 Food Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...items.map<Widget>((item) {
                    final menuItem = item['menuItem'] as Map?;
                    final itemName = menuItem?['name'] ?? 'Item';
                    final qty = item['qty'] ?? 1;
                    final unitPrice = double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('  × $qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(itemName.toString(), style: const TextStyle(fontSize: 13))),
                          Text('\$${(unitPrice * qty).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        ],
                      ),
                    );
                  }),
                ],

                // Drink items
                if (drinkItems.isNotEmpty) ...[
                  if (items.isNotEmpty) const SizedBox(height: 8),
                  const Text('🍹 Drinks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...drinkItems.map<Widget>((drink) {
                    final dName = drink['name'] ?? 'Drink';
                    final qty = drink['qty'] ?? 1;
                    final price = double.tryParse(drink['price']?.toString() ?? '0') ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('  × $qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(dName.toString(), style: const TextStyle(fontSize: 13))),
                          Text('\$${(price * qty).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        ],
                      ),
                    );
                  }),
                ],

                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.yellow.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(child: Text(notes, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Total: ', style: TextStyle(color: Colors.black54)),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
