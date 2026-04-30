import 'dart:convert';
import 'package:http/http.dart' as http;

class OtpResult {
  final bool success;
  final String message;
  final String? requestId;
  final String? token;
  final String? email;
  final String? role;
  final String? name;

  OtpResult({
    required this.success,
    required this.message,
    this.requestId,
    this.token,
    this.email,
    this.role,
    this.name,
  });
}

class OtpService {
  OtpService._();

  static const String _hostUrl = 'https://rideconnect-emp0.onrender.com';
  static const String _baseUrl = '$_hostUrl/api/v1';
  static const String _sendOtpUrl = '$_baseUrl/auth/otp/send';
  static const String _verifyOtpUrl = '$_baseUrl/auth/otp/verify';
  static const Duration _timeout = Duration(seconds: 20);

  /// Send OTP to user's email
  static Future<OtpResult> sendOtp({
    required String email,
    String? userType, // 'passenger' or 'driver'
  }) async {
    try {
      final payload = {
        'email': email.trim(),
        if (userType != null && userType.isNotEmpty)
          'user_type': userType.toLowerCase(),
      };

      final response = await http
          .post(
            Uri.parse(_sendOtpUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      final Map<String, dynamic> data = _decodeObject(response.body);

      final isSuccess =
          (data['success'] as bool?) ??
          (response.statusCode >= 200 && response.statusCode < 300);

      if (!isSuccess) {
        return OtpResult(
          success: false,
          message: _asString(data['message']) ?? 'Failed to send OTP',
        );
      }

      final requestId =
          _asString(data['request_id']) ?? _asString(data['otp_request_id']);

      return OtpResult(
        success: true,
        message:
            _asString(data['message']) ?? 'OTP sent successfully to your email',
        requestId: requestId,
      );
    } catch (e) {
      return OtpResult(
        success: false,
        message: 'Unable to send OTP. Please try again.',
      );
    }
  }

  /// Verify OTP and get authentication token
  static Future<OtpResult> verifyOtp({
    required String email,
    required String otp,
    required String requestId,
  }) async {
    try {
      final payload = {
        'email': email.trim(),
        'otp': otp.trim(),
        'request_id': requestId.trim(),
      };

      final response = await http
          .post(
            Uri.parse(_verifyOtpUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      final Map<String, dynamic> data = _decodeObject(response.body);

      final isSuccess =
          (data['success'] as bool?) ??
          (response.statusCode >= 200 && response.statusCode < 300);

      if (!isSuccess) {
        return OtpResult(
          success: false,
          message: _asString(data['message']) ?? 'Invalid OTP',
        );
      }

      final userMap = _extractUserMap(data);
      final token = _asString(data['token']) ?? _asString(data['access_token']);
      final role =
          _asString(userMap['role']) ?? _asString(data['role']) ?? 'passenger';
      final name =
          _asString(userMap['name']) ??
          _asString(data['name']) ??
          'RideConnect User';

      return OtpResult(
        success: true,
        message: _asString(data['message']) ?? 'OTP verified successfully',
        token: token,
        email: email.trim(),
        role: role,
        name: name,
      );
    } catch (e) {
      return OtpResult(
        success: false,
        message: 'Failed to verify OTP. Please try again.',
      );
    }
  }

  /// Resend OTP
  static Future<OtpResult> resendOtp({
    required String email,
    String? userType,
  }) async {
    // Resend is same as send
    return sendOtp(email: email, userType: userType);
  }

  static Map<String, dynamic> _extractUserMap(Map<String, dynamic> data) {
    final nested = _findNestedMap(data, 'data');
    final user = nested != null ? _findNestedMap(nested, 'user') : null;
    return user ?? _findNestedMap(data, 'user') ?? data;
  }

  static Map<String, dynamic>? _findNestedMap(
    Map<String, dynamic> source,
    String key,
  ) {
    final value = source[key];
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
  }

  static Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
