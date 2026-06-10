import 'package:flutter_test/flutter_test.dart';

/// Unit tests for booking/reservation business logic.

String bookingStatusLabel(String status) {
  const labels = {
    'PENDING':      'Pending',
    'CONFIRMED':    'Confirmed',
    'CHECKED_IN':   'Checked In',
    'CHECKED_OUT':  'Checked Out',
    'CANCELLED':    'Cancelled',
    'NO_SHOW':      'No Show',
  };
  return labels[status] ?? status;
}

bool canCheckIn(Map<String, dynamic> reservation) {
  return reservation['status'] == 'CONFIRMED';
}

bool canCheckOut(Map<String, dynamic> reservation) {
  return reservation['status'] == 'CHECKED_IN';
}

bool isActiveStay(Map<String, dynamic> reservation) {
  return reservation['status'] == 'CHECKED_IN';
}

int calculateNights(String checkIn, String checkOut) {
  final inDate  = DateTime.tryParse(checkIn);
  final outDate = DateTime.tryParse(checkOut);
  if (inDate == null || outDate == null) return 0;
  return outDate.difference(inDate).inDays;
}

double calculateTotal(double baseRate, int nights) {
  return baseRate * nights;
}

void main() {
  group('Booking status labels', () {
    test('PENDING maps to Pending', () => expect(bookingStatusLabel('PENDING'), 'Pending'));
    test('CONFIRMED maps to Confirmed', () => expect(bookingStatusLabel('CONFIRMED'), 'Confirmed'));
    test('CHECKED_IN maps to Checked In', () => expect(bookingStatusLabel('CHECKED_IN'), 'Checked In'));
    test('CHECKED_OUT maps to Checked Out', () => expect(bookingStatusLabel('CHECKED_OUT'), 'Checked Out'));
    test('CANCELLED maps to Cancelled', () => expect(bookingStatusLabel('CANCELLED'), 'Cancelled'));
    test('unknown status returns itself', () => expect(bookingStatusLabel('UNKNOWN'), 'UNKNOWN'));
  });

  group('Booking actions', () {
    test('canCheckIn is true only for CONFIRMED', () {
      expect(canCheckIn({'status': 'CONFIRMED'}), true);
      expect(canCheckIn({'status': 'PENDING'}), false);
      expect(canCheckIn({'status': 'CHECKED_IN'}), false);
    });

    test('canCheckOut is true only for CHECKED_IN', () {
      expect(canCheckOut({'status': 'CHECKED_IN'}), true);
      expect(canCheckOut({'status': 'CONFIRMED'}), false);
      expect(canCheckOut({'status': 'CHECKED_OUT'}), false);
    });

    test('isActiveStay is true only for CHECKED_IN', () {
      expect(isActiveStay({'status': 'CHECKED_IN'}), true);
      expect(isActiveStay({'status': 'CONFIRMED'}), false);
    });
  });

  group('Nights and total calculation', () {
    test('calculates 3 nights correctly', () {
      final nights = calculateNights('2026-06-01', '2026-06-04');
      expect(nights, 3);
    });

    test('calculates 1 night correctly', () {
      final nights = calculateNights('2026-06-10', '2026-06-11');
      expect(nights, 1);
    });

    test('returns 0 nights for same-day check-in/out', () {
      final nights = calculateNights('2026-06-10', '2026-06-10');
      expect(nights, 0);
    });

    test('returns 0 for malformed dates', () {
      final nights = calculateNights('bad-date', '2026-06-10');
      expect(nights, 0);
    });

    test('calculates total as baseRate × nights', () {
      expect(calculateTotal(150.0, 3), closeTo(450.0, 0.01));
    });

    test('calculates total for single night', () {
      expect(calculateTotal(200.0, 1), closeTo(200.0, 0.01));
    });

    test('calculates total for zero nights is 0', () {
      expect(calculateTotal(150.0, 0), closeTo(0.0, 0.01));
    });
  });
}
