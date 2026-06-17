import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

import '../core/network/api_endpoints.dart';
import '../config/dio_config.dart';

class HeartbeatService with WidgetsBindingObserver {
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;

  Timer? _heartbeatTimer;
  final Logger _logger = Logger();
  late Dio _dio;

  HeartbeatService._internal() {
    _dio = DioConfig.createDioClient();
  }

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
      _ping(); // Immediate ping on resume
    } else if (state == AppLifecycleState.paused) {
      _stopHeartbeat();
    }
  }

  void _startHeartbeat() {
    if (_heartbeatTimer != null && _heartbeatTimer!.isActive) return;
    
    // Poll every 15 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _ping();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _ping() async {
    try {
      // Use /mobile/trips/current or /auth/profile to keep is_online active
      await _dio.get(ApiEndpoints.currentTrip);
      _logger.d('Heartbeat ping successful');
    } catch (e) {
      _logger.e('Heartbeat ping failed: $e');
    }
  }
}
