import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class SecureStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _fcmTokenKey = 'fcm_token';

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
      _logger.d('Token saved');
    } catch (e) {
      _logger.e('Error saving token: $e');
      rethrow;
    }
  }

  /// Get stored token
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      _logger.e('Error reading token: $e');
      return null;
    }
  }

  /// Clear token
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
      _logger.d('Token cleared');
    } catch (e) {
      _logger.e('Error clearing token: $e');
      rethrow;
    }
  }

  /// Save user data (JSON string)
  Future<void> saveUserData(String userJson) async {
    try {
      await _storage.write(key: _userKey, value: userJson);
      _logger.d('User data saved');
    } catch (e) {
      _logger.e('Error saving user data: $e');
      rethrow;
    }
  }

  /// Get stored user data
  Future<String?> getUserData() async {
    try {
      return await _storage.read(key: _userKey);
    } catch (e) {
      _logger.e('Error reading user data: $e');
      return null;
    }
  }

  /// Save FCM token
  Future<void> saveFcmToken(String fcmToken) async {
    try {
      await _storage.write(key: _fcmTokenKey, value: fcmToken);
      _logger.d('FCM token saved');
    } catch (e) {
      _logger.e('Error saving FCM token: $e');
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    try {
      return await _storage.read(key: _fcmTokenKey);
    } catch (e) {
      _logger.e('Error reading FCM token: $e');
      return null;
    }
  }

  /// Clear all auth data (logout)
  Future<void> clearAll() async {
    try {
      await Future.wait([
        _storage.delete(key: _tokenKey),
        _storage.delete(key: _userKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
      _logger.d('All auth data cleared');
    } catch (e) {
      _logger.e('Error clearing auth data: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
