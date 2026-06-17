import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ──────────────────────────────────────────────────────────────────────
// WEBSOCKET SERVICE FOR REAL-TIME UPDATES
// ──────────────────────────────────────────────────────────────────────

class WebSocketService {
  WebSocketChannel? _channel;
  final Logger _logger;
  final String _baseUrl;
  final String Function() _getToken;

  Stream<Map<String, dynamic>>? _stream;
  bool _isConnected = false;

  WebSocketService({
    required String baseUrl,
    required String Function() getToken,
    Logger? logger,
  }) : _baseUrl = baseUrl,
       _getToken = getToken,
       _logger = logger ?? Logger();

  /// Connect to WebSocket
  Future<bool> connect() async {
    try {
      if (_isConnected && _channel != null) {
        _logger.d('Already connected to WebSocket');
        return true;
      }

      final token = _getToken();
      if (token.isEmpty) {
        throw Exception('No token available for WebSocket connection');
      }

      // Convert HTTP URL to WS URL
      final wsUrl = _baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$wsUrl?token=$token');

      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to be ready
      await _channel!.ready;
      _isConnected = true;

      _logger.d('Connected to WebSocket: $wsUrl');

      return true;
    } catch (e) {
      _logger.e('Error connecting to WebSocket', error: e);
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    try {
      if (_channel != null) {
        await _channel!.sink.close();
        _isConnected = false;
        _logger.d('Disconnected from WebSocket');
      }
    } catch (e) {
      _logger.e('Error disconnecting from WebSocket', error: e);
    }
  }

  /// Send message
  void send(Map<String, dynamic> message) {
    try {
      if (!_isConnected || _channel == null) {
        throw Exception('WebSocket not connected');
      }

      final json = jsonEncode(message);
      _channel!.sink.add(json);
      _logger.d('WebSocket message sent: $message');
    } catch (e) {
      _logger.e('Error sending WebSocket message', error: e);
    }
  }

  /// Get stream of messages
  Stream<Map<String, dynamic>> getStream() {
    if (_channel == null) {
      throw Exception('WebSocket not connected');
    }
    _stream ??= _channel!.stream
        .map((message) {
          try {
            return jsonDecode(message);
          } catch (e) {
            _logger.e('Error decoding WebSocket message', error: e);
            return null;
          }
        })
        .where((message) => message != null)
        .map((m) => m as Map<String, dynamic>);

    return _stream!;
  }

  /// Check connection status
  bool get isConnected => _isConnected;

  /// Listen to trip updates
  Stream<Map<String, dynamic>> listenToTripUpdates(int tripId) {
    send({'action': 'subscribe_trip', 'trip_id': tripId});
    return getStream()
        .where((message) => message['trip_id'] == tripId)
        .map((m) => m.cast<String, dynamic>());
  }

  /// Listen to driver location updates
  Stream<Map<String, dynamic>> listenToDriverLocation(int tripId) {
    send({'action': 'subscribe_location', 'trip_id': tripId});
    return getStream()
        .where((message) =>
            message['action'] == 'location_update' && message['trip_id'] == tripId)
        .map((m) => m.cast<String, dynamic>());
  }

  /// Dispose service
  void dispose() {
    disconnect();
    _channel = null;
    _stream = null;
  }
}

// ──────────────────────────────────────────────────────────────────────
// POLLING SERVICE FOR FALLBACK
// ──────────────────────────────────────────────────────────────────────

class PollingService {
  final Logger _logger;
  bool _isPolling = false;

  PollingService({Logger? logger}) : _logger = logger ?? Logger();

  /// Start polling with interval
  Stream<T> poll<T>({
    required Future<T> Function() request,
    required Duration interval,
    bool Function(T)? shouldContinue,
  }) async* {
    try {
      _isPolling = true;
      _logger.d('Starting polling with interval: ${interval.inSeconds}s');

      while (_isPolling) {
        try {
          final result = await request();
          yield result;

          // Check if should continue polling
          if (shouldContinue != null && !shouldContinue(result)) {
            _logger.d('Polling stopped by condition');
            break;
          }

          // Wait before next poll
          await Future.delayed(interval);
        } catch (e) {
          _logger.e('Error in polling request', error: e);
          // Continue polling even on error
          await Future.delayed(interval);
        }
      }
    } finally {
      _isPolling = false;
      _logger.d('Polling stopped');
    }
  }

  /// Stop polling
  void stop() {
    _isPolling = false;
  }
}
