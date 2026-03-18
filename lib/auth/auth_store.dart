/// Simple in-memory credential store.
/// Holds the account registered during the current session.
class AuthStore {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  String? _email;
  String? _password;
  String? _name;

  /// Save credentials when a new account is created.
  void register({
    required String name,
    required String email,
    required String password,
  }) {
    _name = name;
    _email = email.trim().toLowerCase();
    _password = password;
  }

  /// Returns the stored full name if [email] + [password] match, otherwise null.
  String? login({required String email, required String password}) {
    if (_email == null) return null;
    if (email.trim().toLowerCase() == _email && password == _password) {
      return _name;
    }
    return null;
  }

  bool get hasAccount => _email != null;
}
