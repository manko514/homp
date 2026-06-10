import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/utils.dart';
import '../widgets/app_theme.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _revenue;
  List<dynamic>? _weekly;
  List<dynamic>? _rooms;
  List<dynamic>? _alerts;
  List<dynamic>? _reservations;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final results = await Future.wait([
        ApiService.get('/reports/daily-revenue?date=$today'),
        ApiService.get('/reports/weekly-revenue?days=7'),
        ApiService.get('/hotel/rooms'),
        ApiService.get('/inventory/stock/alerts'),
        ApiService.get('/hotel/reservations'),
      ]);
      setState(() {
        _revenue = results[0];
        _weekly = results[1];
        _rooms = results[2];
        _alerts = results[3];
        _reservations = results[4];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final occupied = _rooms?.where((r) => r['status'] == 'OCCUPIED').length ?? 0;
    final total = _rooms?.length ?? 0;
    final occupancy = total > 0 ? (occupied / total * 100).round() : 0;
    final totalRevenue = toDouble(_revenue?['totalRevenue']);
    final alertCount = _alerts?.length ?? 0;
    final barRevenue = toDouble(_revenue?['bar']?['revenue']);

    // Build chart spots
    final weeklyData = _weekly ?? [];
    final hotelSpots = <FlSpot>[];
    final restSpots = <FlSpot>[];
    final barSpots = <FlSpot>[];
    for (int i = 0; i < weeklyData.length; i++) {
      hotelSpots.add(FlSpot(i.toDouble(), toDouble(weeklyData[i]['hotel']?['revenue'])));
      restSpots.add(FlSpot(i.toDouble(), toDouble(weeklyData[i]['restaurant']?['revenue'])));
      barSpots.add(FlSpot(i.toDouble(), toDouble(weeklyData[i]['bar']?['revenue'])));
    }

    final activeRes = (_reservations ?? [])
        .where((r) => ['CONFIRMED', 'CHECKED_IN', 'PENDING'].contains(r['status']))
        .take(5)
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dashboard',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    Text(
                      DateFormat('EEEE, MMM d yyyy').format(DateTime.now()),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textLight),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.circle, color: AppTheme.green, size: 8),
                      SizedBox(width: 6),
                      Text('Live',
                          style: TextStyle(
                              color: AppTheme.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stat cards grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                StatCard(
                  label: 'OCCUPANCY',
                  value: '$occupancy%',
                  sub: '$occupied / $total rooms',
                  color: AppTheme.green,
                  icon: Icons.hotel,
                ),
                StatCard(
                  label: "TODAY'S REVENUE",
                  value: '\$${totalRevenue.toStringAsFixed(0)}',
                  sub: 'All departments',
                  color: AppTheme.blue,
                  icon: Icons.attach_money,
                ),
                StatCard(
                  label: 'LOW STOCK',
                  value: '$alertCount',
                  sub: 'Items need restock',
                  color: alertCount > 0 ? AppTheme.red : AppTheme.purple,
                  icon: Icons.warning_amber_rounded,
                ),
                StatCard(
                  label: 'BAR REVENUE',
                  value: '\$${barRevenue.toStringAsFixed(0)}',
                  sub: 'Bar sales today',
                  color: AppTheme.purple,
                  icon: Icons.local_bar,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Revenue chart
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
                  const Text('Revenue — Last 7 Days',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: hotelSpots.isEmpty
                        ? const Center(
                            child: Text('No data',
                                style: TextStyle(color: AppTheme.textLight)))
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                    color: Colors.grey.shade100, strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (v, _) => Text(
                                        '\$${v.toInt()}',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.textLight)),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) {
                                      final idx = v.toInt();
                                      if (idx < 0 || idx >= weeklyData.length) {
                                        return const SizedBox();
                                      }
                                      final date = DateTime.tryParse(
                                          weeklyData[idx]['date'] ?? '');
                                      if (date == null) return const SizedBox();
                                      return Text(
                                          DateFormat('M/d').format(date),
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: AppTheme.textLight));
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                _line(hotelSpots, AppTheme.green),
                                _line(restSpots, AppTheme.yellow),
                                _line(barSpots, AppTheme.blue),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend('Hotel', AppTheme.green),
                      const SizedBox(width: 16),
                      _legend('Restaurant', AppTheme.yellow),
                      const SizedBox(width: 16),
                      _legend('Bar', AppTheme.blue),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Today's breakdown
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
                  const Text("Today's Breakdown",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 16),
                  ...[
                    ('Hotel', toDouble(_revenue?['hotel']?['revenue']), AppTheme.green),
                    ('Restaurant', toDouble(_revenue?['restaurant']?['revenue']), AppTheme.yellow),
                    ('Bar', toDouble(_revenue?['bar']?['revenue']), AppTheme.blue),
                  ].map((item) {
                    final pct = totalRevenue > 0 ? item.$2 / totalRevenue : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.$1,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textDark)),
                              Text('\$${item.$2.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textMid)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade100,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(item.$3),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark)),
                      Text('\$${totalRevenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active reservations
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEEF0F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text('Active Reservations',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark)),
                  ),
                  const SizedBox(height: 8),
                  if (activeRes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No active reservations',
                          style: TextStyle(
                              color: AppTheme.textLight, fontSize: 12)),
                    )
                  else
                    ...activeRes.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      final colors = [
                        AppTheme.green, AppTheme.blue, AppTheme.purple,
                        AppTheme.red, const Color(0xFFFF9800), AppTheme.cyan
                      ];
                      final statusColors = {
                        'CONFIRMED': AppTheme.green,
                        'CHECKED_IN': AppTheme.green,
                        'PENDING': AppTheme.blue,
                        'CHECKED_OUT': AppTheme.textLight,
                        'CANCELLED': AppTheme.red,
                      };
                      final guestName = r['guest']?['name'] ?? 'Guest';
                      final initial = guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G';
                      final status = r['status'] ?? '';
                      final checkIn = DateTime.tryParse(r['checkIn'] ?? '');
                      return Column(
                        children: [
                          if (i > 0) const Divider(height: 1, indent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: colors[i % colors.length],
                                  child: Text(initial,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(guestName,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textDark)),
                                      Text(
                                        'Room ${r['room']?['roomNumber'] ?? '—'}  •  ${checkIn != null ? DateFormat('MMM d').format(checkIn) : '—'}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textLight),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (statusColors[status] ?? AppTheme.textLight)
                                        .withValues(alpha:0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(status,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: statusColors[status] ?? AppTheme.textLight)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: 80), // bottom nav padding
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha:0.08),
        ),
      );

  Widget _legend(String label, Color color) => Row(
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMid)),
        ],
      );
}
