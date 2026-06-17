import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/rtdb_service.dart';
import '../../../services/passenger_api.dart';
import '../domain/trip_lifecycle_state.dart' as lifecycle;
import '../models/motor_vehicle_trip_status.dart';
import 'realtime_event_router.dart';
import 'trip_realtime_service.dart';

class TripLifecycleManager with WidgetsBindingObserver {
  TripLifecycleManager({
    PassengerApi? api,
    TripRealtimeService? realtimeService,
    Connectivity? connectivity,
  }) : _api = api ?? PassengerApi.instance,
       _realtime = realtimeService ?? TripRealtimeService(),
       _connectivity = connectivity ?? Connectivity();

  static const _storageKey = 'trip_lifecycle.active_motor_vehicle_trip';
  static const Duration _offlineRetryDelay = Duration(seconds: 4);

  final PassengerApi _api;
  final TripRealtimeService _realtime;
  final Connectivity _connectivity;

  final _controller =
      StreamController<lifecycle.TripLifecycleState>.broadcast();

  Stream<lifecycle.TripLifecycleState> get stream => _controller.stream;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  int? _tripId;
  bool _paused = false;
  bool _stopped = true;
  bool _inFlight = false;
  bool _offline = false;
  bool _callbacksRegistered = false;

  lifecycle.TripLifecycleState? latest;

