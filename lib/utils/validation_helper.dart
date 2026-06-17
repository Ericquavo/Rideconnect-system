// File: lib/utils/validation_helper.dart
// Validation Helper for Trip IDs and other inputs
// Last Updated: May 29, 2026

class ValidationHelper {
  /// Validates that a trip ID is valid (not null, not 0, positive integer)
  static bool isValidTripId(int? tripId) {
    return tripId != null && tripId > 0;
  }

  /// Safely parse trip ID from various sources
  static int? parseTripId(dynamic tripId) {
    if (tripId == null) return null;

    if (tripId is int) {
      return tripId > 0 ? tripId : null;
    }

    if (tripId is String) {
      try {
        final parsed = int.parse(tripId);
        return parsed > 0 ? parsed : null;
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// Asserts that a trip ID is valid, throws if not
  static int assertValidTripId(int? tripId, {String? message}) {
    if (!isValidTripId(tripId)) {
      throw ArgumentError(
        message ?? 'Trip ID must be a positive integer, got: $tripId',
      );
    }
    return tripId!;
  }

  /// Validates email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validates phone number (basic validation)
  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-()]{10,}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Validates password strength
  static bool isValidPassword(String password) {
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }

  /// Validates latitude
  static bool isValidLatitude(double? lat) {
    return lat != null && lat >= -90.0 && lat <= 90.0;
  }

  /// Validates longitude
  static bool isValidLongitude(double? lng) {
    return lng != null && lng >= -180.0 && lng <= 180.0;
  }

  /// Validates location coordinates
  static bool isValidLocation(double? lat, double? lng) {
    return isValidLatitude(lat) && isValidLongitude(lng);
  }

  /// Validates driver ID
  static bool isValidDriverId(int? driverId) {
    return driverId != null && driverId > 0;
  }

  /// Validates passenger ID
  static bool isValidPassengerId(int? passengerId) {
    return passengerId != null && passengerId > 0;
  }

  /// Validates session ID
  static bool isValidSessionId(String? sessionId) {
    return sessionId != null && sessionId.trim().isNotEmpty;
  }

  /// Validates fare amount
  static bool isValidFare(double? fare) {
    return fare != null && fare > 0;
  }

  /// Validates seat count
  static bool isValidSeatCount(int? seats) {
    return seats != null && seats > 0 && seats <= 10;
  }

  /// Get user-friendly error message for validation failure
  static String getValidationErrorMessage(String fieldName, String? reason) {
    if (reason != null) return reason;

    return switch (fieldName) {
      'email' => 'Please enter a valid email address',
      'password' =>
        'Password must be at least 8 characters with uppercase, lowercase, and numbers',
      'phone' => 'Please enter a valid phone number',
      'latitude' => 'Invalid latitude (must be between -90 and 90)',
      'longitude' => 'Invalid longitude (must be between -180 and 180)',
      'tripId' => 'Invalid trip ID',
      'driverId' => 'Invalid driver ID',
      'passengerId' => 'Invalid passenger ID',
      'fare' => 'Invalid fare amount',
      'seats' => 'Invalid seat count (1-10)',
      _ => 'Invalid $fieldName',
    };
  }
}
