import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:app_links/app_links.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/offline_queue.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/my_tickets_screen.dart';
import 'screens/concierge_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase — graceful degradation if google-services.json is absent (dev).
  try {
    await Firebase.initializeApp();
    await NotificationService.instance.init();
  } catch (_) {
    // Running without Firebase config is fine in dev/simulator.
  }
  runApp(const GuestApp());
}

class GuestApp extends StatelessWidget {
  const GuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HOMP Guest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2A3A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/home':    (_) => const _AppShell(),
      },
    );
  }
}

/// Top-level shell that holds hotel context + bottom nav
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  // Hotel context (set on HomeScreen hotel lookup)
  String? _tenantId;
  String? _hotelName;

  // Auth state
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentUser;

  // Bottom nav index
  int _navIdx = 0;

  // Connectivity stream for offline-queue auto-sync
  late final Stream<List<ConnectivityResult>> _connectivityStream;
  bool _wasOffline = false;

  // Deep link handler
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _restoreSession();
    NotificationService.onNotification = _handleNotification;
    _connectivityStream = Connectivity().onConnectivityChanged;
    _connectivityStream.listen(_onConnectivityChanged);
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    // Handle initial link that launched the app
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handleDeepLink(initial);
    // Handle subsequent links while app is running
    _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    if (!mounted) return;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    switch (segments[0]) {
      case 'booking':
      case 'bookings':
        if (_isLoggedIn) setState(() => _navIdx = 1);
        break;
      case 'ticket':
        setState(() => _navIdx = 2);
        break;
      case 'checkin':
        if (_isLoggedIn) setState(() => _navIdx = 1);
        break;
      case 'concierge':
        if (_tenantId != null) setState(() => _navIdx = 3);
        break;
      case 'gate':
        setState(() => _navIdx = 0);
        break;
      case 'menu':
        setState(() => _navIdx = 0);
        break;
    }
  }

  @override
  void dispose() {
    NotificationService.onNotification = null;
    super.dispose();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = !results.contains(ConnectivityResult.none);
    if (isOnline && _wasOffline) {
      // Back online — flush any queued orders silently.
      OfflineQueue.flush().then((placed) {
        if (placed.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${placed.length} offline order${placed.length != 1 ? "s" : ""} placed successfully!'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }).catchError((_) {});
    }
    _wasOffline = !isOnline;
  }

  void _handleNotification(String type, String id) {
    if (!mounted) return;
    switch (type) {
      case 'booking':
      case 'checkin':
      case 'checkin_reminder':
      case 'bill_ready':
      case 'order_served':
        if (_isLoggedIn) setState(() => _navIdx = 1); // Bookings tab
        break;
      case 'order_ready':
        setState(() => _navIdx = 0); // Home tab
        break;
      case 'ticket':
        setState(() => _navIdx = 2); // Tickets tab
        break;
      case 'offer':
        setState(() => _navIdx = 0); // Home tab
        break;
      case 'concierge':
        if (_tenantId != null) setState(() => _navIdx = 3); // Concierge tab
        break;
    }
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTenantId   = prefs.getString('guest_tenant_id');
    final savedHotelName  = prefs.getString('guest_hotel_name');
    final loggedIn        = await AuthService.isLoggedIn();
    final user            = loggedIn ? await AuthService.getUser() : null;

    setState(() {
      _tenantId   = savedTenantId;
      _hotelName  = savedHotelName;
      _isLoggedIn = loggedIn;
      _currentUser = user;
    });
  }

  void _onHotelResolved(String tenantId, String hotelName) {
    setState(() {
      _tenantId  = tenantId;
      _hotelName = hotelName;
    });
  }

  void _onLoggedIn(Map<String, dynamic> user) {
    setState(() {
      _isLoggedIn  = true;
      _currentUser = user;
    });
  }

  void _onLoggedOut() {
    setState(() {
      _isLoggedIn  = false;
      _currentUser = null;
      _navIdx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The home/ordering screen always shows; others depend on context
    final pages = _buildPages();

    return Scaffold(
      body: IndexedStack(index: _navIdx, children: pages),
      bottomNavigationBar: _tenantId != null ? _buildNavBar() : null,
    );
  }

  List<Widget> _buildPages() {
    final tenantId  = _tenantId ?? '';
    final hotelName = _hotelName ?? 'Hotel';

    return [
      // Tab 0: Home (ordering, QR, tickets, concierge)
      HomeScreen(
        onHotelResolved: _onHotelResolved,
        onLoginRequested: () => _showLoginSheet(),
        isLoggedIn: _isLoggedIn,
        currentUser: _currentUser,
      ),

      // Tab 1: My Bookings (auth required)
      _isLoggedIn
          ? const BookingsScreen()
          : _authRequiredPage('My Bookings', Icons.hotel, 'Sign in to view and manage your room bookings.'),

      // Tab 2: My Tickets
      _tenantId != null
          ? MyTicketsScreen(tenantId: tenantId)
          : _noHotelPage(),

      // Tab 3: AI Concierge
      _tenantId != null
          ? ConciergeScreen(tenantId: tenantId, hotelName: hotelName)
          : _noHotelPage(),

      // Tab 4: Profile & Loyalty
      _isLoggedIn
          ? ProfileScreen(onLogout: _onLoggedOut)
          : _authRequiredPage('Profile & Loyalty', Icons.person, 'Sign in to access your profile, loyalty points, and booking history.'),
    ];
  }

  Widget _buildNavBar() {
    return NavigationBar(
      selectedIndex: _navIdx,
      onDestinationSelected: (i) {
        // If tapping bookings/profile and not logged in → show login sheet
        if ((i == 1 || i == 4) && !_isLoggedIn) {
          _showLoginSheet();
          return;
        }
        setState(() => _navIdx = i);
      },
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: Color(0xFF4CAF50)),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: false,
            child: const Icon(Icons.hotel_outlined),
          ),
          selectedIcon: const Icon(Icons.hotel, color: Color(0xFF4CAF50)),
          label: 'Bookings',
        ),
        const NavigationDestination(
          icon: Icon(Icons.confirmation_number_outlined),
          selectedIcon: Icon(Icons.confirmation_number, color: Color(0xFF4CAF50)),
          label: 'Tickets',
        ),
        const NavigationDestination(
          icon: Icon(Icons.smart_toy_outlined),
          selectedIcon: Icon(Icons.smart_toy, color: Color(0xFF4CAF50)),
          label: 'Concierge',
        ),
        NavigationDestination(
          icon: _isLoggedIn
              ? const Icon(Icons.person_outlined)
              : Stack(children: [
                  const Icon(Icons.person_outlined),
                  Positioned(right: 0, top: 0,
                    child: Container(width: 8, height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle))),
                ]),
          selectedIcon: const Icon(Icons.person, color: Color(0xFF4CAF50)),
          label: 'Profile',
        ),
      ],
    );
  }

  void _showLoginSheet() {
    if (_tenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to a hotel first'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.6,
        builder: (_, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: LoginScreen(
            tenantId: _tenantId!,
            hotelName: _hotelName ?? 'Hotel',
            onSuccess: () async {
              Navigator.pop(ctx);
              final user = await AuthService.getUser();
              _onLoggedIn(user ?? {});
              setState(() => _navIdx = 4); // go to profile tab
              // Register FCM token now that the user is authenticated.
              NotificationService.instance.onLogin();
            },
          ),
        ),
      ),
    );
  }

  Widget _authRequiredPage(String title, IconData icon, String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A3A).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: const Color(0xFF888EA8)),
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A3A))),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF888EA8), height: 1.5)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: _showLoginSheet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noHotelPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hotel, size: 56, color: Color(0xFFDDDDDD)),
            const SizedBox(height: 16),
            const Text('Connect to a hotel first', style: TextStyle(fontSize: 15, color: Color(0xFF888EA8))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => setState(() => _navIdx = 0),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
