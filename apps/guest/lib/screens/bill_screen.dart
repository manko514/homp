import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/booking_service.dart';
import '../services/auth_service.dart';

class BillScreen extends StatefulWidget {
  final String reservationId;
  final bool checkingOut;

  const BillScreen({super.key, required this.reservationId, this.checkingOut = false});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  Map<String, dynamic>? _bill;
  bool _loading = true;
  bool _checkingOut = false;
  bool _checkedOut = false;
  bool _payingWallet = false;
  double _walletBalance = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    try {
      final results = await Future.wait([
        BookingService.getBill(widget.reservationId),
        AuthService.getWallet().catchError((_) => <String, dynamic>{'balance': 0}),
      ]);
      setState(() {
        _bill = results[0];
        _walletBalance = ((results[1])['balance'] as num? ?? 0).toDouble();
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payWithWallet(double grandTotal) async {
    final tenantId = (_bill?['reservation'] as Map<String, dynamic>?)?['tenantId'] as String?;
    if (tenantId == null) return;

    final deductable = grandTotal > _walletBalance ? _walletBalance : grandTotal;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pay with Wallet'),
        content: Text(
          grandTotal <= _walletBalance
            ? 'Pay \$${grandTotal.toStringAsFixed(2)} from your wallet?\n\nNew balance: \$${(_walletBalance - grandTotal).toStringAsFixed(2)}'
            : 'Your wallet has \$${_walletBalance.toStringAsFixed(2)}.\nThis will cover \$${deductable.toStringAsFixed(2)} of the \$${grandTotal.toStringAsFixed(2)} total.\n\nPay the remaining \$${(grandTotal - deductable).toStringAsFixed(2)} at reception.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _payingWallet = true);
    try {
      final result = await AuthService.debitWallet(
        tenantId: tenantId, amount: deductable,
        note: 'Bill payment — reservation ${widget.reservationId.substring(0, 8)}',
      );
      if (!mounted) return;
      setState(() => _walletBalance = (result['balance'] as num).toDouble());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('\$${deductable.toStringAsFixed(2)} deducted from wallet ✓'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _payingWallet = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_bill == null) return;
    final bill = _bill!;
    final res  = bill['reservation'] as Map<String, dynamic>;
    final room = res['room'] as Map<String, dynamic>?;
    final items = (bill['lineItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final grand = double.tryParse(bill['grandTotal'].toString()) ?? 0;

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('HOMP', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.Text('Guest Receipt', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${room?['type'] ?? 'Room'} — #${room?['roomNumber'] ?? ''}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text('Check-in: ${res['checkIn']?.substring(0, 10) ?? ''}   Check-out: ${res['checkOut']?.substring(0, 10) ?? ''}',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              pw.Text('${bill['nights']} night(s)',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ]),
          ),
          pw.SizedBox(height: 20),
          pw.Text('ITEMISED BILL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5, color: PdfColors.grey600)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey300)),
            children: [
              ...items.map((item) => pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Text(item['description'] as String? ?? '', style: const pw.TextStyle(fontSize: 12))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Text('\$${double.tryParse(item['total'].toString())?.toStringAsFixed(2) ?? ""}',
                        style: const pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.right)),
              ])),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey400),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Accommodation', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Text('\$${double.tryParse(bill['accommodationTotal'].toString())?.toStringAsFixed(2) ?? ""}',
                style: const pw.TextStyle(fontSize: 12)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Room Service', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Text('\$${double.tryParse(bill['roomServiceTotal'].toString())?.toStringAsFixed(2) ?? ""}',
                style: const pw.TextStyle(fontSize: 12)),
          ]),
          pw.Divider(color: PdfColors.grey400),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text('\$${grand.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
          ]),
          pw.SizedBox(height: 40),
          pw.Center(child: pw.Text('Thank you for staying with us!',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))),
          pw.Center(child: pw.Text('Ref: ${widget.reservationId.substring(0, 8).toUpperCase()}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500))),
        ],
      ),
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _doCheckOut() async {
    setState(() { _checkingOut = true; _error = null; });
    try {
      await BookingService.checkOut(widget.reservationId);
      setState(() => _checkedOut = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return DateFormat('MMM d, yyyy').format(d.toLocal());
  }

  Widget _billView() {
    final bill = _bill!;
    final res  = bill['reservation'] as Map<String, dynamic>;
    final room = res['room'] as Map<String, dynamic>?;
    final items = (bill['lineItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final grand = double.tryParse(bill['grandTotal'].toString()) ?? 0;
    final accom = double.tryParse(bill['accommodationTotal'].toString()) ?? 0;
    final rsvcs = double.tryParse(bill['roomServiceTotal'].toString()) ?? 0;
    final nights = bill['nights'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),

          // Header card
          _card(children: [
            Row(children: [
              const Icon(Icons.receipt_long, color: Color(0xFF1E2A3A), size: 20),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  room != null ? '${room['type']} — Room ${room['roomNumber']}' : 'Room Booking',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A)),
                ),
                Text('$nights night${nights != 1 ? "s" : ""}  •  ${_fmt(res['checkIn'] as String?)} → ${_fmt(res['checkOut'] as String?)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
              ]),
            ]),
          ]),
          const SizedBox(height: 14),

          // Line items
          _card(children: [
            const Text('ITEMISED BILL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.2)),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item['description'] as String? ?? '—',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A))),
                  ),
                  const SizedBox(width: 12),
                  Text('\$${double.tryParse(item['total'].toString())?.toStringAsFixed(2) ?? "—"}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                ],
              ),
            )),
            const Divider(height: 16),
            _amtRow('Accommodation', accom),
            const SizedBox(height: 4),
            _amtRow('Room Service', rsvcs),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                Text('\$${grand.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
              ],
            ),
          ]),
          const SizedBox(height: 14),

