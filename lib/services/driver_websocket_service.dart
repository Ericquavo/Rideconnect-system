import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

typedef NewTripRequestCallback = void Function(Map<String, dynamic> payload);

class DriverWebSocketService {
  DriverWebSocketService._();
  static final DriverWebSocketService instance = DriverWebSocketService._();

  final Logger _logger = Logger();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  Timer? _pingTimer;

  NewTripRequestCallback? _onNewTripRequest;

  bool get isConnected => _isConnected;

  /// Connect and subscribe to private-driver.{userId} channel
  Future<void> connect({
    required String token,
    required int userId,
    required NewTripRequestCallback onNewTripRequest,
  }) async {
    if (_isConnected) {
      _logger.d('[DriverWebSocket] Already connected.');
      return;
    }

    _onNewTripRequest = onNewTripRequest;

    try {
      _logger.i('[DriverWebSocket] Connecting to Reverb for userId: $userId');

      final wsUrl = Uri.parse(
        'wss://rideconnect-emp0.onrender.com/app/reverb-key?protocol=7&client=js&version=7.0.6&flash=false',
      );

      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message, token, userId);
        },
        onError: (error) {
          _logger.e('[DriverWebSocket] WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          _logger.w('[DriverWebSocket] WebSocket connection closed.');
          _handleDisconnect();
        },
      );

      // Start a heartbeat timer to keep the connection alive (every 30 seconds)
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_isConnected && _channel != null) {
          _sendEvent('pusher:ping', {});
        }
      });

    } catch (e) {
      _logger.e('[DriverWebSocket] Connection error: $e');
      _handleDisconnect();
    }
  }

  void _sendEvent(String event, Map<String, dynamic> data) {
    if (_channel == null) return;
    final payload = jsonEncode({
      'event': event,
      'data': data,
    });
    _channel!.sink.add(payload);
  }

  Future<void> _handleMessage(dynamic rawMessage, String token, int userId) async {
    try {
      final message = jsonDecode(rawMessage.toString());
      final event = message['event']?.toString();
      final dataStr = message['data'];
      
      _logger.d('[DriverWebSocket] Received event: $event');

      if (event == 'pusher:connection_established') {
        final data = jsonDecode(dataStr.toString());
        final socketId = data['socket_id'];
        _logger.i('[DriverWebSocket] Connection established. Socket ID: $socketId');
        
        // Authenticate the private channel
        await _authenticateAndSubscribe(socketId, token, userId);
      } else if (event == 'pusher:ping') {
        _sendEvent('pusher:pong', {});
      } else if (event == 'App\\Events\\NewTripRequestEvent' || 
                 event == '.NewTripRequestEvent' ||
                 (event != null && event.contains('NewTripRequestEvent'))) {
        
        final data = dataStr is Map ? dataStr : jsonDecode(dataStr.toString());
        _logger.i('[DriverWebSocket] Received NewTripRequestEvent: $data');
        
        final payload = data['payload'] ?? data;
        if (payload != null && _onNewTripRequest != null) {
          _onNewTripRequest!(Map<String, dynamic>.from(payload));
        }
      }
    } catch (e) {
      _logger.e('[DriverWebSocket] Error parsing message: $e');
    }
  }

  Future<void> _authenticateAndSubscribe(String socketId, String token, int userId) async {
    try {
      final channelName = 'private-driver.$userId';
      var authUrl = 'https://rideconnect-emp0.onrender.com/broadcasting/auth';
      _logger.i('[DriverWebSocket] Authenticating channel: $channelName via $authUrl');

      var response = await http.post(
        Uri.parse(authUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'socket_id': socketId,
          'channel_name': channelName,
        },
      );

      if (response.statusCode != 200) {
        authUrl = 'https://rideconnect-emp0.onrender.com/api/v1/broadcasting/auth';
        _logger.i('[DriverWebSocket] Auth failed on default endpoint. Retrying via fallback: $authUrl');
        response = await http.post(
          Uri.parse(authUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'socket_id': socketId,
            'channel_name': channelName,
          },
        );
      }

      if (response.statusCode == 200) {
        final authData = jsonDecode(response.body);
        final authSignature = authData['auth'];

        _logger.i('[DriverWebSocket] Subscribing to channel: $channelName');
        _sendEvent('pusher:subscribe', {
          'auth': authSignature,
          'channel': channelName,
        });
      } else {
        _logger.e('[DriverWebSocket] Auth failed on all endpoints. Status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _logger.e('[DriverWebSocket] Error authenticating channel: $e');
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel = null;
  }

  /// Disconnect and cleanup
  void disconnect() {
    _logger.i('[DriverWebSocket] Disconnecting from Reverb...');
    _handleDisconnect();
    _onNewTripRequest = null;
  }
}
