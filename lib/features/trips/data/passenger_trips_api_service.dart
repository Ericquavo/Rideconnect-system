import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../../auth/auth_session.dart';
import 'passenger_trips_models.dart';

export 'passenger_trips_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Auth headers provider type
// ─────────────────────────────────────────────────────────────────────────────

/// A function that resolves the auth headers (e.g. Bearer token) to attach
/// to every API request.  Throw on auth failure so callers can detect 401s.
typedef AuthHeadersProvider = Future<Map<String, String>> Function();

// ─────────────────────────────────────────────────────────────────────────────
//  Singleton – wired to AuthSession so pages can import and use directly
// ─────────────────────────────────────────────────────────────────────────────

final PassengerTripsApiService passengerTripsApi = PassengerTripsApiService(
  baseUrl: 'https://rideconnect-emp0.onrender.com/v1',
  authHeadersProvider: AuthSession.authHeaders,
);

// ─────────────────────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────────────────────

class PassengerTripsApiService {
  PassengerTripsApiService({
    required this.baseUrl,
    required AuthHeadersProvider authHeadersProvider,
    http.Client? client,
  }) : _authHeadersProvider = authHeadersProvider,
       _client = client ?? http.Client();

  /// e.g. https://host/v1  (no trailing slash)
  final String baseUrl;
  final AuthHeadersProvider _authHeadersProvider;
  final http.Client _client;

  // ── Helpers ──────────────────────────────────────────────────────────────

  Uri _uri(String path, [Map<String, String?>? query]) {
    final filtered = <String, String>{};
    (query ?? {}).forEach((k, v) {
      if (v != null && v.isNotEmpty) filtered[k] = v;
    });
    return Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  Future<Map<String, String>> _headers() async {
    final auth = await _authHeadersProvider();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...auth,
    };
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    final rawBody = response.body;
    if (rawBody.trim().isEmpty) return {};

    try {
      final decoded = jsonDecode(rawBody);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return <String, dynamic>{
        'message': 'Server returned an invalid response format.',
        'raw_body': rawBody,
        'invalid_json': true,
      };
    }
  }

