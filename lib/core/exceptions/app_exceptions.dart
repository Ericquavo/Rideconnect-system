
/// Base exception class for the application
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException({required this.message, this.code, this.originalError});

  @override
  String toString() => message;
}

/// Authentication-related exceptions
class AuthException extends AppException {
  AuthException({required super.message, super.code, super.originalError});
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// API-related exceptions
class ApiException extends AppException {
  final int? statusCode;

  ApiException({
    required super.message,
    this.statusCode,
    super.code,
    super.originalError,
  });
}

/// Validation-related exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException({
    required super.message,
    this.fieldErrors,
    super.code,
    super.originalError,
  });
}

/// Offline/Connectivity exceptions
class OfflineException extends AppException {
  OfflineException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Server exceptions (5xx errors)
class ServerException extends AppException {
  ServerException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Not found exceptions (404)
class NotFoundException extends AppException {
  NotFoundException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Forbidden exceptions (403)
class ForbiddenException extends AppException {
  ForbiddenException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Conflict exceptions (409)
class ConflictException extends AppException {
  ConflictException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Timeout exceptions
class TimeoutException extends AppException {
  TimeoutException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Location-related exceptions
class LocationException extends AppException {
  LocationException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Trip-related exceptions
class TripException extends AppException {
  TripException({required super.message, super.code, super.originalError});
}
