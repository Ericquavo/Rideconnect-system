import 'package:logger/logger.dart';
import '../../../services/passenger_api.dart';

/// Realtime configuration from backend
/// Used to determine if WebSocket is enabled and connection details
class RealtimeConfig {
  const RealtimeConfig({
    required this.enabled,
    required this.provider,
    required this.host,
    required this.port,
    required this.scheme,
    required this.wsPath,
  });

  final bool enabled;
  final String provider;
  final String host;
  final int port;
  final String scheme;
  final String wsPath;

  factory RealtimeConfig.fromJson(Map<String, dynamic> json) {
    return RealtimeConfig(
      enabled: json['enabled'] == true,
      provider: json['provider'] as String? ?? 'reverb',
      host: json['host'] as String? ?? 'localhost',
      port: (json['port'] as num?)?.toInt() ?? 443,
      scheme: json['scheme'] as String? ?? 'https',
      wsPath: json['ws_path'] as String? ?? 'ws',
    );
  }

  factory RealtimeConfig.disabled() {
    return const RealtimeConfig(
      enabled: false,
      provider: 'none',
      host: 'localhost',
      port: 443,
      scheme: 'https',
      wsPath: 'ws',
    );
  }

  @override
  String toString() =>
      'RealtimeConfig(enabled=$enabled, provider=$provider, host=$host, port=$port, scheme=$scheme, wsPath=$wsPath)';
}

/// Service to fetch and cache realtime configuration
class RealtimeConfigService {
  RealtimeConfigService({PassengerApi? api, Logger? logger})
    : _api = api ?? PassengerApi.instance,
      _logger = logger ?? Logger();

  final PassengerApi _api;
  final Logger _logger;
  RealtimeConfig? _cached;
  DateTime? _cachedAt;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Fetch realtime configuration
  /// Uses cache if available and not expired
  Future<RealtimeConfig> fetch() async {
    try {
      // Check cache
      if (_cached != null && _cachedAt != null) {
        if (DateTime.now().difference(_cachedAt!) < _cacheDuration) {
          _logger.d('[RealtimeConfigService] Using cached config');
          return _cached!;
        }
      }

      // Fetch from backend
      _logger.d('[RealtimeConfigService] Fetching config from backend');
      final response = await _api.get('/realtime/config');

      // Response is always Map<String, dynamic>, may contain nested 'data'
      final configData = (response['data'] ?? response) as Map<String, dynamic>;

      _cached = RealtimeConfig.fromJson(configData);
      _cachedAt = DateTime.now();

      _logger.i('[RealtimeConfigService] Config fetched: $_cached');
      return _cached!;
    } catch (e, st) {
      _logger.w(
        '[RealtimeConfigService] Failed to fetch config, using disabled: $e\n$st',
      );
      return RealtimeConfig.disabled();
    }
  }

  /// Clear cached config to force refresh
  void clearCache() {
    _cached = null;
    _cachedAt = null;
  }
}
