import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';

class DriverApi {
  DriverApi._();

  static final DriverApi instance = DriverApi._();

  static const String _baseUrl =
      'https://rideconnect-emp0.onrender.com/api/v1/driver';
  static const Duration _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getProfile() => _get('/profile');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) =>
      _put('/profile', payload);

  Future<Map<String, dynamic>> getStats() => _get('/stats');

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

  Future<List<Map<String, dynamic>>> getTrips() async {
    final response = await _get('/trips');
    return extractList(response, preferredKeys: const ['trips', 'history']);
  }

  Future<Map<String, dynamic>> updateStatus({required bool isOnline}) => _put(
    '/status',
    {'is_online': isOnline, 'status': isOnline ? 'online' : 'offline'},
  );

  Future<List<Map<String, dynamic>>> getRequests() async {
    final response = await _get('/requests');
    return extractList(response, preferredKeys: const ['requests']);
  }

  Future<Map<String, dynamic>> acceptRequest(dynamic id) =>
      _put('/requests/$id/accept', <String, dynamic>{});

  Future<Map<String, dynamic>> rejectRequest(dynamic id) =>
      _put('/requests/$id/reject', <String, dynamic>{});

  Future<Map<String, dynamic>> completeRequest(dynamic id) =>
      _put('/requests/$id/complete', <String, dynamic>{});

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
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: headers).timeout(_timeout);
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
