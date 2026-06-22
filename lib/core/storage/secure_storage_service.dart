import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'dart:math' as math;
import 'dart:convert';

class SecureStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _deviceIdKey = 'device_id';

  final FlutterSecureStorage _storage;
  final Logger _logger;

  SecureStorageService({
    FlutterSecureStorage? storage,
    Logger? logger,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _logger = logger ?? Logger();

  /// Save auth token
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      _logger.d('Token saved to secure storage');
    } catch (e) {
      _logger.e('Error saving token to secure storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth.token', token);
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      _logger.e('Error saving token to SharedPreferences: $e');
    }
  }

  /// Get stored token
  Future<String?> getToken() async {
    String? token;
    try {
      token = await _storage.read(key: _tokenKey);
    } catch (e) {
      _logger.e('Error reading token from secure storage: $e');
    }
    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('auth.token') ?? prefs.getString(_tokenKey);
      } catch (e) {
        _logger.e('Error reading token from SharedPreferences: $e');
      }
    }
    return token;
  }

  /// Clear token
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
      _logger.d('Token cleared from secure storage');
    } catch (e) {
      _logger.e('Error clearing token from secure storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth.token');
      await prefs.remove(_tokenKey);
    } catch (e) {
      _logger.e('Error clearing token from SharedPreferences: $e');
    }
  }

  /// Save user data (JSON string)
  Future<void> saveUserData(String userJson) async {
    try {
      await _storage.write(key: _userKey, value: userJson);
      _logger.d('User data saved to secure storage');
    } catch (e) {
      _logger.e('Error saving user data to secure storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth.user', userJson);
      await prefs.setString(_userKey, userJson);
      
      // Also try to sync name/email/role for AuthSession compatibility!
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      final name = userMap['name']?.toString() ?? '';
      final email = userMap['email']?.toString() ?? '';
      final role = userMap['role']?.toString()?.toLowerCase() ?? '';
      await prefs.setString('auth.name', name);
      await prefs.setString('auth.email', email);
      await prefs.setString('auth.role', role);
    } catch (e) {
      _logger.e('Error saving user data to SharedPreferences: $e');
    }
  }

  /// Get stored user data
  Future<String?> getUserData() async {
    String? data;
    try {
      data = await _storage.read(key: _userKey);
    } catch (e) {
      _logger.e('Error reading user data from secure storage: $e');
    }
    if (data == null || data.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        data = prefs.getString('auth.user') ?? prefs.getString(_userKey);
      } catch (e) {
        _logger.e('Error reading user data from SharedPreferences: $e');
      }
    }
    return data;
  }

  /// Save FCM token
  Future<void> saveFcmToken(String fcmToken) async {
    try {
      await _storage.write(key: _fcmTokenKey, value: fcmToken);
      _logger.d('FCM token saved to secure storage');
    } catch (e) {
      _logger.e('Error saving FCM token to secure storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, fcmToken);
    } catch (e) {
      _logger.e('Error saving FCM token to SharedPreferences: $e');
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    String? token;
    try {
      token = await _storage.read(key: _fcmTokenKey);
    } catch (e) {
      _logger.e('Error reading FCM token from secure storage: $e');
    }
    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString(_fcmTokenKey);
      } catch (e) {
        _logger.e('Error reading FCM token from SharedPreferences: $e');
      }
    }
    return token;
  }

  /// Clear all auth data (logout)
  Future<void> clearAll() async {
    try {
      await Future.wait([
        _storage.delete(key: _tokenKey),
        _storage.delete(key: _userKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
      _logger.d('All auth data cleared from secure storage');
    } catch (e) {
      _logger.e('Error clearing secure storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth.token');
      await prefs.remove('auth.user');
      await prefs.remove('auth.name');
      await prefs.remove('auth.email');
      await prefs.remove('auth.role');
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_refreshTokenKey);
    } catch (e) {
      _logger.e('Error clearing SharedPreferences: $e');
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get or create a persistent device ID
  Future<String> getOrCreateDeviceId() async {
    String? deviceId;
    try {
      deviceId = await _storage.read(key: _deviceIdKey);
    } catch (e) {
      _logger.e('Error reading device ID from secure storage: $e');
    }
    
    if (deviceId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        deviceId = prefs.getString(_deviceIdKey);
      } catch (_) {}
    }

    if (deviceId == null) {
      final rnd = math.Random.secure();
      final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
      deviceId = base64UrlEncode(bytes);
      
      try {
        await _storage.write(key: _deviceIdKey, value: deviceId);
      } catch (_) {}
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_deviceIdKey, deviceId);
      } catch (_) {}
      
      _logger.d('Generated new device ID: $deviceId');
    }
    return deviceId;
  }
}
