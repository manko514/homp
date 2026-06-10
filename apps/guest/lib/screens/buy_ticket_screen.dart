import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/guest_api_service.dart';
import '../services/ticket_storage.dart';
import 'ticket_wallet_screen.dart';

class BuyTicketScreen extends StatefulWidget {
  final String tenantId;

  const BuyTicketScreen({super.key, required this.tenantId});

  @override
  State<BuyTicketScreen> createState() => _BuyTicketScreenState();
}

class _BuyTicketScreenState extends State<BuyTicketScreen> {
  List<dynamic> _catalog = [];
  bool _loading = true;
  bool _buying = false;
  String? _selectedType;
  DateTime _selectedDate = DateTime.now();
  final _nameCtrl = TextEditingController();
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final data = await GuestApiService.getTicketCatalog();
      setState(() { _catalog = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _confirmAndBuy() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a ticket type'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final selected = _catalog.firstWhere((c) => c['type'] == _selectedType);
    final price    = (selected['price'] as num).toDouble();
    final total    = price * _qty;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PaymentSheet(
        icon:   selected['icon'] as String,
        label:  selected['label'] as String,
        price:  price,
        qty:    _qty,
        total:  total,
        date:   DateFormat('EEE, MMM d yyyy').format(_selectedDate),
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel:  () => Navigator.pop(ctx, false),
      ),
    );

    if (confirmed != true || !mounted) return;
    await _buy(selected);
  }

  Future<void> _buy(Map<String, dynamic> selected) async {
    setState(() => _buying = true);
    final tickets = <Map<String, dynamic>>[];
    try {
      for (int i = 0; i < _qty; i++) {
        final ticket = await GuestApiService.buyTicket(
          widget.tenantId,
          ticketType: _selectedType!,
          guestName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          validDate:  DateFormat('yyyy-MM-dd').format(_selectedDate),
        );
        await TicketStorage.save(ticket);
        tickets.add(ticket);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicketWalletScreen(ticket: tickets.first),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _buying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _catalog.firstWhere(
      (c) => c['type'] == _selectedType,
      orElse: () => null,
    );
    final price = selected != null ? (selected['price'] as num).toDouble() : 0.0;
    final total = price * _qty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        title: const Text('Buy Ticket',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Ticket type grid ──────────────────────────────────────
                const _Label('SELECT TICKET TYPE'),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.4,
                  children: _catalog.map<Widget>((c) {
                    final isSelected = _selectedType == c['type'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = c['type'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFFEEF0F3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(c['icon'] as String, style: const TextStyle(fontSize: 28)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['label'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF1E2A3A),
                                    )),
                                Text(
                                  '\$${(c['price'] as num).toStringAsFixed(0)}  •  ${c['validHours']}h',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Quantity stepper ──────────────────────────────────────
                const _Label('QUANTITY'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEF0F3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined,
                          size: 20, color: Color(0xFF888EA8)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Number of tickets',
                            style: TextStyle(fontSize: 14, color: Color(0xFF1E2A3A))),
                      ),
                      _QtyButton(
                        icon: Icons.remove,
                        enabled: _qty > 1,
                        onTap: () => setState(() => _qty--),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '$_qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _QtyButton(
                        icon: Icons.add,
                        enabled: _qty < 10,
                        onTap: () => setState(() => _qty++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Guest name ────────────────────────────────────────────
                const _Label('YOUR NAME (OPTIONAL)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. John Smith',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFEEF0F3))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFEEF0F3))),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Date picker ───────────────────────────────────────────
                const _Label('VALID DATE'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEF0F3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF888EA8), size: 18),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE, MMMM d yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1E2A3A)),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: Color(0xFF888EA8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Price summary ─────────────────────────────────────────
                if (selected != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2A3A).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E2A3A).withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${selected['icon']}  ${selected['label']}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A)),
                            ),
                            Text(
                              '\$${price.toStringAsFixed(2)} × $_qty',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF888EA8)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_buying || _selectedType == null) ? null : _confirmAndBuy,
            child: _buying
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    selected != null
                        ? 'Review & Pay  •  \$${(price * _qty).toStringAsFixed(2)}'
                        : 'Select a Ticket Type',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Payment Confirmation Sheet ───────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final String icon;
  final String label;
  final double price;
  final int qty;
  final double total;
  final String date;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _PaymentSheet({
    required this.icon,
    required this.label,
    required this.price,
    required this.qty,
    required this.total,
    required this.date,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String _method = 'Wallet';

  static const _methods = [
    _PayMethod(id: 'Wallet', label: 'HOMP Wallet', icon: Icons.account_balance_wallet),
    _PayMethod(id: 'MTN',    label: 'MTN Mobile Money', icon: Icons.phone_android),
    _PayMethod(id: 'Airtel', label: 'Airtel Money',     icon: Icons.phone_android),
    _PayMethod(id: 'Card',   label: 'Credit / Debit Card', icon: Icons.credit_card),
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
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text('Confirm Purchase',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
          const SizedBox(height: 4),
          const Text('Review your order before paying',
              style: TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
          const SizedBox(height: 20),

          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _summaryRow('Ticket', '${widget.icon} ${widget.label}'),
                const SizedBox(height: 8),
                _summaryRow('Quantity', '${widget.qty}×'),
                const SizedBox(height: 8),
                _summaryRow('Valid Date', widget.date),
                const SizedBox(height: 8),
                _summaryRow('Price each', '\$${widget.price.toStringAsFixed(2)}'),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                    Text(
                      '\$${widget.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payment method
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
                child: Row(
                  children: [
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
                    if (sel)
                      const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          Row(
            children: [
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
                  onPressed: widget.onConfirm,
                  child: Text(
                    'Pay \$${widget.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
      Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
    ],
  );
}

class _PayMethod {
  final String id;
  final String label;
  final IconData icon;
  const _PayMethod({required this.id, required this.label, required this.icon});
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: Color(0xFF888EA8), letterSpacing: 1.2),
  );
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF4CAF50).withValues(alpha: 0.1) : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Icon(icon, size: 16,
            color: enabled ? const Color(0xFF4CAF50) : const Color(0xFFCCCCCC)),
      ),
    );
  }
}
