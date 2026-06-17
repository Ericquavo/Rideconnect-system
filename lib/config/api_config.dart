// File: lib/config/api_config.dart
// RideConnect API Configuration for Production
// Last Updated: May 29, 2026

class ApiConfig {
  // Production URLs
  static const String baseUrl = 'https://rideconnect-emp0.onrender.com';
  static const String mlServiceUrl = 'https://ml-service-j72g.onrender.com';

  // API Paths
  static const String apiVersion = '/api/v1';
  static const String mobileApiPath = '/api/v1/mobile';

  // Full URLs for services
  static const String authBaseUrl = '$baseUrl$apiVersion/auth';
  static const String tripBaseUrl = '$baseUrl$mobileApiPath/trips';
  static const String driverBaseUrl = '$baseUrl$mobileApiPath/drivers';
  static const String passengerBaseUrl = '$baseUrl$apiVersion/passenger';
  static const String mlPredictionUrl = '$mlServiceUrl/predict';

  // Timeouts
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  static const int sendTimeout = 30000; // 30 seconds

  // Retry configuration
  static const int maxRetries = 3;
  static const int retryDelayMs = 1000;

  // Feature flags
  static const bool enableLogging = true;
  static const bool validateCertificates = true;

  /// Get full URL for a given endpoint
  static String getUrl(String endpoint, {String? service}) {
    final serviceUrl = service ?? baseUrl;
    return serviceUrl + endpoint;
  }

  /// Get authentication URL
  static String getAuthUrl(String path) => '$authBaseUrl$path';

  /// Get trip URL
  static String getTripUrl(String path) => '$tripBaseUrl$path';

  /// Get driver URL
  static String getDriverUrl(String path) => '$driverBaseUrl$path';

  /// Get passenger URL
  static String getPassengerUrl(String path) => '$passengerBaseUrl$path';

  /// Get ML service URL
  static String getMlUrl(String path) => '$mlServiceUrl$path';
}

/// Environment-specific configuration
enum Environment { production, staging, development }

class EnvironmentConfig {
  static Environment current = Environment.production;

  static String getBaseUrl() {
    switch (current) {
      case Environment.production:
        return 'https://rideconnect-emp0.onrender.com';
      case Environment.staging:
        return 'https://staging-rideconnect.onrender.com';
      case Environment.development:
        return 'http://localhost:8000';
    }
  }

  static String getMlServiceUrl() {
    switch (current) {
      case Environment.production:
        return 'https://ml-service-j72g.onrender.com';
      case Environment.staging:
        return 'https://staging-ml-service.onrender.com';
      case Environment.development:
        return 'http://localhost:5000';
    }
  }
}

/// API Endpoints - Used for type-safe URL construction
class ApiEndpoints {
  static const String apiRoot = 'https://rideconnect-emp0.onrender.com/api/v1';
  static const String mobileRoot = '$apiRoot/mobile';

  // ── Auth ──────────────────────────────────────────────────
  static const String login = '$apiRoot/auth/mobile/login';
  static const String register = '$apiRoot/auth/register';
  static const String registerPassenger = '$apiRoot/auth/register/passenger';
  static const String registerDriver = '$apiRoot/auth/register/driver';
  static const String logout = '$apiRoot/auth/logout';
  static const String sessionClear = '$apiRoot/auth/session/clear';
  static const String validateToken = '$apiRoot/auth/token/validate';
  static const String authProfile = '$apiRoot/auth/profile';
  static const String pushToken = '$apiRoot/devices/push-token';

  // ── Motorcycle Passenger ──────────────────────────────────
  static const String motoCreate =
      '$apiRoot/passenger/motor-vehicle/trip-requests';
  static String motoShow(int id) =>
      '$apiRoot/passenger/motor-vehicle/trip-requests/$id';
  static String motoCancel(int id) =>
      '$apiRoot/passenger/motor-vehicle/trip-requests/$id/cancel'; // POST
  static String passengerRate(String type, int id) =>
      '$apiRoot/passenger/$type/trip-rate/$id'; // POST

  // ── Unified Driver Trips (replaces moto/private specific) ───────
  static String driverAccept(int id) => '$apiRoot/driver/trips/$id/accept'; // POST
  static String driverReject(int id) => '$apiRoot/driver/trips/$id/reject'; // POST
  static String driverArrived(int id) => '$apiRoot/driver/trips/$id/arrived'; // POST
  static String driverStart(int id) => '$apiRoot/driver/trips/$id/start'; // POST
  static String driverComplete(int id) => '$apiRoot/driver/trips/$id/complete'; // POST

