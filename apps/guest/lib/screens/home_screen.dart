import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/guest_api_service.dart';
import '../services/booking_service.dart';
import 'scan_screen.dart';
import 'menu_screen.dart';
import 'gate_screen.dart';
import 'rooms_screen.dart';
import 'my_tickets_screen.dart';
import 'bar_tab_screen.dart';
import 'bookings_screen.dart';
import 'checkin_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(String tenantId, String hotelName)? onHotelResolved;
  final VoidCallback? onLoginRequested;
  final bool isLoggedIn;
  final Map<String, dynamic>? currentUser;

  const HomeScreen({
    super.key,
    this.onHotelResolved,
    this.onLoginRequested,
    this.isLoggedIn = false,
    this.currentUser,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _subdomainCtrl = TextEditingController();
  final _tableCtrl     = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _tenantId;
  String? _hotelName;
  String? _logoUrl;

  // Active reservation
  Map<String, dynamic>? _activeBooking;
  bool _bookingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTenant();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    // Refresh booking card when user logs in
    if (!old.isLoggedIn && widget.isLoggedIn) {
      _loadActiveBooking();
    }
    if (old.isLoggedIn && !widget.isLoggedIn) {
      setState(() => _activeBooking = null);
    }
  }

  @override
  void dispose() {
    _subdomainCtrl.dispose();
    _tableCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTenant() async {
    final prefs = await SharedPreferences.getInstance();
    final saved   = prefs.getString('guest_tenant_id');
    final name    = prefs.getString('guest_hotel_name');
    final logoUrl = prefs.getString('guest_logo_url');
    if (saved != null && name != null) {
      setState(() { _tenantId = saved; _hotelName = name; _logoUrl = logoUrl; });
      if (widget.isLoggedIn) _loadActiveBooking();
    }
  }

  Future<void> _loadActiveBooking() async {
    if (!widget.isLoggedIn) return;
    setState(() => _bookingLoading = true);
    try {
      final bookings = await BookingService.getMyBookings();
      // Most recent CONFIRMED or CHECKED_IN
      final active = bookings.firstWhere(
        (b) => b['status'] == 'CONFIRMED' || b['status'] == 'CHECKED_IN',
        orElse: () => null,
      );
      if (mounted) setState(() { _activeBooking = active; _bookingLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _bookingLoading = false; });
    }
  }

  Future<void> _lookupHotel() async {
    final sub = _subdomainCtrl.text.trim().toLowerCase();
    if (sub.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final tenant  = await GuestApiService.lookupTenant(sub);
      final id      = tenant['id'] as String;
      final name    = tenant['name'] as String;
      final logoUrl = tenant['logoUrl'] as String?;
      final prefs   = await SharedPreferences.getInstance();
      await prefs.setString('guest_tenant_id', id);
      await prefs.setString('guest_hotel_name', name);
      if (logoUrl != null) await prefs.setString('guest_logo_url', logoUrl);
      setState(() { _tenantId = id; _hotelName = name; _logoUrl = logoUrl; _loading = false; });
      widget.onHotelResolved?.call(id, name);
      if (widget.isLoggedIn) _loadActiveBooking();
    } catch (e) {
      setState(() { _error = 'Hotel not found. Check the name and try again.'; _loading = false; });
    }
  }

  Future<void> _goWithTable() async {
    if (_tenantId == null) return;
    final tableNum = int.tryParse(_tableCtrl.text.trim());
    if (tableNum == null) { setState(() => _error = 'Enter a valid table number'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final table = await GuestApiService.getTable(_tenantId!, tableNum);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MenuScreen(
          tenantId: _tenantId!,
          tableId: table['id'] as String,
          tableNumber: table['tableNumber'] as int,
        ),
      ));
    } catch (e) {
      setState(() => _error = 'Table $tableNum not found');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeHotel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_tenant_id');
    await prefs.remove('guest_hotel_name');
    await prefs.remove('guest_logo_url');
    setState(() {
      _tenantId = null; _hotelName = null; _logoUrl = null;
      _activeBooking = null;
      _subdomainCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2A3A),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top header ─────────────────────────────────────────────────
              _buildHeader(),

              // ── Hero / property banner ──────────────────────────────────────
              if (_tenantId != null) _buildHero(),

              // ── Active reservation card ─────────────────────────────────────
              if (_tenantId != null && widget.isLoggedIn)
                _buildActiveReservation(),

              // ── Offers banner ───────────────────────────────────────────────
              if (_tenantId != null) _buildOffersBanner(),

              // ── Main content card ───────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: _tenantId == null ? _hotelLookup() : _orderOptions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HOMP',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5)),
                const Text('Guest Experience',
                    style: TextStyle(
                        color: Color(0xFF4CAF50), fontSize: 11, letterSpacing: 1.5)),
              ],
            ),
          ),
          // Auth pill
          if (!widget.isLoggedIn)
            GestureDetector(
              onTap: widget.onLoginRequested,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.person_outline, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('Sign In',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            )
          else
            GestureDetector(
              onTap: widget.onLoginRequested,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Icon(Icons.person, color: Color(0xFF4CAF50), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    (widget.currentUser?['name'] as String? ?? 'Guest')
                        .split(' ')
                        .first,
                    style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Hero / Property banner ───────────────────────────────────────────────

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: network image or gradient fallback
          if (_logoUrl != null && _logoUrl!.isNotEmpty)
            Image.network(
              _logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => _heroGradient(),
            )
          else
            _heroGradient(),

          // Dark scrim so text is always readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),

          // Hotel name + change button
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.hotel, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _hotelName ?? 'Hotel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _changeHotel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: const Text('Change',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('✓ Connected',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D3B63), Color(0xFF1E2A3A)],
        ),
      ),
      child: Stack(
        children: [
          // Subtle pattern
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 30,
            top: 30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          const Center(
            child: Icon(Icons.apartment,
                size: 72, color: Colors.white12),
          ),
        ],
      ),
    );
  }

  // ─── Active Reservation Card ──────────────────────────────────────────────

  Widget _buildActiveReservation() {
    if (_bookingLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white38)),
            SizedBox(width: 12),
            Text('Loading your reservation…',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    if (_activeBooking == null) return const SizedBox.shrink();

    final booking = _activeBooking!;
    final status = booking['status'] as String? ?? '';
    final room   = (booking['room'] as Map<String, dynamic>?) ?? {};
    final roomNum  = room['roomNumber']?.toString() ?? '—';
    final roomType = room['type'] as String? ?? 'Room';
    final checkIn  = _formatDate(booking['checkIn'] as String?);
    final checkOut = _formatDate(booking['checkOut'] as String?);
    final isCheckedIn = status == 'CHECKED_IN';
    final statusColor =
        isCheckedIn ? const Color(0xFF4CAF50) : const Color(0xFF2196F3);
    final statusLabel = isCheckedIn ? 'Checked In' : 'Confirmed';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => isCheckedIn
              ? CheckinScreen(reservation: booking)
              : const BookingsScreen(),
        ));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isCheckedIn ? Icons.key : Icons.hotel,
                  color: statusColor, size: 26),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$roomType — Room $roomNum',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2A3A),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$checkIn  →  $checkOut',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF888EA8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF888EA8)),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  // ─── Offers Banner ────────────────────────────────────────────────────────

  static const _offers = [
    _Offer(emoji: '🌿', label: '10% off Spa',    sub: 'Today only',      color: Color(0xFF4CAF50)),
    _Offer(emoji: '⬆️',  label: 'Free Upgrade',   sub: 'Ask at desk',     color: Color(0xFF2196F3)),
    _Offer(emoji: '🍸',  label: 'Happy Hour',     sub: '6 – 8 PM nightly', color: Color(0xFFFF9800)),
    _Offer(emoji: '🏊',  label: 'Pool Day Pass',  sub: 'Complimentary',   color: Color(0xFF00BCD4)),
  ];

  Widget _buildOffersBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 20, 0, 10),
          child: Text(
            'TODAY\'S OFFERS',
            style: TextStyle(
              color: Color(0xFF888EA8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _offers.length,
            separatorBuilder: (_, i) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final o = _offers[i];
              return Container(
                width: 130,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: o.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: o.color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.emoji, style: const TextStyle(fontSize: 24)),
                    const Spacer(),
                    Text(o.label,
                        style: TextStyle(
                          color: o.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 2),
                    Text(o.sub,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Hotel Lookup ─────────────────────────────────────────────────────────

  Widget _hotelLookup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Welcome',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2A3A))),
        const SizedBox(height: 4),
        const Text('Enter your hotel name to get started',
            style: TextStyle(fontSize: 13, color: Color(0xFF888EA8))),
        const SizedBox(height: 20),
        TextField(
          controller: _subdomainCtrl,
          decoration: InputDecoration(
            labelText: 'Hotel name',
            hintText: 'e.g. demo',
            prefixIcon: const Icon(Icons.hotel),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: _error,
          ),
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _lookupHotel(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _loading ? null : _lookupHotel,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Continue',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ─── Order Options ────────────────────────────────────────────────────────

  Widget _orderOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ordering Section ────────────────────────────────────────────────
        const _SectionHeader('ORDER & DINE'),
        const SizedBox(height: 10),

        _optionTile(
          icon: Icons.qr_code_scanner,
          color: const Color(0xFF1E2A3A),
          title: 'Scan Table QR Code',
          subtitle: 'Point camera at your table\'s QR code',
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ScanScreen(tenantId: _tenantId),
          )),
        ),
        const SizedBox(height: 8),

        // Enter table number
        const Text('OR ENTER TABLE NUMBER',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF888EA8),
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tableCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Table number',
                  prefixIcon: const Icon(Icons.table_restaurant),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  errorText: _error,
                ),
                onSubmitted: (_) => _goWithTable(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _goWithTable,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_forward),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _optionTile(
          icon: Icons.restaurant_menu,
          color: const Color(0xFF9C27B0),
          title: 'Browse Menu',
          subtitle: 'View food & drinks without ordering',
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => MenuScreen(tenantId: _tenantId!),
          )),
        ),
        const SizedBox(height: 8),

        _optionTile(
          icon: Icons.hotel,
          color: const Color(0xFF2196F3),
          title: 'Room Service',
          subtitle: 'Order food & drinks to your room',
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) =>
                MenuScreen(tenantId: _tenantId!, isRoomService: true, initialTab: 2),
          )),
        ),
        const SizedBox(height: 8),

        _optionTile(
          icon: Icons.local_bar,
          color: const Color(0xFF795548),
          title: 'Bar Tab',
          subtitle: 'Open a tab, order drinks, view running total',
          badge: widget.isLoggedIn ? null : 'Sign in',
          onTap: () {
            if (!widget.isLoggedIn) {
              widget.onLoginRequested?.call();
              return;
            }
            Navigator.push(context, MaterialPageRoute(
              builder: (_) =>
                  BarTabScreen(tenantId: _tenantId!, hotelName: _hotelName ?? 'Hotel'),
            ));
          },
        ),

        const SizedBox(height: 16),
        const Divider(),

        // ── Rooms Section ────────────────────────────────────────────────────
        const _SectionHeader('ROOMS & STAYS'),
        const SizedBox(height: 10),

        _optionTile(
          icon: Icons.bed,
          color: const Color(0xFF4CAF50),
          title: 'Book a Room',
          subtitle: 'Browse available rooms & reserve',
          badge: widget.isLoggedIn ? null : 'Sign in',
          onTap: () {
            if (!widget.isLoggedIn) {
              widget.onLoginRequested?.call();
              return;
            }
            Navigator.push(context, MaterialPageRoute(
              builder: (_) =>
                  RoomsScreen(tenantId: _tenantId!, hotelName: _hotelName ?? 'Hotel'),
            ));
          },
        ),

        const SizedBox(height: 16),
        const Divider(),

        // ── Activities Section ───────────────────────────────────────────────
        const _SectionHeader('ACTIVITIES'),
        const SizedBox(height: 10),

        _optionTile(
          icon: Icons.confirmation_number,
          color: const Color(0xFFFF9800),
          title: 'Pool & Event Tickets',
          subtitle: 'Day passes, spa, gym, tennis & more',
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => MyTicketsScreen(tenantId: _tenantId!),
          )),
        ),

        const SizedBox(height: 16),
        const Divider(),

        // ── Staff Section ─────────────────────────────────────────────────────
        const _SectionHeader('STAFF'),
        const SizedBox(height: 10),

        _optionTile(
          icon: Icons.sensor_door,
          color: const Color(0xFF607D8B),
          title: 'Gate Scanner',
          subtitle: 'Staff — validate entry tickets',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const GateScreen())),
        ),
      ],
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E2A3A))),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(badge,
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFFF9800),
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888EA8))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

// ─── Supporting types ─────────────────────────────────────────────────────────

class _Offer {
  final String emoji;
  final String label;
  final String sub;
  final Color color;
  const _Offer(
      {required this.emoji,
      required this.label,
      required this.sub,
      required this.color});
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF888EA8),
          letterSpacing: 1.5,
        ),
      );
}
