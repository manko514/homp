import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/utils.dart' as u;
import '../widgets/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic>? _stock;
  List<dynamic>? _alerts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        ApiService.get('/inventory/stock'),
        ApiService.get('/inventory/stock/alerts'),
      ]);
      setState(() {
        _stock = res[0];
        _alerts = res[1];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Tab(text: 'All Stock'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Alerts'),
                    if (_alerts != null && _alerts!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_alerts!.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [_stockTab(_stock), _alertsTab()],
                ),
        ),
      ],
    );
  }

  Widget _stockTab(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return const Center(child: Text('No stock items'));
    }
    final colors = [
      AppTheme.green, AppTheme.blue, AppTheme.yellow,
      AppTheme.red, AppTheme.purple, AppTheme.cyan
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, idx) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          final qty = u.toDouble(item['currentQty']);
          final reorder = u.toDouble(item['reorderLevel']);
          final max = qty > reorder * 3 ? qty : reorder * 3;
          final pct = max > 0 ? (qty / max).clamp(0.0, 1.0) : 0.0;
          final isLow = qty <= reorder;
          final color = isLow ? AppTheme.red : colors[i % colors.length];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isLow
                      ? AppTheme.red.withValues(alpha:0.3)
                      : const Color(0xFFEEF0F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(item['name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textDark)),
                    ),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.red.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('LOW',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.red)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['category'] ?? ''} • ${qty.toStringAsFixed(1)} ${item['unit'] ?? ''} in stock',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Reorder at ${reorder.toStringAsFixed(0)} ${item['unit'] ?? ''}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _alertsTab() {
    if (_alerts == null || _alerts!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppTheme.green, size: 48),
            SizedBox(height: 12),
            Text('All stock levels are healthy!',
                style: TextStyle(color: AppTheme.textMid)),
          ],
        ),
      );
    }
    return _stockTab(_alerts);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}
