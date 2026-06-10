import 'package:flutter/material.dart';
import '../widgets/app_theme.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  int? _open; // which sub-screen is expanded (null = menu)

  @override
  Widget build(BuildContext context) {
    if (_open == 0) {
      return Column(
        children: [
          _backBar('Inventory'),
          const Expanded(child: InventoryScreen()),
        ],
      );
    }
    if (_open == 1) {
      return Column(
        children: [
          _backBar('Reports'),
          const Expanded(child: ReportsScreen()),
        ],
      );
    }

    // Menu list
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        const Text('MODULES',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textLight,
                letterSpacing: 1)),
        const SizedBox(height: 10),
        _tile('Inventory', 'Stock levels & low stock alerts',
            Icons.inventory_2_outlined, AppTheme.purple, () => setState(() => _open = 0)),
        const SizedBox(height: 8),
        _tile('Reports', 'Daily & weekly revenue reports',
            Icons.bar_chart_rounded, AppTheme.blue, () => setState(() => _open = 1)),
        const SizedBox(height: 24),
        const Text('ACCOUNT',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textLight,
                letterSpacing: 1)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEF0F3)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.blue,
              child: const Text('A',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
            title: const Text('Admin',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            subtitle: const Text('admin@homp.demo',
                style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textLight),
          ),
        ),
      ],
    );
  }

  Widget _backBar(String title) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.navy),
              onPressed: () => setState(() => _open = null),
            ),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.textDark)),
          ],
        ),
      );

  Widget _tile(String title, String sub, IconData icon, Color color,
      VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEF0F3)),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textDark)),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textLight),
            ],
          ),
        ),
      );
}
