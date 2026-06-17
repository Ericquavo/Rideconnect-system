import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'app_exception.dart';

class ErrorHandler {
  static final Logger _logger = Logger();

  /// Parse Dio error into AppException
  static AppException handleError(dynamic error) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      return _handleDioError(error);
    }

    return ApiException(
      message: error.toString(),
      originalError: error,
    );
  }

  static AppException _handleDioError(DioException error) {
    _logger.e('DioException: ${error.type} - ${error.message}');

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message: 'Connection timeout',
          originalError: error,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          message: 'Connection error',
          originalError: error,
        );

      case DioExceptionType.unknown:
        if (error.message?.contains('Connection refused') ?? false) {
          return NetworkException(
            message: 'Connection refused',
            originalError: error,
          );
        }
        return ApiException(
          message: error.message ?? 'Unknown error',
          originalError: error,
        );

      case DioExceptionType.badResponse:
        return _handleResponseError(error);

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request cancelled',
          originalError: error,
        );

      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'Bad certificate',
          originalError: error,
        );
    }
  }

  static AppException _handleResponseError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    _logger.e('Response error: $statusCode - $data');

    switch (statusCode) {
      case 400:
        return _handle400Error(data);

      case 401:
        return AuthException(
          message: 'Unauthorized - invalid credentials or expired token',
          code: 'UNAUTHORIZED',
        );

      case 403:
        return AuthException(
          message: 'Forbidden - access denied',
          code: 'FORBIDDEN',
        );

      case 404:
        return NotFoundException(
          message: 'Resource not found',
        );

      case 422:
        return _handle422Error(data);

      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          message: 'Server error (Status: $statusCode)',
          code: 'SERVER_ERROR',
        );

      default:
        return ApiException(
          message: 'API error (Status: $statusCode)',
          statusCode: statusCode,
          originalError: error,
        );
    }
  }

  static AppException _handle400Error(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String?;
      final errors = data['errors'] as Map<String, dynamic>?;

      if (errors != null && errors.isNotEmpty) {
        final fieldErrors = <String, List<String>>{};
        errors.forEach((key, value) {
          if (value is List) {
            fieldErrors[key] = value.cast<String>();
          } else if (value is String) {
            fieldErrors[key] = [value];
          }
        });

        return ValidationException(
          message: message ?? 'Validation error',
          errors: fieldErrors,
          code: 'VALIDATION_ERROR',
        );
      }

      return ApiException(
        message: message ?? 'Bad request',
        code: 'BAD_REQUEST',
      );
    }

    return ApiException(
      message: 'Bad request',
      code: 'BAD_REQUEST',
    );
  }

  static AppException _handle422Error(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String?;
      final errors = data['errors'] as Map<String, dynamic>?;

      if (errors != null && errors.isNotEmpty) {
        final fieldErrors = <String, List<String>>{};
        errors.forEach((key, value) {
          if (value is List) {
            fieldErrors[key] = value.cast<String>();
          } else if (value is String) {
            fieldErrors[key] = [value];
          }
        });

        return ValidationException(
          message: message ?? 'Validation failed',
          errors: fieldErrors,
          code: 'VALIDATION_ERROR',
        );
      }

      return ValidationException(
        message: message ?? 'Validation failed',
        errors: {},
        code: 'VALIDATION_ERROR',
      );
    }

    return ValidationException(
      message: 'Validation failed',
      errors: {},
      code: 'VALIDATION_ERROR',
    );
  }

  /// Get user-friendly error message
  static String getErrorMessage(AppException exception) {
    if (exception is AuthException) {
      return exception.message;
    }

    if (exception is ValidationException) {
      return exception.errorSummary.isNotEmpty
          ? exception.errorSummary
          : exception.message;
    }

    if (exception is NetworkException) {
      return 'Network connection error. Please check your connection.';
    }

    if (exception is NotFoundException) {
      return exception.message;
    }

    if (exception is ServerException) {
      return 'Server error. Please try again later.';
    }

    return exception.message;
  }
}
