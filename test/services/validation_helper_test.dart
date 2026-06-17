// test/services/validation_helper_test.dart
// Unit tests for ValidationHelper

import 'package:flutter_test/flutter_test.dart';
import 'package:rideconnect_app/utils/validation_helper.dart';

void main() {
  group('ValidationHelper', () {
    group('isValidTripId', () {
      test('returns true for positive integer', () {
        expect(ValidationHelper.isValidTripId(1), true);
        expect(ValidationHelper.isValidTripId(100), true);
        expect(ValidationHelper.isValidTripId(999999), true);
      });

      test('returns false for zero', () {
        expect(ValidationHelper.isValidTripId(0), false);
      });

      test('returns false for negative integer', () {
        expect(ValidationHelper.isValidTripId(-1), false);
        expect(ValidationHelper.isValidTripId(-100), false);
      });

      test('returns false for null', () {
        expect(ValidationHelper.isValidTripId(null), false);
      });
    });

    group('parseTripId', () {
      test('parses int correctly', () {
        expect(ValidationHelper.parseTripId(123), 123);
        expect(ValidationHelper.parseTripId(1), 1);
      });

      test('parses valid string to int', () {
        expect(ValidationHelper.parseTripId('123'), 123);
        expect(ValidationHelper.parseTripId('1'), 1);
      });

      test('returns null for zero', () {
        expect(ValidationHelper.parseTripId(0), null);
        expect(ValidationHelper.parseTripId('0'), null);
      });

      test('returns null for negative values', () {
        expect(ValidationHelper.parseTripId(-1), null);
        expect(ValidationHelper.parseTripId('-1'), null);
      });

      test('returns null for invalid string', () {
        expect(ValidationHelper.parseTripId('abc'), null);
        expect(ValidationHelper.parseTripId('12.5'), null);
      });

      test('returns null for null', () {
        expect(ValidationHelper.parseTripId(null), null);
      });
    });

    group('assertValidTripId', () {
      test('returns valid trip id', () {
        expect(ValidationHelper.assertValidTripId(123), 123);
        expect(ValidationHelper.assertValidTripId(1), 1);
      });

      test('throws ArgumentError for null', () {
        expect(
          () => ValidationHelper.assertValidTripId(null),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for zero', () {
        expect(
          () => ValidationHelper.assertValidTripId(0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative', () {
        expect(
          () => ValidationHelper.assertValidTripId(-1),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('isValidEmail', () {
      test('returns true for valid emails', () {
        expect(ValidationHelper.isValidEmail('test@example.com'), true);
        expect(ValidationHelper.isValidEmail('user.name@domain.co.uk'), true);
      });

      test('returns false for invalid emails', () {
        expect(ValidationHelper.isValidEmail('invalid@'), false);
        expect(ValidationHelper.isValidEmail('invalid.com'), false);
        expect(ValidationHelper.isValidEmail(''), false);
      });
    });

    group('isValidPhoneNumber', () {
      test('returns true for valid phone numbers', () {
        expect(ValidationHelper.isValidPhoneNumber('+250788123456'), true);
        expect(ValidationHelper.isValidPhoneNumber('0788123456'), true);
        expect(ValidationHelper.isValidPhoneNumber('+1 (555) 123-4567'), true);
      });

      test('returns false for invalid phone numbers', () {
        expect(ValidationHelper.isValidPhoneNumber('123'), false);
        expect(ValidationHelper.isValidPhoneNumber(''), false);
      });
    });

    group('isValidPassword', () {
      test('returns true for valid passwords', () {
        expect(ValidationHelper.isValidPassword('ValidPass123'), true);
        expect(ValidationHelper.isValidPassword('SecurePass456'), true);
      });

      test('returns false for weak passwords', () {
        expect(ValidationHelper.isValidPassword('short'), false);
        expect(ValidationHelper.isValidPassword('nouppercase123'), false);
        expect(ValidationHelper.isValidPassword('NOLOWERCASE123'), false);
        expect(ValidationHelper.isValidPassword('NoNumbers'), false);
      });
    });

    group('isValidLocation', () {
      test('returns true for valid coordinates', () {
        expect(ValidationHelper.isValidLocation(0.0, 0.0), true);
        expect(ValidationHelper.isValidLocation(45.5, -120.5), true);
        expect(ValidationHelper.isValidLocation(-90.0, 180.0), true);
      });

      test('returns false for invalid coordinates', () {
        expect(ValidationHelper.isValidLocation(91.0, 0.0), false);
        expect(ValidationHelper.isValidLocation(0.0, 181.0), false);
        expect(ValidationHelper.isValidLocation(null, 0.0), false);
        expect(ValidationHelper.isValidLocation(0.0, null), false);
      });
    });

    group('isValidFare', () {
      test('returns true for positive fares', () {
        expect(ValidationHelper.isValidFare(100.0), true);
        expect(ValidationHelper.isValidFare(0.01), true);
      });

      test('returns false for zero or negative', () {
        expect(ValidationHelper.isValidFare(0.0), false);
        expect(ValidationHelper.isValidFare(-100.0), false);
        expect(ValidationHelper.isValidFare(null), false);
      });
    });

    group('isValidSeatCount', () {
      test('returns true for valid seat counts', () {
        expect(ValidationHelper.isValidSeatCount(1), true);
        expect(ValidationHelper.isValidSeatCount(4), true);
        expect(ValidationHelper.isValidSeatCount(10), true);
      });

      test('returns false for invalid seat counts', () {
        expect(ValidationHelper.isValidSeatCount(0), false);
        expect(ValidationHelper.isValidSeatCount(11), false);
        expect(ValidationHelper.isValidSeatCount(-1), false);
        expect(ValidationHelper.isValidSeatCount(null), false);
      });
    });
  });
}
