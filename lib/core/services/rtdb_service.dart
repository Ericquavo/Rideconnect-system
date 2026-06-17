import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';

/// Central service for RTDB operations
/// Replaces Firestore completely
class RTDBService {
  final FirebaseDatabase _database;
  final Logger _logger;

  RTDBService({
    FirebaseDatabase? database,
    Logger? logger,
  })  : _database = database ?? FirebaseDatabase.instance,
        _logger = logger ?? Logger();

  /// RTDB Node Paths (Constants)
  static const String driversOnlinePath = 'drivers_online';
  static const String driverLocationsPath = 'driver_locations';
  static const String activeTripsPath = 'active_trips';
  static const String tripTrackingPath = 'trip_tracking';
  static const String presencePath = 'presence';
  static const String notificationQueuePath = 'notification_queue';
  static const String emergencyAlertsPath = 'emergency_alerts';

  /// Get driver online status
  Future<bool> isDriverOnline(String driverId) async {
    try {
      final snapshot = await _database.ref('$driversOnlinePath/$driverId').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        return data?['status'] == 'online' ?? false;
      }
      return false;
    } catch (e) {
      _logger.e('Error checking driver online status: $e');
      return false;
    }
  }

  /// Set driver online/offline
  Future<void> setDriverStatus(String driverId, bool isOnline) async {
    try {
      await _database.ref('$driversOnlinePath/$driverId').update({
        'status': isOnline ? 'online' : 'offline',
        'updated_at': ServerValue.timestamp,
      });
    } catch (e) {
      _logger.e('Error setting driver status: $e');
      rethrow;
    }
  }

  /// Update driver location
  Future<void> updateDriverLocation(
    String driverId, {
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    try {
      await _database.ref('$driverLocationsPath/$driverId').set({
        'lat': lat,
        'lng': lng,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
        'updated_at': ServerValue.timestamp,
      });
    } catch (e) {
      _logger.e('Error updating driver location: $e');
      rethrow;
    }
  }

  /// Get driver location stream
  Stream<Map<String, dynamic>?> getDriverLocationStream(String driverId) {
    return _database
        .ref('$driverLocationsPath/$driverId')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(
          event.snapshot.value as Map? ?? {},
        );
      }
      return null;
    });
  }

  /// Listen to active trip status
  Stream<Map<String, dynamic>?> getTripStatusStream(int tripId) {
    return _database
        .ref('$activeTripsPath/$tripId')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(
          event.snapshot.value as Map? ?? {},
        );
      }
      return null;
    });
  }

  /// Update trip status
  Future<void> updateTripStatus(int tripId, String status) async {
    try {
      await _database.ref('$activeTripsPath/$tripId/status').set(status);
      await _database
          .ref('$activeTripsPath/$tripId/updated_at')
          .set(ServerValue.timestamp);
    } catch (e) {
      _logger.e('Error updating trip status: $e');
      rethrow;
    }
  }

  /// Get trip tracking stream (live driver location during trip)
  Stream<Map<String, dynamic>?> getTripTrackingStream(int tripId) {
    return _database
        .ref('$tripTrackingPath/$tripId')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(
          event.snapshot.value as Map? ?? {},
        );
      }
      return null;
    });
  }

  /// Set user online presence
  Future<void> setUserPresence(String userId, bool isOnline) async {
    try {
      await _database.ref('$presencePath/$userId').set({
        'online': isOnline,
        'last_seen': ServerValue.timestamp,
      });
    } catch (e) {
      _logger.e('Error setting user presence: $e');
      rethrow;
    }
  }

  /// Listen to incoming trip assignment (for driver)
  Stream<Map<String, dynamic>?> getIncomingTripStream(String driverId) {
    return _database
        .ref('$driversOnlinePath/$driverId/assigned_trip')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(
          event.snapshot.value as Map? ?? {},
        );
      }
      return null;
    });
  }

  /// Listen to notification queue for a user
  Stream<List<Map<String, dynamic>>> getNotificationStream(String userId) {
    return _database
        .ref('$notificationQueuePath/$userId')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map?;
        return (data ?? {})
            .entries
            .map((e) => Map<String, dynamic>.from(e.value as Map? ?? {}))
            .toList();
      }
      return [];
    });
  }

  /// Get RTDB reference for custom operations
  DatabaseReference ref(String path) => _database.ref(path);

  /// Enable offline persistence
  Future<void> enableOfflinePersistence() async {
    try {
      _database.setPersistenceEnabled(true);
    } catch (e) {
      _logger.e('Error enabling offline persistence: $e');
    }
  }

  /// Cleanup and disconnect
  Future<void> dispose() async {
    try {
      await _database.ref().onDisconnect().cancel();
    } catch (e) {
      _logger.e('Error during cleanup: $e');
    }
  }
}
