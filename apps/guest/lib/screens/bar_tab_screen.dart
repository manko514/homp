import 'package:flutter/material.dart';
import '../services/bar_tab_service.dart';
import '../services/guest_api_service.dart';

class BarTabScreen extends StatefulWidget {
  final String tenantId;
  final String hotelName;

  const BarTabScreen({super.key, required this.tenantId, required this.hotelName});

  @override
  State<BarTabScreen> createState() => _BarTabScreenState();
}

class _BarTabScreenState extends State<BarTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _tab;
  List<dynamic> _drinks = [];
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  // Drink qty picker per drinkId
  final Map<String, int> _qty = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        BarTabService.getTab(),
        GuestApiService.getDrinks(widget.tenantId),
      ]);
      setState(() {
        _tab = results[0] as Map<String, dynamic>?;
        _drinks = results[1] as List;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTab() async {
    setState(() { _actionLoading = true; _error = null; });
    try {
      final tab = await BarTabService.openTab(widget.tenantId);
      setState(() => _tab = tab);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _addDrink(String drinkId) async {
    final qty = _qty[drinkId] ?? 1;
    setState(() { _actionLoading = true; _error = null; });
    try {
      // Open tab first if none
      if (_tab == null) await _openTab();
      final updated = await BarTabService.addItem(drinkId, qty);
      if (!mounted) return;
      setState(() { _tab = updated; _qty[drinkId] = 1; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to bar tab ✓'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _closeTab() async {
    final total = double.tryParse(_tab!['total'].toString()) ?? 0.0;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _BarPaySheet(
        total: total,
        onPay: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _actionLoading = true; _error = null; });
    try {
      await BarTabService.closeTab();
      if (!mounted) return;
      setState(() => _tab = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of \$${total.toStringAsFixed(2)} confirmed. Tab closed ✓'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bar Tab', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(widget.hotelName, style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF50))),
        ]),
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'My Tab'),
            Tab(icon: Icon(Icons.local_bar, size: 18), text: 'Drink Menu'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_buildTabView(), _buildDrinkMenu()],
            ),
    );
  }

  Widget _buildTabView() {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              _errorCard(_error!),

            if (_tab == null) ...[
              // No open tab
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2A3A).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_bar, size: 40, color: Color(0xFF888EA8)),
                    ),
                    const SizedBox(height: 20),
                    const Text('No open bar tab', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                    const SizedBox(height: 8),
                    const Text('Open a tab to start ordering drinks\nand track your running total.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF888EA8), height: 1.5)),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 200,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E2A3A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _actionLoading ? null : _openTab,
                        icon: _actionLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add),
                        label: const Text('Open Bar Tab'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Open tab summary
              _card(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Text('Tab Open', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                  ]),
                  Text(
                    '\$${double.tryParse(_tab!['total'].toString())?.toStringAsFixed(2) ?? "0.00"}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A)),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text('Running Total', style: TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
              ]),
              const SizedBox(height: 12),

              // Items
              _buildTabItems(),

              const SizedBox(height: 16),
              _card(children: [
                const Text('PAYMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.2)),
                const SizedBox(height: 8),
                const Text('Tap "Pay Tab" below to choose your payment method and settle your balance.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E2A3A), height: 1.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  _methodChip(Icons.account_balance_wallet, 'Wallet'),
                  _methodChip(Icons.phone_android, 'MTN / Airtel'),
                  _methodChip(Icons.credit_card, 'Card'),
                  _methodChip(Icons.attach_money, 'Cash'),
                ]),
              ]),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _actionLoading ? null : _closeTab,
                  icon: _actionLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.payment),
                  label: Text(
                    'Pay Tab  •  \$${double.tryParse(_tab!['total'].toString())?.toStringAsFixed(2) ?? "0.00"}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabItems() {
    final items = (_tab!['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (items.isEmpty) {
      return _card(children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No drinks added yet — go to Drink Menu tab',
              style: TextStyle(color: Color(0xFF888EA8), fontSize: 13),
            ),
          ),
        ),
      ]);
    }
    return _card(children: [
      const Text('ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.2)),
      const SizedBox(height: 12),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2A3A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_bar, size: 16, color: Color(0xFF1E2A3A)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] as String? ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
              Text('${item['qty']}× @ \$${double.tryParse(item['unitPrice'].toString())?.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
            ])),
            Text('\$${double.tryParse(item['total'].toString())?.toStringAsFixed(2) ?? "—"}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
          ],
        ),
      )),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Running Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text('\$${double.tryParse(_tab!['total'].toString())?.toStringAsFixed(2) ?? "0.00"}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
      ]),
    ]);
  }

  Widget _buildDrinkMenu() {
    // Group by category
    final Map<String, List<dynamic>> byCategory = {};
    for (final d in _drinks) {
      final cat = d['category'] as String? ?? 'Other';
      byCategory.putIfAbsent(cat, () => []).add(d);
    }

    if (_drinks.isEmpty) {
      return const Center(child: Text('No drinks available', style: TextStyle(color: Color(0xFF888EA8))));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) _errorCard(_error!),
        if (_tab != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long, color: Color(0xFF4CAF50), size: 16),
              const SizedBox(width: 8),
              Text('Tab open — Total: \$${double.tryParse(_tab!['total'].toString())?.toStringAsFixed(2) ?? "0.00"}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
            ]),
          ),
        ...byCategory.entries.map((e) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(e.key.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.5)),
            ),
            ...e.value.map((drink) => _drinkTile(drink)),
          ],
        )),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _drinkTile(Map<String, dynamic> drink) {
    final id = drink['id'] as String;
    final qty = _qty[id] ?? 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2A3A).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_bar, color: Color(0xFF1E2A3A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(drink['name'] as String? ?? '—',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
            Text('\$${double.tryParse(drink['price'].toString())?.toStringAsFixed(2) ?? "—"}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
          ])),
          // Qty stepper
          Row(children: [
            _qtyBtn(Icons.remove, () {
              if (qty > 1) setState(() => _qty[id] = qty - 1);
            }),
            SizedBox(
              width: 28,
              child: Text('$qty', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            _qtyBtn(Icons.add, () => setState(() => _qty[id] = qty + 1)),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2A3A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
              ),
              onPressed: _actionLoading ? null : () => _addDrink(id),
              child: const Text('Add', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: const Color(0xFF1E2A3A)),
    ),
  );

  Widget _card({required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEF0F3))),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _errorCard(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
    child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 13)),
  );

  Widget _methodChip(IconData icon, String label) => Chip(
    avatar: Icon(icon, size: 14, color: const Color(0xFF888EA8)),
    label: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
    backgroundColor: const Color(0xFFF5F6FA),
    side: const BorderSide(color: Color(0xFFEEF0F3)),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
  );
}

