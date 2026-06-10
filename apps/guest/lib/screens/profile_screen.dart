import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _loyalty;
  Map<String, dynamic>? _wallet;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _saved = false;

  // Edit fields
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _dietaryOptions = ['Vegetarian', 'Vegan', 'Halal', 'Gluten-Free', 'No Dairy', 'Nut Allergy'];
  final _roomOptions    = ['High Floor', 'Low Floor', 'Quiet Room', 'Sea View', 'Non-Smoking', 'King Bed', 'Twin Beds'];
  final _commOptions    = ['Email', 'SMS', 'WhatsApp', 'App Notifications'];

  List<String> _dietary = [];
  List<String> _roomPref = [];
  List<String> _commPrefs = [];

  // Notification toggles (stored in SharedPreferences)
  bool _notifBooking  = true;
  bool _notifCheckin  = true;
  bool _notifOrder    = true;
  bool _notifOffers   = false;

  // Payment methods (demo — no API backend)
  final List<Map<String, String>> _payMethods = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
    _loadNotifPrefs();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        AuthService.getProfile(),
        AuthService.getLoyalty(),
        AuthService.getWallet(),
      ]);
      final profile = results[0];
      final loyalty = results[1];
      final wallet  = results[2];
      final gp = profile['guestProfile'] as Map<String, dynamic>?;
      setState(() {
        _profile = profile;
        _loyalty = loyalty;
        _wallet  = wallet;
        _nameCtrl.text = profile['name'] as String? ?? '';
        _phoneCtrl.text = gp?['phone'] as String? ?? '';
        _dietary   = ((gp?['dietaryPreferences'] as List?)?.cast<String>()) ?? [];
        _roomPref  = ((gp?['roomPreferences'] as List?)?.cast<String>()) ?? [];
        _commPrefs = ((gp?['communicationPrefs'] as List?)?.cast<String>()) ?? [];
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saved = false; _error = null; });
    try {
      await AuthService.updateProfile({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'dietaryPreferences': _dietary,
        'roomPreferences': _roomPref,
        'communicationPrefs': _commPrefs,
      });
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return DateFormat('MMM d, yyyy').format(d.toLocal());
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifBooking = prefs.getBool('notif_booking') ?? true;
      _notifCheckin = prefs.getBool('notif_checkin') ?? true;
      _notifOrder   = prefs.getBool('notif_order')   ?? true;
      _notifOffers  = prefs.getBool('notif_offers')  ?? false;
    });
  }

  Future<void> _saveNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        foregroundColor: Colors.white,
        title: const Text('Profile & Loyalty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: _confirmLogout,
            tooltip: 'Sign Out',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF4CAF50),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'Profile'), Tab(text: 'Loyalty'), Tab(text: 'Settings')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _profile == null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : TabBarView(
                  controller: _tabs,
                  children: [_profileTab(), _loyaltyTab(), _settingsTab()],
                ),
    );
  }

  Widget _profileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar header
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFF1E2A3A),
                  child: Text(
                    (_profile?['name'] as String? ?? 'G').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_profile?['name'] as String? ?? '',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
                Text(_profile?['email'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
                const SizedBox(height: 16),
              ],
            ),
          ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),

          if (_saved)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Profile saved successfully', style: TextStyle(color: Colors.green, fontSize: 13)),
              ]),
            ),

          // Edit fields
          _card(children: [
            const _SectionLabel('PERSONAL INFO'),
            const SizedBox(height: 12),
            _lbl('Full Name'),
            _field(_nameCtrl, 'Your name'),
            const SizedBox(height: 14),
            _lbl('Phone Number'),
            _field(_phoneCtrl, '+1 555 000 0000', type: TextInputType.phone),
          ]),
          const SizedBox(height: 14),

          // Dietary preferences
          _card(children: [
            const _SectionLabel('DIETARY PREFERENCES'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _dietaryOptions.map((opt) {
                final sel = _dietary.contains(opt);
                return FilterChip(
                  label: Text(opt, style: TextStyle(fontSize: 12, color: sel ? Colors.white : const Color(0xFF1E2A3A))),
                  selected: sel,
                  onSelected: (v) => setState(() => v ? _dietary.add(opt) : _dietary.remove(opt)),
                  selectedColor: const Color(0xFF4CAF50),
                  backgroundColor: const Color(0xFFF5F6FA),
                  checkmarkColor: Colors.white,
                  side: BorderSide(color: sel ? const Color(0xFF4CAF50) : const Color(0xFFDDDDDD)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 14),

          // Room preferences
          _card(children: [
            const _SectionLabel('ROOM PREFERENCES'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _roomOptions.map((opt) {
                final sel = _roomPref.contains(opt);
                return FilterChip(
                  label: Text(opt, style: TextStyle(fontSize: 12, color: sel ? Colors.white : const Color(0xFF1E2A3A))),
                  selected: sel,
                  onSelected: (v) => setState(() => v ? _roomPref.add(opt) : _roomPref.remove(opt)),
                  selectedColor: const Color(0xFF2196F3),
                  backgroundColor: const Color(0xFFF5F6FA),
                  checkmarkColor: Colors.white,
                  side: BorderSide(color: sel ? const Color(0xFF2196F3) : const Color(0xFFDDDDDD)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 16),

          // Communication preferences
          _card(children: [
            const Text('COMMUNICATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.2)),
            const SizedBox(height: 4),
            const Text('How would you like us to reach you?',
                style: TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _commOptions.map((opt) {
                final sel = _commPrefs.contains(opt);
                return FilterChip(
                  label: Text(opt, style: TextStyle(fontSize: 12, color: sel ? Colors.white : const Color(0xFF1E2A3A))),
                  selected: sel,
                  onSelected: (v) => setState(() => v ? _commPrefs.add(opt) : _commPrefs.remove(opt)),
                  selectedColor: const Color(0xFF9C27B0),
                  backgroundColor: const Color(0xFFF5F6FA),
                  checkmarkColor: Colors.white,
                  side: BorderSide(color: sel ? const Color(0xFF9C27B0) : const Color(0xFFDDDDDD)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _loyaltyTab() {
    final balance = _loyalty?['balance'] as int? ?? 0;
    final txns = (_loyalty?['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Balance card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2A3A), Color(0xFF2C3E50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.stars, color: Color(0xFF4CAF50), size: 20),
                  SizedBox(width: 8),
                  Text('Loyalty Points', style: TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 0.5)),
                ]),
                const SizedBox(height: 12),
                Text(NumberFormat('#,###').format(balance),
                    style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('≈ \$${(balance / 1000).toStringAsFixed(2)} value  •  10 pts per \$1 spent',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Wallet balance card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      '\$${((_wallet?['balance'] as num?) ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('Use at checkout for any service', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _showTopUpSheet,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Top Up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Wallet transaction history
          if ((_wallet?['transactions'] as List?)?.isNotEmpty == true)
            _card(children: [
              const _SectionLabel('WALLET TRANSACTIONS'),
              const SizedBox(height: 12),
              ...((_wallet!['transactions'] as List).cast<Map<String, dynamic>>()).map((t) {
                final amt = (t['amount'] as num?) ?? 0;
                final type = t['type'] as String? ?? 'TOPUP';
                final positive = type == 'TOPUP';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: (positive ? const Color(0xFF4CAF50) : const Color(0xFFF44336)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        positive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: positive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['note'] as String? ?? type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                      Text(_fmtDate(t['createdAt'] as String?), style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
                    ])),
                    Text(
                      '${positive ? "+" : "-"}\$${amt.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: positive ? const Color(0xFF4CAF50) : const Color(0xFFF44336)),
                    ),
                  ]),
                );
              }),
            ]),

          if ((_wallet?['transactions'] as List?)?.isNotEmpty == true)
            const SizedBox(height: 14),

          // How to earn
          _card(children: [
            const _SectionLabel('HOW TO EARN POINTS'),
            const SizedBox(height: 12),
            _earnRow(Icons.hotel, 'Room Booking', '10 pts per \$1'),
            const SizedBox(height: 8),
            _earnRow(Icons.restaurant, 'Restaurant Order', '5 pts per \$1'),
            const SizedBox(height: 8),
            _earnRow(Icons.pool, 'Ticket Purchase', '5 pts per \$1'),
          ]),
          const SizedBox(height: 14),

          // Transaction history
          if (txns.isEmpty)
            _card(children: [
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No transactions yet', style: TextStyle(color: Color(0xFF888EA8), fontSize: 13)),
              )),
            ])
          else
            _card(children: [
              const _SectionLabel('TRANSACTION HISTORY'),
              const SizedBox(height: 12),
              ...txns.map((t) {
                final pts = t['points'] as int? ?? 0;
                final positive = pts > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: (positive ? const Color(0xFF4CAF50) : const Color(0xFFF44336)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          positive ? Icons.add : Icons.remove,
                          color: positive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['reason'] as String? ?? '—',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                            Text(_fmtDate(t['createdAt'] as String?),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
                          ],
                        ),
                      ),
                      Text(
                        '${positive ? "+" : ""}$pts pts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: positive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Settings Tab ─────────────────────────────────────────────────────────────

  Widget _settingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Notification Settings ─────────────────────────────────────
          _card(children: [
            const _SectionLabel('NOTIFICATION SETTINGS'),
            const SizedBox(height: 4),
            const Text('Choose what you would like to be notified about',
                style: TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
            const SizedBox(height: 16),
            _notifTile(
              icon: Icons.hotel,
              color: const Color(0xFF4CAF50),
              title: 'Booking Confirmations',
              subtitle: 'When a room booking is confirmed',
              value: _notifBooking,
              onChanged: (v) {
                setState(() => _notifBooking = v);
                _saveNotifPref('notif_booking', v);
              },
            ),
            _notifTile(
              icon: Icons.key,
              color: const Color(0xFF2196F3),
              title: 'Check-in Reminders',
              subtitle: 'Reminder on your check-in day',
              value: _notifCheckin,
              onChanged: (v) {
                setState(() => _notifCheckin = v);
                _saveNotifPref('notif_checkin', v);
              },
            ),
            _notifTile(
              icon: Icons.restaurant,
              color: const Color(0xFF9C27B0),
              title: 'Order Ready Alerts',
              subtitle: 'When your food or drink order is ready',
              value: _notifOrder,
              onChanged: (v) {
                setState(() => _notifOrder = v);
                _saveNotifPref('notif_order', v);
              },
            ),
            _notifTile(
              icon: Icons.local_offer,
              color: const Color(0xFFFF9800),
              title: 'Offers & Promotions',
              subtitle: 'Special deals and hotel offers',
              value: _notifOffers,
              onChanged: (v) {
                setState(() => _notifOffers = v);
                _saveNotifPref('notif_offers', v);
              },
              isLast: true,
            ),
          ]),
          const SizedBox(height: 16),

          // ── Payment Methods ───────────────────────────────────────────
          _card(children: [
            Row(children: [
              const Expanded(child: _SectionLabel('PAYMENT METHODS')),
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero),
                onPressed: _showAddCardSheet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (_payMethods.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                alignment: Alignment.center,
                child: Column(children: [
                  const Icon(Icons.credit_card, size: 36, color: Color(0xFFCCCCCC)),
                  const SizedBox(height: 8),
                  const Text('No payment methods saved',
                      style: TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showAddCardSheet,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Payment Method'),
                  ),
                ]),
              )
            else
              ..._payMethods.asMap().entries.map((e) {
                final m = e.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2A3A).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      m['type'] == 'Card' ? Icons.credit_card : Icons.phone_android,
                      size: 20, color: const Color(0xFF1E2A3A),
                    ),
                  ),
                  title: Text(m['label'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(m['detail'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF888EA8))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    onPressed: () => setState(() => _payMethods.removeAt(e.key)),
                  ),
                );
              }),
          ]),
          const SizedBox(height: 16),

          // ── Support ───────────────────────────────────────────────────
          _card(children: [
            const _SectionLabel('SUPPORT'),
            const SizedBox(height: 12),
            _supportTile(
              icon: Icons.headset_mic,
              color: const Color(0xFF4CAF50),
              title: 'Contact Front Desk',
              subtitle: 'Call or message the hotel directly',
              onTap: () => _showSupportDialog(
                'Contact Front Desk',
                'Our front desk team is available 24/7.\n\n📞 +1 (555) 000-0001\n💬 WhatsApp: +1 (555) 000-0002',
              ),
            ),
            _supportTile(
              icon: Icons.help_outline,
              color: const Color(0xFF2196F3),
              title: 'FAQ',
              subtitle: 'Frequently asked questions',
              onTap: () => _showFaqSheet(),
            ),
            _supportTile(
              icon: Icons.bug_report_outlined,
              color: const Color(0xFFFF9800),
              title: 'Report an Issue',
              subtitle: 'Something not working? Let us know',
              onTap: () => _showSupportDialog(
                'Report an Issue',
                'To report an issue, email us at:\n\nsupport@homp.app\n\nPlease describe the problem and include your booking reference if applicable.',
              ),
              isLast: true,
            ),
          ]),
          const SizedBox(height: 24),

          // App version
          Center(
            child: Text(
              'HOMP Guest App  •  v1.0.0',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _notifTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF4CAF50),
              activeTrackColor: const Color(0xFF4CAF50).withValues(alpha: 0.4),
            ),
          ],
        ),
        if (!isLast) const Divider(height: 20),
      ],
    );
  }

  Widget _supportTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                      Text(subtitle,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF888EA8))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF888EA8), size: 18),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 20),
      ],
    );
  }

  void _showAddCardSheet() {
    String type = 'Card';
    final ctrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Payment Method',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
              const SizedBox(height: 16),
              // Type selector
              Wrap(spacing: 8, children: ['Card', 'MTN', 'Airtel', 'M-Pesa'].map((t) {
                final sel = type == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: sel,
                  onSelected: (v) => setS(() => type = t),
                  selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: sel ? const Color(0xFF4CAF50) : const Color(0xFF1E2A3A),
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(color: sel ? const Color(0xFF4CAF50) : const Color(0xFFDDDDDD)),
                );
              }).toList()),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: type == 'Card' ? 'Card number (last 4 digits)' : 'Phone number',
                  prefixIcon: Icon(type == 'Card' ? Icons.credit_card : Icons.phone_android),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final detail = ctrl.text.trim();
                    if (detail.isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() => _payMethods.add({
                      'type': type,
                      'label': type == 'Card' ? 'Card ending ••••$detail' : '$type — $detail',
                      'detail': type == 'Card' ? 'Credit / Debit Card' : 'Mobile Money',
                    }));
                  },
                  child: const Text('Add', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title),
        content: Text(message, style: const TextStyle(height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFaqSheet() {
    const faqs = [
      _Faq('How do I check in?', 'Go to Bookings, tap your reservation, then tap "Check In" on your check-in date.'),
      _Faq('How do I earn loyalty points?', 'You earn points automatically on every booking, restaurant order, and ticket purchase.'),
      _Faq('Can I order room service?', 'Yes — go to Home → Room Service to browse the menu and order to your room.'),
      _Faq('How do I write my room key to an NFC card?', 'After checking in, tap "Write NFC Room Key" and hold a blank NFC card to the back of your phone.'),
      _Faq('How do I top up my wallet?', 'Go to Profile → Loyalty tab and tap "Top Up". We accept MTN, Airtel, M-Pesa, and card.'),
      _Faq('Who do I contact for help?', 'Tap "Contact Front Desk" above or visit the hotel reception desk.'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text('Frequently Asked Questions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
            const SizedBox(height: 16),
            ...faqs.map((f) => _FaqTile(faq: f)),
          ],
        ),
      ),
    );
  }

  // ─── Wallet top-up sheet ──────────────────────────────────────────────────────

  void _showTopUpSheet() {
    final tenantId = _profile?['tenantId'] as String?;
    if (tenantId == null) return;

    final amountCtrl = TextEditingController(text: '50');
    String selectedMethod = 'MTN';
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                child: Text('Top-Up Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 4),
            const Text('Add credit to your HOMP wallet for instant checkout.',
                style: TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
            const SizedBox(height: 20),

            // Amount
            const Text('Amount (USD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888EA8))),
            const SizedBox(height: 6),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                ),
              ),
            ),

            // Quick amounts
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [10, 25, 50, 100].map((v) => OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E2A3A),
                side: const BorderSide(color: Color(0xFFDDE1EA)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
              ),
              onPressed: () => amountCtrl.text = '$v',
              child: Text('\$$v', style: const TextStyle(fontSize: 13)),
            )).toList()),

            const SizedBox(height: 20),

            // Payment method
            const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888EA8))),
            const SizedBox(height: 8),
            ...['MTN', 'Airtel', 'M-Pesa', 'Card'].map((method) {
              final iconData = method == 'Card' ? Icons.credit_card : Icons.phone_android;
              final selected = selectedMethod == method;
              return GestureDetector(
                onTap: () => setS(() => selectedMethod = method),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? const Color(0xFF4CAF50) : const Color(0xFFCCCCCC),
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Center(child: Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                            ))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Icon(iconData, size: 18, color: const Color(0xFF888EA8)),
                    const SizedBox(width: 8),
                    Text(method, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E2A3A))),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: loading ? null : () async {
                  final amt = double.tryParse(amountCtrl.text.trim());
                  if (amt == null || amt <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount'), behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  setS(() => loading = true);
                  try {
                    final result = await AuthService.topUpWallet(
                      tenantId: tenantId,
                      amount: amt,
                      method: selectedMethod,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    final newBalance = result['balance'] as num? ?? 0;
                    if (!mounted) return;
                    setState(() {
                      _wallet = {
                        ..._wallet ?? {},
                        'balance': newBalance,
                        'transactions': [result['transaction'], ...(_wallet?['transactions'] as List? ?? [])],
                      };
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('\$$amt topped up via $selectedMethod ✓  New balance: \$${newBalance.toStringAsFixed(2)}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    );
                  } catch (e) {
                    setS(() => loading = false);
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
                          behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
                    );
                  }
                },
                child: loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Top Up Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ]),
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

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
  );

  Widget _field(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text}) => TextField(
    controller: ctrl,
    keyboardType: type,
    decoration: InputDecoration(
      hintText: hint,
      filled: true, fillColor: const Color(0xFFF5F6FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEEF0F3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEEF0F3))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  Widget _earnRow(IconData icon, String label, String pts) => Row(children: [
    Icon(icon, size: 16, color: const Color(0xFF4CAF50)),
    const SizedBox(width: 10),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF1E2A3A)))),
    Text(pts, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
  ]);

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.logout().then((_) => widget.onLogout());
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888EA8), letterSpacing: 1.2),
  );
}

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(widget.faq.q,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E2A3A))),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF888EA8), size: 20),
              ]),
              if (_open) ...[
                const SizedBox(height: 8),
                Text(widget.faq.a,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF888EA8), height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
