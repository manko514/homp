import 'package:flutter/material.dart';
import '../widgets/app_theme.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'hotel_screen.dart';
import 'restaurant_screen.dart';
import 'bar_screen.dart';
import 'more_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    HotelScreen(),
    RestaurantScreen(),
    BarScreen(),
    MoreScreen(),
  ];

  final _titles = const ['Dashboard', 'Hotel', 'Restaurant', 'Bar', 'More'];

  void _logout() async {
    await ApiService.clearToken();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEF0F3)),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppTheme.textMid),
                onPressed: () {},
              ),
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      color: AppTheme.red, shape: BoxShape.circle),
                  child: const Center(
                    child: Text('3',
                        style: TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
              ),
            ],
          ),
          PopupMenuButton(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.blue,
                child: const Text('A',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: AppTheme.textMid),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
            onSelected: (v) { if (v == 'logout') _logout(); },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEF0F3))),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.navy,
          unselectedItemColor: AppTheme.textLight,
          selectedLabelStyle:
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.hotel), label: 'Hotel'),
            BottomNavigationBarItem(
                icon: Icon(Icons.restaurant), label: 'Restaurant'),
            BottomNavigationBarItem(
                icon: Icon(Icons.local_bar), label: 'Bar'),
            BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }
}
