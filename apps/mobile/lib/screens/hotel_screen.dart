import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/utils.dart';
import '../widgets/app_theme.dart';

class HotelScreen extends StatefulWidget {
  const HotelScreen({super.key});
  @override
  State<HotelScreen> createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic>? _rooms;
  List<dynamic>? _reservations;
  bool _loading = true;

  static const _statusColor = {
    'AVAILABLE': AppTheme.green,
    'OCCUPIED': AppTheme.blue,
    'MAINTENANCE': AppTheme.red,
    'CLEANING': AppTheme.yellow,
  };

  static const _resColor = {
    'CONFIRMED': AppTheme.green,
    'CHECKED_IN': AppTheme.blue,
    'PENDING': AppTheme.yellow,
    'CHECKED_OUT': AppTheme.textLight,
    'CANCELLED': AppTheme.red,
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        ApiService.get('/hotel/rooms'),
        ApiService.get('/hotel/reservations'),
      ]);
      setState(() {
        _rooms = res[0];
        _reservations = res[1];
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
            tabs: const [
              Tab(text: 'Rooms'),
              Tab(text: 'Reservations'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [_roomsTab(), _reservationsTab()],
                ),
        ),
      ],
    );
  }

  Widget _roomsTab() {
    if (_rooms == null || _rooms!.isEmpty) {
      return const Center(child: Text('No rooms found'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.3,
        ),
        itemCount: _rooms!.length,
        itemBuilder: (_, i) {
          final room = _rooms![i];
          final status = room['status'] ?? 'AVAILABLE';
          final color = _statusColor[status] ?? AppTheme.textLight;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.hotel, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text('Room ${room['roomNumber']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textDark)),
                const SizedBox(height: 4),
                Text(room['type'] ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textLight)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _reservationsTab() {
    if (_reservations == null || _reservations!.isEmpty) {
      return const Center(child: Text('No reservations'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _reservations!.length,
        separatorBuilder: (context, idx) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = _reservations![i];
          final status = r['status'] ?? '';
          final color = _resColor[status] ?? AppTheme.textLight;
          final checkIn = DateTime.tryParse(r['checkIn'] ?? '');
          final checkOut = DateTime.tryParse(r['checkOut'] ?? '');
          final amount = toDouble(r['totalAmount']);
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
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['guest']?['name'] ?? 'Guest',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textDark)),
                      const SizedBox(height: 3),
                      Text(
                        'Room ${r['room']?['roomNumber'] ?? '—'}  •  ${checkIn != null ? DateFormat('MMM d').format(checkIn) : '—'} → ${checkOut != null ? DateFormat('MMM d').format(checkOut) : '—'}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha:0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                    const SizedBox(height: 4),
                    Text('\$${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}
