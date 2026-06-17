import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../storage/secure_storage_service.dart';
import '../errors/app_exception.dart';
import 'api_endpoints.dart';

/// API Client for RideConnect backend
class ApiClient {
  final Dio _dio;
  final SecureStorageService _storage;
  final Logger _logger;

  ApiClient({
    Dio? dio,
    SecureStorageService? storage,
    Logger? logger,
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? SecureStorageService(),
        _logger = logger ?? Logger() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options
      ..baseUrl = ApiEndpoints.baseUrl
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 30)
      ..headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

    _dio.interceptors.clear();
    _dio.interceptors.add(_AuthInterceptor(_storage, _logger));
    _dio.interceptors.add(_LoggingInterceptor(_logger));
    _dio.interceptors.add(_ErrorInterceptor(_logger));
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      _logger.i('GET $path');
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _logger.e('GET $path failed: ${e.message}');
      throw _handleError(e);
    }
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      _logger.i('POST $path');
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _logger.e('POST $path failed: ${e.message}');
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      _logger.i('PUT $path');
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _logger.e('PUT $path failed: ${e.message}');
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      _logger.i('DELETE $path');
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _logger.e('DELETE $path failed: ${e.message}');
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      _logger.i('PATCH $path');
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _logger.e('PATCH $path failed: ${e.message}');
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    // Handle 409 Conflict (Active trip exists)
    if (statusCode == 409 && responseData is Map) {
      final errorCode = responseData['error_code'];
      if (errorCode == 'ACTIVE_TRIP_EXISTS') {
        return ActiveTripExistsException(
          message: responseData['message'] ?? 'You already have an active trip',
          tripId: responseData['data']?['trip_id'],
          status: responseData['data']?['status'],
          canCancel: responseData['data']?['can_cancel'] ?? false,
        );
      }
    }

    // Handle 422 Validation errors
    if (statusCode == 422 && responseData is Map) {
      final errors = responseData['errors'] as Map<String, dynamic>?;
      return ValidationException(
        message: responseData['message'] ?? 'Validation failed',
        errors: errors?.map((key, value) => MapEntry(
          key,
          value is List ? List<String>.from(value) : [value.toString()],
        )) ?? {},
      );
    }

    // Handle 401 Unauthorized
    if (statusCode == 401) {
      return AuthException(
        message: 'Authentication failed. Please login again.',
        code: 'UNAUTHORIZED',
      );
    }

    // Handle 404 Not Found
    if (statusCode == 404) {
      return NotFoundException(
        message: responseData['message'] ?? 'Resource not found',
      );
    }

    // Handle 500 Server errors
    if (statusCode != null && statusCode >= 500) {
      return ServerException(
        message: responseData['message'] ?? 'Server error occurred',
      );
    }

    // Handle network errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return NetworkException(
        message: 'Request timed out. Please check your connection.',
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return NetworkException(
        message: 'Network error. Please check your connection.',
      );
    }

    // Default error
    return ApiException(
      message: responseData['message'] ?? error.message ?? 'Request failed',
      statusCode: statusCode,
    );
  }

  Dio get dio => _dio;
}

/// Auth interceptor for adding Bearer token
class _AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Logger _logger;

  _AuthInterceptor(this._storage, this._logger);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        _logger.d('Added auth token to request');
      }
    } catch (e) {
      _logger.e('Error adding token: $e');
    }
    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      _logger.w('Received 401 - Dispatching AuthException for re-login');
      // Removed eager token clearing to support multi-device login properly.
    }
    super.onError(err, handler);
  }
}

/// Logging interceptor
class _LoggingInterceptor extends Interceptor {
  final Logger _logger;

  _LoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.i('--> ${options.method} ${options.uri}');
    if (options.data != null) {
      _logger.d('Request: ${options.data}');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.i('<-- ${response.statusCode} ${response.requestOptions.uri}');
    _logger.d('Response: ${response.data}');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e('<-- ERROR ${err.response?.statusCode} ${err.requestOptions.uri}');
    _logger.e('Error: ${err.message}');
    super.onError(err, handler);
  }
}

/// Error interceptor
class _ErrorInterceptor extends Interceptor {
  final Logger _logger;

  _ErrorInterceptor(this._logger);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode != null && response.statusCode! >= 400) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    super.onResponse(response, handler);
  }
}
