import 'package:flutter_test/flutter_test.dart';

/// Unit tests for ticket business logic (expiry, status, display formatting).
/// These are pure Dart tests — no Flutter widgets or platform channels needed.

bool isTicketExpired(Map<String, dynamic> ticket) {
  final until = DateTime.tryParse(ticket['validUntil'] as String? ?? '');
  if (until == null) return true;
  return DateTime.now().isAfter(until);
}

bool isTicketUsable(Map<String, dynamic> ticket) {
  final status = ticket['status'] as String? ?? '';
  if (status != 'ACTIVE') return false;
  return !isTicketExpired(ticket);
}

String formatTicketType(String raw) {
  return raw.replaceAll('_', ' ').toLowerCase().replaceFirstMapped(
        RegExp(r'^.'),
        (m) => m.group(0)!.toUpperCase(),
      );
}

void main() {
  group('Ticket business logic', () {
    test('isTicketExpired returns false for future ticket', () {
      final ticket = {
        'validUntil': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
        'status': 'ACTIVE',
      };
      expect(isTicketExpired(ticket), false);
    });

    test('isTicketExpired returns true for past ticket', () {
      final ticket = {
        'validUntil': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'status': 'ACTIVE',
      };
      expect(isTicketExpired(ticket), true);
    });

    test('isTicketUsable returns true for active non-expired ticket', () {
      final ticket = {
        'validUntil': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
        'status': 'ACTIVE',
      };
      expect(isTicketUsable(ticket), true);
    });

    test('isTicketUsable returns false for USED ticket', () {
      final ticket = {
        'validUntil': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
        'status': 'USED',
      };
      expect(isTicketUsable(ticket), false);
    });

    test('isTicketUsable returns false for CANCELLED ticket', () {
      final ticket = {
        'validUntil': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
        'status': 'CANCELLED',
      };
      expect(isTicketUsable(ticket), false);
    });

    test('isTicketUsable returns false for expired-but-ACTIVE ticket', () {
      final ticket = {
        'validUntil': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
        'status': 'ACTIVE',
      };
      expect(isTicketUsable(ticket), false);
    });

    test('formatTicketType converts DAY_PASS to "Day pass"', () {
      expect(formatTicketType('DAY_PASS'), 'Day pass');
    });

    test('formatTicketType converts POOL to "Pool"', () {
      expect(formatTicketType('POOL'), 'Pool');
    });

    test('formatTicketType handles single word', () {
      expect(formatTicketType('GYM'), 'Gym');
    });

    test('isTicketExpired handles malformed date gracefully', () {
      final ticket = {'validUntil': 'not-a-date', 'status': 'ACTIVE'};
      expect(isTicketExpired(ticket), true);
    });
  });
}
