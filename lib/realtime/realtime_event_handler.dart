import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:rideconnect_app/models/matching/realtime_events.dart';
import 'package:rideconnect_app/auth/auth_session.dart';

/// Handles WebSocket connections for real-time events
class RealtimeEventHandler {
  static final RealtimeEventHandler _instance =
      RealtimeEventHandler._internal();

  factory RealtimeEventHandler() {
    return _instance;
  }

  RealtimeEventHandler._internal();

  WebSocketChannel? _channel;
  final _eventStreamController = StreamController<RealtimeEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  bool get isConnected => _channel != null;
  Stream<RealtimeEvent> get eventStream => _eventStreamController.stream;
  Stream<bool> get connectionStream => _connectionStateController.stream;

  /// Connect to WebSocket for real-time events
  Future<void> connect() async {
    if (isConnected) return;

    try {
      final session = await AuthSession.load();
      final token = session?.token;
      if (token == null) throw Exception('No auth token available');

      // Update WebSocket URL based on your backend
      const wsUrl = 'wss://rideconnect-emp0.onrender.com/ws';

      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl?token=$token'));

      _connectionStateController.add(true);
      _listenToChannel();
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _connectionStateController.add(false);
      rethrow;
    }
  }

  /// Listen to incoming WebSocket messages
  void _listenToChannel() {
    _channel?.stream.listen(
      (message) {
        try {
          final json = jsonDecode(message as String) as Map<String, dynamic>;
          final event = RealtimeEvent.fromJson(json);
          _eventStreamController.add(event);
        } catch (e) {
          debugPrint('Error parsing real-time event: $e');
        }
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
        _connectionStateController.add(false);
      },
      onDone: () {
        debugPrint('WebSocket closed');
        _connectionStateController.add(false);
        _channel = null;
      },
    );
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _connectionStateController.add(false);
  }

  /// Subscribe to specific event type
  Stream<T> subscribeToEvent<T extends RealtimeEvent>() {
    return _eventStreamController.stream.where((event) => event is T).cast<T>();
  }

  /// Cleanup resources
  void dispose() {
    disconnect();
    _eventStreamController.close();
    _connectionStateController.close();
  }
}
