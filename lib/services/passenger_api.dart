import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';

class PassengerApi {
  PassengerApi._();

  static final PassengerApi instance = PassengerApi._();

  static const String _baseUrl =
      'https://rideconnect-emp0.onrender.com/api/v1/passenger';
  static const Duration _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getProfile() => _get('/profile');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) =>
      _put('/profile', payload);

  Future<Map<String, dynamic>> getStats() => _get('/stats');

  Future<List<Map<String, dynamic>>> getAvailableRides() async {
    final response = await _get('/rides/available');
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

  Future<Map<String, dynamic>> createRideRequest(
    Map<String, dynamic> payload,
  ) => _post('/ride-requests', payload);

  Future<List<Map<String, dynamic>>> getTrips() async {
    final response = await _get('/trips');
    return _extractList(response);
  }

  Future<Map<String, dynamic>> getTripById(dynamic tripId) =>
      _get('/trips/$tripId');

  Future<Map<String, dynamic>> cancelTrip(dynamic tripId) =>
      _put('/trips/$tripId/cancel', <String, dynamic>{});

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> payload) =>
      _post('/payments', payload);

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final response = await _get('/payments/history');
    return _extractList(response);
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

    final parsed = _decodeObject(response.body);
    final success = _asBool(parsed['success']);
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    if (!(success ?? ok)) {
      final errorMap = parsed['error'];
      final nestedError =
          errorMap is Map<String, dynamic>
              ? _asString(errorMap['description'])
              : null;
      final message =
          _asString(parsed['message']) ??
          nestedError ??
          _asString(parsed['error']) ??
          'Request failed (${response.statusCode})';
      throw Exception(message);
    }

    return parsed;
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> response) {
    final directData = response['data'];
    if (directData is List) {
      return directData.whereType<Map<String, dynamic>>().toList();
    }

    if (directData is Map<String, dynamic>) {
      final values = [
        directData['items'],
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

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}
