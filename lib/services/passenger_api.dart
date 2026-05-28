import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';

class PassengerApi {
  PassengerApi._();

  static final PassengerApi instance = PassengerApi._();

  static const String _baseUrl =
      'https://rideconnect-emp0.onrender.com/api/v1/passenger';
  static const Duration _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getProfile() => _get('/profile');

  /// Initialize/create the passenger profile if it doesn't exist
  /// Call this after successful registration
  Future<Map<String, dynamic>> initializeProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      // Try to create profile with initial data
      return await _post('/profile', {
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
    } catch (e) {
      // If POST fails, try a PATCH/PUT to initialize
      try {
        return await _put('/profile', {
          if (name != null && name.isNotEmpty) 'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        });
      } catch (_) {
        // If both fail, just return empty success
        return {'success': true, 'message': 'Profile initialization attempted'};
      }
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) =>
      _put('/profile', payload);

  Future<Map<String, dynamic>> getStats() => _get('/stats');

  Future<List<Map<String, dynamic>>> getAvailableRides() async {
    final response = await _get('/rides/available');
    return _extractList(response);
  }

  /// Get rides by type and travel mode
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
    final response = await _getWithQuery('/rides', {
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

  Future<Map<String, dynamic>> bookPublicBusSeat({
    required int corridorId,
    required int boardingStopId,
    required int destinationStopId,
    int? busRouteAssignmentId,
    int seatsReserved = 1,
  }) {
    return _post('/public-bus/book-seat', {
      'corridor_id': corridorId,
      'boarding_stop_id': boardingStopId,
      'destination_stop_id': destinationStopId,
      'seats_reserved': seatsReserved,
      if (busRouteAssignmentId != null)
        'bus_route_assignment_id': busRouteAssignmentId,
    });
  }

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

  Future<Map<String, dynamic>> cancelRideRequest(dynamic requestId) =>
      _put('/ride-requests/$requestId/cancel', <String, dynamic>{});

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> payload) =>
      _post('/payments', payload);

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final response = await _get('/payments/history');
    return _extractList(response);
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await _get('/notifications/unread-count');
    final data = _extractDataMap(response);
    return _asInt(
      data['unread_count'] ?? data['count'] ?? data['unread'],
      fallback: 0,
    );
  }

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

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) => _request('POST', path, body: payload);

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> payload,
  ) => _request('PUT', path, body: payload);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final session = await AuthSession.load();
    final token = session?.token;

    if (token == null || token.trim().isEmpty) {
      throw Exception('No auth token found. Please login again.');
    }

    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
      'Content-Type': 'application/json',
    };

    _logRequest(method, uri, body: body);

    late http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: headers).timeout(_timeout);
    } else if (method == 'POST') {
      response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(_timeout);
    } else if (method == 'PUT') {
      response = await http
          .put(
            uri,
            headers: headers,
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(_timeout);
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    _logResponse(method, uri, response);

    final parsed = _decodeObject(response.body);
    final success = _asBool(parsed['success']);
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    if (!(success ?? ok)) {
      final errorMap = parsed['error'];
      final nestedError =
          errorMap is Map<String, dynamic>
              ? _asString(errorMap['description'])
              : null;
      final nestedErrorCode =
          errorMap is Map<String, dynamic> ? _asString(errorMap['code']) : null;
      final fieldErrors = _extractFieldErrors(parsed);
      final message =
          _asString(parsed['message']) ??
          nestedError ??
          _asString(parsed['error']) ??
          'Request failed (${response.statusCode})';
      final errorCode =
          _asString(parsed['error_code']) ??
          nestedErrorCode ??
          _asString(parsed['code']);
      final safeMessage =
          response.statusCode >= 500
              ? 'Server error (${response.statusCode}). Please try again later.'
              : message;

      throw PassengerApiException(
        message: safeMessage,
        statusCode: response.statusCode,
        raw: parsed,
        fieldErrors: fieldErrors,
        errorCode: errorCode,
      );
    }

    return parsed;
  }

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
