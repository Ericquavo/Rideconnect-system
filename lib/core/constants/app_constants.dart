/// Application constants
class AppConstants {
  // API Configuration
  static const String apiBaseUrl =
      'https://rideconnect-emp0.onrender.com/api/v1';
  static const String mlServiceUrl = 'https://ml-service-j72g.onrender.com';

  // API Endpoints - Authentication
  static const String authLoginEndpoint = '/api/v1/auth/mobile/login';
  static const String authRegisterEndpoint = '/api/v1/auth/register';
  static const String authRegisterPassengerEndpoint =
      '/api/v1/auth/register/passenger';
  static const String authRegisterDriverEndpoint =
      '/api/v1/auth/register/driver';
  static const String authLogoutEndpoint = '/api/v1/auth/logout';
  static const String authSessionClearEndpoint = '/api/v1/auth/session/clear';
  static const String authValidateTokenEndpoint = '/api/v1/auth/token/validate';
  static const String pushTokenEndpoint = '/api/v1/devices/push-token';
  // REMOVED: authRefreshEndpoint - Sanctum tokens do not auto-refresh

  // Passenger Endpoints - Motor Vehicle
  static const String passengerMotorVehicleRequestEndpoint =
      '/api/v1/passenger/motor-vehicle/trip-requests';
  static const String passengerMotorVehicleTripStatusEndpoint =
      '/api/v1/passenger/motor-vehicle/trip-requests/{id}';
  static const String passengerCancelMotorVehicleTripEndpoint =
      '/api/v1/passenger/motor-vehicle/trip-requests/{id}/cancel'; // POST
  static const String passengerRateMotorVehicleTripEndpoint =
      '/api/v1/passenger/motor-vehicle/trip-requests/{id}/rate';

  // Passenger Endpoints - Public Bus
  static const String passengerPublicBusRequestEndpoint =
      '/api/v1/passenger/public-bus/request';
  static const String passengerPublicBusStatusEndpoint =
      '/api/v1/passenger/public-bus/requests/{id}';
  static const String passengerPublicBusCorridorsEndpoint =
      '/api/v1/passenger/public-bus/corridors';
  static const String passengerPublicBusStopsEndpoint =
      '/api/v1/passenger/public-bus/corridors/{corridor}/stops';
  static const String passengerPublicBusActiveBusesEndpoint =
      '/api/v1/passenger/public-bus/corridors/{corridor}/active-buses';
  static const String passengerPublicBusBookSeatEndpoint =
      '/api/v1/passenger/public-bus/book-seat';

  // Passenger Endpoints - General (Trips Table)
  static const String passengerTripsEndpoint = '/api/v1/passenger/trips';
  static const String passengerTripDetailEndpoint =
      '/api/v1/passenger/trips/{id}';
  static const String passengerTripStatusEndpoint =
      '/api/v1/passenger/trips/{id}/status';
  static const String passengerCancelTripEndpoint =
      '/api/v1/passenger/trips/{id}/cancel'; // PUT
  static const String passengerTripMatchingSessionEndpoint =
      '/api/v1/passenger/trips/{id}/matching-session';

  // Driver Endpoints - Motorcycle
  static const String driverMotoAcceptTripEndpoint =
      '/api/v1/driver/motor-vehicle/trip-requests/{id}/accept';
  static const String driverMotoRejectTripEndpoint =
      '/api/v1/driver/motor-vehicle/trip-requests/{id}/reject';
  static const String driverMotoArrivedEndpoint =
      '/api/v1/driver/motor-vehicle/trip-requests/{id}/arrived';
  static const String driverMotoStartTripEndpoint =
      '/api/v1/driver/motor-vehicle/trip-requests/{id}/start';
  static const String driverMotoCompleteTripEndpoint =
      '/api/v1/driver/motor-vehicle/trip-requests/{id}/complete';

  // Driver Endpoints - Mobile (Private Car)
  static const String driverStatusEndpoint =
      '/api/v1/mobile/drivers/status'; // POST
  static const String driverTripsEndpoint =
      '/api/v1/mobile/drivers/trips'; // GET
  static const String driverAcceptTripEndpoint =
      '/api/v1/mobile/drivers/trips/{id}/accept'; // POST
  static const String driverRejectTripEndpoint =
      '/api/v1/mobile/drivers/trips/{id}/reject'; // POST
  static const String driverStartTripEndpoint =
      '/api/v1/mobile/drivers/trips/{id}/start'; // PUT
  static const String driverArrivedEndpoint =
      '/api/v1/mobile/drivers/trips/{id}/arrived'; // PUT
  static const String driverCompleteTripEndpoint =
      '/api/v1/mobile/drivers/trips/{id}/complete'; // PUT
  static const String driverLocationUpdateEndpoint =
      '/api/v1/driver/location/update'; // POST
  static const String driverLiveLocationEndpoint =
      '/api/v1/mobile/drivers/live-location'; // POST

