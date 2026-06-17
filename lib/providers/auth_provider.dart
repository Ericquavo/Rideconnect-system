import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../services/api_repository.dart';
import '../services/http_client.dart';

// ──────────────────────────────────────────────────────────────────────
// PROVIDERS FOR DEPENDENCIES
// ──────────────────────────────────────────────────────────────────────

final loggerProvider = Provider((ref) => Logger());

final httpClientProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  final httpClient = HttpClient(logger: logger);
  httpClient.initialize(
    baseUrl: 'https://rideconnect-emp0.onrender.com/api/v1',
    getToken: () => _tokenGetter(ref),
  );
  return httpClient;
});

final secureStorageServiceProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return SecureStorageService(logger: logger);
});

final apiRepositoryProvider = Provider((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final logger = ref.watch(loggerProvider);
  return ApiRepository(httpClient: httpClient, logger: logger);
});

final authServiceProvider = Provider((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final apiRepository = ref.watch(apiRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  return AuthService(
    secureStorage: secureStorage,
    apiRepository: apiRepository,
    logger: logger,
  );
});

// ──────────────────────────────────────────────────────────────────────
// AUTH STATE PROVIDER
// ──────────────────────────────────────────────────────────────────────

enum AuthState { unauthenticated, authenticated, loading, error }

class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;
  final Logger _logger;

  AuthStateNotifier({required AuthService authService, required Logger logger})
    : _authService = authService,
      _logger = logger,
      super(const AsyncValue.data(null));

  /// Initialize auth state from storage
  Future<void> initialize() async {
    try {
      state = const AsyncValue.loading();
      final isLoggedIn = await _authService.isLoggedIn();

      if (isLoggedIn) {
        // In production, fetch user profile from API
        // For now, we'll just set as authenticated
        state = AsyncValue.data(null);
        _logger.d('User authenticated from storage');
      } else {
        state = const AsyncValue.data(null);
        _logger.d('User not authenticated');
      }
    } catch (e, st) {
      _logger.e('Error initializing auth', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Login
  Future<void> login({required String email, required String password}) async {
    try {
      state = const AsyncValue.loading();
      final user = await _authService.login(email: email, password: password);
      state = AsyncValue.data(user);
      _logger.d('Login successful');
    } catch (e, st) {
      _logger.e('Login error', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Register
  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String userType,
  }) async {
    try {
      state = const AsyncValue.loading();
      final user = await _authService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
        userType: userType,
      );
      state = AsyncValue.data(user);
      _logger.d('Registration successful');
    } catch (e, st) {
      _logger.e('Registration error', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      state = const AsyncValue.loading();
      await _authService.logout();
      state = const AsyncValue.data(null);
      _logger.d('Logout successful');
    } catch (e, st) {
      _logger.e('Logout error', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh token
  Future<void> refreshToken() async {
    try {
      await _authService.refreshAccessToken();
      _logger.d('Token refreshed');
    } catch (e, st) {
      _logger.e('Token refresh error', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Check authentication status
  Future<bool> isAuthenticated() async {
    return await _authService.isLoggedIn();
  }
}

final authStateProvider = StateNotifierProvider.autoDispose<
  AuthStateNotifier,
  AsyncValue<User?>
>((ref) {
  final authService = ref.watch(authServiceProvider);
  final logger = ref.watch(loggerProvider);

  final notifier = AuthStateNotifier(authService: authService, logger: logger);

  // Initialize on creation
  notifier.initialize();

  return notifier;
});

// ──────────────────────────────────────────────────────────────────────
// AUTH HELPER PROVIDERS
// ──────────────────────────────────────────────────────────────────────

final isAuthenticatedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isLoggedIn();
});

final currentUserTypeProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserType();
});

final currentUserIdProvider = FutureProvider.autoDispose<int?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserId();
});

final accessTokenProvider = FutureProvider.autoDispose<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getAccessToken();
});

// ──────────────────────────────────────────────────────────────────────
// HELPER FUNCTION
// ──────────────────────────────────────────────────────────────────────

String _tokenGetter(Ref ref) {
  try {
    final token = ref.read(accessTokenProvider).whenData((t) => t ?? '');
    return '';
  } catch (e) {
    return '';
  }
}
