import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guest/services/ticket_storage.dart';

void main() {
  group('TicketStorage', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('save and loadAll returns stored ticket', () async {
      final ticket = {
        'qrToken': 'HOMP-TEST001',
        'ticketType': 'POOL',
        'status': 'ACTIVE',
        'validFrom': '2026-01-01T08:00:00Z',
        'validUntil': '2026-01-01T20:00:00Z',
      };
      await TicketStorage.save(ticket);
      final all = await TicketStorage.loadAll();
      expect(all.length, 1);
      expect(all.first['qrToken'], 'HOMP-TEST001');
      expect(all.first['ticketType'], 'POOL');
    });

    test('saving duplicate token replaces existing', () async {
      final ticket1 = {'qrToken': 'HOMP-DUP', 'status': 'ACTIVE'};
      final ticket2 = {'qrToken': 'HOMP-DUP', 'status': 'USED'};
      await TicketStorage.save(ticket1);
      await TicketStorage.save(ticket2);
      final all = await TicketStorage.loadAll();
      expect(all.length, 1);
      expect(all.first['status'], 'USED');
    });

    test('remove deletes a ticket by qrToken', () async {
      await TicketStorage.save({'qrToken': 'HOMP-A', 'status': 'ACTIVE'});
      await TicketStorage.save({'qrToken': 'HOMP-B', 'status': 'ACTIVE'});
      await TicketStorage.remove('HOMP-A');
      final all = await TicketStorage.loadAll();
      expect(all.length, 1);
      expect(all.first['qrToken'], 'HOMP-B');
    });

    test('updateStatus changes status for matching token', () async {
      await TicketStorage.save({'qrToken': 'HOMP-UPD', 'status': 'ACTIVE'});
      await TicketStorage.updateStatus('HOMP-UPD', 'USED');
      final all = await TicketStorage.loadAll();
      expect(all.first['status'], 'USED');
    });

    test('updateStatus does nothing for unknown token', () async {
      await TicketStorage.save({'qrToken': 'HOMP-X', 'status': 'ACTIVE'});
      await TicketStorage.updateStatus('HOMP-UNKNOWN', 'USED');
      final all = await TicketStorage.loadAll();
      expect(all.first['status'], 'ACTIVE');
    });

    test('loadAll returns empty list when nothing stored', () async {
      final all = await TicketStorage.loadAll();
      expect(all, isEmpty);
    });

    test('most recently saved ticket appears first', () async {
      await TicketStorage.save({'qrToken': 'HOMP-FIRST', 'status': 'ACTIVE'});
      await TicketStorage.save({'qrToken': 'HOMP-SECOND', 'status': 'ACTIVE'});
      final all = await TicketStorage.loadAll();
      expect(all.first['qrToken'], 'HOMP-SECOND');
    });
  });
}
