import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/utils.dart';
import '../widgets/app_theme.dart';

class BarScreen extends StatefulWidget {
  const BarScreen({super.key});
  @override
  State<BarScreen> createState() => _BarScreenState();
}

class _BarScreenState extends State<BarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic>? _drinks;
  List<dynamic>? _sales;
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/bar/drinks'),
        ApiService.get('/bar/sales'),
        ApiService.get('/bar/shift-summary'),
      ]);
      setState(() {
        _drinks  = results[0];
        _sales   = results[1];
        _summary = results[2];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleDrink(String id, bool available) async {
    try {
      await ApiService.patch('/bar/drinks/$id/toggle', {});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  void _showSaleDialog() {
    if (_drinks == null || _drinks!.isEmpty) return;
    final available = _drinks!.where((d) => d['isAvailable'] == true).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No drinks available to sell')),
      );
      return;
    }
    String? selectedDrinkId = available.first['id'];
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Sale',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Drink', style: TextStyle(fontSize: 12, color: AppTheme.textMid)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedDrinkId,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: available.map<DropdownMenuItem<String>>((d) =>
                  DropdownMenuItem(
                    value: d['id'] as String,
                    child: Text('${d['name']} — \$${toDouble(d['price']).toStringAsFixed(2)}'),
                  )).toList(),
              onChanged: (v) => selectedDrinkId = v,
            ),
            const SizedBox(height: 14),
            const Text('Quantity', style: TextStyle(fontSize: 12, color: AppTheme.textMid)),
            const SizedBox(height: 6),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.post('/bar/sales', {
                  'drinkId': selectedDrinkId,
                  'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                });
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sale recorded!'),
                      backgroundColor: AppTheme.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
                  );
                }
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSaleDialog,
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Record Sale'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: AppTheme.navy,
              unselectedLabelColor: AppTheme.textLight,
              indicatorColor: AppTheme.navy,
              tabs: const [
                Tab(text: 'Menu'),
                Tab(text: 'Sales'),
                Tab(text: 'Summary'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [_menuTab(), _salesTab(), _summaryTab()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _menuTab() {
    if (_drinks == null || _drinks!.isEmpty) {
      return const Center(child: Text('No drinks in menu'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _drinks!.length,
        separatorBuilder: (_, idx) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final d = _drinks![i];
          final available = d['isAvailable'] == true;
          final price = toDouble(d['price']);
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: available
                      ? const Color(0xFFEEF0F3)
                      : AppTheme.red.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: available
                        ? AppTheme.blue.withValues(alpha: 0.1)
                        : AppTheme.red.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_bar,
                      color: available ? AppTheme.blue : AppTheme.textLight,
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['name'] ?? '',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: available
                                  ? AppTheme.textDark
                                  : AppTheme.textLight)),
                      Text('${d['category'] ?? ''} · \$${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textLight)),
                    ],
                  ),
                ),
                Switch(
                  value: available,
                  activeThumbColor: AppTheme.green,
                  onChanged: (_) => _toggleDrink(d['id'], available),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _salesTab() {
    if (_sales == null || _sales!.isEmpty) {
      return const Center(child: Text('No sales today'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sales!.length,
        separatorBuilder: (_, idx) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = _sales![i];
          final total = toDouble(s['total']);
          final qty = s['quantity'] ?? 1;
          final soldAt = DateTime.tryParse(s['soldAt'] ?? s['createdAt'] ?? '');
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_bar,
                      color: AppTheme.purple, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['drink']?['name'] ?? 'Drink',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textDark)),
                      Text(
                        'Qty: $qty${soldAt != null ? '  ·  ${DateFormat('h:mm a').format(soldAt)}' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                ),
                Text('\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryTab() {
    if (_summary == null) {
      return const Center(child: Text('No summary available'));
    }

    final totalSales  = toDouble(_summary!['totalSales']);
    final totalWaste  = toDouble(_summary!['totalWaste']);
    final salesCount  = _summary!['salesCount'] ?? 0;
    final topDrinks   = _summary!['topDrinks'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // KPI cards
          Row(
            children: [
              Expanded(child: _kpiCard('Total Sales', '\$${totalSales.toStringAsFixed(2)}', AppTheme.green, Icons.attach_money)),
              const SizedBox(width: 10),
              Expanded(child: _kpiCard('Orders', '$salesCount', AppTheme.blue, Icons.receipt)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _kpiCard('Waste', '\$${totalWaste.toStringAsFixed(2)}', AppTheme.red, Icons.delete_outline)),
              const SizedBox(width: 10),
              Expanded(child: _kpiCard('Net', '\$${(totalSales - totalWaste).toStringAsFixed(2)}', AppTheme.navy, Icons.trending_up)),
            ],
          ),
          const SizedBox(height: 16),

          // Top drinks
          if (topDrinks.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEEF0F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top Sellers',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 12),
                  ...topDrinks.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final d = entry.value;
                    final colors = [AppTheme.green, AppTheme.blue, AppTheme.purple,
                        AppTheme.yellow, AppTheme.cyan];
                    final rev = toDouble(d['revenue']);
                    final maxRev = toDouble(topDrinks.first['revenue']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${idx + 1}. ${d['name'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textDark)),
                              Text('\$${rev.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textMid)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxRev > 0 ? (rev / maxRev).clamp(0.0, 1.0) : 0,
                              minHeight: 5,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  colors[idx % colors.length]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEF0F3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textLight)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}
