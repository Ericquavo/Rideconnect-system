/// API endpoints for RideConnect backend
class ApiEndpoints {
  // Base URL
  static const String baseUrl = 'https://rideconnect-emp0.onrender.com/api/v1';
  
  // Auth endpoints
  static const String login = '/auth/mobile/login';
  static const String logout = '/auth/logout';
  static const String validate = '/auth/validate';
  static const String authProfile = '/auth/profile';
  
  // Passenger trip endpoints
  static const String motorVehicleTripRequest = '/passenger/motor-vehicle/trip-request';
  static const String privateCarTripRequest = '/passenger/private-car/trip-request';
  static const String publicBusTripRequest = '/passenger/public-bus/trip-request';
  static const String tripCancel = '/passenger/{type}/trip-cancel';
  static const String tripRate = '/passenger/{type}/trip-requests/{id}/rate';
  static const String tripHistory = '/passenger/{type}/trip-history';
  static const String passengerProfile = '/passenger/profile';
  
  // Mobile shared endpoints
  static const String currentTrip = '/mobile/trips/current';
  static const String tripDetails = '/mobile/trips/{id}';
  static const String tripTrack = '/mobile/trips/{id}/track';
  
  static String passengerRate(String type, int id) => '/passenger/$type/trip-rate/$id';
  static String tripAcknowledge(int id) => '/trips/$id/acknowledge';
  
  // Notification endpoints
  static const String notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  
  // Driver endpoints
  static const String driverStatus = '/mobile/drivers/status';
  static const String driverLiveLocation = '/mobile/drivers/live-location';
  static const String driverAcceptTrip = '/mobile/drivers/trips/{id}/accept';
  static const String driverRejectTrip = '/mobile/drivers/trips/{id}/reject';
  static const String driverStartTrip = '/mobile/drivers/trips/{id}/start';
  static const String driverCompleteTrip = '/mobile/drivers/trips/{id}/complete';
  static const String driverArrived = '/driver/motor-vehicle/trip-requests/{id}/arrived';
  static const String driverEarnings = '/driver/earnings';
  static const String driverProfile = '/mobile/drivers/profile';
  static const String driverTripHistory = '/mobile/drivers/trips/history';
  
  // Route computation
  static const String routeCompute = '/route/compute';
  
  // Public bus endpoints
  static const String busCorridors = '/passenger/public-transport/routes';
  static const String busStops = '/passenger/public-transport/stops';
  static const String busBookSeat = '/passenger/public-bus/book-seat';
  
  // Helper method to replace path parameters
  static String replacePath(String path, Map<String, dynamic> params) {
    String result = path;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }
}
