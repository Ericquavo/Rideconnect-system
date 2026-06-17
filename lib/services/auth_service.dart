import 'dart:convert';

import 'package:logger/logger.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../models/user_model.dart';
import 'api_repository.dart';
import 'fcm_service.dart';

/// Authentication service
class AuthService {
  final SecureStorageService _secureStorage;
  final ApiRepository _apiRepository;
  final Logger _logger;

  AuthService({
    required SecureStorageService secureStorage,
    required ApiRepository apiRepository,
    Logger? logger,
  }) : _secureStorage = secureStorage,
       _apiRepository = apiRepository,
       _logger = logger ?? Logger();

  /// Login with email and password
  Future<User> login({required String email, required String password}) async {
    try {
      _logger.d('Logging in user: $email');

      final request = LoginRequest(email: email, password: password);

      final response = await _apiRepository.login(request);

      if (!response.success) {
        throw AuthException(message: 'Login failed');
      }

      // Store tokens
      await _secureStorage.saveToken(response.token);
      // Store user data as JSON string
      await _secureStorage.saveUserData(jsonEncode(response.user.toJson()));

      // Update HTTP client token
      _apiRepository.setAuthToken(response.token);

      _logger.d('Login successful for user: ${response.user.id}');

      // Sync FCM token
      try {
        await FcmService.instance.registerDevice();
      } catch (e) {
        _logger.w('Failed to register FCM device: $e');
      }

      return response.user;
    } catch (e) {
      _logger.e('Login error', error: e);
      rethrow;
    }
  }

  /// Register new user
  Future<User> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String userType,
  }) async {
    try {
      _logger.d('Registering new user: $email as $userType');

      final request = RegisterRequest(
        name: name,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
        userType: userType,
      );

      final response = await _apiRepository.register(request);

      if (!response.success) {
        throw AuthException(message: 'Registration failed');
      }

      // Store tokens
      await _secureStorage.saveToken(response.token);
      // Store user data as JSON string
      await _secureStorage.saveUserData(jsonEncode(response.user.toJson()));

      // Update HTTP client token
      _apiRepository.setAuthToken(response.token);

      _logger.d('Registration successful for user: ${response.user.id}');

      return response.user;
    } catch (e) {
      _logger.e('Registration error', error: e);
      rethrow;
    }
  }

  /// Refresh access token using refresh token
  Future<void> refreshAccessToken() async {
    // Sanctum tokens do not auto-refresh.
    return;
  }

  /// Logout user
  Future<void> logout() async {
    try {
      _logger.d('Logging out user');

      try {
        await _apiRepository.logout();
      } catch (e) {
        _logger.w('Logout API call failed', error: e);
      }

      // Clear stored data
      await _secureStorage.clearAll();

      // Clear HTTP client token
      _apiRepository.clearAuthToken();

      _logger.d('Logout successful');
    } catch (e) {
      _logger.e('Logout error', error: e);
      rethrow;
    }
  }

  /// Get stored access token
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.getToken();
    } catch (e) {
      _logger.e('Error getting access token', error: e);
      return null;
    }
  }

  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    try {
      // Sanctum doesn't use refresh tokens
      return null;
    } catch (e) {
      _logger.e('Error getting refresh token', error: e);
      return null;
    }
  }

  /// Get stored user ID
  Future<int?> getUserId() async {
    try {
      final userJson = await _secureStorage.getUserData();
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return userMap['id'] as int?;
      }
      return null;
    } catch (e) {
      _logger.e('Error getting user ID', error: e);
      return null;
    }
  }

  /// Get stored user type
  Future<String?> getUserType() async {
    try {
      final userJson = await _secureStorage.getUserData();
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return userMap['role'] as String?;
      }
      return null;
    } catch (e) {
      _logger.e('Error getting user type', error: e);
      return null;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      _logger.e('Error checking login status', error: e);
      return false;
    }
  }

  /// Check if token needs refresh
  Future<bool> tokenNeedsRefresh() async {
    try {
      // This is a simple check - in production, parse JWT token expiry
      final token = await getAccessToken();
      return token == null || token.isEmpty;
    } catch (e) {
      _logger.e('Error checking token refresh', error: e);
      return true;
    }
  }

  /// Initialize auth service on app startup
  Future<void> initializeAuth() async {
    try {
      _logger.d('Initializing authentication');

      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        _apiRepository.setAuthToken(token);
        _logger.d('Authentication initialized with stored token');
      } else {
        _logger.d('No stored token found');
      }
    } catch (e) {
      _logger.e('Error initializing authentication', error: e);
    }
  }
}
