import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';


class AuthSessionData {
  final String role;
  final String name;
  final String email;
  final String? token;

  const AuthSessionData({
    required this.role,
    required this.name,
    required this.email,
    this.token,
  });
}

class AuthSession {
  AuthSession._();

  static const String _kRole = 'auth.role';
  static const String _kName = 'auth.name';
  static const String _kEmail = 'auth.email';
  static const String _kToken = 'auth.token';

  static Future<void> save({
    required String role,
    required String name,
    required String email,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role.trim().toLowerCase());
    await prefs.setString(_kName, name);
    await prefs.setString(_kEmail, email);
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_kToken, token);
    } else {
      await prefs.remove(_kToken);
    }
  }

  static Future<AuthSessionData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    var role = prefs.getString(_kRole);
    var name = prefs.getString(_kName);
    var email = prefs.getString(_kEmail);
    var token = prefs.getString(_kToken);

    if (role == null || role.isEmpty || name == null || email == null || token == null || token.isEmpty) {
      // Fallback: Read from FlutterSecureStorage (used by Riverpod auth flow)
      try {
        const secureStorage = FlutterSecureStorage();
        final secureToken = await secureStorage.read(key: 'auth_token');
        final secureUserJson = await secureStorage.read(key: 'auth_user');
        if (secureToken != null && secureToken.isNotEmpty && secureUserJson != null) {
          final userMap = jsonDecode(secureUserJson) as Map<String, dynamic>;
          name = userMap['name']?.toString() ?? '';
          email = userMap['email']?.toString() ?? '';
          role = userMap['role']?.toString()?.toLowerCase() ?? '';
          token = secureToken;
          
          // Sync back to SharedPreferences
          await save(role: role, name: name, email: email, token: token);
        }
      } catch (_) {}
    }

    if (role == null || role.isEmpty || name == null || email == null) {
      return null;
    }

    return AuthSessionData(role: role, name: name, email: email, token: token);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
    await prefs.remove(_kToken);
    try {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.delete(key: 'auth_token');
      await secureStorage.delete(key: 'auth_user');
      await secureStorage.delete(key: 'access_token');
    } catch (_) {}
  }

  /// Returns the `Authorization: Bearer …` header map.
  /// Throws if no token is stored (forces re-login).
  static Future<Map<String, String>> authHeaders() async {
    final session = await load();
    final token = session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('No auth token found. Please login again.');
    }
    return {'Authorization': 'Bearer ${token.trim()}'};
  }
}
