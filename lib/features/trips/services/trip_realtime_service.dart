import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../auth/auth_session.dart';

class TripRealtimeService {
  TripRealtimeService({
    String baseUrl = 'https://rideconnect-emp0.onrender.com/api/v1',
    Logger? logger,
  }) : _baseUrl = baseUrl,
       _logger = logger ?? Logger();

  final String _baseUrl;
  final Logger _logger;

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  Timer? _heartbeat;
  bool _subscribed = false;

  Stream<Map<String, dynamic>> get messages {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast(
      onCancel: _disposeChannel,
    );
    return _controller!.stream;
  }

  bool get isConnected => _channel != null;

  Future<bool> connect() async {
    if (_channel != null) return true;

    final session = await AuthSession.load();
    final token = session?.token;
    if (token == null || token.isEmpty) {
      _logger.w('Realtime connection skipped because auth token is missing.');
      return false;
    }

    try {
      final wsBase = _baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$wsBase/realtime?token=${Uri.encodeQueryComponent(token)}');
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _onRawMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
      _logger.d('[TripRealtimeService] Connected to $uri');
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_channel != null) {
          _send({'action': 'ping'});
        }
      });
      return true;
    } catch (e, stackTrace) {
      _logger.e('[TripRealtimeService] Connect failed: $e\n$stackTrace');
      _disposeChannel();
      return false;
    }
  }

  Future<void> subscribeTrip(int tripId) async {
    if (!await connect()) return;
    if (_subscribed) return;
    _send({'action': 'subscribe', 'topic': 'trip.$tripId'});
    _subscribed = true;
    _logger.d('[TripRealtimeService] Subscribed to trip.$tripId');
  }

  Future<void> unsubscribeTrip(int tripId) async {
    if (!_subscribed || _channel == null) return;
    _send({'action': 'unsubscribe', 'topic': 'trip.$tripId'});
    _subscribed = false;
    _logger.d('[TripRealtimeService] Unsubscribed from trip.$tripId');
  }

  void _send(Map<String, dynamic> envelope) {
    try {
      final data = jsonEncode(envelope);
      _channel?.sink.add(data);
      _logger.d('[TripRealtimeService] Sent: $envelope');
    } catch (e) {
      _logger.e('[TripRealtimeService] Failed to send message: $e');
    }
  }

  void _onRawMessage(dynamic raw) {
    try {
      if (raw is String) {
        final payload = jsonDecode(raw);
        if (payload is Map<String, dynamic>) {
          _controller?.add(payload);
          return;
        }
      }
      if (raw is Map<String, dynamic>) {
        _controller?.add(raw);
      }
    } catch (e) {
      _logger.e('[TripRealtimeService] Error decoding message: $e');
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    _logger.e('[TripRealtimeService] Connection error: $error\n$stackTrace');
    _disposeChannel();
  }

  void _onDone() {
    _logger.w('[TripRealtimeService] Connection closed');
    _disposeChannel();
  }

  Future<void> dispose() async {
    _disposeChannel();
    await _controller?.close();
    _controller = null;
  }

  void _disposeChannel() {
    _heartbeat?.cancel();
    _heartbeat = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _subscribed = false;
  }
}
