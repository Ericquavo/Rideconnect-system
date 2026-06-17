// lib/services/api_client.dart

import 'package:dio/dio.dart';
import 'package:rideconnect_app/config/api_config.dart'; // adjust import path if needed
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  final _logger = Logger();

  ApiClient._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: ApiConfig.baseUrl, // Base URL without version; endpoints add version
      connectTimeout: Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
      sendTimeout: Duration(milliseconds: ApiConfig.sendTimeout),
      headers: ApiHeaders.defaultHeaders(),
    );
    dio = Dio(options);
    _addInterceptors();
  }

  void _addInterceptors() {
    // Authorization interceptor
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null && token.isNotEmpty) {
        options.headers[ApiHeaders.authorization] = 'Bearer $token';
      }
      return handler.next(options);
    }, onError: (DioException e, handler) {
      // Convert error payload to ApiException (simple example)
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        final message = data['message']?.toString() ?? e.message ?? 'Unknown error';
        final code = e.response?.statusCode ?? 0;
        return handler.reject(DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          error: ApiException(message, code, data['errors'] ?? {}),
          type: e.type,
        ));
      }
      return handler.next(e);
    }));
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic errors; // could be Map<String, List<String>>
  ApiException(this.message, this.statusCode, this.errors);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
