import 'dart:convert';

import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';

import 'api_client.dart';
import 'package:dio/dio.dart';

class DriverApi {
  DriverApi._();

  static final DriverApi instance = DriverApi._();

  static const String _rootBaseUrl =
      'https://rideconnect-emp0.onrender.com/api/v1';
  static const String _hostBaseUrl = 'https://rideconnect-emp0.onrender.com';
  static const String _baseUrl =
      'https://rideconnect-emp0.onrender.com/api/v1/driver';
  static const Duration _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getProfile() => _get('/profile');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) =>
      _put('/profile', payload);

  Future<Map<String, dynamic>> getStats() async {
    return _get('/stats');
  }

  Future<List<Map<String, dynamic>>> getRides() async {
    final response = await _get('/rides');
    return extractList(response, preferredKeys: const ['rides']);
  }

  Future<Map<String, dynamic>> createRide(Map<String, dynamic> payload) =>
      _post('/rides', payload);

  Future<Map<String, dynamic>> updateRide(
    dynamic id,
    Map<String, dynamic> payload,
  ) => _put('/rides/$id', payload);

  Future<Map<String, dynamic>> deleteRide(dynamic id) => _delete('/rides/$id');

  Future<List<Map<String, dynamic>>> getBookings() async {
    final response = await _get('/bookings');
    return extractList(response, preferredKeys: const ['bookings']);
  }

  Future<Map<String, dynamic>> confirmBooking(dynamic id) =>
      _put('/bookings/$id/confirm', <String, dynamic>{});

  Future<Map<String, dynamic>> cancelBooking(dynamic id) =>
      _put('/bookings/$id/cancel', <String, dynamic>{});

  Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int perPage = 20,
    bool onlyUnread = false,
  }) async {
    final response = await _requestHost(
      'GET', 
      '/api/v3/driver/notifications?page=$page&per_page=$perPage&only_unread=$onlyUnread'
    );
    return extractList(
      response,
      preferredKeys: const ['notifications', 'items', 'results'],
    );
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await _requestHost('GET', '/api/v3/driver/notifications/unread-count');
    final data = extractDataMap(response);
    return readInt(data, const [
      'unread_count',
      'count',
      'unread',
    ], fallback: 0);
  }

  Future<Map<String, dynamic>> markNotificationRead(dynamic id) =>
      _requestHost('PUT', '/api/v3/driver/notifications/$id/read', body: <String, dynamic>{});

  Future<Map<String, dynamic>> markAllNotificationsRead() =>
      _requestHost('PUT', '/api/v3/driver/notifications/read-all', body: <String, dynamic>{});

  Future<Map<String, dynamic>> clearActionedNotifications() =>
      _requestHost('DELETE', '/api/v3/driver/notifications/clear-actioned');

  Future<Map<String, dynamic>> deleteNotification(dynamic id) =>
      _requestHost('DELETE', '/api/v3/driver/notifications/$id');

  Future<List<Map<String, dynamic>>> getTrips() async {
    final response = await _get('/trips');
    return extractList(response, preferredKeys: const ['trips', 'history']);
  }

  Future<Map<String, dynamic>> updateStatus({required bool isOnline}) => _put(
    '/status',
    {'is_online': isOnline, 'status': isOnline ? 'online' : 'offline'},
  );

  Future<List<Map<String, dynamic>>> getRequests() async {
    Map<String, dynamic> response;
    try {
      response = await _get('/requests');
    } catch (_) {
      response = await _get('/trip-requests');
    }
    return extractList(
      response,
      preferredKeys: const ['requests', 'items', 'rides'],
    );
  }

  Future<List<Map<String, dynamic>>> getTripRequests() async {
    Map<String, dynamic> response;
    try {
      response = await _get('/trip-requests');
    } catch (_) {
      response = await _get('/requests');
    }
    return extractList(
      response,
      preferredKeys: const ['trip_requests', 'requests', 'items'],
    );
  }

  Future<Map<String, dynamic>> acceptRequest(
    dynamic id, {
    String? rideId,
    String? requestId,
    String? bookingId,
  }) async {
    final payload = _requestActionPayload(
      id: id,
      rideId: rideId,
      requestId: requestId,
      bookingId: bookingId,
    );
    try {
      return await _requestHost('POST', '/api/v3/trips/$id/accept', body: payload);
    } catch (_) {
      try {
        return await _put('/trip-requests/$id/accept', payload);
      } catch (_) {
        return _put('/requests/$id/accept', payload);
      }
    }
  }

  Future<Map<String, dynamic>> rejectRequest(
    dynamic id, {
    String? rideId,
    String? requestId,
    String? bookingId,
  }) async {
    final payload = _requestActionPayload(
      id: id,
      rideId: rideId,
      requestId: requestId,
      bookingId: bookingId,
    );
    try {
      return await _requestHost('POST', '/api/v3/trips/$id/reject', body: payload);
    } catch (_) {
      try {
        return await _put('/trip-requests/$id/reject', payload);
      } catch (_) {
        return _put('/requests/$id/reject', payload);
      }
    }
  }

  Future<bool> clearReadNotifications() async {
    try {
      await clearActionedNotifications();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> completeRequest(
    dynamic id, {
    String? rideId,
    String? requestId,
    String? bookingId,
  }) async {
    final payload = _requestActionPayload(
      id: id,
      rideId: rideId,
      requestId: requestId,
      bookingId: bookingId,
    );
    try {
      return await _put('/trip-requests/$id/complete', payload);
    } catch (_) {
      return _put('/requests/$id/complete', payload);
    }
  }

  Future<Map<String, dynamic>> postLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) async {
    final payload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      'lat': latitude,
      'lng': longitude,
    };

    try {
      return await _post('/location', payload);
    } catch (_) {
      return _requestHost('POST', '/api/driver/location', body: payload);
    }
  }

  Future<Map<String, dynamic>> startTrip(dynamic id) =>
      _put('/trips/$id/start', <String, dynamic>{});

  Future<Map<String, dynamic>> cancelTrip(dynamic id) =>
      _put('/trips/$id/cancel', <String, dynamic>{});

  Future<bool> notifyPassengerDecision({
    required String passengerId,
    required bool accepted,
    required bool bookingDecision,
    String passengerName = '',
    String referenceId = '',
    String pickup = '',
    String dropoff = '',
  }) async {
    final target = passengerId.trim();
    if (target.isEmpty) return false;

    final type =
        bookingDecision
            ? (accepted ? 'booking_confirmed' : 'booking_rejected')
            : (accepted ? 'ride_request_accepted' : 'ride_request_rejected');

    final title =
        bookingDecision
            ? (accepted ? 'Booking Confirmed' : 'Booking Rejected')
            : (accepted ? 'Ride Request Accepted' : 'Ride Request Rejected');

    final subjectName =
        passengerName.trim().isEmpty ? 'Passenger' : passengerName.trim();
    final message =
        bookingDecision
            ? (accepted
                ? 'Driver confirmed your booking request.'
                : 'Driver rejected your booking request.')
            : (accepted
                ? 'Driver accepted your ride request.'
                : 'Driver rejected your ride request.');

    final payload = <String, dynamic>{
      'type': type,
      'title': title,
      'message': message,
      // Send multiple recipient keys for backend compatibility.
      'recipient_id': target,
      'user_id': target,
      'passenger_id': target,
      'data': <String, dynamic>{
        'passenger_name': subjectName,
        'reference_id': referenceId,
        'pickup': pickup,
        'dropoff': dropoff,
        'accepted': accepted,
        'source': 'driver_app',
      },
    };

    const paths = <String>[
      '/notifications',
      '/notifications/send',
      '/passenger/notifications',
    ];

    for (final path in paths) {
      try {
        await _requestRoot('POST', path, body: payload);
        return true;
      } catch (_) {
        // Try alternative endpoint.
      }
    }

    return false;
  }

  Future<Map<String, dynamic>> getEarnings() => _get('/earnings');

  Future<Map<String, dynamic>> getMonthlyEarnings() =>
      _get('/earnings/monthly');

  Future<Map<String, dynamic>> postDocuments(Map<String, dynamic> payload) =>
      _post('/documents', payload);

  Future<List<Map<String, dynamic>>> getDocuments() async {
    final response = await _get('/documents');
    return extractList(response, preferredKeys: const ['documents']);
  }

  Future<Map<String, dynamic>> _get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) => _request('POST', path, body: payload);

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> payload,
  ) => _request('PUT', path, body: payload);

  Future<Map<String, dynamic>> _delete(String path) => _request('DELETE', path);

  Map<String, dynamic> _requestActionPayload({
    required dynamic id,
    String? rideId,
    String? requestId,
    String? bookingId,
  }) {
    final payload = <String, dynamic>{
      if (rideId != null && rideId.trim().isNotEmpty) ...<String, dynamic>{
        'ride_id': rideId.trim(),
        'trip_id': rideId.trim(),
      },
      if (requestId != null &&
          requestId.trim().isNotEmpty) ...<String, dynamic>{
        'request_id': requestId.trim(),
        'ride_request_id': requestId.trim(),
        'trip_request_id': requestId.trim(),
      },
      if (bookingId != null &&
          bookingId.trim().isNotEmpty) ...<String, dynamic>{
        'booking_id': bookingId.trim(),
        'order_id': bookingId.trim(),
      },
    };

    final rawId = '$id'.trim();
    if (rawId.isNotEmpty) {
      payload['id'] = rawId;
    }

    return payload;
  }

  Future<Map<String, dynamic>> _requestRoot(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) => _request(method, path, body: body, useRootBaseUrl: true);

  Future<Map<String, dynamic>> _requestHost(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) => _request(method, path, body: body, customBaseUrl: _hostBaseUrl);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool useRootBaseUrl = false,
    String? customBaseUrl,
  }) async {
    // Use the centralized ApiClient for all HTTP calls
    final client = ApiClient();
    // Determine the base URL according to the provided flags
    final base = customBaseUrl ??
        (useRootBaseUrl ? _rootBaseUrl : _baseUrl);
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

      // Dio already parses JSON; ensure we have a map
      final parsed = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : _decodeObject(response.data?.toString() ?? '');

      final success = _asBool(parsed['success']);
      final ok = response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;

      if (!(success ?? ok)) {
        final message = _asString(parsed['message']) ??
            'Request failed (${response.statusCode})';
        final errorCode = _asString(parsed['error_code']);
        throw DriverApiException(
          message: message,
          statusCode: response.statusCode ?? 0,
          errorCode: errorCode,
        );
      }

      return parsed;
    } on DioException catch (e) {
      final response = e.response;
      final parsed = response?.data is Map<String, dynamic>
          ? response!.data as Map<String, dynamic>
          : {};
      final message = _asString(parsed['message']) ?? e.message ?? 'Unknown error';
      final statusCode = response?.statusCode ?? 0;
      throw DriverApiException(
        message: message,
        statusCode: statusCode,
        errorCode: _asString(parsed['error_code']),
      );
    }
  }

  Map<String, dynamic> extractDataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    return response;
  }

  List<Map<String, dynamic>> extractList(
    Map<String, dynamic> response, {
    List<String> preferredKeys = const <String>[],
  }) {
    final data = response['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    final candidates = <dynamic>[];
    if (data is Map<String, dynamic>) {
      for (final key in preferredKeys) {
        candidates.add(data[key]);
      }
      candidates.addAll(data.values);
    }

    for (final key in preferredKeys) {
      candidates.add(response[key]);
    }

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate.whereType<Map<String, dynamic>>().toList();
      }
    }

    return <Map<String, dynamic>>[];
  }

  String readString(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = source[key];
      final text = _asString(value)?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  double readDouble(
    Map<String, dynamic> source,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
        final parsed = double.tryParse(cleaned);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  int readInt(
    Map<String, dynamic> source,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[^0-9-]'), '');
        final parsed = int.tryParse(cleaned);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  bool readBool(
    Map<String, dynamic> source,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = _asBool(source[key]);
      if (value != null) return value;
    }
    return fallback;
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
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == 'online' || lower == '1') return true;
      if (lower == 'false' || lower == 'offline' || lower == '0') return false;
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}

class DriverApiException implements Exception {
  DriverApiException({
    required this.message,
    required this.statusCode,
    this.errorCode,
  });

  final String message;
  final int statusCode;
  final String? errorCode;

  bool get isActionRequiredConflict =>
      statusCode == 422 && errorCode == 'notification_not_actioned';

  @override
  String toString() => message;
}
