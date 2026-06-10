import 'package:flutter_test/flutter_test.dart';

/// Pure business logic tests for staff attendance module.

bool isClockedIn(Map<String, dynamic>? attendance) {
  if (attendance == null) return false;
  return attendance['clockOut'] == null;
}

Duration shiftDuration(Map<String, dynamic> attendance) {
  final clockIn = DateTime.tryParse(attendance['clockIn'] as String? ?? '');
  final clockOutRaw = attendance['clockOut'] as String?;
  if (clockIn == null) return Duration.zero;
  final clockOut = clockOutRaw != null ? DateTime.tryParse(clockOutRaw) : DateTime.now();
  if (clockOut == null) return Duration.zero;
  return clockOut.difference(clockIn);
}

String formatShiftDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return '${h}h ${m}m';
}

void main() {
  group('Staff attendance business logic', () {
    test('isClockedIn returns true when clockOut is null', () {
      expect(isClockedIn({'clockIn': '2026-06-09T08:00:00Z', 'clockOut': null}), true);
    });

    test('isClockedIn returns false when clockOut is set', () {
      expect(isClockedIn({'clockIn': '2026-06-09T08:00:00Z', 'clockOut': '2026-06-09T17:00:00Z'}), false);
    });

    test('isClockedIn returns false for null attendance', () {
      expect(isClockedIn(null), false);
    });

    test('shiftDuration calculates 9h 0m correctly', () {
      final att = {
        'clockIn': '2026-06-09T08:00:00Z',
        'clockOut': '2026-06-09T17:00:00Z',
      };
      final d = shiftDuration(att);
      expect(d.inHours, 9);
      expect(d.inMinutes % 60, 0);
    });

    test('shiftDuration calculates 4h 30m correctly', () {
      final att = {
        'clockIn': '2026-06-09T08:00:00Z',
        'clockOut': '2026-06-09T12:30:00Z',
      };
      final d = shiftDuration(att);
      expect(d.inHours, 4);
      expect(d.inMinutes % 60, 30);
    });

    test('shiftDuration returns zero for malformed clockIn', () {
      final att = {'clockIn': 'bad', 'clockOut': '2026-06-09T17:00:00Z'};
      expect(shiftDuration(att), Duration.zero);
    });

    test('formatShiftDuration formats correctly', () {
      expect(formatShiftDuration(const Duration(hours: 8, minutes: 45)), '8h 45m');
      expect(formatShiftDuration(const Duration(hours: 0, minutes: 30)), '0h 30m');
    });
  });
}
