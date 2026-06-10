import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/utils.dart';
import '../widgets/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _daily;
  List<dynamic>? _weekly;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final res = await Future.wait([
        ApiService.get('/reports/daily-revenue?date=$dateStr'),
        ApiService.get('/reports/weekly-revenue?days=7'),
      ]);
      setState(() {
        _daily = res[0];
        _weekly = res[1];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.navy),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date picker row
            Row(
              children: [
                const Text('Daily Report',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),
                const Spacer(),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: AppTheme.textMid),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMM d, yyyy').format(_selectedDate),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ))
            else ...[
              // Daily revenue breakdown
              _sectionCard(
                title: 'Revenue Breakdown',
                child: Column(
                  children: [
                    ...[
                      ('Hotel', toDouble(_daily?['hotel']?['revenue']), AppTheme.green, Icons.hotel),
                      ('Restaurant', toDouble(_daily?['restaurant']?['revenue']), AppTheme.yellow, Icons.restaurant),
                      ('Bar', toDouble(_daily?['bar']?['revenue']), AppTheme.blue, Icons.local_bar),
                    ].map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: d.$3.withValues(alpha:0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(d.$4, color: d.$3, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.$1,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textDark)),
                                    const SizedBox(height: 3),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: (_daily?['totalRevenue'] ?? 0) > 0
                                            ? (d.$2 / toDouble(_daily!['totalRevenue'])).clamp(0.0, 1.0)
                                            : 0.0,
                                        minHeight: 4,
                                        backgroundColor: Colors.grey.shade100,
                                        valueColor: AlwaysStoppedAnimation<Color>(d.$3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('\$${d.$2.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark)),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Revenue',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark)),
                        Text(
                          '\$${((_daily?['totalRevenue'] ?? 0) as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weekly summary
              _sectionCard(
                title: '7-Day Summary',
                child: Column(
                  children: (_weekly ?? []).asMap().entries.map((entry) {
                    final d = entry.value;
                    final date = DateTime.tryParse(d['date'] ?? '');
                    final total = toDouble(d['totalRevenue']);
                    final maxRevenue = (_weekly ?? [])
                        .map((w) => toDouble(w['totalRevenue']))
                        .fold(0.0, (a, b) => a > b ? a : b);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              date != null ? DateFormat('EEE M/d').format(date) : '—',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMid),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxRevenue > 0 ? (total / maxRevenue).clamp(0.0, 1.0) : 0,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.blue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 60,
                            child: Text('\$${total.toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
