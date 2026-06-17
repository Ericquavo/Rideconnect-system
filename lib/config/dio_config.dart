// File: lib/config/dio_config.dart
// Dio HTTP Client Configuration for RideConnect API
// Last Updated: May 29, 2026

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';

class DioConfig {
  static Dio createDioClient({
    String? baseUrl,
    String? authToken,
    bool enableLogging = ApiConfig.enableLogging,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConfig.baseUrl,
        connectTimeout: Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
        sendTimeout: Duration(milliseconds: ApiConfig.sendTimeout),
        contentType: 'application/json',
        headers: ApiHeaders.defaultHeaders(token: authToken),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Add interceptors
    if (enableLogging) {
      dio.interceptors.add(LoggingInterceptor());
    }

    dio.interceptors.add(AuthInterceptor(authToken: authToken));

    dio.interceptors.add(ErrorHandlingInterceptor());

    dio.interceptors.add(
      RetryInterceptor(
        maxRetries: ApiConfig.maxRetries,
        retryDelayMs: ApiConfig.retryDelayMs,
      ),
    );

    return dio;
  }

  static Dio createMlServiceClient({
    String? authToken,
    bool enableLogging = ApiConfig.enableLogging,
  }) {
    return createDioClient(
      baseUrl: ApiConfig.mlServiceUrl,
      authToken: authToken,
      enableLogging: enableLogging,
    );
  }
}

/// Logging Interceptor for debugging API calls
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('🌐 [API REQUEST]');
      print('   URL: ${options.baseUrl}${options.path}');
      print('   Method: ${options.method}');
      print('   Headers: ${options.headers}');
      if (options.data != null) {
        print('   Body: ${options.data}');
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('✅ [API RESPONSE]');
      print('   Status: ${response.statusCode}');
      print('   URL: ${response.requestOptions.path}');
      print('   Data: ${response.data}');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('❌ [API ERROR]');
      print('   URL: ${err.requestOptions.path}');
      print('   Status: ${err.response?.statusCode}');
      print('   Message: ${err.message}');
      print('   Response: ${err.response?.data}');
    }
    super.onError(err, handler);
  }
}

/// Authentication Interceptor for token management
class AuthInterceptor extends Interceptor {
  final String? authToken;

  AuthInterceptor({this.authToken});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (authToken != null && authToken!.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $authToken';
    }
    super.onRequest(options, handler);
  }
}

/// Error Handling Interceptor for consistent error responses
class ErrorHandlingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final errorResponse = _parseError(err);
    if (kDebugMode) {
      print('🚨 Handled Error: ${errorResponse['message']}');
    }
    super.onError(err, handler);
  }

  Map<String, dynamic> _parseError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return {
          'type': 'CONNECTION_TIMEOUT',
          'message':
              'Connection timeout. Please check your internet connection.',
          'code': 'TIMEOUT_CONNECTION',
        };
      case DioExceptionType.sendTimeout:
        return {
          'type': 'SEND_TIMEOUT',
          'message': 'Request timeout. Please try again.',
          'code': 'TIMEOUT_SEND',
        };
      case DioExceptionType.receiveTimeout:
        return {
          'type': 'RECEIVE_TIMEOUT',
          'message': 'Response timeout. Please try again.',
          'code': 'TIMEOUT_RECEIVE',
        };
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        if (statusCode == 404) {
          return {
            'type': 'NOT_FOUND',
            'message': 'Resource not found',
            'code': 'NOT_FOUND',
            'statusCode': 404,
          };
        } else if (statusCode == 401) {
          return {
            'type': 'UNAUTHORIZED',
            'message': 'Authentication failed. Please login again.',
            'code': 'UNAUTHORIZED',
            'statusCode': 401,
          };
        } else if (statusCode == 403) {
          return {
            'type': 'FORBIDDEN',
            'message': 'You do not have permission to access this resource.',
            'code': 'FORBIDDEN',
            'statusCode': 403,
          };
        } else if (statusCode == 422) {
          return {
            'type': 'VALIDATION_ERROR',
            'message': 'Invalid request data',
            'code': 'VALIDATION_FAILED',
            'statusCode': 422,
            'errors': err.response?.data['errors'],
          };
        } else if (statusCode! >= 500) {
          return {
            'type': 'SERVER_ERROR',
            'message': 'Server error. Please try again later.',
            'code': 'SERVER_ERROR',
            'statusCode': statusCode,
          };
        }
        return {
          'type': 'HTTP_ERROR',
          'message': 'Request failed',
          'code': 'HTTP_ERROR',
          'statusCode': statusCode,
        };
      case DioExceptionType.cancel:
        return {
          'type': 'REQUEST_CANCELLED',
          'message': 'Request was cancelled',
          'code': 'CANCELLED',
        };
      case DioExceptionType.unknown:
        return {
          'type': 'UNKNOWN_ERROR',
          'message': 'An unexpected error occurred',
          'code': 'UNKNOWN',
        };
      default:
        return {
          'type': 'UNKNOWN_ERROR',
          'message': 'An unexpected error occurred',
          'code': 'UNKNOWN',
        };
    }
  }
}