// ─── Bar Payment Bottom Sheet ─────────────────────────────────────────────────

class _BarPaySheet extends StatefulWidget {
  final double total;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  const _BarPaySheet({required this.total, required this.onPay, required this.onCancel});

  @override
  State<_BarPaySheet> createState() => _BarPaySheetState();
}

class _BarPaySheetState extends State<_BarPaySheet> {
  String _method = 'Wallet';

  static const _methods = [
    _M('Wallet',  'HOMP Wallet',        Icons.account_balance_wallet),
    _M('MTN',     'MTN Mobile Money',   Icons.phone_android),
    _M('Airtel',  'Airtel Money',       Icons.phone_android),
    _M('Card',    'Credit / Debit Card', Icons.credit_card),
    _M('Cash',    'Cash at Bar',        Icons.attach_money),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pay Your Tab',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                SizedBox(height: 2),
                Text('Choose how you would like to pay',
                    style: TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\$${widget.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          const Text('PAYMENT METHOD',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Color(0xFF888EA8), letterSpacing: 1.2)),
          const SizedBox(height: 10),

          ..._methods.map((m) {
            final sel = _method == m.id;
            return GestureDetector(
              onTap: () => setState(() => _method = m.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF4CAF50).withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? const Color(0xFF4CAF50) : const Color(0xFFEEF0F3),
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(m.icon,
                      size: 20,
                      color: sel ? const Color(0xFF4CAF50) : const Color(0xFF888EA8)),
                  const SizedBox(width: 12),
                  Text(m.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? const Color(0xFF4CAF50) : const Color(0xFF1E2A3A),
                      )),
                  const Spacer(),
                  if (sel) const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                ]),
              ),
            );
          }),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF888EA8),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: widget.onPay,
                child: Text(
                  'Pay \$${widget.total.toStringAsFixed(2)} via $_method',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _M {
  final String id;
  final String label;
  final IconData icon;
  const _M(this.id, this.label, this.icon);
}
