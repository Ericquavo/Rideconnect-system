import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverPreferencesService {
  DriverPreferencesService._();

  static const String _kRideRequestAlerts = 'driver.ride_request_alerts';
  static const String _kAppNotifications = 'driver.app_notifications';
  static const String _kAutoRefreshRequests = 'driver.auto_refresh_requests';
  static const String _kLiveLocationSharing = 'driver.live_location_sharing';
  static const String _kDataSaverMode = 'driver.data_saver_mode';

  static final ValueNotifier<bool> rideRequestAlertsNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> appNotificationsNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> autoRefreshRequestsNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> liveLocationSharingNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> dataSaverModeNotifier = ValueNotifier<bool>(
    false,
  );

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    rideRequestAlertsNotifier.value =
        prefs.getBool(_kRideRequestAlerts) ?? true;
    appNotificationsNotifier.value = prefs.getBool(_kAppNotifications) ?? true;
    autoRefreshRequestsNotifier.value =
        prefs.getBool(_kAutoRefreshRequests) ?? true;
    liveLocationSharingNotifier.value =
        prefs.getBool(_kLiveLocationSharing) ?? true;
    dataSaverModeNotifier.value = prefs.getBool(_kDataSaverMode) ?? false;

    _initialized = true;
  }

  static bool get rideRequestAlerts => rideRequestAlertsNotifier.value;
  static bool get appNotifications => appNotificationsNotifier.value;
  static bool get autoRefreshRequests => autoRefreshRequestsNotifier.value;
  static bool get liveLocationSharing => liveLocationSharingNotifier.value;
  static bool get dataSaverMode => dataSaverModeNotifier.value;

  static Future<void> setRideRequestAlerts(bool value) async {
    rideRequestAlertsNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRideRequestAlerts, value);
  }

  static Future<void> setAppNotifications(bool value) async {
    appNotificationsNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAppNotifications, value);
  }

  static Future<void> setAutoRefreshRequests(bool value) async {
    autoRefreshRequestsNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoRefreshRequests, value);
  }

  static Future<void> setLiveLocationSharing(bool value) async {
    liveLocationSharingNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLiveLocationSharing, value);
  }

  static Future<void> setDataSaverMode(bool value) async {
    dataSaverModeNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDataSaverMode, value);
  }
}
