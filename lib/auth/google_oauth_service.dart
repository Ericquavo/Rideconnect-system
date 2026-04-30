import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleOAuthConfig {
  // Configuration should be loaded from environment variables or a secure config file
  // DO NOT hardcode credentials in source code
  static String get clientId =>
      const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID', defaultValue: '');
  static String get clientSecret => const String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_SECRET',
    defaultValue: '',
  );
  static const String redirectUrl =
      'http://localhost:8000/auth/google/callback';
  static const String authorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String revokeEndpoint = 'https://oauth2.googleapis.com/revoke';
  static const String userInfoEndpoint =
      'https://www.googleapis.com/oauth2/v2/userinfo';
  static const List<String> scopes = ['openid', 'email', 'profile'];
}

class GoogleOAuthResult {
  final bool success;
  final String message;
  final String? accessToken;
  final String? idToken;
  final String? email;
  final String? name;
  final String? picture;
  final DateTime? expiresAt;

  GoogleOAuthResult({
    required this.success,
    required this.message,
    this.accessToken,
    this.idToken,
    this.email,
    this.name,
    this.picture,
    this.expiresAt,
  });
}

class GoogleOAuthService {
  GoogleOAuthService._();

  static String getAuthorizationUrl({String? state}) {
    final params = {
      'client_id': GoogleOAuthConfig.clientId,
      'redirect_uri': GoogleOAuthConfig.redirectUrl,
      'response_type': 'code',
      'scope': GoogleOAuthConfig.scopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
      if (state != null) 'state': state,
    };

    final uri = Uri.parse(
      GoogleOAuthConfig.authorizationEndpoint,
    ).replace(queryParameters: params);
    return uri.toString();
  }

  static Future<GoogleOAuthResult> exchangeCodeForToken(String code) async {
    try {
      final response = await http
          .post(
            Uri.parse(GoogleOAuthConfig.tokenEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'code': code,
              'client_id': GoogleOAuthConfig.clientId,
              'client_secret': GoogleOAuthConfig.clientSecret,
              'redirect_uri': GoogleOAuthConfig.redirectUrl,
              'grant_type': 'authorization_code',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return GoogleOAuthResult(
          success: false,
          message: 'Failed to exchange code for token',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final idToken = data['id_token'] as String?;
      final expiresIn = data['expires_in'] as int?;

      if (accessToken == null) {
        return GoogleOAuthResult(
          success: false,
          message: 'No access token received',
        );
      }

      // Decode ID token to get user info
      final userInfo = _decodeIdToken(idToken);

      final expiresAt =
          expiresIn != null
              ? DateTime.now().add(Duration(seconds: expiresIn))
              : null;

      return GoogleOAuthResult(
        success: true,
        message: 'Successfully authenticated with Google',
        accessToken: accessToken,
        idToken: idToken,
        email: userInfo['email'] as String?,
        name: userInfo['name'] as String?,
        picture: userInfo['picture'] as String?,
        expiresAt: expiresAt,
      );
    } catch (e) {
      return GoogleOAuthResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  static Future<GoogleOAuthResult> getUserInfo(String accessToken) async {
    try {
      final response = await http
          .get(
            Uri.parse(GoogleOAuthConfig.userInfoEndpoint),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return GoogleOAuthResult(
          success: false,
          message: 'Failed to fetch user info',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return GoogleOAuthResult(
        success: true,
        message: 'User info retrieved successfully',
        email: data['email'] as String?,
        name: data['name'] as String?,
        picture: data['picture'] as String?,
      );
    } catch (e) {
      return GoogleOAuthResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  static Future<GoogleOAuthResult> refreshAccessToken(
    String refreshToken,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(GoogleOAuthConfig.tokenEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'client_id': GoogleOAuthConfig.clientId,
              'client_secret': GoogleOAuthConfig.clientSecret,
              'refresh_token': refreshToken,
              'grant_type': 'refresh_token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return GoogleOAuthResult(
          success: false,
          message: 'Failed to refresh token',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final expiresIn = data['expires_in'] as int?;

      if (accessToken == null) {
        return GoogleOAuthResult(
          success: false,
          message: 'No new access token received',
        );
      }

      final expiresAt =
          expiresIn != null
              ? DateTime.now().add(Duration(seconds: expiresIn))
              : null;

      return GoogleOAuthResult(
        success: true,
        message: 'Token refreshed successfully',
        accessToken: accessToken,
        expiresAt: expiresAt,
      );
    } catch (e) {
      return GoogleOAuthResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  static Map<String, dynamic> _decodeIdToken(String? idToken) {
    if (idToken == null) return {};

    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return {};

      final payload = parts[1];
      // Add padding if necessary
      final padding = 4 - (payload.length % 4);
      final paddedPayload = padding == 4 ? payload : payload + ('=' * padding);

      final decoded = utf8.decode(base64Url.decode(paddedPayload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}
