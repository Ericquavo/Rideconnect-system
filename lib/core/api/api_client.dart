import 'package:dio/dio.dart';

import '../../auth/auth_session.dart';

class ApiClient {
  ApiClient({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://rideconnect-emp0.onrender.com/api/v1',
    ),
    Dio? dio,
    this.timeout = const Duration(seconds: 20),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: timeout,
               receiveTimeout: timeout,
               sendTimeout: timeout,
               responseType: ResponseType.json,
               headers: const {
                 'Accept': 'application/json',
                 'Content-Type': 'application/json',
               },
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers.addAll(await AuthSession.authHeaders());
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            AuthSession.clear();
          }
          handler.next(error);
        },
      ),
    );
  }

  final String baseUrl;
  final Dio _dio;
  final Duration timeout;

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) => _send('POST', path, body: body, query: query);

  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) => _send('PUT', path, body: body, query: query);

  Future<ApiResponse> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) => _send('DELETE', path, body: body, query: query);

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    Response<dynamic> response;
    try {
      switch (method) {
        case 'GET':
          response = await _dio.get<dynamic>(
            path,
            queryParameters: _query(query),
          );
          break;
        case 'POST':
          response = await _dio.post<dynamic>(
            path,
            data: body ?? {},
            queryParameters: _query(query),
          );
          break;
        case 'PUT':
          response = await _dio.put<dynamic>(
            path,
            data: body ?? {},
            queryParameters: _query(query),
          );
          break;
        case 'DELETE':
          response = await _dio.delete<dynamic>(
            path,
            data: body ?? {},
            queryParameters: _query(query),
          );
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method', 0, {});
      }
    } on DioException catch (e) {
      throw _dioException(e);
    }

    final envelope = _decodeData(response.data);
    final statusCode = response.statusCode ?? 0;
    final ok = statusCode >= 200 && statusCode < 300;
    final success = envelope['success'] ?? envelope['status'];
    final accepted =
        success is bool
            ? success
            : success == 'success' || success == 'ok' || ok;

    if (!accepted) {
      final error = envelope['error'];
      final message =
          envelope['message'] ??
          (error is Map<String, dynamic> ? error['description'] : error) ??
          'Request failed ($statusCode)';
      throw ApiException(message.toString(), statusCode, envelope);
    }

    return ApiResponse(statusCode, envelope);
  }

  ApiException _dioException(DioException error) {
    final statusCode = error.response?.statusCode ?? 0;
    final envelope = _decodeData(error.response?.data);
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(
        'Request timed out. Check your connection and retry.',
        408,
        envelope,
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return ApiException(
        'Network error. Please check your connection.',
        0,
        envelope,
      );
    }
    final responseError = envelope['error'];
    final message =
        envelope['message'] ??
        (responseError is Map<String, dynamic>
            ? responseError['description'] ?? responseError['message']
            : responseError) ??
        error.message ??
        'Request failed ($statusCode)';
    return ApiException(message.toString(), statusCode, envelope);
  }

  Map<String, dynamic>? _query(Map<String, dynamic>? query) {
    final filtered = <String, String>{};
    query?.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isNotEmpty) filtered[key] = text;
    });
    return filtered.isEmpty ? null : filtered;
  }

  Map<String, dynamic> _decodeData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}

class ApiResponse {
  ApiResponse(this.statusCode, this.envelope);

  final int statusCode;
  final Map<String, dynamic> envelope;

  dynamic get data =>
      envelope['data'] ?? envelope['trip'] ?? envelope['request'];

  Map<String, dynamic> get dataMap {
    final value = data;
    if (value is Map<String, dynamic>) return value;
    return envelope;
  }

  List<Map<String, dynamic>> list(List<String> keys) {
    final value = data;
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    if (value is Map<String, dynamic>) {
      for (final key in keys) {
        final candidate = value[key];
        if (candidate is List) {
          return candidate.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    for (final key in keys) {
      final candidate = envelope[key];
      if (candidate is List) {
        return candidate.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode, this.raw);

  final String message;
  final int statusCode;
  final Map<String, dynamic> raw;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 422;

  @override
  String toString() => message;
}