/// Retry Interceptor for automatic retry on failure
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final int retryDelayMs;

  /// Track retry count per request
  final Map<String, int> _retryCount = {};

  RetryInterceptor({this.maxRetries = 3, this.retryDelayMs = 1000});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final key = _getRequestKey(err.requestOptions);
    _retryCount[key] = (_retryCount[key] ?? 0) + 1;

    if (_shouldRetry(err) && _retryCount[key]! < maxRetries) {
      if (kDebugMode) {
        print(
          '🔄 Retrying request (${_retryCount[key]}/$maxRetries): ${err.requestOptions.path}',
        );
      }

      // Wait before retrying
      await Future.delayed(
        Duration(milliseconds: retryDelayMs * _retryCount[key]!),
      );

      try {
        final response = await _retry(err.requestOptions);
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else {
      _retryCount.remove(key);
      handler.next(err);
    }
  }

  /// Check if request should be retried
  bool _shouldRetry(DioException err) {
    // Retry on connection timeout, receive timeout, and 5xx errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return true;
    }

    // Retry on 5xx server errors
    if (err.response?.statusCode != null && err.response!.statusCode! >= 500) {
      return true;
    }

    // Don't retry on client errors (4xx)
    return false;
  }

  /// Retry the request
  Future<Response> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    // Create a new client instance for retry
    final dio = Dio();
    return dio.request<dynamic>(
      requestOptions.baseUrl + requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  /// Generate unique key for request
  String _getRequestKey(RequestOptions options) {
    return '${options.method}:${options.path}';
  }
}

/// Service Locator for Dio instances (optional but recommended)
class DioServiceLocator {
  static final DioServiceLocator _instance = DioServiceLocator._internal();

  late Dio _mainDio;
  late Dio _mlServiceDio;

  factory DioServiceLocator() {
    return _instance;
  }

  DioServiceLocator._internal();

  /// Initialize Dio clients with optional auth token
  void initialize({String? authToken}) {
    _mainDio = DioConfig.createDioClient(authToken: authToken);
    _mlServiceDio = DioConfig.createMlServiceClient(authToken: authToken);
  }

  /// Get main API Dio client
  Dio getMainDio() {
    return _mainDio;
  }

  /// Get ML Service Dio client
  Dio getMlServiceDio() {
    return _mlServiceDio;
  }

  /// Update auth token
  void updateAuthToken(String token) {
    _mainDio.options.headers['Authorization'] = 'Bearer $token';
    _mlServiceDio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear auth token
  void clearAuthToken() {
    _mainDio.options.headers.remove('Authorization');
    _mlServiceDio.options.headers.remove('Authorization');
  }
}
