import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthApiLoginResult {
  final bool success;
  final String message;
  final String role;
  final String name;
  final String email;
  final String? token;

  const AuthApiLoginResult({
    required this.success,
    required this.message,
    required this.role,
    required this.name,
    required this.email,
    this.token,
  });
}

class AuthApi {
  AuthApi._();

  static const String _baseUrl = 'https://rideconnect-emp0.onrender.com';
  static const String _loginUrl = '$_baseUrl/api/v1/auth/login';
  static const String _clearSessionUrl = '$_baseUrl/api/v1/auth/session/clear';
  static const String _validateTokenUrl =
      '$_baseUrl/api/v1/auth/token/validate';

  static Future<AuthApiLoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );

      final Map<String, dynamic> data = _decodeObject(response.body);
      final bool isSuccess =
          _asBool(data['success']) ??
          (response.statusCode >= 200 && response.statusCode < 300);

      if (!isSuccess) {
        return AuthApiLoginResult(
          success: false,
          message: _asString(data['message']) ?? 'Invalid credentials.',
          role: '',
          name: '',
          email: email.trim(),
        );
      }

      final userMap = _extractUserMap(data);
      final role =
          _asString(userMap['role']) ??
          _asString(userMap['type']) ??
          _asString(data['role']) ??
          _asString(data['type']) ??
          '';

      final userName =
          _asString(userMap['name']) ??
          _asString(data['name']) ??
          'RideConnect User';
      final userEmail =
          _asString(userMap['email']) ??
          _asString(data['email']) ??
          email.trim();

      return AuthApiLoginResult(
        success: true,
        message: _asString(data['message']) ?? 'Login successful.',
        role: role.toLowerCase(),
        name: userName,
        email: userEmail,
        token: _extractToken(data),
      );
    } catch (_) {
      return AuthApiLoginResult(
        success: false,
        message: 'Unable to reach server. Please try again.',
        role: '',
        name: '',
        email: email.trim(),
      );
    }
  }

  static Map<String, dynamic> _extractUserMap(Map<String, dynamic> data) {
    final nestedData = _findNestedMap(data, 'data');
    final nestedUser =
        nestedData != null ? _findNestedMap(nestedData, 'user') : null;
    return nestedUser ?? _findNestedMap(data, 'user') ?? data;
  }

  static String? _extractToken(Map<String, dynamic> data) {
    final directToken =
        _asString(data['token']) ?? _asString(data['access_token']);
    if (directToken != null && directToken.isNotEmpty) {
      return directToken;
    }

    final nestedData = _findNestedMap(data, 'data');
    if (nestedData != null) {
      final nestedToken =
          _asString(nestedData['token']) ??
          _asString(nestedData['access_token']);
      if (nestedToken != null && nestedToken.isNotEmpty) {
        return nestedToken;
      }
    }

    return null;
  }

  static Future<bool> validateToken({required String token}) async {
    if (token.trim().isEmpty) return false;

    try {
      final response = await http.get(
        Uri.parse(_validateTokenUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = _decodeObject(response.body);
      final successField = _asBool(body['success']);
      final validField = _asBool(body['valid']);
      final errorMap = _findNestedMap(body, 'error');
      final errorCode = _asString(errorMap?['code']) ?? _asString(body['code']);

      if (response.statusCode == 404 || errorCode == 'ENDPOINT_NOT_FOUND') {
        // Keep session usable while backend validation endpoint is unavailable.
        return true;
      }

      if (validField != null) return validField;
      if (successField != null) return successField;

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearSession({String? token}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    try {
      final postResponse = await http.post(
        Uri.parse(_clearSessionUrl),
        headers: headers,
      );

      if (postResponse.statusCode == 405) {
        await http.get(Uri.parse(_clearSessionUrl), headers: headers);
      }
    } catch (_) {
      // Best-effort remote logout; local session cleanup still happens.
    }
  }

  static Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic>? _findNestedMap(
    Map<String, dynamic> root,
    String key,
  ) {
    final value = root[key];
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }
}
