import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String passengerLocationRequiredTitle = 'Location required';
const String passengerLocationRequiredMessage =
    'Location required to request rides. Please enable Location Services and allow RideConnect to use your location.';
const String passengerLocationValidationMessage =
    "We couldn't get your location. Please enable Location Services and allow the app to access your location, then try again.";
const String passengerLastKnownLocationNote =
    'Using last known location - tap to refresh';

enum PassengerLocationSource { fresh, lastKnown }

class PassengerResolvedLocation {
  const PassengerResolvedLocation({
    required this.point,
    required this.source,
    required this.permission,
  });

  final LatLng point;
  final PassengerLocationSource source;
  final LocationPermission permission;

  bool get usedLastKnown => source == PassengerLocationSource.lastKnown;
}

class PassengerLocationHelper {
  static const Duration freshFixTimeout = Duration(milliseconds: 5000);

  static Future<PassengerResolvedLocation?> resolveRideLocation(
    BuildContext context, {
    Duration timeout = freshFixTimeout,
    bool showLastKnownNote = true,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('serviceEnabled=false');
      if (!context.mounted) return null;
      await showLocationSettingsPrompt(context);
      return null;
    }

    var permission = await Geolocator.checkPermission();
    _log('permissionBefore=$permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      _log('permissionAfterRequest=$permission');
    }

    final granted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (!granted) {
      final lastKnown = await _lastKnown(permission);
      if (lastKnown != null && context.mounted) {
        final useLastKnown = await _confirmUseLastKnown(context);
        if (useLastKnown) {
          if (showLastKnownNote && context.mounted) {
            showUsingLastKnownNote(context);
          }
          return lastKnown;
        }
      }

      if (!context.mounted) return null;
      await showLocationSettingsPrompt(context);
      return null;
    }

    final fresh = await _freshLocation(permission, timeout);
    if (fresh != null) return fresh;

    final lastKnown = await _lastKnown(permission);
    if (lastKnown != null && context.mounted) {
      final useLastKnown = await _confirmUseLastKnown(context);
      if (useLastKnown) {
        if (showLastKnownNote && context.mounted) {
          showUsingLastKnownNote(context);
        }
        return lastKnown;
      }
    }

    if (!context.mounted) return null;
    await showLocationSettingsPrompt(context);
    return null;
  }

  static Future<void> showLocationSettingsPrompt(
    BuildContext context, {
    String message = passengerLocationRequiredMessage,
  }) async {
    if (!context.mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(passengerLocationRequiredTitle),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('retry'),
                child: const Text('Retry'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('settings'),
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );

    if (action == 'settings') {
      await Geolocator.openLocationSettings();
      await Geolocator.openAppSettings();
    }
  }

  static void showUsingLastKnownNote(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(passengerLastKnownLocationNote),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Refresh',
          onPressed: () {
            unawaited(
              PassengerLocationHelper.resolveRideLocation(
                context,
                showLastKnownNote: false,
              ),
            );
          },
        ),
      ),
    );
  }

  static bool isLocationValidationError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('pickup') && text.contains('dropoff') ||
        text.contains('pickup_lat') ||
        text.contains('pickup_lng') ||
        text.contains('dropoff_lat') ||
        text.contains('dropoff_lng') ||
        text.contains('location') && text.contains('required') ||
        text.contains('coordinate') && text.contains('invalid');
  }

  static Future<PassengerResolvedLocation?> _freshLocation(
    LocationPermission permission,
    Duration timeout,
  ) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: timeout,
        ),
      ).timeout(timeout);
      _log(
        'source=fresh permission=$permission coordsPresent=true '
        'lat=${position.latitude} lng=${position.longitude}',
      );
      return PassengerResolvedLocation(
        point: LatLng(position.latitude, position.longitude),
        source: PassengerLocationSource.fresh,
        permission: permission,
      );
    } catch (e) {
      _log('freshLocationFailed=$e');
      return null;
    }
  }

  static Future<PassengerResolvedLocation?> _lastKnown(
    LocationPermission permission,
  ) async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        _log('source=lastKnown coordsPresent=false');
        return null;
      }
      _log(
        'source=lastKnown permission=$permission coordsPresent=true '
        'lat=${position.latitude} lng=${position.longitude}',
      );
      return PassengerResolvedLocation(
        point: LatLng(position.latitude, position.longitude),
        source: PassengerLocationSource.lastKnown,
        permission: permission,
      );
    } catch (e) {
      _log('lastKnownFailed=$e');
      return null;
    }
  }

  static Future<bool> _confirmUseLastKnown(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(passengerLocationRequiredTitle),
            content: const Text(
              'Fresh GPS location is unavailable. Use your last known location for this request?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Use last known location'),
              ),
            ],
          ),
    );
    return confirmed ?? false;
  }

  static void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[PassengerLocation] $message');
  }
}
