// lib/repositories/auth_repository.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/storage/secure_storage_service.dart';

/// Repository for authentication token management.
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  final SecureStorageService _storage = SecureStorageService();

  /// Save the access token securely.
  Future<void> saveToken(String token) async => await _storage.saveToken(token);

  /// Retrieve the stored access token, or null if not present.
  Future<String?> getToken() async => await _storage.getToken();

  /// Clear all authentication related data (token, user info, etc.).
  Future<void> clear() async => await _storage.clearAll();

  /// Returns authentication headers (Bearer token) for API calls.
  /// Throws if no token is available.
  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No auth token found. Please login.');
    }
    return {'Authorization': 'Bearer ${token.trim()}'};
  }
}
