import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';

@pragma('vm:entry-point')
Future<void> rideConnectFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // App-level Firebase options may be configured by the target build.
  }
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  static const _tokenKey = 'notifications.fcm_token';
  late FirebaseMessaging _messaging;
  final ApiClient _api = ApiClient();

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(
        rideConnectFirebaseMessagingBackgroundHandler,
      );
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      _messaging.onTokenRefresh.listen((token) {
        registerDevice(tokenOverride: token);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmService] Firebase init skipped: $e');
      }
    }
  }

  Future<String?> currentToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> registerDevice({String? tokenOverride}) async {
    final permission = await _messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    final token = tokenOverride ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return null;
    await _api.post(
      '/devices/push-token',
      body: {'device_token': token, 'platform': _platform, 'device_id': token},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    return token;
  }

  Future<void> unregisterDevice(String token) async {
    await _api.delete('/devices/push-token/$token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FcmService] foreground message: ${message.data}');
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FcmService] opened message: ${message.data}');
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