  // Trip Management - Mobile
  static const String mobileRequestTripEndpoint =
      '/api/v1/mobile/trips/request'; // POST
  static const String mobileCurrentTripEndpoint =
      '/api/v1/mobile/trips/current'; // GET
  static const String getTripStatusEndpoint =
      '/api/v1/mobile/trips/{id}/status'; // GET
  static const String mobileTripTrackingEndpoint =
      '/api/v1/mobile/trips/{id}/track'; // GET
  static const String mobileCancelTripEndpoint =
      '/api/v1/mobile/trips/{id}/cancel'; // PUT
  static const String mobileCompleteTripEndpoint =
      '/api/v1/mobile/trips/{id}/complete'; // PUT

  // Matching & Drivers
  static const String matchDriversEndpoint =
      '/api/v1/mobile/drivers/match'; // GET
  static const String trackingNearbyEndpoint =
      '/api/v1/mobile/tracking/nearby'; // GET

  // Route & Pricing
  static const String getRouteEndpoint =
      '/api/v1/route/compute'; // POST (was GET /route/get-route)
  static const String pricingCalculateEndpoint =
      '/api/v1/pricing/calculate'; // POST

  // Firebase Configuration
  static const String firebaseProjectId = 'rideconnect-project';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userTypeKey = 'user_type';
  static const String userDataKey = 'user_data';
  static const String lastKnownLocationKey = 'last_known_location';
  static const String offlineTripsKey = 'offline_trips';

  // Timing Constants
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration locationUpdateInterval = Duration(seconds: 5);
  static const Duration pollingInterval = Duration(seconds: 5);
  static const Duration tripStatusCheckInterval = Duration(seconds: 3);
  static const Duration tokenRefreshThreshold = Duration(minutes: 5);

  // Trip Polling Intervals - Backoff Strategy
  static const Duration tripPollInitial = Duration(seconds: 2);
  static const Duration tripPollBackoff1 = Duration(seconds: 3);
  static const Duration tripPollBackoff2 = Duration(seconds: 5);
  static const Duration tripPollBackoff3 = Duration(seconds: 8);
  static const Duration tripPollMax = Duration(seconds: 8);

  // Location Constants
  static const double minLocationUpdateDistance = 10.0; // meters
  static const int locationAccuracy = 20; // meters

  // Map Constants
  static const double defaultMapZoom = 15.0;
  static const double defaultCameraZoom = 16.0;

  // Trip Constants
  static const int maxMatchingAttempts = 3;
  static const Duration matchingTimeout = Duration(seconds: 30);
  static const Duration tripCancellationWindow = Duration(seconds: 30);

  // Pagination
  static const int pageSize = 20;

  // Transport Types
  static const String transportTypePublicBus = 'PUBLIC_BUS';
  static const String transportTypeMotorcycle = 'MOTORCYCLE';

  // User Types
  static const String userTypePassenger = 'passenger';
  static const String userTypeDriver = 'driver';

  // Trip Status Values
  static const String tripStatusRequested = 'REQUESTED';
  static const String tripStatusMatching = 'MATCHING';
  static const String tripStatusAssigned = 'ASSIGNED';
  static const String tripStatusDriverAssigned = 'DRIVER_ASSIGNED';
  static const String tripStatusPassengerWaiting = 'PASSENGER_WAITING';
  static const String tripStatusDriverArrived = 'DRIVER_ARRIVED';
  static const String tripStatusInProgress = 'IN_PROGRESS';
  static const String tripStatusCompleted = 'COMPLETED';
  static const String tripStatusCancelled = 'CANCELLED';
  static const String tripStatusExpired = 'EXPIRED';

  // Error Messages
  static const String networkErrorMessage =
      'Network error. Please check your connection.';
  static const String serverErrorMessage =
      'Server error. Please try again later.';
  static const String unauthorizedMessage = 'Unauthorized. Please login again.';
  static const String validationErrorMessage =
      'Validation error. Please check your input.';
  static const String locationPermissionMessage = 'Location permission denied.';
  static const String locationUnavailableMessage =
      'Location service unavailable.';
  static const String noDriversAvailableMessage =
      'No drivers available. Please try again.';
  static const String tripCancelledMessage = 'Trip has been cancelled.';
  static const String unknownErrorMessage = 'An unknown error occurred.';
}

/// Feature flags for development
class FeatureFlags {
  static const bool enableLogging = true;
  static const bool enableWebSocket = true;
  static const bool enablePolling = true;
  static const bool enableOfflineMode = true;
  static const bool enableLocationTracking = true;
  static const bool enableMapDisplay = true;
}

/// Log levels
enum LogLevel { debug, info, warning, error }
