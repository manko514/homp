import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/utils.dart';
import '../widgets/app_theme.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});
  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic>? _orders;
  bool _loading = true;

  static const _statusColor = {
    'PENDING':     AppTheme.yellow,
    'IN_PROGRESS': AppTheme.blue,
    'READY':       AppTheme.green,
    'COMPLETED':   AppTheme.textLight,
    'CANCELLED':   AppTheme.red,
  };

  static const _statusIcon = {
    'PENDING':     Icons.hourglass_empty,
    'IN_PROGRESS': Icons.restaurant,
    'READY':       Icons.check_circle_outline,
    'COMPLETED':   Icons.done_all,
    'CANCELLED':   Icons.cancel_outlined,
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/restaurant/orders');
      setState(() { _orders = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> _filtered(List<String> statuses) =>
      (_orders ?? []).where((o) => statuses.contains(o['status'])).toList();

  Future<void> _updateStatus(String id, String status) async {
    try {
      await ApiService.patch('/restaurant/orders/$id/status', {'status': status});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  Future<void> _closeBill(String id) async {
    try {
      await ApiService.patch('/restaurant/orders/$id/bill', {});
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill closed'), backgroundColor: AppTheme.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active  = _filtered(['PENDING', 'IN_PROGRESS', 'READY']);
    final ready   = _filtered(['READY']);
    final done    = _filtered(['COMPLETED', 'CANCELLED']);

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppTheme.navy,
            unselectedLabelColor: AppTheme.textLight,
            indicatorColor: AppTheme.navy,
            tabs: [
              _tabLabel('Active', active.length),
              _tabLabel('Ready', ready.length, color: AppTheme.green),
              const Tab(text: 'History'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _orderList(active),
                    _orderList(ready),
                    _orderList(done),
                  ],
                ),
        ),
      ],
    );
  }

  Tab _tabLabel(String text, int count, {Color? color}) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color ?? AppTheme.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );

  Widget _orderList(List<dynamic> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, color: AppTheme.textLight, size: 48),
            SizedBox(height: 12),
            Text('No orders here', style: TextStyle(color: AppTheme.textLight)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, idx) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _orderCard(orders[i]),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'PENDING';
    final color = _statusColor[status] ?? AppTheme.textLight;
    final icon  = _statusIcon[status] ?? Icons.receipt;
    final items = order['orderItems'] as List? ?? [];
    final total = toDouble(order['total']);
    final tableNum = order['tableNumber']?.toString() ?? '—';
    final createdAt = DateTime.tryParse(order['createdAt'] ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Table $tableNum',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textDark)),
                      if (createdAt != null)
                        Text(DateFormat('MMM d, h:mm a').format(createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textLight)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                    const SizedBox(height: 3),
                    Text('\$${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                  ],
                ),
              ],
            ),
          ),

          // Items list
          if (items.isNotEmpty) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(
                children: items.take(3).map<Widget>((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item['quantity']}x ${item['menuItem']?['name'] ?? 'Item'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMid)),
                      Text('\$${toDouble(item['price']).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMid)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],

          // Action buttons
          if (['PENDING', 'IN_PROGRESS', 'READY'].contains(status)) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (status == 'PENDING')
                    _actionBtn('Start Cooking', AppTheme.blue, () =>
                        _updateStatus(order['id'], 'IN_PROGRESS')),
                  if (status == 'IN_PROGRESS')
                    _actionBtn('Mark Ready', AppTheme.green, () =>
                        _updateStatus(order['id'], 'READY')),
                  if (status == 'READY') ...[
                    _actionBtn('Complete', AppTheme.green, () =>
                        _updateStatus(order['id'], 'COMPLETED')),
                    const SizedBox(width: 8),
                    _actionBtn('Close Bill', AppTheme.navy, () =>
                        _closeBill(order['id'])),
                  ],
                  const Spacer(),
                  if (status != 'READY')
                    TextButton(
                      onPressed: () => _updateStatus(order['id'], 'CANCELLED'),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppTheme.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(label),
      );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}
