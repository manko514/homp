import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/guest_api_service.dart';
import '../services/utils.dart';
import '../models/cart_item.dart';
import 'cart_screen.dart';

class MenuScreen extends StatefulWidget {
  final String tenantId;
  final String? tableId;
  final int? tableNumber;
  final bool isRoomService;
  final String? roomNumber;
  final int initialTab;

  const MenuScreen({
    super.key,
    required this.tenantId,
    this.tableId,
    this.tableNumber,
    this.isRoomService = false,
    this.roomNumber,
    this.initialTab = 0,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _menuItems = [];
  List<dynamic> _drinks = [];
  bool _loading = true;
  bool _isOffline = false;
  String? _error;

  final List<CartItem> _cart = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _menuCacheKey  => 'menu_cache_${widget.tenantId}';
  String get _drinkCacheKey => 'drinks_cache_${widget.tenantId}';

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        GuestApiService.getMenu(widget.tenantId),
        GuestApiService.getDrinks(widget.tenantId),
      ]);
      // Persist fresh data for offline use.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_menuCacheKey,  jsonEncode(results[0]));
      await prefs.setString(_drinkCacheKey, jsonEncode(results[1]));
      setState(() {
        _menuItems = results[0];
        _drinks    = results[1];
        _isOffline = false;
        _loading   = false;
      });
    } catch (_) {
      // Network failed — load cached data so guest can still browse.
      final prefs = await SharedPreferences.getInstance();
      final cachedMenu   = prefs.getString(_menuCacheKey);
      final cachedDrinks = prefs.getString(_drinkCacheKey);
      if (cachedMenu != null && cachedDrinks != null) {
        setState(() {
          _menuItems = jsonDecode(cachedMenu)  as List;
          _drinks    = jsonDecode(cachedDrinks) as List;
          _isOffline = true;
          _loading   = false;
        });
      } else {
        setState(() {
          _error   = 'No internet connection and no cached menu available.';
          _loading = false;
        });
      }
    }
  }

  void _addToCart(CartItem item) {
    setState(() {
      final existing = _cart.indexWhere(
          (c) => c.id == item.id && c.isDrink == item.isDrink);
      if (existing >= 0) {
        _cart[existing].qty++;
      } else {
        _cart.add(item);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  int get _cartCount => _cart.fold(0, (sum, i) => sum + i.qty);

  List<dynamic> get _foodItems =>
      _menuItems.where((m) => m['category'] != 'DRINK').toList();

  List<dynamic> get _roomItems => _menuItems;

  String _locationLabel() {
    if (widget.isRoomService) return 'Room Service';
    if (widget.tableNumber != null) return 'Table ${widget.tableNumber}';
    return 'Browse Menu';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Menu',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text(
              _locationLabel(),
              style:
                  const TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF4CAF50),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Food'),
            Tab(text: 'Drinks'),
            Tab(text: 'Room Service'),
          ],
        ),
        actions: [
          if (_cartCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  onPressed: _openCart,
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_isOffline)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFFF9800),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 14),
                            SizedBox(width: 8),
                            Text('Offline — viewing cached menu. Ordering disabled.',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _ItemGrid(items: _foodItems, onAdd: _isOffline ? null : _addToCart, isDrink: false),
                          _ItemGrid(items: _drinks,    onAdd: _isOffline ? null : _addToCart, isDrink: true),
                          _ItemGrid(items: _roomItems, onAdd: _isOffline ? null : _addToCart, isDrink: false, isRoomService: true),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _cartCount > 0 && !_isOffline
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _openCart,
                  child: Text(
                    'View Cart  •  $_cartCount item${_cartCount != 1 ? "s" : ""}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          cart: _cart,
          tenantId: widget.tenantId,
          tableId: widget.tableId,
          tableNumber: widget.tableNumber,
          isRoomService: widget.isRoomService,
          roomNumber: widget.roomNumber,
          onCartUpdated: (newCart) => setState(() {
            _cart.clear();
            _cart.addAll(newCart);
          }),
        ),
      ),
    );
  }
}

class _ItemGrid extends StatelessWidget {
  final List<dynamic> items;
  final void Function(CartItem)? onAdd; // null when offline
  final bool isDrink;
  final bool isRoomService;

  const _ItemGrid({
    required this.items,
    required this.onAdd,
    required this.isDrink,
    this.isRoomService = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No items available',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    // Group by category
    final Map<String, List<dynamic>> grouped = {};
    for (final item in items) {
      final cat = item['category'] as String? ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              entry.key.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF888EA8),
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...entry.value.map((item) {
            final price = toDouble(item['price']);
            return _MenuCard(
              id: item['id'] as String,
              name: item['name'] as String,
              description: item['description'] as String? ?? '',
              category: item['category'] as String? ?? '',
              price: price,
              isDrink: isDrink,
              onAdd: onAdd,
            );
          }),
          const SizedBox(height: 8),
        ],
        if (isRoomService)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 16),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Room service orders will be delivered to your room',
                    style:
                        TextStyle(color: Color(0xFF2196F3), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final bool isDrink;
  final void Function(CartItem)? onAdd;

  const _MenuCard({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isDrink,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDrink
                ? const Color(0xFF9C27B0).withValues(alpha: 0.1)
                : const Color(0xFF4CAF50).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDrink ? Icons.local_bar : Icons.restaurant,
            color:
                isDrink ? const Color(0xFF9C27B0) : const Color(0xFF4CAF50),
            size: 22,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E2A3A),
          ),
        ),
        subtitle: description.isNotEmpty
            ? Text(
                description,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF888EA8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2A3A),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onAdd == null ? null : () => onAdd!(CartItem(
                id: id,
                name: name,
                category: category,
                price: price,
                isDrink: isDrink,
              )),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: onAdd != null
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  onAdd != null ? '+ Add' : 'Offline',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
