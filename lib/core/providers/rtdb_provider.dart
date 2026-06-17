import 'package:riverpod/riverpod.dart';
import '../../core/services/rtdb_service.dart';

/// Provider for RTDBService
/// Single instance shared across the app
final rtdbServiceProvider = Provider<RTDBService>((ref) {
  return RTDBService();
});

/// Trip status stream provider
/// Watches real-time changes to a specific trip
final tripStatusStreamProvider = StreamProvider.family<
    Map<String, dynamic>?,
    int>((ref, tripId) {
  final rtdb = ref.watch(rtdbServiceProvider);
  return rtdb.getTripStatusStream(tripId);
});

/// Trip tracking stream provider
/// Watches driver location during trip
final tripTrackingStreamProvider = StreamProvider.family<
    Map<String, dynamic>?,
    int>((ref, tripId) {
  final rtdb = ref.watch(rtdbServiceProvider);
  return rtdb.getTripTrackingStream(tripId);
});

/// Driver location stream provider
final driverLocationStreamProvider = StreamProvider.family<
    Map<String, dynamic>?,
    String>((ref, driverId) {
  final rtdb = ref.watch(rtdbServiceProvider);
  return rtdb.getDriverLocationStream(driverId);
});

/// Incoming trip requests stream provider (for driver)
final incomingTripRequestsProvider = StreamProvider.family<
    Map<String, dynamic>?,
    String>((ref, driverId) {
  final rtdb = ref.watch(rtdbServiceProvider);
  return rtdb.getIncomingTripStream(driverId);
});

/// Notifications stream provider
final notificationsStreamProvider = StreamProvider.family<
    Map<String, dynamic>?,
    String>((ref, userId) {
  final rtdb = ref.watch(rtdbServiceProvider);
  return rtdb.getNotificationStream(userId).map((list) => list.isNotEmpty ? list.first : null);
});
