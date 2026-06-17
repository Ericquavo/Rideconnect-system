import 'dart:convert';

import 'package:logger/logger.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../datasources/auth_datasource.dart';
import '../models/auth_response.dart';

abstract class IAuthRepository {
  Future<AuthData> login({
    required String email,
    required String password,
    required String deviceName,
    required String fcmToken,
  });

  Future<void> logout();

  Future<bool> validateToken();

  Future<AuthData?> getStoredAuth();

  Future<void> clearAuth();
}

class AuthRepository implements IAuthRepository {
  final IAuthDataSource dataSource;
  final SecureStorageService storage;
  final Logger logger;

  AuthRepository({
    required this.dataSource,
    required this.storage,
    Logger? logger,
  }) : logger = logger ?? Logger();

  @override
  Future<AuthData> login({
    required String email,
    required String password,
    required String deviceName,
    required String fcmToken,
  }) async {
    try {
      final response = await dataSource.login(
        email: email,
        password: password,
        deviceName: deviceName,
        fcmToken: fcmToken,
      );

      if (response.success && response.data != null) {
        final authData = response.data!;

        // Save token and user data
        await storage.saveToken(authData.token);
        await storage.saveUserData(jsonEncode(authData.user.toJson()));
        await storage.saveFcmToken(fcmToken);

        logger.d(
          'Login successful for user: ${authData.user.name} '
          '(${authData.user.phone})',
        );

        return authData;
      } else {
        throw AuthException(
          message: response.message ?? 'Login failed',
          code: 'LOGIN_FAILED',
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      logger.e('Login error: $e');
      throw ApiException(message: 'Login failed: $e', originalError: e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Call logout API
      await dataSource.logout();

      // Clear local storage
      await storage.clearAll();
      logger.d('Logout successful');
    } catch (e) {
      logger.e('Logout error: $e');
      // Still clear local storage even if API fails
      try {
        await storage.clearAll();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<bool> validateToken() async {
    try {
      final token = await storage.getToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      final isValid = await dataSource.validateToken();

      if (!isValid) {
        logger.w('Token validation failed - clearing');
        await storage.clearToken();
      }

      return isValid;
    } catch (e) {
      logger.e('Token validation error: $e');
      return false;
    }
  }

  @override
  Future<AuthData?> getStoredAuth() async {
    try {
      final token = await storage.getToken();
      final userJson = await storage.getUserData();

      if (token == null || userJson == null) {
        return null;
      }

      final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);

      return AuthData(token: token, user: user);
    } catch (e) {
      logger.e('Error getting stored auth: $e');
      return null;
    }
  }

  @override
  Future<void> clearAuth() async {
    try {
      await storage.clearAll();
      logger.d('Auth cleared');
    } catch (e) {
      logger.e('Error clearing auth: $e');
      rethrow;
    }
  }
}
