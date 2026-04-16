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

class AuthApiRegisterResult {
  final bool success;
  final String message;
  final String role;
  final String name;
  final String email;
  final String? token;

  const AuthApiRegisterResult({
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

  static const String _hostUrl = 'https://rideconnect-emp0.onrender.com';
  static const String _baseUrl = '$_hostUrl/api/v1';
  static const String _loginUrl = '$_baseUrl/auth/mobile/login';
  static const String _fallbackLoginUrl = '$_baseUrl/auth/login';
  static const String _clearSessionUrl = '$_baseUrl/auth/session/clear';
  static const String _logoutUrl = '$_baseUrl/auth/logout';
  static const Duration _timeout = Duration(seconds: 20);
  static const String _validateTokenUrl = '$_baseUrl/auth/token/validate';

  static Future<AuthApiRegisterResult> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    final normalizedRole =
        role.trim().toLowerCase() == 'driver' ? 'driver' : 'passenger';
    final payload = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'role': normalizedRole,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    };

    final roleSpecificPath = '/api/v1/auth/register/$normalizedRole';
    const genericPath = '/api/v1/auth/register';

    try {
      http.Response response;
      try {
        response = await _postJson(
          Uri.parse('$_hostUrl$roleSpecificPath'),
          body: payload,
        );
      } catch (_) {
        response = await _postJson(
          Uri.parse('$_hostUrl$genericPath'),
          body: payload,
        );
      }

      final Map<String, dynamic> data = _decodeObject(response.body);
      final bool isSuccess =
          _asBool(data['success']) ??
          (response.statusCode >= 200 && response.statusCode < 300);

      if (!isSuccess) {
        return AuthApiRegisterResult(
          success: false,
          message:
              _asString(data['message']) ??
              'Registration failed. Please try again.',
          role: normalizedRole,
          name: name.trim(),
          email: email.trim(),
        );
      }

      final userMap = _extractUserMap(data);
      final resolvedRole = _resolveRole(data, userMap) ?? normalizedRole;

      return AuthApiRegisterResult(
        success: true,
        message: _asString(data['message']) ?? 'Registration successful.',
        role: resolvedRole,
        name:
            _asString(userMap['name']) ??
            _asString(data['name']) ??
            name.trim(),
        email:
            _asString(userMap['email']) ??
            _asString(data['email']) ??
            email.trim(),
        token: _extractToken(data),
      );
    } catch (_) {
      return AuthApiRegisterResult(
        success: false,
        message: 'Unable to reach server. Please try again.',
        role: normalizedRole,
        name: name.trim(),
        email: email.trim(),
      );
    }
  }

  static Future<AuthApiLoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      http.Response response;
      try {
        response = await _postJson(
          Uri.parse(_loginUrl),
          body: {'email': email.trim(), 'password': password},
        );
      } catch (_) {
        response = await _postJson(
          Uri.parse(_fallbackLoginUrl),
          body: {'email': email.trim(), 'password': password},
        );
      }

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
      final token = _extractToken(data);
      var role = _resolveRole(data, userMap, token: token) ?? '';
      if (role.isEmpty && token != null && token.trim().isNotEmpty) {
        role = await _resolveRoleFromProfileProbe(token) ?? '';
      }

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
        role: role,
        name: userName,
        email: userEmail,
        token: token,
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

  static String? _resolveRole(
    Map<String, dynamic> root,
    Map<String, dynamic> user, {
    String? token,
  }) {
    final candidates = <dynamic>[
      user['role'],
      user['type'],
      user['user_type'],
      user['userType'],
      user['account_type'],
      user['accountType'],
      user['roles'],
      user['user_roles'],
      root['role'],
      root['type'],
      root['user_type'],
      root['userType'],
      root['account_type'],
      root['accountType'],
      root['roles'],
      root['user_roles'],
    ];

    final nestedData = _findNestedMap(root, 'data');
    if (nestedData != null) {
      candidates.addAll(<dynamic>[
        nestedData['role'],
        nestedData['type'],
        nestedData['user_type'],
        nestedData['userType'],
        nestedData['account_type'],
        nestedData['accountType'],
        nestedData['roles'],
        nestedData['user_roles'],
      ]);
      final nestedUser = _findNestedMap(nestedData, 'user');
      if (nestedUser != null) {
        candidates.addAll(<dynamic>[
          nestedUser['role'],
          nestedUser['type'],
          nestedUser['user_type'],
          nestedUser['userType'],
          nestedUser['account_type'],
          nestedUser['accountType'],
          nestedUser['roles'],
          nestedUser['user_roles'],
        ]);
      }
    }

    final jwtRole = _extractRoleFromJwt(token);
    if (jwtRole != null) {
      candidates.add(jwtRole);
    }

    for (final candidate in candidates) {
      final normalized = _normalizeRoleCandidate(candidate);
      if (normalized != null) return normalized;
    }

    return null;
  }

