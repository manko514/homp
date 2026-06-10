import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/staff_api_service.dart';

class BartenderScreen extends StatefulWidget {
  const BartenderScreen({super.key});

  @override
  State<BartenderScreen> createState() => _BartenderScreenState();
}

class _BartenderScreenState extends State<BartenderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadSummary();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadSummary());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    if (!mounted) return;
    try {
      final data = await StaffApiService.getBartenderSummary();
      if (mounted) setState(() { _summary = data; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String _fmtTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          TextButton(onPressed: _loadSummary, child: const Text('Retry')),
        ],
      ));
    }

    final sales = _summary?['sales'] as List? ?? [];
    final drinks = _summary?['drinks'] as List? ?? [];
    final totalRevenue = (_summary?['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final totalSales = (_summary?['totalSales'] as num?)?.toInt() ?? 0;

    return Scaffold(
      body: Column(
        children: [
          // Summary header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                _statChip('Today\'s Sales', '$totalSales drinks', Icons.local_bar),
                const SizedBox(width: 16),
                _statChip('Revenue', '\$${totalRevenue.toStringAsFixed(2)}', Icons.attach_money),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadSummary,
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabCtrl,
            tabs: [
              Tab(text: 'Sales Log (${sales.length})'),
              Tab(text: 'Drinks Menu (${drinks.length})'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildSalesLog(sales),
                _buildDrinkMenu(drinks),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSalesLog(List<dynamic> sales) {
    if (sales.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No sales yet today', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sales.length,
        itemBuilder: (ctx, i) {
          final sale = sales[i] as Map<String, dynamic>;
          final drink = sale['drink'] as Map?;
          final drinkName = drink?['name'] as String? ?? 'Unknown';
          final drinkCat = drink?['category'] as String? ?? '';
          final qty = sale['qty'] as int? ?? 0;
          final total = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
          final time = sale['createdAt'] as String? ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  qty.toString(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                ),
              ),
              title: Text(drinkName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(drinkCat.isNotEmpty ? '$drinkCat • ${_fmtTime(time)}' : _fmtTime(time)),
              trailing: Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrinkMenu(List<dynamic> drinks) {
    if (drinks.isEmpty) {
      return const Center(
        child: Text('No drinks available', style: TextStyle(color: Colors.grey)),
      );
    }

    // Group by category
    final Map<String, List<dynamic>> grouped = {};
    for (final d in drinks) {
      final cat = (d as Map)['category'] as String? ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54),
              ),
            ),
            ...entry.value.map<Widget>((drink) {
              final d = drink as Map<String, dynamic>;
              final name = d['name'] as String? ?? '';
              final price = double.tryParse(d['price']?.toString() ?? '0') ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.local_bar, color: Colors.blue),
                  title: Text(name),
                  trailing: Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}