  static Future<lifecycle.TripLifecycleState?> restoreSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final data = decoded['raw'];
      if (data is! Map<String, dynamic>) return null;
      final status = MotorVehicleTripStatus.fromJson(data);
      if (status.phase.isTerminal || status.tripId <= 0) {
        await prefs.remove(_storageKey);
        return null;
      }
      return lifecycle.TripLifecycleState.fromStatus(status, polling: true);
    } catch (_) {
      await prefs.remove(_storageKey);
      return null;
    }
  }

  static Future<void> clearRestoredTrip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> start(
    int tripId, {
    String? initialStatus,
    String? initialMatchingStatus,
    Map<String, dynamic>? initialData,
  }) async {
    stop();
    _log('start trip=$tripId');
    WidgetsBinding.instance.addObserver(this);
    _tripId = tripId;
    _stopped = false;
    _paused = false;
    _offline = false;
    _listenConnectivity();
    _listenRealtime();
    await _emitInitial(
      initialStatus: initialStatus,
      initialMatchingStatus: initialMatchingStatus,
      initialData: initialData,
    );
    unawaited(refreshTripState(reason: 'start'));
  }

  Future<void> resumeFromStoredState() async {
    final restored = await restoreSnapshot();
    if (restored == null) return;
    await start(
      restored.tripId,
      initialStatus: restored.status,
      initialMatchingStatus: restored.matchingStatus,
      initialData: restored.raw,
    );
  }

  Future<void> refreshTripState({String reason = 'manual'}) async {
    if (_stopped || _paused || _tripId == null || _inFlight) return;
    if (_offline) {
      _scheduleNext(_offlineRetryDelay);
      return;
    }

    _inFlight = true;
    try {
      _log('poll trip=$_tripId reason=$reason');
      final data = await _api.getMotorVehicleTrip(_tripId!);
      final status = MotorVehicleTripStatus.fromJson(data);
      await _publish(status, source: 'poll');
    } on PassengerApiException catch (e) {
      _log('poll error status=${e.statusCode} message=${e.message}');
      if (e.statusCode == 404) {
        await clearRestoredTrip();
      }
      _scheduleNext(_pollInterval(error: true));
    } catch (e) {
      _log('poll network error=$e');
      _scheduleNext(_pollInterval(error: true));
    } finally {
      _inFlight = false;
    }
  }

  void pause() {
    _log('pause');
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_stopped || _tripId == null) return;
    _log('resume');
    _paused = false;
    unawaited(refreshTripState(reason: 'resume'));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopped = true;
    _paused = false;
    _inFlight = false;
    _tripId = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _unregisterEventCallbacks();
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> dispose() async {
    stop();
    await _realtime.dispose();
    await _controller.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('appLifecycle=$state');
    if (state == AppLifecycleState.resumed) {
      resume();
    } else {
      pause();
    }
  }

  Future<void> _emitInitial({
    String? initialStatus,
    String? initialMatchingStatus,
    Map<String, dynamic>? initialData,
  }) async {
    if (_tripId == null) return;
    if (initialStatus != null && initialStatus.trim().isNotEmpty) {
      final data = <String, dynamic>{
        'trip_id': _tripId,
        if (initialData != null) ...initialData,
        'status': initialStatus,
        if (initialMatchingStatus != null &&
            initialMatchingStatus.trim().isNotEmpty)
          'matching_status': initialMatchingStatus,
      };
      final status = MotorVehicleTripStatus.fromJson(data);
      if (status.phase != TripLifecyclePhase.unknown) {
        await _publish(status, source: 'initial', schedule: false);
        return;
      }
    }

    latest = lifecycle.TripLifecycleState.initial(tripId: _tripId!);
    _controller.add(latest!);
  }

  void _listenConnectivity() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final offline =
          results.isEmpty ||
          results.every((result) => result == ConnectivityResult.none);
      if (offline == _offline) return;
      _offline = offline;
      _log(offline ? 'offline' : 'online');
      final current = latest;
      if (current != null && offline && !_stopped) {
        _publish(
          MotorVehicleTripStatus.fromJson(current.raw),
          source: 'offline',
        );
      }
    });
  }

  void _listenRealtime() {
    _registerEventCallbacks();

    // Use watchTrip to get Firestore stream
    if (_tripId == null) return;

    final eventStream = _realtime.watchTrip(_tripId!);
    if (eventStream != null) {
      _log('realtime available subscribing');
      eventStream.listen(
        (event) {
          _log('realtime event received: ${event.event}');
        },
        onError: (error) {
          _log('realtime stream error=$error polling-only');
        },
      );
    } else {
      _log('realtime unavailable polling-only');
    }
  }

    /// Register event router callbacks to handle Firestore events
    void _registerEventCallbacks() {
      if (_callbacksRegistered) return;

      RideConnectEventRouter.onDriverAssigned = _onRealtimeEvent;
      RideConnectEventRouter.onDriverAccepted = _onRealtimeEvent;
      RideConnectEventRouter.onDriverArrived = _onRealtimeEvent;
      RideConnectEventRouter.onTripStarted = _onRealtimeEvent;
      RideConnectEventRouter.onTripCompleted = _onRealtimeEvent;
      RideConnectEventRouter.onTripCancelled = _onRealtimeEvent;
      RideConnectEventRouter.onTripRequestUpdated = _onRealtimeEvent;

      _callbacksRegistered = true;
    }

    void _onRealtimeEvent(Map<String, dynamic> payload) async {
      if (_tripId == null) return;
      final tripId = payload['trip_id'] as int?;
      if (tripId != _tripId) return;

      try {
        final status = MotorVehicleTripStatus.fromJson(payload);
        if (status.tripId != _tripId) return;
        await _publish(status, source: 'realtime');
      } catch (e) {
        _log('realtime parse error=$e');
      }
    }

  /// Unregister event router callbacks
  void _unregisterEventCallbacks() {
    if (!_callbacksRegistered) return;

    RideConnectEventRouter.onDriverAssigned = null;
    RideConnectEventRouter.onDriverAccepted = null;
    RideConnectEventRouter.onDriverArrived = null;
    RideConnectEventRouter.onTripStarted = null;
    RideConnectEventRouter.onTripCompleted = null;
    RideConnectEventRouter.onTripCancelled = null;
    RideConnectEventRouter.onTripRequestUpdated = null;

    _callbacksRegistered = false;
  }

  Future<void> _publish(
    MotorVehicleTripStatus status, {
    required String source,
    bool schedule = true,
  }) async {
    if (status.phase == TripLifecyclePhase.unknown) return;

    final next = lifecycle.TripLifecycleState.fromStatus(
      status,
      realtimeConnected: source == 'realtime',
      polling: source == 'poll',
    );

    if (latest?.phase != next.phase) {
      _log('phase-change ${latest?.phase} -> ${next.phase} (via $source)');
    }

    latest = next;
    _controller.add(next);

    if (schedule) {
      final prefs = await SharedPreferences.getInstance();
      unawaited(prefs.setString(_storageKey, jsonEncode(next.raw)));
    }

    if (next.phase.isTerminal) {
      await clearRestoredTrip();
    } else {
      _scheduleNext(_pollInterval());
    }
  }

  Duration _pollInterval({bool error = false}) {
    if (_offline) return _offlineRetryDelay;
    if (error) return const Duration(seconds: 4);

    final phase = latest?.phase;
    if (phase == lifecycle.TripLifecyclePhase.searchingCandidates ||
        phase == lifecycle.TripLifecyclePhase.matchTimeout) {
      return const Duration(seconds: 2);
    }

    if (phase == lifecycle.TripLifecyclePhase.driverAccepted ||
        phase == lifecycle.TripLifecyclePhase.driverArrived) {
      return const Duration(seconds: 3);
    }

    return const Duration(seconds: 5);
  }

  void _scheduleNext(Duration interval) {
    if (_stopped || _paused) return;
    _timer?.cancel();
    _timer = Timer(interval, refreshTripState);
  }

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[TripLifecycleManager] $message');
    }
  }
}

