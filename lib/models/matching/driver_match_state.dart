/// Represents the state of a matched driver for a trip
///
/// Contains driver information, vehicle details, and trip matching metadata
class DriverMatchState {
  final int tripId;
  final int driverId;
  final String driverName;
  final double driverRating;
  final String? driverPhoto;
  final String? vehicleName;
  final String? licensePlate;
  final String? phoneNumber;
  final String status; // 'matched', 'accepted', 'arrived', 'in_progress'
  final DateTime matchedAt;

  DriverMatchState({
    required this.tripId,
    required this.driverId,
    required this.driverName,
    required this.driverRating,
    this.driverPhoto,
    this.vehicleName,
    this.licensePlate,
    this.phoneNumber,
    required this.status,
    required this.matchedAt,
  });

  /// Check if driver has accepted the trip
  bool get isAccepted =>
      status == 'accepted' || status == 'arrived' || status == 'in_progress';

  /// Check if driver has arrived at pickup location
  bool get hasArrived => status == 'arrived' || status == 'in_progress';

  /// Check if trip is in progress
  bool get isInProgress => status == 'in_progress';

  @override
  String toString() =>
      'DriverMatchState('
      'tripId: $tripId, '
      'driverId: $driverId, '
      'driver: $driverName, '
      'rating: $driverRating, '
      'status: $status'
      ')';
}