          // Wallet payment
          if (_walletBalance > 0)
            _card(children: [
              const Text('PAY WITH WALLET CREDIT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet, size: 14, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    Text('Balance: \$${_walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                  ]),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _payingWallet ? null : () => _payWithWallet(grand),
                  child: _payingWallet
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Pay Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          const SizedBox(height: 12),

          // Payment methods
          _card(children: [
            const Text('PAYMENT AT RECEPTION',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _payMethod(Icons.phone_android, 'Mobile Money', 'MTN, Airtel, M-Pesa'),
            const SizedBox(height: 8),
            _payMethod(Icons.credit_card, 'Card', 'Visa, Mastercard, Amex'),
            const SizedBox(height: 8),
            _payMethod(Icons.money, 'Cash', 'USD, EUR, local currency'),
          ]),
          const SizedBox(height: 12),

          // Download PDF receipt
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E2A3A),
                side: const BorderSide(color: Color(0xFF1E2A3A)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _downloadPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Download PDF Receipt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _checkoutSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Checked Out!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
            const SizedBox(height: 10),
            const Text('Thank you for staying with us.\nWe hope to see you again soon!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF888EA8), height: 1.5)),
            const SizedBox(height: 32),
            if (_bill != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Charged', style: TextStyle(fontSize: 14, color: Color(0xFF1E2A3A))),
                    Text(
                      '\$${double.tryParse(_bill!['grandTotal'].toString())?.toStringAsFixed(2) ?? "—"}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2A3A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Bookings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEEF0F3)),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _amtRow(String label, double amount) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
      Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A))),
    ],
  );

  Widget _payMethod(IconData icon, String name, String detail) => Row(
    children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2A3A).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF1E2A3A), size: 18),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
        Text(detail, style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
      ]),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        title: Text(
          widget.checkingOut ? 'Check-Out & Bill' : 'Your Bill',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _bill == null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadBill, child: const Text('Retry')),
                ]))
              : _checkedOut
                  ? _checkoutSuccessView()
                  : _billView(),
      bottomNavigationBar: widget.checkingOut && !_loading && _bill != null && !_checkedOut
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _checkingOut ? null : _doCheckOut,
                  icon: _checkingOut
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.logout),
                  label: Text(
                    'Confirm Check-Out  •  \$${double.tryParse(_bill!['grandTotal'].toString())?.toStringAsFixed(2) ?? "—"}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
