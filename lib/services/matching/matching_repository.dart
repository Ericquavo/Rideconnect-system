import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rideconnect_app/models/matching/matching_session.dart';
import 'package:rideconnect_app/auth/auth_session.dart';

/// Repository for matching-related API calls
class MatchingRepository {
  static final MatchingRepository _instance = MatchingRepository._internal();

  factory MatchingRepository() {
    return _instance;
  }

  MatchingRepository._internal();

  static const String _baseUrl =
      'https://rideconnect-emp0.onrender.com/api/v1/mobile';
  static const String _rootBaseUrl =
      'https://rideconnect-emp0.onrender.com/api/v1';
  static const Duration _timeout = Duration(seconds: 30);

  /// Get available drivers for matching
  ///
  /// Parameters:
  /// - transportType: 'BUS', 'CAR', or 'MOTORCYCLE'
  /// - pickupLat / pickupLng: Pickup location
  /// - dropoffLat / dropoffLng: Dropoff location
  /// - excludedDriverIds: List of driver IDs to exclude (optional)
  Future<MatchingSession> getAvailableDrivers({
    required String transportType,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    List<int>? excludedDriverIds,
  }) async {
    try {
      final session = await AuthSession.load();
      final token = session?.token;
      if (token == null) throw Exception('No auth token available');

      final normalizedTransport = _normalizeTransportType(transportType);
      final queryParams = {
        'transport_type': normalizedTransport,
        'pickup_lat': pickupLat.toString(),
        'pickup_lng': pickupLng.toString(),
        'dropoff_lat': dropoffLat.toString(),
        'dropoff_lng': dropoffLng.toString(),
      };

      // Add excluded driver IDs if provided
      if (excludedDriverIds != null && excludedDriverIds.isNotEmpty) {
        queryParams['excluded_driver_ids'] = excludedDriverIds.join(',');
      }

      // Try passenger-scoped matching endpoints first (more likely to exist),
      // then fall back to mobile endpoints.
      final response = await _getFirstSuccessful(
        paths: const [
          '/passenger/drivers/match',
          '/passenger/drivers/online',
          '/drivers/match',
        ],
        queryParams: queryParams,
        token: token,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _matchingException(response, 'Unable to load drivers. Retry');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _matchingSessionFromResponse(json, transportType);
    } catch (e) {
      rethrow;
    }
  }

  /// Request a trip (Moto flow)
  ///
  /// Uses:
  /// POST /api/v1/mobile/trips/request
  ///
  /// Includes X-Idempotency-Key header for deduplication
  Future<Map<String, dynamic>> requestMotoTrip({
    required int driverId,
    required String matchingSessionId,
    required String pickupName,
    required double pickupLat,
    required double pickupLng,
    required String dropoffName,
    required double dropoffLat,
    required double dropoffLng,
    String? idempotencyKey,
  }) async {
    try {
      final session = await AuthSession.load();
      final token = session?.token;
      if (token == null) throw Exception('No auth token available');

      final payload = {
        'driver_id': driverId,
        'matching_session_id': matchingSessionId,
        'transport_type': 'MOTORCYCLE',
        'pickup_name': pickupName,
        'pickup_location': pickupName,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_name': dropoffName,
        'dropoff_location': dropoffName,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
      };

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      if (idempotencyKey != null) {
        headers['X-Idempotency-Key'] = idempotencyKey;
      }

      final uri = Uri.parse('$_baseUrl/trips/request');
      _logRequest('POST', uri, body: payload);

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(_timeout);

      _logResponse('POST', uri, response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _matchingException(response, 'Unable to request trip. Retry');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['data'] ?? json;
    } catch (e) {
      rethrow;
    }
  }

  /// Request a private car booking
  ///
  /// Uses:
  /// POST /api/v1/mobile/bookings
  ///
  /// Includes X-Idempotency-Key header for deduplication
  Future<Map<String, dynamic>> requestPrivateCarBooking({
    required int driverId,
    required String matchingSessionId,
    required int seats,
    required String pickupName,
    required double pickupLat,
    required double pickupLng,
    required String dropoffName,
    required double dropoffLat,
    required double dropoffLng,
    DateTime? scheduleTime,
    String? idempotencyKey,
  }) async {
    try {
      final session = await AuthSession.load();
      final token = session?.token;
      if (token == null) throw Exception('No auth token available');

      final payload = {
        'driver_id': driverId,
        'matching_session_id': matchingSessionId,
        'transport_type': 'CAR',
        'seats': seats,
        'pickup_name': pickupName,
        'pickup_location': pickupName,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_name': dropoffName,
        'dropoff_location': dropoffName,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
      };

      if (scheduleTime != null) {
        payload['schedule_time'] = scheduleTime.toIso8601String();
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      if (idempotencyKey != null) {
        headers['X-Idempotency-Key'] = idempotencyKey;
      }

      final uri = Uri.parse('$_baseUrl/bookings');
      _logRequest('POST', uri, body: payload);

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(_timeout);

      _logResponse('POST', uri, response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _matchingException(response, 'Unable to request booking. Retry');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['data'] ?? json;
    } catch (e) {
      rethrow;
    }
  }

  void _logRequest(String method, Uri uri, {Map<String, dynamic>? body}) {
    if (!kDebugMode) return;
    debugPrint('[MatchingRepository] --> $method $uri');
    if (body != null) {
      debugPrint('[MatchingRepository] request body: ${jsonEncode(body)}');
    }
  }

  Future<http.Response> _getFirstSuccessful({
    required List<String> paths,
    required Map<String, String> queryParams,
    required String token,
  }) async {
    http.Response? lastResponse;
    for (final path in paths) {
      final base = path.startsWith('/passenger') ? _rootBaseUrl : _baseUrl;
      final uri = Uri.parse('$base$path').replace(queryParameters: queryParams);
      _logRequest('GET', uri);
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);
      _logResponse('GET', uri, response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      lastResponse = response;
      if (!_shouldTryNextMatchingEndpoint(response)) {
        break;
      }
    }
    return lastResponse!;
  }

  bool _shouldTryNextMatchingEndpoint(http.Response response) {
    if (response.statusCode == 404 || response.statusCode == 405) return true;

    final body = _decodeMap(response.body);
    final error = body['error'];
    final errorCode =
        body['error_code']?.toString() ??
        body['code']?.toString() ??
        (error is Map<String, dynamic> ? error['code']?.toString() : null);

    return errorCode == 'DRIVER_MATCHING_FAILURE' ||
        response.statusCode == 500 ||
        response.statusCode == 502 ||
        response.statusCode == 503 ||
        response.statusCode == 504;
  }

  MatchingSession _matchingSessionFromResponse(
    Map<String, dynamic> json,
    String transportType,
  ) {
    final data = json['data'];
    if (data is List) {
      return _syntheticSession(
        transportType: transportType,
        drivers: data.whereType<Map<String, dynamic>>().toList(),
      );
    }

    if (data is Map<String, dynamic>) {
      final drivers = _extractDrivers(data);
      if (drivers != null) {
        return _syntheticSession(
          transportType:
              data['transport_type']?.toString().trim().isNotEmpty == true
                  ? data['transport_type'].toString()
                  : transportType,
          drivers: drivers,
          source: data,
        );
      }
      return MatchingSession.fromJson(data);
    }

    final drivers = _extractDrivers(json);
    if (drivers != null) {
      return _syntheticSession(
        transportType: transportType,
        drivers: drivers,
        source: json,
      );
    }

    return MatchingSession.fromJson(json);
  }

  List<Map<String, dynamic>>? _extractDrivers(Map<String, dynamic> source) {
    const keys = [
      'drivers',
      'matched_drivers',
      'online_drivers',
      'items',
      'results',
    ];

    for (final key in keys) {
      final value = source[key];
      if (value is List) {
        return value.whereType<Map<String, dynamic>>().toList();
      }
    }
    return null;
  }

  MatchingSession _syntheticSession({
    required String transportType,
    required List<Map<String, dynamic>> drivers,
    Map<String, dynamic>? source,
  }) {
    final now = DateTime.now();
    final sessionId =
        source?['matching_session_id']?.toString() ??
        source?['matchingSessionId']?.toString() ??
        source?['session_id']?.toString() ??
        'local-${now.millisecondsSinceEpoch}';

    return MatchingSession.fromJson({
      ...?source,
      'matching_session_id': sessionId,
      'transport_type': transportType,
      'generated_at': source?['generated_at'] ?? now.toIso8601String(),
      'expires_at':
          source?['expires_at'] ??
          now.add(const Duration(minutes: 5)).toIso8601String(),
      'drivers': drivers,
    });
  }

  void _logResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    debugPrint('[MatchingRepository] <-- ${response.statusCode} $method $uri');
    debugPrint('[MatchingRepository] response body: ${response.body}');
  }

  MatchingApiException _matchingException(
    http.Response response,
    String fallbackMessage,
  ) {
    final body = _decodeMap(response.body);
    final error = body['error'];
    final errorCode =
        body['error_code']?.toString() ??
        body['code']?.toString() ??
        (error is Map<String, dynamic> ? error['code']?.toString() : null);
    final serverMessage =
        body['message']?.toString() ??
        (error is Map<String, dynamic>
            ? error['description']?.toString() ?? error['message']?.toString()
            : null);

    return MatchingApiException(
      message: _friendlyMessageForCode(
        errorCode,
        statusCode: response.statusCode,
        fallback: fallbackMessage,
      ),
      statusCode: response.statusCode,
      errorCode: errorCode,
      raw: body,
      serverMessage: serverMessage,
    );
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  String _friendlyMessageForCode(
    String? errorCode, {
    required int statusCode,
    required String fallback,
  }) {
    switch (errorCode) {
      case 'DRIVER_MATCHING_FAILURE':
        return 'Unable to load drivers. Retry';
      case 'PASSENGER_NOT_APPROVED':
        return 'Your account must be approved before requesting a ride.';
      case 'PASSENGER_ONLY':
        return 'Only passengers can request rides.';
      default:
        if (statusCode >= 500) return fallback;
        if (statusCode == 403) {
          return 'You are not allowed to complete this request.';
        }
        if (statusCode == 422) {
          return 'We could not complete this request. Please check your locations and try again.';
        }
        return fallback;
    }
  }
}

/// Normalize transport type strings to the server-expected constants.
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

class MatchingApiException implements Exception {
  MatchingApiException({
    required this.message,
    required this.statusCode,
    required this.raw,
    this.errorCode,
    this.serverMessage,
  });

  final String message;
  final int statusCode;
  final Map<String, dynamic> raw;
  final String? errorCode;
  final String? serverMessage;

  bool get isDriverMatchingFailure => errorCode == 'DRIVER_MATCHING_FAILURE';

  @override
  String toString() => message;
}