  List<Map<String, dynamic>> _extractDataList(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      final candidates = <dynamic>[
        data['items'],
        data['rides'],
        data['bookings'],
        data['history'],
        data['trips'],
      ];
      for (final value in candidates) {
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    final fallback = <dynamic>[body['ride'], body['booking'], body['trip']];
    for (final value in fallback) {
      if (value is Map<String, dynamic>) return value;
    }
    return body;
  }

  void _throwIfNotOk(http.Response response, Map<String, dynamic> body) {
    if (body['invalid_json'] == true) {
      throw ApiException(
        (body['message'] ?? 'Server returned an invalid response format.')
            .toString(),
        response.statusCode,
        body,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final msg = (body['message'] ?? 'Request failed').toString();
    throw ApiException(msg, response.statusCode, body);
  }

  void _logEndpointHit(String operation, String path) {
    if (!kDebugMode) return;
    debugPrint('[PassengerTripsApi] $operation -> $path');
  }

  // ── Auth endpoints ────────────────────────────────────────────────────────

  /// Returns `true` if the current token is still valid.
  /// A 401 returns `false`; other errors propagate.
  Future<bool> validateToken() async {
    final res = await _client.get(
      _uri('/auth/token/validate'),
      headers: await _headers(),
    );
    if (res.statusCode == 401) return false;
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  /// Clears the session on the backend.  Pass [allDevices] = false to clear
  /// only the current device session.
  Future<void> clearSession({bool allDevices = true}) async {
    final res = await _client.post(
      _uri('/auth/session/clear'),
      headers: await _headers(),
      body: jsonEncode({'all_devices': allDevices}),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
  }

  // ── Ride endpoints ────────────────────────────────────────────────────────

  /// GET /passenger/rides/available
  /// Returns rides that the passenger can book.
  Future<List<RideSummary>> fetchAvailableRides({
    String? status,
    String? search,
    String? date, // YYYY-MM-DD
    bool? availableOnly,
  }) async {
    final path = '/passenger/rides/available';
    final res = await _client.get(
      _uri(path, <String, String?>{
        'status': status,
        'search': search,
        'date': date,
        'available_only': availableOnly?.toString(),
      }),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('fetchAvailableRides', path);
    return _extractDataList(body).map(RideSummary.fromJson).toList();
  }

  /// GET /passenger/rides
  /// Returns the passenger's own active / current ride bookings.
  Future<List<RideHistoryItem>> fetchMyRides({
    String? status,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    final path = '/passenger/rides';
    final res = await _client.get(
      _uri(path, <String, String?>{
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'per_page': perPage?.toString(),
      }),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('fetchMyRides', path);
    return _extractDataList(body).map(RideHistoryItem.fromJson).toList();
  }

  /// GET /passenger/bookings/my
  /// Returns the passenger's booking list to track booking status.
  Future<List<RideHistoryItem>> fetchMyBookings({
    String? status,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    final res = await _client.get(
      _uri('/passenger/bookings/my', {
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'per_page': perPage?.toString(),
      }),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('fetchMyBookings', '/passenger/bookings/my');
    return _extractDataList(body).map(RideHistoryItem.fromJson).toList();
  }

  /// GET /passenger/trips
  /// Returns active/completed passenger trips.
  Future<List<RideHistoryItem>> fetchPassengerTrips() async {
    final res = await _client.get(
      _uri('/passenger/trips'),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('fetchPassengerTrips', '/passenger/trips');
    return _extractDataList(body).map(RideHistoryItem.fromJson).toList();
  }

  /// GET /passenger/rides/history
  /// Returns the passenger's completed / cancelled ride history.
  Future<List<RideHistoryItem>> fetchRideHistory({
    String? status,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    final path = '/passenger/rides/history';
    final res = await _client.get(
      _uri(path, <String, String?>{
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'per_page': perPage?.toString(),
      }),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('fetchRideHistory', path);
    return _extractDataList(body).map(RideHistoryItem.fromJson).toList();
  }

  /// GET /passenger/rides/{id}
  /// Returns full details for a single ride.
  Future<RideDetails> fetchRideDetails(int rideId) async {
    final path = '/passenger/rides/$rideId';
    final res = await _client.get(_uri(path), headers: await _headers());
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('fetchRideDetails', path);
    return RideDetails.fromJson(_extractDataMap(body));
  }

  /// POST /passenger/rides
  /// Books a seat on an available ride.
  Future<CreateBookingResponse> createBooking(
    CreateBookingRequest request,
  ) async {
    const path = '/passenger/rides';
    final res = await _client.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('createBooking', path);
    return CreateBookingResponse.fromJson(_extractDataMap(body));
  }

  /// POST /passenger/payments
  /// Processes payment for a booking/trip.
  Future<CreatePaymentResponse> createPayment(
    CreatePaymentRequest request,
  ) async {
    final res = await _client.post(
      _uri('/passenger/payments'),
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('createPayment', '/passenger/payments');
    return CreatePaymentResponse.fromJson(_extractDataMap(body));
  }

  /// PUT /passenger/rides/{id}/cancel
  /// Cancels a booking.  [reason] is optional.
  Future<void> cancelBooking(int rideId, {String? reason}) async {
    const pathPrefix = '/passenger/rides';
    final payload = <String, dynamic>{
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    final path = '$pathPrefix/$rideId/cancel';
    final res = await _client.put(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    _logEndpointHit('cancelBooking', path);
  }

  void dispose() => _client.close();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Exception type
// ─────────────────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  ApiException(this.message, this.statusCode, this.raw);

  final String message;
  final int statusCode;
  final Map<String, dynamic> raw;

  /// Returns `true` when the token was rejected by the server.
  bool get isAuthError => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
