import 'package:shared_preferences/shared_preferences.dart';

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
    final role = prefs.getString(_kRole);
    final name = prefs.getString(_kName);
    final email = prefs.getString(_kEmail);

    if (role == null || role.isEmpty || name == null || email == null) {
      return null;
    }

    final token = prefs.getString(_kToken);
    return AuthSessionData(role: role, name: name, email: email, token: token);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
    await prefs.remove(_kToken);
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