  // ── Public Bus Passenger ──────────────────────────────────
  static const String busRequest = '$apiRoot/passenger/public-bus/request';
  static String busShow(int id) => '$apiRoot/passenger/public-bus/requests/$id';
  static const String busCorridors = '$apiRoot/passenger/public-bus/corridors';
  static String busStops(int c) =>
      '$apiRoot/passenger/public-bus/corridors/$c/stops';
  static String busActive(int c) =>
      '$apiRoot/passenger/public-bus/corridors/$c/active-buses';
  static const String busBookSeat = '$apiRoot/passenger/public-bus/book-seat';
  static const String busCurrentTrip =
      '$apiRoot/passenger/public-bus/trips/current';

  // ── Private Car / Trips Table (mobile) ───────────────────
  static const String requestTrip = '$mobileRoot/trips/request'; // POST
  static const String currentTrip = '$mobileRoot/trips/current'; // GET
  static String trackTrip(int id) => '$mobileRoot/trips/$id/track'; // GET
  static String cancelTrip(int id) => '$mobileRoot/trips/$id/cancel'; // PUT
  static String completeTrip(int id) => '$mobileRoot/trips/$id/complete'; // PUT
  static String tripDetail(int id) => '$apiRoot/passenger/trips/$id'; // GET
  static String tripStatus(int id) =>
      '$apiRoot/passenger/trips/$id/status'; // GET
  static String matchingSession(int tripId) =>
      '$apiRoot/passenger/trips/$tripId/matching-session'; // GET

  // ── Driver Mobile (Private Car) ────────────────────────────
  static const String driverStatus = '$mobileRoot/drivers/status'; // POST
  static const String driverTrips = '$mobileRoot/drivers/trips'; // GET
  // Note: driverAccept/Reject/Start/Complete are now unified above
  static const String driverLiveLocation =
      '$mobileRoot/drivers/live-location'; // POST
  static const String driverLocationUpdate =
      '$apiRoot/driver/location/update'; // POST

  // ── Matching & Tracking ───────────────────────────────────
  static const String matchDrivers = '$mobileRoot/drivers/match'; // GET
  static const String availableDrivers = '$apiRoot/passenger/drivers/match'; // GET
  static String trackingDriver(int id) => '$mobileRoot/tracking/driver/$id';
  static String trackingTrip(int id) => '$mobileRoot/tracking/trip/$id';
  static const String trackingNearby = '$mobileRoot/tracking/nearby';

  // ── Route & Pricing ───────────────────────────────────────
  static const String routeCompute = '$apiRoot/route/compute'; // POST
  static const String pricingCalculate = '$apiRoot/pricing/calculate'; // POST

  // ── Payments & Notifications ──────────────────────────────
  static const String payments = '$apiRoot/passenger/payments';
  static const String paymentHistory = '$apiRoot/passenger/payments/history';
  static const String notifications = '$apiRoot/notifications';
  
  // ── Acknowledgments ───────────────────────────────────────
  static String tripAcknowledge(int id) => '$apiRoot/trips/$id/acknowledge'; // POST
  static String notificationAcknowledge(String id) => '$apiRoot/notifications/$id/acknowledged'; // POST

  // ── ML Service ────────────────────────────────────────────
  static const String mlHealth = 'https://ml-service-j72g.onrender.com/health';
  static const String mlRankDrivers =
      'https://ml-service-j72g.onrender.com/rank-drivers';
  static const String apiMlRank = '$apiRoot/ml/rank-drivers';

  // ── User Profile ──────────────────────────────────────────
  static const String userProfile = '$apiRoot/auth/profile';
  static const String passengerProfile = '$apiRoot/passenger/profile';
  static const String driverProfile = '$apiRoot/driver/profile';
}

/// HTTP Header constants
class ApiHeaders {
  static const String contentType = 'Content-Type';
  static const String authorization = 'Authorization';
  static const String acceptJson = 'Accept';

  static const String contentTypeJson = 'application/json';
  static const String acceptJsonValue = 'application/json';

  static Map<String, String> defaultHeaders({String? token}) {
    return {
      contentType: contentTypeJson,
      acceptJson: acceptJsonValue,
      if (token != null) authorization: 'Bearer $token',
    };
  }
}
