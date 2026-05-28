import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../auth/auth_session.dart';

final MobileFlowApiService mobileFlowApi = MobileFlowApiService(
  baseUrl: 'https://rideconnect-emp0.onrender.com/api/v1',
  authHeadersProvider: AuthSession.authHeaders,
);

typedef AuthHeadersProvider = Future<Map<String, String>> Function();

class MobileFlowApiService {
  MobileFlowApiService({
    required this.baseUrl,
    required AuthHeadersProvider authHeadersProvider,
    http.Client? client,
  }) : _authHeadersProvider = authHeadersProvider,
       _client = client ?? http.Client();

  final String baseUrl;
  final AuthHeadersProvider _authHeadersProvider;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String?>? query]) {
    final filtered = <String, String>{};
    (query ?? const <String, String?>{}).forEach((k, v) {
      if (v != null && v.trim().isNotEmpty) {
        filtered[k] = v.trim();
      }
    });
    return Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  Future<Map<String, String>> _headers() async {
    final auth = await _authHeadersProvider();
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...auth,
    };
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  void _ensureSuccess(http.Response response, Map<String, dynamic> envelope) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final success = envelope['success'];
    final accepted = success is bool ? success : ok;
    if (accepted) return;
    final message = (envelope['message'] ?? 'Request failed').toString();
    final error = envelope['error'];
    final errorCode =
        error is Map<String, dynamic>
            ? error['code']?.toString()
            : envelope['error_code']?.toString();
    throw MobileApiException(
      message: message,
      statusCode: response.statusCode,
      envelope: envelope,
      errorCode: errorCode,
    );
  }

  dynamic _envelopeData(Map<String, dynamic> envelope) => envelope['data'];

  Future<List<MobileNotificationItem>> getNotifications({
    bool? onlyClearable,
    bool? onlyActionRequired,
    bool? unreadOnly,
  }) async {
    final res = await _client
        .get(
          _uri('/notifications', <String, String?>{
            'only_clearable':
                onlyClearable == null
                    ? null
                    : (onlyClearable ? 'true' : 'false'),
            'only_action_required':
                onlyActionRequired == null
                    ? null
                    : (onlyActionRequired ? 'true' : 'false'),
            'unread_only':
                unreadOnly == null ? null : (unreadOnly ? 'true' : 'false'),
          }),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
    final data = _envelopeData(envelope);

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MobileNotificationItem.fromJson)
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final list = data['notifications'] ?? data['items'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(MobileNotificationItem.fromJson)
            .toList();
      }
    }

    return <MobileNotificationItem>[];
  }

  Future<Map<String, dynamic>> clearActionedNotifications() async {
    final res = await _client
        .delete(
          _uri('/notifications/clear-actioned'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
    return envelope;
  }

  Future<void> deleteNotification(int id) async {
    final res = await _client
        .delete(_uri('/notifications/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
  }

  Future<int> getUnreadCount() async {
    final res = await _client
        .get(_uri('/notifications/unread-count'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
    final data = _envelopeData(envelope);

    if (data is num) return data.toInt();
    if (data is Map<String, dynamic>) {
      final value = data['count'] ?? data['unread_count'] ?? data['unread'];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '0') ?? 0;
    }
    return 0;
  }

  Future<void> markNotificationRead(int id) async {
    final res = await _client
        .put(
          _uri('/notifications/$id/read'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
  }

  Future<void> markAllNotificationsRead() async {
    final res = await _client
        .put(
          _uri('/notifications/read-all'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
  }

  Future<List<OnlineDriver>> getOnlineDrivers() async {
    final res = await _client
        .get(_uri('/passenger/drivers/online'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
    final data = _envelopeData(envelope);

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(OnlineDriver.fromJson)
          .where((d) => d.id > 0)
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final list = data['drivers'] ?? data['items'] ?? data['results'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(OnlineDriver.fromJson)
            .where((d) => d.id > 0)
            .toList();
      }
    }

    return <OnlineDriver>[];
  }

  Future<RideRequestResult> createRideRequest(
    RideRequestPayload payload,
  ) async {
    final uri = _uri('/passenger/ride-requests');
    final requestBody = payload.toJson();

    if (kDebugMode) {
      debugPrint('[MobileFlowApiService] --> POST $uri');
      debugPrint(
        '[MobileFlowApiService] request body: ${jsonEncode(requestBody)}',
      );
    }

    final res = await _client
        .post(uri, headers: await _headers(), body: jsonEncode(requestBody))
        .timeout(const Duration(seconds: 20));

    if (kDebugMode) {
      debugPrint('[MobileFlowApiService] <-- ${res.statusCode} POST $uri');
      debugPrint('[MobileFlowApiService] response body: ${res.body}');
    }

    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
    final data = _envelopeData(envelope);
    if (data is Map<String, dynamic>) {
      return RideRequestResult.fromJson(data);
    }
    return RideRequestResult.fromJson(envelope);
  }

  Future<List<PassengerTripSnapshot>> getPassengerTrips() async {
    final res = await _client
        .get(_uri('/passenger/trips'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
    final data = _envelopeData(envelope);

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(PassengerTripSnapshot.fromJson)
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final list = data['trips'] ?? data['items'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(PassengerTripSnapshot.fromJson)
            .toList();
      }
    }

    return <PassengerTripSnapshot>[];
  }

  Future<PassengerTripSnapshot> getPassengerTripById(int tripId) async {
    final res = await _client
        .get(_uri('/passenger/trips/$tripId'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
    final data = _envelopeData(envelope);
    if (data is Map<String, dynamic>) {
      return PassengerTripSnapshot.fromJson(data);
    }
    return PassengerTripSnapshot.fromJson(envelope);
  }

  Future<void> cancelPassengerTrip(int tripId) async {
    final res = await _client
        .put(
          _uri('/passenger/trips/$tripId/cancel'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
  }

  Future<void> registerPushToken(PushTokenPayload payload) async {
    final res = await _client
        .post(
          _uri('/devices/push-token'),
          headers: await _headers(),
          body: jsonEncode(payload.toJson()),
        )
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
  }

  Future<void> unregisterPushToken(String token) async {
    final res = await _client
        .delete(_uri('/devices/push-token/$token'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final envelope = _decodeMap(res);
    _ensureSuccess(res, envelope);
  }

  void dispose() => _client.close();
}

class MobileApiException implements Exception {
  MobileApiException({
    required this.message,
    required this.statusCode,
    required this.envelope,
    this.errorCode,
  });

  final String message;
  final int statusCode;
  final Map<String, dynamic> envelope;
  final String? errorCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotificationNotActioned =>
      statusCode == 422 && errorCode == 'notification_not_actioned';

  @override
  String toString() => 'MobileApiException($statusCode): $message';
}

class MobileNotificationItem {
  MobileNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.canBeCleared = false,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;
  final bool canBeCleared;

  factory MobileNotificationItem.fromJson(Map<String, dynamic> json) {
    return MobileNotificationItem(
      id: _readInt(json, <String>['id', 'notification_id']) ?? 0,
      type: _readString(json, <String>['type', 'event']) ?? 'notification',
      title:
          _readString(json, <String>['title', 'subject', 'event_name']) ??
          'Notification',
      body:
          _readString(json, <String>['body', 'message', 'content']) ??
          'No details provided.',
      createdAt: DateTime.tryParse(
        _readString(json, <String>['created_at', 'time', 'timestamp']) ?? '',
      ),
      read:
          _readBool(json, <String>['read', 'is_read', 'seen']) ??
          (_readString(json, <String>['status']) == 'read'),
      canBeCleared:
          _readBool(json, <String>['can_be_cleared', 'canBeCleared']) ?? false,
    );
  }
}

class OnlineDriver {
  OnlineDriver({
    required this.id,
    required this.name,
    required this.rating,
    required this.vehicle,
  });

  final int id;
  final String name;
  final double rating;
  final String vehicle;

  factory OnlineDriver.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userMap =
        user is Map<String, dynamic> ? user : const <String, dynamic>{};
    return OnlineDriver(
      id:
          _readInt(json, <String>['id', 'driver_id', 'user_id']) ??
          _readInt(userMap, <String>['id', 'user_id']) ??
          0,
      name:
          _readString(json, <String>['name', 'driver_name']) ??
          _readString(userMap, <String>['name', 'full_name']) ??
          'Driver',
      rating:
          _readDouble(json, <String>[
            'rating',
            'avg_rating',
            'driver_rating',
          ]) ??
          _readDouble(userMap, <String>['rating', 'avg_rating']) ??
          0,
      vehicle:
          _readString(json, <String>['vehicle', 'vehicle_name', 'car']) ??
          _readString(userMap, <String>['vehicle', 'car']) ??
          'Vehicle',
    );
  }
}

class RideRequestPayload {
  RideRequestPayload({
    required this.driverId,
    required this.pickupLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLocation,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.fare,
    this.seats = 1,
    this.transportType,
    this.notes,
    this.scheduledAt,
  });

  final int driverId;
  final String pickupLocation;
  final double pickupLat;
  final double pickupLng;
  final String dropoffLocation;
  final double dropoffLat;
  final double dropoffLng;
  final double fare;
  final int seats;
  final String? transportType;
  final String? notes;
  final DateTime? scheduledAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'driver_id': driverId,
    'pickup_location': pickupLocation,
    'dropoff_location': dropoffLocation,
    'fare': fare,
    'seats': seats,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'pickup': {'lat': pickupLat, 'lng': pickupLng},
    'dropoff_lat': dropoffLat,
    'dropoff_lng': dropoffLng,
    'dropoff': {'lat': dropoffLat, 'lng': dropoffLng},
    if (transportType != null && transportType!.trim().isNotEmpty)
      'transport_type': transportType!.trim(),
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
  };
}

class RideRequestResult {
  RideRequestResult({
    required this.tripId,
    required this.requestId,
    required this.status,
  });

  final int? tripId;
  final int? requestId;
  final String status;

  factory RideRequestResult.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'];
    final request = json['request'];
    final tripMap =
        trip is Map<String, dynamic> ? trip : const <String, dynamic>{};
    final requestMap =
        request is Map<String, dynamic> ? request : const <String, dynamic>{};
    return RideRequestResult(
      tripId:
          _readInt(json, <String>['trip_id', 'tripId']) ??
          _readInt(tripMap, <String>['id', 'trip_id']) ??
          _readInt(json, <String>['id']),
      requestId:
          _readInt(json, <String>['request_id', 'ride_request_id']) ??
          _readInt(requestMap, <String>['id', 'request_id']) ??
          _readInt(json, <String>['id']),
      status:
          _readString(json, <String>['status']) ??
          _readString(tripMap, <String>['status']) ??
          _readString(requestMap, <String>['status']) ??
          'pending',
    );
  }

  factory RideRequestResult.empty() {
    return RideRequestResult(tripId: null, requestId: null, status: 'pending');
  }
}

class PassengerTripSnapshot {
  PassengerTripSnapshot({
    required this.id,
    required this.status,
    required this.driverName,
    required this.pickup,
    required this.dropoff,
    required this.fare,
  });

  final int id;
  final String status;
  final String driverName;
  final String pickup;
  final String dropoff;
  final double fare;

  bool get isTerminal {
    final lower = status.toLowerCase();
    return lower.contains('reject') ||
        lower.contains('cancel') ||
        lower.contains('complete');
  }

  factory PassengerTripSnapshot.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'];
    final driverMap =
        driver is Map<String, dynamic> ? driver : const <String, dynamic>{};
    return PassengerTripSnapshot(
      id: _readInt(json, <String>['id', 'trip_id']) ?? 0,
      status: _readString(json, <String>['status', 'trip_status']) ?? 'pending',
      driverName:
          _readString(json, <String>['driver_name', 'driver']) ??
          _readString(driverMap, <String>['name', 'driver_name']) ??
          _readString(json, <String>['name']) ??
          'Driver',
      pickup:
          _readString(json, <String>[
            'pickup_location',
            'pickup',
            'pickup_address',
          ]) ??
          '--',
      dropoff:
          _readString(json, <String>[
            'dropoff_location',
            'dropoff',
            'dropoff_address',
          ]) ??
          '--',
      fare: _readDouble(json, <String>['fare', 'price']) ?? 0,
    );
  }

  factory PassengerTripSnapshot.empty({required int id}) {
    return PassengerTripSnapshot(
      id: id,
      status: 'pending',
      driverName: 'Driver',
      pickup: '--',
      dropoff: '--',
      fare: 0,
    );
  }
}

class PushTokenPayload {
  PushTokenPayload({
    required this.platform,
    required this.deviceToken,
    required this.deviceId,
  });

  final String platform;
  final String deviceToken;
  final String deviceId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'platform': platform,
    'device_token': deviceToken,
    'device_id': deviceId,
  };
}

int? _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _readDouble(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool? _readBool(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
  }
  return null;
}

String? _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
