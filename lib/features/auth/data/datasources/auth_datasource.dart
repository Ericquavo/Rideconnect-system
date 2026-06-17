import 'package:logger/logger.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/errors/app_exception.dart';
import '../models/auth_response.dart';

abstract class IAuthDataSource {
  Future<AuthResponse> login({
    required String email,
    required String password,
    required String deviceName,
    required String fcmToken,
  });

  Future<void> logout();

  Future<bool> validateToken();
}

class AuthDataSource implements IAuthDataSource {
  final ApiClient apiClient;
  final Logger logger;

  AuthDataSource({
    required this.apiClient,
    Logger? logger,
  }) : logger = logger ?? Logger();

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
    required String deviceName,
    required String fcmToken,
  }) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {
          'email': email,
          'password': password,
          'device_name': deviceName,
          'fcm_token': fcmToken,
        },
      );

      logger.d('Login response status: ${response.statusCode}');

      if (response.data == null) {
        throw ApiException(
          message: 'Empty response from server',
          statusCode: response.statusCode,
        );
      }

      try {
        return AuthResponse.fromJson(response.data!);
      } catch (e) {
        logger.e('Error parsing login response: $e');
        throw ApiException(
          message: 'Invalid response format from server',
          originalError: e,
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      logger.e('Login error: $e');
      throw ApiException(
        message: 'Login failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      await apiClient.post(ApiEndpoints.logout);
      logger.d('Logout successful');
    } catch (e) {
      logger.e('Logout error: $e');
      // Don't rethrow - logout should clear local data even if API call fails
    }
  }

  @override
  Future<bool> validateToken() async {
    try {
      final response = await apiClient.get(ApiEndpoints.validate);
      
      if (response.statusCode == 200) {
        logger.d('Token valid');
        return true;
      }
      
      logger.w('Token validation failed: ${response.statusCode}');
      return false;
    } catch (e) {
      logger.e('Token validation error: $e');
      return false;
    }
  }
}
