import 'dart:async';

import 'package:logger/logger.dart';

import '../../../services/passenger_api.dart';
import '../domain/trip_lifecycle_state.dart' as lifecycle;
import '../models/motor_vehicle_trip_status.dart';
import 'trip_realtime_service.dart';

class TripMatchingService {
  TripMatchingService({
    PassengerApi? api,
    TripRealtimeService? realtimeService,
    Logger? logger,
  }) : _api = api ?? PassengerApi.instance,
       _realtime = realtimeService ?? TripRealtimeService(),
       _logger = logger ?? Logger();

  final PassengerApi _api;
  final TripRealtimeService _realtime;
  final Logger _logger;

  // Backoff schedule (ms): 2s, 3s, 4.5s, 6.7s, then capped at 8s.
  static const int _minIntervalMs = 2000;
  static const int _maxIntervalMs = 8000;
  static const double _factor = 1.5;

  // Stop searching after this long with no driver (client-side safety net).
  static const Duration _searchTimeout = Duration(seconds: 120);

  final _controller =
      StreamController<lifecycle.TripLifecycleState>.broadcast();
  Stream<lifecycle.TripLifecycleState> get stream => _controller.stream;

  Timer? _timer;
  int _intervalMs = _minIntervalMs;
  bool _inFlight = false;
  bool _paused = false;
  bool _stopped = false;
  bool _useRealtime = false;
  DateTime? _startedAt;
  TripLifecyclePhase? _lastPhase;
  int? _tripId;

  lifecycle.TripLifecycleState? latest;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;

  void startPolling(
    int tripId, {
    String? initialStatus,
    String? initialMatchingStatus,
    Map<String, dynamic>? initialData,
  }) {
    stop();
    _tripId = tripId;
    _stopped = false;
    _paused = false;
    _useRealtime = false;
    _intervalMs = _minIntervalMs;
    _startedAt = DateTime.now();
    _lastPhase = null;
    _listenRealtime();
    _emitInitial(
      initialStatus: initialStatus,
      initialMatchingStatus: initialMatchingStatus,
      initialData: initialData,
    );
    _tick();
  }

  void _listenRealtime() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _realtime.messages.listen(
      _onRealtimeMessage,
      onError: (error, stackTrace) {
        _logger.w('[TripMatchingService] realtime error: $error');
        _switchToPolling();
      },
      onDone: _switchToPolling,
    );
    _realtime
        .connect()
        .then((connected) {
          if (connected && _tripId != null) {
            _realtime.subscribeTrip(_tripId!);
          }
        })
        .catchError((error) {
          _logger.w('[TripMatchingService] realtime connect failed: $error');
          _switchToPolling();
        });
  }

  void _onRealtimeMessage(Map<String, dynamic> payload) {
    _logger.d('[TripMatchingService] realtime payload: $payload');
    if (_tripId == null) return;
    final data =
        payload['data'] is Map<String, dynamic>
            ? payload['data'] as Map<String, dynamic>
            : payload;
    final status = MotorVehicleTripStatus.fromJson(data);
    if (status.tripId != _tripId) return;
    _useRealtime = true;
    _publish(status, source: 'realtime');
    if (status.phase.isTerminal) {
      stop();
    }
  }

  void _switchToPolling() {
    if (_stopped) return;
    if (_useRealtime) {
      _logger.i(
        '[TripMatchingService] realtime disconnected, falling back to polling',
      );
    }
    _useRealtime = false;
    _scheduleNext();
  }

  void _emitInitial({
    String? initialStatus,
    String? initialMatchingStatus,
    Map<String, dynamic>? initialData,
  }) {
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
        _lastPhase = status.phase;
        _publish(status, source: 'initial');
        return;
      }
    }

    final state = lifecycle.TripLifecycleState.initial(tripId: _tripId!);
    latest = state;
    _controller.add(state);
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_stopped || _tripId == null || !_paused) return;
    _paused = false;
    _intervalMs = _minIntervalMs;
    _tick();
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    _tripId = null;
    _useRealtime = false;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtime.dispose();
  }

  Future<void> dispose() async {
    stop();
    await _controller.close();
  }

  Future<void> _tick() async {
    if (_stopped || _paused || _tripId == null) return;
    if (_useRealtime) {
      _logger.d('[TripMatchingService] realtime is active, skipping polling');
      return;
    }
    if (_inFlight) {
      _scheduleNext();
      return;
    }

    if (_lastPhase == TripLifecyclePhase.searchingCandidates &&
        _startedAt != null &&
        DateTime.now().difference(_startedAt!) > _searchTimeout) {
      _logger.w('[TripMatchingService] match timeout for trip=$_tripId');
      final timeoutState = lifecycle.TripLifecycleState(
        tripId: _tripId!,
        phase: lifecycle.TripLifecyclePhase.matchTimeout,
        status: 'EXPIRED',
        statusMessage: 'Match timeout. Please retry or change pickup.',
        polling: false,
      );
      _controller.add(timeoutState);
      stop();
      return;
    }

    _inFlight = true;
    try {
      _logger.d('[TripMatchingService] poll tick for trip=$_tripId');
      final data = await _api.getMotorVehicleTrip(_tripId!);
      final status = MotorVehicleTripStatus.fromJson(data);
      _publish(status, source: 'poll');
      if (status.phase.isTerminal) {
        stop();
        return;
      }
      if (status.phase != _lastPhase) {
        _intervalMs = _minIntervalMs;
        _lastPhase = status.phase;
      } else {
        _growInterval();
      }
    } catch (e) {
      _logger.w('[TripMatchingService] poll failed: $e');
      _growInterval();
    } finally {
      _inFlight = false;
    }

    _scheduleNext();
  }

  void _publish(MotorVehicleTripStatus status, {required String source}) {
    if (status.phase == TripLifecyclePhase.unknown) {
      _logger.w(
        '[TripMatchingService] ignoring unknown phase for '
        'status=${status.status} matching=${status.matchingStatus} '
        'keys=${status.raw.keys.toList()}',
      );
      return;
    }

    final next = lifecycle.TripLifecycleState.fromStatus(
      status,
      realtimeConnected: source == 'realtime',
      polling: source == 'poll',
    );
    if (latest?.phase != next.phase) {
      _logger.i(
        '[TripMatchingService] state transition ${latest?.phase} -> ${next.phase} ($source)',
      );
    }
    if (source == 'poll') {
      _logger.d(
        '[TripMatchingService] poll status=${next.status} phase=${next.phase}',
      );
    }
    latest = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }

  void _scheduleNext() {
    if (_stopped || _paused || _useRealtime) return;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: _intervalMs), _tick);
  }

  void _growInterval() {
    _intervalMs = (_intervalMs * _factor).round();
    if (_intervalMs > _maxIntervalMs) {
      _intervalMs = _maxIntervalMs;
    }
  }
}
