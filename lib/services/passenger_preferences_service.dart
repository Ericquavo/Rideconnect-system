import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PassengerPreferencesService {
  PassengerPreferencesService._();

  static const String _kLocationSharing = 'passenger.location_sharing';
  static const String _kPushNotifications = 'passenger.push_notifications';
  static const String _kRideRequestAlerts = 'passenger.ride_request_alerts';
  static const String _kAutoRefreshDashboard =
      'passenger.auto_refresh_dashboard';
  static const String _kProfilePhotoBase64 = 'passenger.profile_photo_b64';

  static final ValueNotifier<bool> locationSharingNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> pushNotificationsNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> rideRequestAlertsNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> autoRefreshDashboardNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<Uint8List?> profilePhotoNotifier =
      ValueNotifier<Uint8List?>(null);

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    final locationSharing = prefs.getBool(_kLocationSharing) ?? true;
    final pushNotifications = prefs.getBool(_kPushNotifications) ?? true;
    final rideRequestAlerts = prefs.getBool(_kRideRequestAlerts) ?? true;
    final autoRefreshDashboard = prefs.getBool(_kAutoRefreshDashboard) ?? true;
    final photoRaw = prefs.getString(_kProfilePhotoBase64);

    locationSharingNotifier.value = locationSharing;
    pushNotificationsNotifier.value = pushNotifications;
    rideRequestAlertsNotifier.value = rideRequestAlerts;
    autoRefreshDashboardNotifier.value = autoRefreshDashboard;
    profilePhotoNotifier.value = _decodePhoto(photoRaw);

    _initialized = true;
  }

  static bool get locationSharing => locationSharingNotifier.value;
  static bool get pushNotifications => pushNotificationsNotifier.value;
  static bool get rideRequestAlerts => rideRequestAlertsNotifier.value;
  static bool get autoRefreshDashboard => autoRefreshDashboardNotifier.value;
  static Uint8List? get profilePhoto => profilePhotoNotifier.value;

  static Future<void> setLocationSharing(bool value) async {
    locationSharingNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationSharing, value);
  }

  static Future<void> setPushNotifications(bool value) async {
    pushNotificationsNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPushNotifications, value);
  }

  static Future<void> setRideRequestAlerts(bool value) async {
    rideRequestAlertsNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRideRequestAlerts, value);
  }

  static Future<void> setAutoRefreshDashboard(bool value) async {
    autoRefreshDashboardNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoRefreshDashboard, value);
  }

  static Future<void> setProfilePhotoBytes(Uint8List? bytes) async {
    profilePhotoNotifier.value = bytes;
    final prefs = await SharedPreferences.getInstance();
    if (bytes == null || bytes.isEmpty) {
      await prefs.remove(_kProfilePhotoBase64);
      return;
    }

    final encoded = base64Encode(bytes);
    await prefs.setString(_kProfilePhotoBase64, encoded);
  }

  static Uint8List? _decodePhoto(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}
