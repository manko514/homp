import 'package:flutter_test/flutter_test.dart';

/// Pure unit tests for order business logic in the waiter/KDS module.

bool isOrderActive(Map<String, dynamic> order) {
  const active = {'PENDING', 'KDS', 'READY'};
  return active.contains(order['status']);
}

bool isOrderUrgent(Map<String, dynamic> order) {
  if (!isOrderActive(order)) return false;
  final createdAt = DateTime.tryParse(order['createdAt'] as String? ?? '');
  if (createdAt == null) return false;
  return DateTime.now().difference(createdAt).inMinutes >= 15;
}

String orderStatusLabel(String status) {
  const labels = {
    'PENDING':   'New Order',
    'KDS':       'In Kitchen',
    'READY':     'Ready to Serve',
    'SERVED':    'Served',
    'BILLED':    'Billed',
    'CANCELLED': 'Cancelled',
  };
  return labels[status] ?? status;
}

double orderTotal(List<Map<String, dynamic>> items) {
  return items.fold(0.0, (sum, item) {
    final qty = (item['qty'] as num? ?? 0).toDouble();
    final price = (item['unitPrice'] as num? ?? 0).toDouble();
    return sum + qty * price;
  });
}

void main() {
  group('Order status logic', () {
    test('isOrderActive is true for PENDING', () => expect(isOrderActive({'status': 'PENDING'}), true));
    test('isOrderActive is true for KDS', () => expect(isOrderActive({'status': 'KDS'}), true));
    test('isOrderActive is true for READY', () => expect(isOrderActive({'status': 'READY'}), true));
    test('isOrderActive is false for SERVED', () => expect(isOrderActive({'status': 'SERVED'}), false));
    test('isOrderActive is false for BILLED', () => expect(isOrderActive({'status': 'BILLED'}), false));
    test('isOrderActive is false for CANCELLED', () => expect(isOrderActive({'status': 'CANCELLED'}), false));
  });

  group('Order urgency', () {
    test('isOrderUrgent is false for recent order', () {
      final order = {
        'status': 'PENDING',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      };
      expect(isOrderUrgent(order), false);
    });

    test('isOrderUrgent is true for order older than 15 minutes', () {
      final order = {
        'status': 'PENDING',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
      };
      expect(isOrderUrgent(order), true);
    });

    test('isOrderUrgent is false for served order even if old', () {
      final order = {
        'status': 'SERVED',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      };
      expect(isOrderUrgent(order), false);
    });
  });

  group('Order status labels', () {
    test('PENDING → New Order', () => expect(orderStatusLabel('PENDING'), 'New Order'));
    test('KDS → In Kitchen', () => expect(orderStatusLabel('KDS'), 'In Kitchen'));
    test('READY → Ready to Serve', () => expect(orderStatusLabel('READY'), 'Ready to Serve'));
    test('unknown → itself', () => expect(orderStatusLabel('FOO'), 'FOO'));
  });

  group('Order total calculation', () {
    test('calculates total for single item', () {
      final items = [{'qty': 2, 'unitPrice': 12.5}];
      expect(orderTotal(items), closeTo(25.0, 0.01));
    });

    test('calculates total for multiple items', () {
      final items = [
        {'qty': 1, 'unitPrice': 10.0},
        {'qty': 3, 'unitPrice': 5.0},
        {'qty': 2, 'unitPrice': 8.0},
      ];
      expect(orderTotal(items), closeTo(41.0, 0.01));
    });

    test('returns 0 for empty items list', () {
      expect(orderTotal([]), closeTo(0.0, 0.01));
    });

    test('handles missing price gracefully', () {
      final items = [{'qty': 2}];
      expect(orderTotal(items), closeTo(0.0, 0.01));
    });
  });
}
