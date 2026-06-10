import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/cart_item.dart';
import '../services/guest_api_service.dart';
import '../services/offline_queue.dart';
import 'tracker_screen.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cart;
  final String tenantId;
  final String? tableId;
  final int? tableNumber;
  final bool isRoomService;
  final String? roomNumber;
  final void Function(List<CartItem>) onCartUpdated;

  const CartScreen({
    super.key,
    required this.cart,
    required this.tenantId,
    this.tableId,
    this.tableNumber,
    this.isRoomService = false,
    this.roomNumber,
    required this.onCartUpdated,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<CartItem> _cart;
  final _notesCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _cart = List.from(widget.cart);
    if (widget.roomNumber != null) {
      _roomCtrl.text = widget.roomNumber!;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  double get _total => _cart.fold(0.0, (s, i) => s + i.lineTotal);

  void _increment(int idx) => setState(() => _cart[idx].qty++);

  void _decrement(int idx) {
    setState(() {
      if (_cart[idx].qty <= 1) {
        _cart.removeAt(idx);
      } else {
        _cart[idx].qty--;
      }
    });
    widget.onCartUpdated(_cart);
  }

  Map<String, dynamic> _buildOrderPayload() {
    final foodItems = _cart
        .where((c) => !c.isDrink)
        .map((c) => {'menuItemId': c.id, 'qty': c.qty})
        .toList();

    final drinkItems = _cart
        .where((c) => c.isDrink)
        .map((c) => {
              'drinkId': c.id,
              'name': c.name,
              'qty': c.qty,
              'price': c.price,
            })
        .toList();

    return {
      if (widget.tableId != null) 'tableId': widget.tableId,
      'isRoomService': widget.isRoomService,
      if (widget.isRoomService && _roomCtrl.text.isNotEmpty)
        'roomNumber': _roomCtrl.text.trim(),
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
      if (foodItems.isNotEmpty) 'items': foodItems,
      if (drinkItems.isNotEmpty) 'drinkItems': drinkItems,
    };
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _placing = true);

    final payload = _buildOrderPayload();

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = !connectivity.contains(ConnectivityResult.none);

    if (!isOnline) {
      // Queue offline
      await OfflineQueue.enqueue(widget.tenantId, payload);
      if (!mounted) return;
      setState(() => _placing = false);
      _showOfflineDialog();
      return;
    }

    try {
      final order = await GuestApiService.placeOrder(widget.tenantId, payload);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TrackerScreen(
            orderId: order['id'] as String,
            tenantId: widget.tenantId,
            tableNumber: widget.tableNumber,
            isRoomService: widget.isRoomService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saved Offline'),
        content: const Text(
          'You\'re offline. Your order has been saved and will be placed automatically when you reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A3A),
        title: const Text('Your Cart',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Your cart is empty',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Location info
                _infoCard(),
                const SizedBox(height: 16),

                // Cart items
                ...List.generate(_cart.length, (i) {
                  final item = _cart[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFFEEF0F3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: item.isDrink
                                ? const Color(0xFF9C27B0)
                                    .withValues(alpha: 0.1)
                                : const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item.isDrink
                                ? Icons.local_bar
                                : Icons.restaurant,
                            color: item.isDrink
                                ? const Color(0xFF9C27B0)
                                : const Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E2A3A))),
                              Text(
                                '\$${item.lineTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF888EA8)),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _qtyBtn(Icons.remove, () => _decrement(i)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('${item.qty}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E2A3A))),
                            ),
                            _qtyBtn(Icons.add, () => _increment(i)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                // Room number (room service only)
                if (widget.isRoomService) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _roomCtrl,
                    decoration: InputDecoration(
                      labelText: 'Room Number',
                      hintText: 'e.g. 214',
                      prefixIcon: const Icon(Icons.hotel),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                ],

                // Notes
                TextField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Special instructions (optional)',
                    hintText: 'No onions, extra sauce...',
                    prefixIcon: const Icon(Icons.note_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Total
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEEF0F3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2A3A))),
                      Text('\$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50))),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _placing ? null : _placeOrder,
                  child: _placing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Place Order  •  \$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _infoCard() {
    final label = widget.isRoomService
        ? 'Room Service'
        : widget.tableNumber != null
            ? 'Table ${widget.tableNumber}'
            : 'Takeaway';
    final icon = widget.isRoomService ? Icons.hotel : Icons.table_restaurant;
    final color = widget.isRoomService
        ? const Color(0xFF2196F3)
        : const Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFEEF0F3)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF1E2A3A)),
      ),
    );
  }
}
