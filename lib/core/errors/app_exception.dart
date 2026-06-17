/// Base exception class
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Network/API exceptions
class ApiException extends AppException {
  final int? statusCode;

  ApiException({
    required String message,
    this.statusCode,
    String? code,
    dynamic originalError,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
  );
}

/// Authentication exceptions
class AuthException extends AppException {
  AuthException({
    required String message,
    String? code,
    dynamic originalError,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
  );
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, List<String>> errors;

  ValidationException({
    required String message,
    required this.errors,
    String? code,
    dynamic originalError,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
  );

  String get errorSummary => errors.entries
      .map((e) => '${e.key}: ${e.value.join(", ")}')
      .join('; ');
}

/// Network exceptions
class NetworkException extends AppException {
  NetworkException({
    String message = 'Network connection failed',
    String? code,
    dynamic originalError,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
  );
}

/// Not found exceptions
class NotFoundException extends AppException {
  NotFoundException({
    String message = 'Resource not found',
    String? code,
    dynamic originalError,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
  );
}

/// Server exceptions
class ServerException extends AppException {
  ServerException({
    required String message,
    String? code,
    dynamic originalError,
  }) : super(
    message: message,
    code: code,
    originalError: originalError,
  );
}

/// Active trip exists exception
class ActiveTripExistsException extends AppException {
  final int? tripId;
  final String? status;
  final bool canCancel;

  ActiveTripExistsException({
    required String message,
    this.tripId,
    this.status,
    this.canCancel = false,
    String? code,
    dynamic originalError,
  }) : super(
    message: message,
    code: code ?? 'ACTIVE_TRIP_EXISTS',
    originalError: originalError,
  );
}
