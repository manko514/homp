import 'package:flutter/material.dart';
import '../services/staff_api_service.dart';
import 'login_screen.dart';
import 'clock_screen.dart';
import 'waiter_screen.dart';
import 'housekeeper_screen.dart';
import 'bartender_screen.dart';

class ShellScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ShellScreen({super.key, required this.user});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  String get role => (widget.user['role'] as String? ?? '').toUpperCase();
  String get name => widget.user['name'] as String? ?? widget.user['email'] as String? ?? 'Staff';

  List<_NavItem> get _navItems {
    final items = <_NavItem>[
      _NavItem(
        label: 'Clock In/Out',
        icon: Icons.access_time,
        screen: const ClockScreen(),
      ),
    ];

    if (role == 'WAITER' || role == 'MANAGER' || role == 'ADMIN') {
      items.add(_NavItem(
        label: 'Orders',
        icon: Icons.receipt_long,
        screen: const WaiterScreen(),
      ));
    }

    if (role == 'HOUSEKEEPER' || role == 'MANAGER' || role == 'ADMIN') {
      items.add(_NavItem(
        label: 'Rooms',
        icon: Icons.bed,
        screen: const HousekeeperScreen(),
      ));
    }

    if (role == 'BARTENDER' || role == 'MANAGER' || role == 'ADMIN') {
      items.add(_NavItem(
        label: 'Bar',
        icon: Icons.local_bar,
        screen: const BartenderScreen(),
      ));
    }

    return items;
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StaffApiService.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Color get _roleColor {
    switch (role) {
      case 'WAITER': return Colors.blue;
      case 'BARTENDER': return Colors.amber.shade800;
      case 'HOUSEKEEPER': return Colors.green;
      case 'MANAGER': return Colors.purple;
      case 'ADMIN': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _navItems;
    if (_currentIndex >= items.length) _currentIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _roleColor,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(role, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: items[_currentIndex].screen,
      bottomNavigationBar: items.length > 1
          ? NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: items.map((item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              )).toList(),
            )
          : null,
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  const _NavItem({required this.label, required this.icon, required this.screen});
}
