import 'dart:convert';
import 'package:http/http.dart' as http;

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
  baseUrl: 'https://rideconnect-emp0.onrender.com/api/v1',
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

  /// e.g. https://host/api/v1  (no trailing slash)
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
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  void _throwIfNotOk(http.Response response, Map<String, dynamic> body) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final msg = (body['message'] ?? 'Request failed').toString();
    throw ApiException(msg, response.statusCode, body);
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
    final res = await _client.get(
      _uri('/passenger/rides/available', {
        'status': status,
        'search': search,
        'date': date,
        'available_only': availableOnly?.toString(),
      }),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    final list = (body['data'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RideSummary.fromJson)
        .toList();
  }

  /// GET /passenger/rides
  /// Returns the passenger's own active / current ride bookings.
  Future<List<RideHistoryItem>> fetchMyRides({
    String? status,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    final res = await _client.get(
      _uri('/passenger/rides', {
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'per_page': perPage?.toString(),
      }),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    final list = (body['data'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RideHistoryItem.fromJson)
        .toList();
  }

  /// GET /passenger/rides/history
  /// Returns the passenger's completed / cancelled ride history.
  Future<List<RideHistoryItem>> fetchRideHistory({
    String? status,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    final res = await _client.get(
      _uri('/passenger/rides/history', {
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'per_page': perPage?.toString(),
      }),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    final list = (body['data'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RideHistoryItem.fromJson)
        .toList();
  }

  /// GET /passenger/rides/{id}
  /// Returns full details for a single ride.
  Future<RideDetails> fetchRideDetails(int rideId) async {
    final res = await _client.get(
      _uri('/passenger/rides/$rideId'),
      headers: await _headers(),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    final data = (body['data'] as Map<String, dynamic>? ?? {});
    return RideDetails.fromJson(data);
  }

  /// POST /passenger/rides
  /// Books a seat on an available ride.
  Future<CreateBookingResponse> createBooking(
    CreateBookingRequest request,
  ) async {
    final res = await _client.post(
      _uri('/passenger/rides'),
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
    final data = (body['data'] as Map<String, dynamic>? ?? {});
    return CreateBookingResponse.fromJson(data);
  }

  /// PUT /passenger/rides/{id}/cancel
  /// Cancels a booking.  [reason] is optional.
  Future<void> cancelBooking(int rideId, {String? reason}) async {
    final res = await _client.put(
      _uri('/passenger/rides/$rideId/cancel'),
      headers: await _headers(),
      body: jsonEncode({
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );
    final body = _decodeBody(res);
    _throwIfNotOk(res, body);
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
