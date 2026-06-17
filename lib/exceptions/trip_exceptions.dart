// File: lib/exceptions/trip_exceptions.dart
// Custom Exception Classes for Trip Operations
// Last Updated: May 29, 2026

class TripException implements Exception {
  final String message;
  final String? code;
  final int? httpStatusCode;

  TripException(this.message, {this.code, this.httpStatusCode});

  @override
  String toString() => message;
}

class TripNotFoundException extends TripException {
  TripNotFoundException(super.message)
    : super(code: 'TRIP_NOT_FOUND', httpStatusCode: 404);
}

class InvalidTripIdException extends TripException {
  InvalidTripIdException(int? tripId)
    : super('Invalid trip ID: $tripId', code: 'INVALID_TRIP_ID');
}

class NoDriversAvailableException extends TripException {
  NoDriversAvailableException()
    : super(
        'No drivers available in your area',
        code: 'NO_DRIVERS_AVAILABLE',
        httpStatusCode: 404,
      );
}

class MatchingSessionExpiredException extends TripException {
  MatchingSessionExpiredException()
    : super('Matching session has expired', code: 'SESSION_EXPIRED');
}

class TripAlreadyAssignedException extends TripException {
  TripAlreadyAssignedException(super.message)
    : super(code: 'TRIP_ALREADY_ASSIGNED', httpStatusCode: 409);
}

class TripNotAvailableException extends TripException {
  TripNotAvailableException(super.message)
    : super(code: 'TRIP_NOT_AVAILABLE', httpStatusCode: 422);
}

class DriverNotFoundException extends TripException {
  DriverNotFoundException()
    : super(
        'Driver profile not found. Please complete registration.',
        code: 'DRIVER_NOT_FOUND',
        httpStatusCode: 404,
      );
}

class UnauthorizedTripException extends TripException {
  UnauthorizedTripException(super.message)
    : super(code: 'UNAUTHORIZED', httpStatusCode: 401);
}

class TripPolicyViolationException extends TripException {
  TripPolicyViolationException(super.message)
    : super(code: 'POLICY_VIOLATION', httpStatusCode: 403);
}

class NetworkException implements Exception {
  final String message;
  final String? code;

  NetworkException(this.message, {this.code = 'NETWORK_ERROR'});

  @override
  String toString() => message;
}

class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => message;
}
