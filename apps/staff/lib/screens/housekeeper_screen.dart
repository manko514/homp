import 'package:flutter/material.dart';
import '../services/staff_api_service.dart';

class HousekeeperScreen extends StatefulWidget {
  const HousekeeperScreen({super.key});

  @override
  State<HousekeeperScreen> createState() => _HousekeeperScreenState();
}

class _HousekeeperScreenState extends State<HousekeeperScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _cleaningRooms = [];
  List<dynamic> _checkoutRooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadRooms();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await StaffApiService.getHousekeeperRooms();
      setState(() {
        _cleaningRooms = data['cleaning'] as List? ?? [];
        _checkoutRooms = data['checkouts'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _markCleaning(String roomId) async {
    try {
      await StaffApiService.markRoomCleaning(roomId);
      await _loadRooms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room marked as CLEANING'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markClean(String roomId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Room Clean'),
        content: const Text('Confirm room is fully cleaned and ready for guests?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await StaffApiService.markRoomClean(roomId);
      await _loadRooms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Room marked AVAILABLE'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CLEANING': return Colors.orange;
      case 'MAINTENANCE': return Colors.red;
      case 'AVAILABLE': return Colors.green;
      case 'OCCUPIED': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'CLEANING': return Icons.cleaning_services;
      case 'MAINTENANCE': return Icons.build;
      case 'AVAILABLE': return Icons.check_circle;
      case 'OCCUPIED': return Icons.hotel;
      default: return Icons.bed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _cleaningRooms.length + _checkoutRooms.length;

    return Scaffold(
      body: Column(
        children: [
          // Summary bar
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.cleaning_services, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$total room${total != 1 ? 's' : ''} need attention',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadRooms,
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                  label: const Text('Refresh', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabCtrl,
            tabs: [
              Tab(text: 'Cleaning (${_cleaningRooms.length})'),
              Tab(text: 'Checkouts (${_checkoutRooms.length})'),
            ],
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(onPressed: _loadRooms, child: const Text('Retry')),
                        ],
                      ))
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildRoomList(_cleaningRooms, isCheckout: false),
                          _buildRoomList(_checkoutRooms, isCheckout: true),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(List<dynamic> rooms, {required bool isCheckout}) {
    if (rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 12),
            Text('All clear!', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rooms.length,
      itemBuilder: (ctx, i) => _buildRoomCard(rooms[i], isCheckout: isCheckout),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, {required bool isCheckout}) {
    final roomId = room['id'] as String;
    final roomNumber = room['roomNumber'] as String? ?? 'N/A';
    final type = room['type'] as String? ?? 'STANDARD';
    final floor = room['floor'] as int? ?? 0;
    final status = room['status'] as String? ?? 'CLEANING';
    final isCleaning = status == 'CLEANING';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_statusIcon(status), color: _statusColor(status), size: 26),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room $roomNumber',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    Text(
                      'Floor $floor  •  ${type.replaceAll('_', ' ')}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(status).withOpacity(0.5)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (isCheckout) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.exit_to_app, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text('Guest checked out today', style: TextStyle(color: Colors.amber, fontSize: 12)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isCleaning) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cleaning_services, size: 16),
                      label: const Text('Start Cleaning'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                      onPressed: () => _markCleaning(roomId),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark Clean'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _markClean(roomId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
