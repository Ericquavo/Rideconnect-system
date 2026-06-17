import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../firebase_options.dart';
import '../core/firebase/firebase_initializer.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/auth/data/repositories/auth_repository.dart';

/// Initializes all app dependencies and configurations
class AppInitializer {
  static final Logger _logger = Logger();

  /// Initialize Firebase and app services
  static Future<void> initialize() async {
    try {
      _logger.i('[AppInitializer] Starting initialization...');

      // 1. Initialize Firebase
      await _initializeFirebase();

      // 2. Set up logging
      _setupLogging();

      // 3. Pre-load auth state
      await _preloadAuthState();

      _logger.i('[AppInitializer] Initialization complete!');
    } catch (e) {
      _logger.e('[AppInitializer] Initialization error: $e', error: e);
      rethrow;
    }
  }

  /// Initialize Firebase with RTDB (RTDB-only, no Firestore)
  static Future<void> _initializeFirebase() async {
    try {
      _logger.i('[AppInitializer] Initializing Firebase...');

      final firebaseInitializer = FirebaseInitializer.instance;
      await firebaseInitializer.initialize();

      _logger.i('[AppInitializer] Firebase initialized successfully');
    } catch (e) {
      _logger.e('[AppInitializer] Firebase init error: $e');
      rethrow;
    }
  }

  /// Setup logging configuration
  static void _setupLogging() {
    // Configure logger for production vs debug
    Logger.level = kDebugMode ? Level.debug : Level.info;
    _logger.i('[AppInitializer] Logging configured');
  }

  /// Pre-load auth state from secure storage
  static Future<void> _preloadAuthState() async {
    try {
      _logger.i('[AppInitializer] Checking auth state...');

      final storage = SecureStorageService();
      final isAuthenticated = await storage.isAuthenticated();

      if (isAuthenticated) {
        _logger.i('[AppInitializer] User is authenticated');
        
        // Validate token is still valid
        // This will be done in AuthProvider on startup
      } else {
        _logger.i('[AppInitializer] User not authenticated');
      }
    } catch (e) {
      _logger.w('[AppInitializer] Auth check error: $e');
      // Continue anyway - user will login if needed
    }
  }

  /// Get version info for debugging
  static Map<String, String> getDebugInfo() {
    return {
      'app': 'RideConnect',
      'env': kDebugMode ? 'DEBUG' : 'RELEASE',
      'firebase': 'RTDB (Firestore removed)',
      'api': 'https://rideconnect-emp0.onrender.com/api/v1',
    };
  }
}
