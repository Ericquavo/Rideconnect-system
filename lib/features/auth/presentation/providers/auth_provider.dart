import 'package:riverpod/riverpod.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/models/auth_response.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

// Storage provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// API Client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Auth DataSource provider
final authDataSourceProvider = Provider<IAuthDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthDataSource(apiClient: apiClient);
});

// Auth repository provider
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final dataSource = ref.watch(authDataSourceProvider);
  final storage = ref.watch(secureStorageProvider);

  return AuthRepository(dataSource: dataSource, storage: storage);
});

// Auth state notifier
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final User? user;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.user,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    User? user,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final IAuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState());

  Future<bool> login({
    required String email,
    required String password,
    required String deviceName,
    required String fcmToken,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authData = await _repository.login(
        email: email,
        password: password,
        deviceName: deviceName,
        fcmToken: fcmToken,
      );

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: authData.user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.logout();
      state = AuthState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final authData = await _repository.getStoredAuth();
      if (authData != null) {
        final isValid = await _repository.validateToken();
        if (isValid) {
          state = state.copyWith(isAuthenticated: true, user: authData.user);
        } else {
          await _repository.clearAuth();
          state = AuthState();
        }
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
