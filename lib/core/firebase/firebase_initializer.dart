import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import '../../firebase_options.dart';

class FirebaseInitializationState {
  const FirebaseInitializationState._(this.initialized, this.error);

  final bool initialized;
  final String? error;

  static const unitialized = FirebaseInitializationState._(false, null);
  static FirebaseInitializationState errorState(String message) =>
      FirebaseInitializationState._(false, message);
}

class FirebaseInitializer {
  FirebaseInitializer._();

  static final FirebaseInitializer instance = FirebaseInitializer._();
  static final Logger _logger = Logger();

  FirebaseInitializationState _state = FirebaseInitializationState.unitialized;
  final StreamController<FirebaseInitializationState> _stateController =
      StreamController<FirebaseInitializationState>.broadcast();

  Stream<FirebaseInitializationState> get stateStream =>
      _stateController.stream;
  FirebaseInitializationState get state => _state;
  bool get isInitialized => _state.initialized;

  Future<void> initialize() async {
    if (_state.initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Enable RTDB offline persistence (RTDB only, no Firestore)
      FirebaseDatabase.instance.setPersistenceEnabled(true);

      _state = const FirebaseInitializationState._(true, null);
      _stateController.add(_state);
      _logger.i('[FirebaseInitializer] Firebase initialized successfully');
    } catch (e, stack) {
      _state = FirebaseInitializationState.errorState(e.toString());
      _stateController.add(_state);
      _logger.e(
        '[FirebaseInitializer] Initialization failed',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> waitForInitialization({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_state.initialized) return;
    await stateStream
        .firstWhere((s) => s.initialized || s.error != null)
        .timeout(timeout);
  }

  void dispose() {
    _stateController.close();
  }
}
