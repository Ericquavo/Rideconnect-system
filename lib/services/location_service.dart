import 'dart:async';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://rideconnect-emp0.onrender.com/api',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));
  Timer? _locationTimer;

  // Start background location updates
  Future<void> startTracking(String token, {int? activeTripId}) async {
    // 1. Request GPS Permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    // Stop any existing tracking first
    stopTracking();

    // 2. Start Timer for periodic updates every 3 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _sendLocationUpdate(
          token: token,
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading.toInt(),
          speed: position.speed,
          accuracy: position.accuracy,
          tripId: activeTripId,
        );
      } catch (e) {
        print("Error fetching/sending location: $e");
      }
    });
  }

  // Stop background location updates
  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // Send coordinates payload to backend
  Future<void> _sendLocationUpdate({
    required String token,
    required double latitude,
    required double longitude,
    int? heading,
    double? speed,
    double? accuracy,
    int? tripId,
  }) async {
    try {
      final response = await _dio.post(
        '/v3/location/update',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'heading': heading,
          'speed': speed,
          'accuracy': accuracy,
          'trip_id': tripId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200) {
        print("Location synchronized successfully.");
      }
    } catch (e) {
      print("Failed to sync location to server: $e");
    }
  }
}
