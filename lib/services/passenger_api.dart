import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'package:http/http.dart' as http;

import '../repositories/auth_repository.dart';

class PassengerApi {
  PassengerApi._();

  static final PassengerApi instance = PassengerApi._();

  // API root (shared/auth/notifications live here, NOT under /passenger).
  static const String _rootUrl = 'https://rideconnect-emp0.onrender.com/api/v1';
  // Passenger-scoped base.
  static const String _baseUrl = '$_rootUrl/passenger';
  static const Duration _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getProfile() => _get('/profile');

  /// Initialize/create the passenger profile if it doesn't exist.
  /// FIX #5: there is no POST /profile on the backend — only GET and PUT|PATCH.
  /// Call PUT /profile directly instead of attempting POST and falling back.
  Future<Map<String, dynamic>> initializeProfile({
    String? name,
    String? email,
    String? phone,
  }) {
    return _put('/profile', {
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) =>
      _request('POST', '/mobile/profile/update', body: payload, useRootBaseUrl: true);

  Future<Map<String, dynamic>> getStats() => _get('/stats');

  Future<List<Map<String, dynamic>>> getAvailableRides() async {
    final response = await _get('/rides/available');
    return _extractList(response);
  }

  /// Get rides by type and travel mode.
  /// FIX #2: discovery is GET /rides/available (RideController@index).
  /// GET /rides is PassengerController@rideHistory and ignores these filters.
  /// Parameters:
  ///   - transportType: 'CAR' or 'MOTORCYCLE'
  ///   - travelMode: 'SCHEDULED' or 'ON_DEMAND'
  ///   - availableOnly: only return available rides
  Future<List<Map<String, dynamic>>> getRidesByType({
    required String transportType,
    required String travelMode,
    bool availableOnly = true,
  }) async {
    final normalizedTransportType = _normalizeTransportType(transportType);
    final response = await _getWithQuery('/rides/available', {
      'transport_type': normalizedTransportType,
      'travel_mode': travelMode,
      'available_only': availableOnly,
    });
    return _extractList(response);
  }

  Future<Map<String, dynamic>> createRide(Map<String, dynamic> payload) =>
      _post('/rides', payload);

  Future<Map<String, dynamic>> createTripBooking({
    required int rideId,
    required int seats,
    required String pickupAddress,
    required String dropoffAddress,
  }) {
    return _post('/rides', {
      'ride_id': rideId,
      'seats': seats,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
    });
  }

  Future<List<Map<String, dynamic>>> getRides({
    String? status,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    final response = await _getWithQuery('/rides', {
      'status': status,
      'start_date': startDate,
      'end_date': endDate,
      'per_page': perPage,
    });
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getRideHistory({
    String? status,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    Map<String, dynamic> response;
    try {
      response = await _getWithQuery('/rides/history', {
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'per_page': perPage,
      });
    } catch (_) {
      response = await _getWithQuery('/rides', {
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'per_page': perPage,
      });
    }
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getRidesOrHistory({
    String? status,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    final rides = await getRides(
      status: status,
      startDate: startDate,
      endDate: endDate,
      perPage: perPage,
    );
    if (rides.isNotEmpty) return rides;
    return getRideHistory(
      status: status,
      startDate: startDate,
      endDate: endDate,
      perPage: perPage,
    );
  }

  Future<Map<String, dynamic>> getRideById(dynamic rideId) =>
      _get('/rides/$rideId');

  Future<Map<String, dynamic>> cancelRide(dynamic rideId) =>
      _put('/rides/$rideId/cancel', <String, dynamic>{});

  Future<List<Map<String, dynamic>>> getBookings() async {
    final response = await _get('/bookings');
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final response = await _get('/bookings/my');
    return _extractList(response);
  }

  Future<Map<String, dynamic>> getBookingById(dynamic bookingId) =>
      _get('/bookings/$bookingId');

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> payload) =>
      _post('/bookings', payload);

  Future<Map<String, dynamic>> updateBooking(
    dynamic bookingId,
    Map<String, dynamic> payload,
  ) => _put('/bookings/$bookingId', payload);

  Future<Map<String, dynamic>> cancelBooking(dynamic bookingId) =>
      _put('/bookings/$bookingId/cancel', <String, dynamic>{});

  Future<List<Map<String, dynamic>>> getOnlineDrivers() async {
    final response = await _get('/drivers/online');
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getMatchedDrivers({
    required String transportType,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final normalizedTransportType = _normalizeTransportType(transportType);
    final response = await _getWithQuery('/drivers/match', {
      'transport_type': normalizedTransportType,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
    });
    return _extractList(response);
  }

  Future<Map<String, dynamic>> createRideRequest(
    Map<String, dynamic> payload,
  ) => _post('/ride-requests', payload);

  // ===========================================================================
  // MOTOR-VEHICLE (motorcycle / private car) ON-DEMAND TRIP FLOW
  // This is the CURRENT trip-request architecture. The created record lives in
  // the `motorcycle_trips` table, so it must be polled via the motor-vehicle
  // endpoint below — NOT via /trips/{id}/status (that reads a different table).
  // ===========================================================================

  /// Create an on-demand motor-vehicle trip request (auto-matched).
  /// Returns { success, trip_id, status, matching_status, estimated_fare, ... }.
  Future<Map<String, dynamic>> createMotorVehicleTrip({
    required String pickupLocation,
    required String dropoffLocation,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    String transportType = 'MOTORCYCLE',
  }) {
    return _post('/motor-vehicle/trip-requests', {
      'transport_type': _normalizeTransportType(transportType),
      'pickup_location': pickupLocation,
      'dropoff_location': dropoffLocation,
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
      if (dropoffLat != null) 'dropoff_lat': dropoffLat,
      if (dropoffLng != null) 'dropoff_lng': dropoffLng,
    });
  }

  /// Poll the live state of a motor-vehicle trip. SINGLE SOURCE OF TRUTH for the
  /// SEARCHING -> ASSIGNED -> DRIVER_ASSIGNED -> PASSENGER_WAITING -> IN_PROGRESS
  /// -> COMPLETED lifecycle. Returns status, matching_status, driver block, etc.
  Future<Map<String, dynamic>> getMotorVehicleTrip(dynamic tripId) async {
    final response = await _get('/motor-vehicle/trip-requests/$tripId');
    return _extractDataMap(response);
  }

  Future<Map<String, dynamic>> getActiveTrip() async {
    final response = await _get('/trips/active');
    return _extractDataMap(response);
  }

  /// FIX #4: motor-vehicle cancel is POST /motor-vehicle/trip-requests/{id}/cancel
  /// (the old PUT /ride-requests/{id}/cancel route does not exist).
  Future<Map<String, dynamic>> cancelMotorVehicleTrip(
    dynamic tripId, {
    String? reason,
  }) => _post('/motor-vehicle/trip-requests/$tripId/cancel', {
    if (reason != null && reason.isNotEmpty) 'reason': reason,
  });

  Future<Map<String, dynamic>> bookPublicBusSeat({
    required int corridorId,
    required int boardingStopId,
    required int destinationStopId,
    int? busRouteAssignmentId,
    int seatsReserved = 1,
    String? pickupLocation,
    double? pickupLat,
    double? pickupLng,
    String? dropoffLocation,
    double? dropoffLat,
    double? dropoffLng,
  }) {
    final payload = <String, dynamic>{
      'transport_type': 'PUBLIC_BUS',
      'seats_reserved': seatsReserved,
      'corridor_id': corridorId,
      'boarding_stop_id': boardingStopId,
      'destination_stop_id': destinationStopId,
      if (busRouteAssignmentId != null)
        'bus_route_assignment_id': busRouteAssignmentId,
    };

    // Backend requires corridor_id, pickup_location, dropoff_location.
    final formattedPickup = pickupLocation ?? 'Boarding Stop $boardingStopId';
    final formattedDropoff =
        dropoffLocation ?? 'Destination Stop $destinationStopId';

    final requestBody = <String, dynamic>{
      ...payload,
      'pickup_name': formattedPickup,
      'pickup_location': formattedPickup,
      'pickup_address': formattedPickup,
      'dropoff_name': formattedDropoff,
      'dropoff_location': formattedDropoff,
      'dropoff_address': formattedDropoff,
    };

    if (pickupLat != null &&
        pickupLng != null &&
        dropoffLat != null &&
        dropoffLng != null) {
      requestBody.addAll({
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'pickup': {'lat': pickupLat, 'lng': pickupLng},
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'dropoff': {'lat': dropoffLat, 'lng': dropoffLng},
      });
    }

    // FIX #1: the public-bus smart request endpoint is POST /public-bus/request
    // (the /public-bus/trip-requests route does not exist).
    return _post('/public-bus/request', requestBody);
  }

  /// Poll a public-bus smart request after creation (matching / bus assignment).
  Future<Map<String, dynamic>> getPublicBusRequest(dynamic requestId) =>
      _get('/public-bus/requests/$requestId');

  Future<List<Map<String, dynamic>>> getPublicBusCorridors() async {
    final response = await _get('/public-bus/corridors');
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getPublicBusStops(int corridorId) async {
    final response = await _get('/public-bus/corridors/$corridorId/stops');
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getPublicBusActiveBuses(
    int corridorId, {
    int? boardingStopId,
    int? destinationStopId,
  }) async {
    final response = await _getWithQuery(
      '/public-bus/corridors/$corridorId/active-buses',
      {
        'boarding_stop_id': boardingStopId,
        'destination_stop_id': destinationStopId,
      },
    );
    return _extractList(response);
  }

  Future<Map<String, dynamic>> getCurrentPublicBusTrip() =>
      _get('/public-bus/trips/current');

  Future<Map<String, dynamic>> getPublicBusTicket(String ticketCode) =>
      _get('/public-bus/tickets/$ticketCode');

  String _normalizeTransportType(String value) {
    final lower = value.trim().toLowerCase();
    if (lower == 'bus') return 'BUS';
    if (lower == 'car' || lower == 'private' || lower == 'private_car') {
      return 'CAR';
    }
    if (lower == 'motorcycle' || lower == 'motor_vehicle' || lower == 'moto') {
      return 'MOTORCYCLE';
    }
    return value.trim();
  }

  Future<List<Map<String, dynamic>>> getTrips() async {
    final response = await _get('/trips');
    return _extractList(response);
  }

  Future<Map<String, dynamic>> getTripById(dynamic tripId) =>
      _get('/trips/$tripId');

  /// Poll a Trip-model trip status (ON_DEMAND car / scheduled). NOTE: this reads
  /// the `trips` table; do NOT use it for motor-vehicle/motorcycle trip_ids —
  /// use [getMotorVehicleTrip] for those.
  Future<Map<String, dynamic>> getTripStatus(dynamic tripId) =>
      _get('/trips/$tripId/status');

  Future<Map<String, dynamic>> trackTrip(dynamic tripId) =>
      _get('/trips/$tripId/track');

  Future<Map<String, dynamic>> getTripMatchingSession(dynamic tripId) =>
      _get('/trips/$tripId/matching-session');

  /// Create a direct trip (for ON_DEMAND rides - Motorcycle, ON_DEMAND CAR)
  /// Used when ride_rules.can_request_trip = true
  Future<Map<String, dynamic>> createDirectTrip({
    required int rideId,
    required String pickupLocation,
    required double pickupLat,
    required double pickupLng,
    required String dropoffLocation,
    required double dropoffLat,
    required double dropoffLng,
    double? fare,
  }) async {
    return _post('/trips', {
      'ride_id': rideId,
      'pickup_location': pickupLocation,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup': {'lat': pickupLat, 'lng': pickupLng},
      'dropoff_location': dropoffLocation,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'dropoff': {'lat': dropoffLat, 'lng': dropoffLng},
      if (fare != null) 'fare': fare,
    });
  }

  /// Create a trip from an existing booking (for SCHEDULED rides)
  /// Used after booking is created and user confirms
  Future<Map<String, dynamic>> createTripFromBooking({
    required int bookingId,
  }) async {
    return _post('/trips/create-from-booking', {'booking_id': bookingId});
  }

  Future<Map<String, dynamic>> cancelTrip(dynamic tripId) =>
      _put('/trips/$tripId/cancel', <String, dynamic>{});

  /// Acknowledge a trip status (e.g. timeout or accepted)
  Future<Map<String, dynamic>> acknowledgeTrip(dynamic tripId, String acknowledgementType) =>
      _post('/trips/$tripId/acknowledge', {'acknowledgement_type': acknowledgementType});

  /// DEPRECATED: kept for backward compatibility. The backend has no
  /// PUT /ride-requests/{id}/cancel route. For motor-vehicle trips use
  /// [cancelMotorVehicleTrip]; for Trip-model trips use [cancelTrip].
  @Deprecated('Use cancelMotorVehicleTrip() or cancelTrip() instead.')
  Future<Map<String, dynamic>> cancelRideRequest(dynamic requestId) =>
      cancelMotorVehicleTrip(requestId);

  Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double lat,
    required double lng,
    double radius = 10.0,
  }) async {
    final response = await _request(
      'GET',
      '/mobile/tracking/nearby?latitude=$lat&longitude=$lng&lat=$lat&lng=$lng&radius=$radius',
      useRootBaseUrl: true,
    );
    return _extractList(response);
  }

  Future<Map<String, dynamic>> assignDriverToTrip(dynamic tripId, int driverId) async {
    try {
      final response = await _request(
        'POST',
        '/mobile/trips/$tripId/assign-driver',
        body: {'driver_id': driverId},
        useRootBaseUrl: true,
      );
      return response;
    } catch (e) {
      debugPrint('[Matching] assignDriverToTrip mobile error: $e');
    }

    return _post('/motor-vehicle/trip-requests/$tripId/assign', {
      'driver_id': driverId,
    });
  }

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> payload) =>
      _post('/payments', payload);

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final response = await _get('/payments/history');
    return _extractList(response);
  }

  /// FIX #3: notifications are NOT under /passenger. The endpoint is
  /// /api/v1/notifications/unread-count, so call it against the API root.
  Future<int> getUnreadNotificationCount() async {
    final response = await _request(
      'GET',
      '/notifications/unread-count',
      customBaseUrl: _rootUrl,
    );
    final data = _extractDataMap(response);
    return _asInt(
      data['unread_count'] ?? data['count'] ?? data['unread'],
      fallback: 0,
    );
  }

  /// List notifications (shared endpoint, outside /passenger).
  Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int perPage = 20,
    bool onlyUnread = false,
  }) async {
    final response = await _request(
      'GET', 
      '/notifications?page=$page&per_page=$perPage&only_unread=$onlyUnread', 
      customBaseUrl: _rootUrl,
    );
    return _extractList(response);
  }

  Future<Map<String, dynamic>> markNotificationRead(dynamic id) =>
      _request('PUT', '/notifications/$id/read', body: <String, dynamic>{}, customBaseUrl: _rootUrl);

  Future<Map<String, dynamic>> _get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> _getWithQuery(
    String path,
    Map<String, dynamic> query,
  ) {
    final queryParams = <String, String>{};
    query.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isEmpty) return;
      queryParams[key] = text;
    });

    if (queryParams.isEmpty) {
      return _get(path);
    }

    final queryString = Uri(queryParameters: queryParams).query;
    return _request('GET', '$path?$queryString');
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) => _post(path, payload);

  Future<Map<String, dynamic>> get(String path) => _get(path);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) => _request('POST', path, body: payload);

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> payload,
  ) => _request('PUT', path, body: payload);



  void _logRequest(String method, Uri uri, {Map<String, dynamic>? body}) {
    if (!kDebugMode) return;
    debugPrint('[PassengerApi] --> $method $uri');
    if (body != null) {
      debugPrint('[PassengerApi] request body: ${jsonEncode(body)}');
    }
  }

  void _logResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    debugPrint('[PassengerApi] <-- ${response.statusCode} $method $uri');
    debugPrint('[PassengerApi] response body: ${response.body}');
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return response;
  }

  Map<String, String> _extractFieldErrors(Map<String, dynamic> payload) {
    final result = <String, String>{};
    final candidates = <dynamic>[
      payload['errors'],
      payload['field_errors'],
      payload['validation_errors'],
      payload['details'],
      payload['data'] is Map<String, dynamic>
          ? (payload['data'] as Map<String, dynamic>)['errors']
          : null,
    ];

    for (final candidate in candidates) {
      if (candidate is! Map<String, dynamic>) continue;
      candidate.forEach((key, value) {
        final message = _normalizeFieldError(value);
        if (message != null && message.isNotEmpty) {
          result[key] = message;
        }
      });
    }

    return result;
  }

  String? _normalizeFieldError(dynamic value) {
    if (value is String) return value;
    if (value is List) {
      final first = value.isNotEmpty ? value.first : null;
      return _asString(first);
    }
    if (value is Map<String, dynamic>) {
      return _asString(value['message']) ?? _asString(value['error']);
    }
    return _asString(value);
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> response) {
    final directData = response['data'];
    if (directData is List) {
      return directData.whereType<Map<String, dynamic>>().toList();
    }

    if (directData is Map<String, dynamic>) {
      final values = [
        directData['items'],
        directData['corridors'],
        directData['stops'],
        directData['active_buses'],
        directData['buses'],
        directData['assignments'],
        directData['rides'],
        directData['bookings'],
        directData['payments'],
        directData['history'],
        directData['drivers'],
        directData['online_drivers'],
        directData['notifications'],
      ];
      for (final value in values) {
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
      }
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  int _asInt(dynamic value, {required int fallback}) {
    // Existing implementation unchanged
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
  /// Centralized request handling using ApiClient
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool useRootBaseUrl = false,
    String? customBaseUrl,
  }) async {
    final client = ApiClient();
    final base = customBaseUrl ?? (useRootBaseUrl ? _rootUrl : _baseUrl);
    final fullUrl = '$base$path';
    try {
      final response = await client.dio.request(
        fullUrl,
        data: body,
        options: Options(
          method: method,
          sendTimeout: client.dio.options.sendTimeout,
          receiveTimeout: client.dio.options.receiveTimeout,
          contentType: 'application/json',
          responseType: ResponseType.json,
        ),
      );
      final parsed = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : _decodeObject(response.data?.toString() ?? '');
      final success = _asBool(parsed['success']);
      final ok = response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
      if (!(success ?? ok)) {
        final fieldErrors = _extractFieldErrors(parsed);
        final message = _asString(parsed['message']) ?? 'Request failed (${response.statusCode})';
        final errorCode = _asString(parsed['error_code']);
        throw PassengerApiException(
          message: message,
          statusCode: response.statusCode ?? 0,
          raw: parsed,
          fieldErrors: fieldErrors,
          errorCode: errorCode,
        );
      }
      return parsed;
    } on DioException catch (e) {
      final response = e.response;
      final parsed = response?.data is Map<String, dynamic>
          ? response!.data as Map<String, dynamic>
          : <String, dynamic>{};
      final message = _asString(parsed['message']) ?? e.message ?? 'Unknown error';
      final statusCode = response?.statusCode ?? 0;
      final errorCode = _asString(parsed['error_code']);
      final fieldErrors = _extractFieldErrors(parsed);
      throw PassengerApiException(
        message: message,
        statusCode: statusCode,
        raw: parsed,
        fieldErrors: fieldErrors,
        errorCode: errorCode,
      );
    }
  }
}

class PassengerApiException implements Exception {
  PassengerApiException({
    required this.message,
    required this.statusCode,
    required this.raw,
    Map<String, String>? fieldErrors,
    this.errorCode,
  }) : fieldErrors = fieldErrors ?? const <String, String>{};

  final String message;
  final int statusCode;
  final Map<String, dynamic> raw;
  final Map<String, String> fieldErrors;
  final String? errorCode;

  bool get isForbidden => statusCode == 403;
  bool get isValidationError => statusCode == 422;

  @override
  String toString() => 'PassengerApiException($statusCode): $message';
}