  static String? _normalizeRoleCandidate(dynamic candidate) {
    if (candidate is List) {
      for (final item in candidate) {
        final normalized = _normalizeRoleCandidate(item);
        if (normalized != null) return normalized;
      }
      return null;
    }

    String? raw;
    if (candidate is Map<String, dynamic>) {
      raw =
          _asString(candidate['name']) ??
          _asString(candidate['value']) ??
          _asString(candidate['role']) ??
          _asString(candidate['type']) ??
          _asString(candidate['slug']) ??
          _asString(candidate['user_type']) ??
          _asString(candidate['account_type']);
    } else {
      raw = _asString(candidate);
    }

    if (raw == null) return null;
    final role = raw.trim().toLowerCase();
    if (role.isEmpty) return null;

    if (role == 'driver' ||
        role == 'chauffeur' ||
        role == 'captain' ||
        role.contains('driver')) {
      return 'driver';
    }

    if (role == 'passenger' ||
        role == 'rider' ||
        role == 'client' ||
        role == 'customer' ||
        role == 'user' ||
        role.contains('passenger') ||
        role.contains('rider')) {
      return 'passenger';
    }

    return role;
  }

  static String? _extractRoleFromJwt(String? token) {
    if (token == null || token.trim().isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = parts[1];
      final normalizedPayload = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalizedPayload));
      final claims = jsonDecode(decoded);
      if (claims is! Map<String, dynamic>) return null;

      final candidates = <dynamic>[
        claims['role'],
        claims['roles'],
        claims['type'],
        claims['user_type'],
        claims['account_type'],
        claims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'],
        claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/role'],
      ];

      for (final candidate in candidates) {
        final normalized = _normalizeRoleCandidate(candidate);
        if (normalized != null) return normalized;
      }
    } catch (_) {
      return null;
    }

    return null;
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
      final response = await http
          .get(
            Uri.parse(_validateTokenUrl),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

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
      await http
          .post(Uri.parse(_clearSessionUrl), headers: headers)
          .timeout(_timeout);
    } catch (_) {
      // Best-effort remote logout; local session cleanup still happens.
    }
  }

  static Future<void> logout({String? token}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    try {
      await http
          .post(Uri.parse(_logoutUrl), headers: headers)
          .timeout(_timeout);
    } catch (_) {
      // Logout is best-effort; local cleanup still proceeds in callers.
    }
  }

  static Future<Map<String, dynamic>> getProfile({
    required String token,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };

    final response = await _getWithAlias(
      paths: const ['/auth/profile', '/user/profile'],
      headers: headers,
    );
    final body = _decodeObject(response.body);
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final success = _asBool(body['success']);
    if (!(success ?? ok)) {
      throw Exception(_asString(body['message']) ?? 'Failed to load profile.');
    }
    return body;
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };

    final response = await _putWithAlias(
      paths: const ['/auth/profile', '/user/profile'],
      headers: headers,
      payload: payload,
    );

    final body = _decodeObject(response.body);
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final success = _asBool(body['success']);
    if (!(success ?? ok)) {
      throw Exception(
        _asString(body['message']) ?? 'Failed to update profile.',
      );
    }
    return body;
  }

  static Future<void> updateUserPassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };

    final payload = <String, dynamic>{
      'current_password': currentPassword,
      'new_password': newPassword,
    };

    final response = await http
        .put(
          Uri.parse('$_baseUrl/user/password'),
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    final body = _decodeObject(response.body);
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final success = _asBool(body['success']);
    if (!(success ?? ok)) {
      throw Exception(
        _asString(body['message']) ?? 'Failed to update password.',
      );
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

  static Future<String?> _resolveRoleFromProfileProbe(String token) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };

    try {
      final driverRes = await http.get(
        Uri.parse('$_baseUrl/driver/profile'),
        headers: headers,
      );
      if (driverRes.statusCode >= 200 && driverRes.statusCode < 300) {
        return 'driver';
      }
    } catch (_) {}

    try {
      final passengerRes = await http.get(
        Uri.parse('$_baseUrl/passenger/profile'),
        headers: headers,
      );
      if (passengerRes.statusCode >= 200 && passengerRes.statusCode < 300) {
        return 'passenger';
      }
    } catch (_) {}

    return null;
  }

  static Future<http.Response> _postJson(
    Uri uri, {
    required Map<String, dynamic> body,
  }) {
    return http
        .post(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  static Future<http.Response> _getWithAlias({
    required List<String> paths,
    required Map<String, String> headers,
  }) async {
    Object? lastError;
    for (final path in paths) {
      try {
        final res = await http
            .get(Uri.parse('$_baseUrl$path'), headers: headers)
            .timeout(_timeout);
        if (res.statusCode != 404) return res;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
    return http.Response('{}', 404);
  }

  static Future<http.Response> _putWithAlias({
    required List<String> paths,
    required Map<String, String> headers,
    required Map<String, dynamic> payload,
  }) async {
    Object? lastError;
    for (final path in paths) {
      try {
        final res = await http
            .put(
              Uri.parse('$_baseUrl$path'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(_timeout);
        if (res.statusCode != 404) return res;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
    return http.Response('{}', 404);
  }
}
