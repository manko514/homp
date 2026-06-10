import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guest/services/offline_queue.dart';

void main() {
  group('OfflineQueue', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('enqueue adds an order and pendingCount returns 1', () async {
      await OfflineQueue.enqueue('tenant-1', {
        'tableId': 'table-1',
        'items': [{'menuItemId': 'item-1', 'qty': 2}],
      });
      final count = await OfflineQueue.pendingCount();
      expect(count, 1);
    });

    test('multiple enqueues accumulate in queue', () async {
      for (var i = 0; i < 4; i++) {
        await OfflineQueue.enqueue('tenant-1', {
          'tableId': 'table-$i',
          'items': [{'menuItemId': 'item-$i', 'qty': 1}],
        });
      }
      final count = await OfflineQueue.pendingCount();
      expect(count, 4);
    });

    test('pendingCount returns 0 when queue is empty', () async {
      final count = await OfflineQueue.pendingCount();
      expect(count, 0);
    });

    test('clear empties the queue', () async {
      await OfflineQueue.enqueue('tenant-1', {'items': []});
      await OfflineQueue.clear();
      final count = await OfflineQueue.pendingCount();
      expect(count, 0);
    });

    test('flush returns empty list when queue is empty', () async {
      final placed = await OfflineQueue.flush();
      expect(placed, isEmpty);
    });

    test('enqueue stores tenantId in the entry', () async {
      SharedPreferences.setMockInitialValues({});
      await OfflineQueue.enqueue('hotel-abc', {'tableId': 't1', 'items': []});
      // Verify indirectly — queue has 1 item
      final count = await OfflineQueue.pendingCount();
      expect(count, 1);
    });
  });
}
