import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';

/// HTTP client with retry logic and error handling
class HttpClient {
  final Dio _dio;
  final Logger _logger;

  HttpClient({Dio? dio, Logger? logger})
    : _dio = dio ?? Dio(),
      _logger = logger ?? Logger();

  void initialize({
    required String baseUrl,
    required String Function() getToken,
  }) {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      sendTimeout: AppConstants.apiTimeout,
      contentType: 'application/json',
      headers: {'Accept': 'application/json'},
    );

    _dio.interceptors.clear();
    _dio.interceptors.add(
      _TokenInterceptor(getToken: getToken, logger: _logger),
    );
    _dio.interceptors.add(_ErrorInterceptor(logger: _logger));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (object) => _logger.d(object),
        ),
      );
    }
  }

  void setToken(String token) {}
  void clearToken() {}

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? converter,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _handleResponse(response, converter);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? converter,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, converter);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? converter,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, converter);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// PATCH request
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? converter,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, converter);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? converter,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, converter);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  T _handleResponse<T>(Response response, T Function(dynamic)? converter) {
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw ApiException(
        message: 'HTTP Error: ${response.statusCode}',
        statusCode: response.statusCode,
        code: 'HTTP_ERROR',
      );
    }

    if (converter != null) {
      return converter(response.data);
    }

    return response.data as T;
  }

  AppException _handleDioException(DioException e) {
    _logger.e('DioException: ${e.message}', error: e, stackTrace: e.stackTrace);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return TimeoutException(
          message: 'Request timeout. Please try again.',
          code: 'TIMEOUT',
          originalError: e,
        );
      case DioExceptionType.badResponse:
        return _handleResponseError(e);
      case DioExceptionType.cancel:
        return NetworkException(
          message: 'Request cancelled',
          code: 'CANCELLED',
          originalError: e,
        );
      case DioExceptionType.unknown:
        if (e.error is NetworkException) return e.error as NetworkException;
        return NetworkException(
          message: e.message ?? AppConstants.networkErrorMessage,
          code: 'NETWORK_ERROR',
          originalError: e,
        );
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: 'SSL Certificate Error',
          code: 'SSL_ERROR',
          originalError: e,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          message: AppConstants.networkErrorMessage,
          code: 'CONNECTION_ERROR',
          originalError: e,
        );
    }
  }

  AppException _handleResponseError(DioException e) {
    final statusCode = e.response?.statusCode ?? 500;
    final responseData = e.response?.data;

    String message = AppConstants.unknownErrorMessage;
    if (responseData is Map) {
      message = responseData['message'] as String? ?? message;
    }

    switch (statusCode) {
      case 400:
        return ValidationException(
          message: message,
          code: 'VALIDATION_ERROR',
          originalError: e,
        );
      case 401:
        return AuthException(
          message: AppConstants.unauthorizedMessage,
          code: 'UNAUTHORIZED',
          originalError: e,
        );
      case 403:
        return ForbiddenException(
          message: message,
          code: 'FORBIDDEN',
          originalError: e,
        );
      case 404:
        return NotFoundException(
          message: message,
          code: 'NOT_FOUND',
          originalError: e,
        );
      case 409:
        return ConflictException(
          message: message,
          code: 'CONFLICT',
          originalError: e,
        );
      case 422:
        return ValidationException(
          message: message,
          code: 'VALIDATION_ERROR',
          originalError: e,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          message: AppConstants.serverErrorMessage,
          code: 'SERVER_ERROR',
          originalError: e,
        );
      default:
        return ApiException(
          message: message,
          statusCode: statusCode,
          code: 'API_ERROR',
          originalError: e,
        );
    }
  }
}

/// Token interceptor to add auth token to requests
class _TokenInterceptor extends Interceptor {
  final String Function() getToken;
  final Logger logger;

  _TokenInterceptor({required this.getToken, required this.logger});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final token = getToken();
      if (token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      logger.w('Token retrieval failed: $e');
    }
    handler.next(options);
  }
}

/// Error interceptor for handling common error patterns
class _ErrorInterceptor extends Interceptor {
  final Logger logger;

  _ErrorInterceptor({required this.logger});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e(
      'API Error: ${err.response?.statusCode} - ${err.message}',
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}

/// Retry interceptor for automatic request retry
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration delay;
  final Logger logger;
  final bool Function(DioException)? retryIf;

  RetryInterceptor({
    required this.maxRetries,
    required this.delay,
    required this.logger,
    this.retryIf,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Don't retry if retryIf returns false
    if (retryIf != null && !retryIf!(err)) {
      return handler.next(err);
    }

    // Only retry on certain status codes
    if (err.response?.statusCode != null) {
      final statusCode = err.response!.statusCode!;
      if (![408, 429, 500, 502, 503, 504].contains(statusCode)) {
        return handler.next(err);
      }
    }

    // Check retry count
    final retryCount = (err.requestOptions.extra['retryCount'] ?? 0) as int;
    if (retryCount >= maxRetries) {
      return handler.next(err);
    }

    logger.w(
      'Retrying request: ${err.requestOptions.path} (attempt ${retryCount + 1}/$maxRetries)',
    );

    // Wait before retrying
    await Future.delayed(delay * (retryCount + 1));

    // Increment retry count
    err.requestOptions.extra['retryCount'] = retryCount + 1;

    handler.next(err);
  }
}
