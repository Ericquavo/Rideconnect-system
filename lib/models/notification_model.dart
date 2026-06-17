/// Notification model
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'DRIVER_ASSIGNED', 'DRIVER_ACCEPTED', etc.
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? '',
        data: json['data'] as Map<String, dynamic>?,
        timestamp:
            DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now(),
        isRead: json['is_read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'is_read': isRead,
  };
}

/// FCM notification payload
class FCMNotificationPayload {
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;

  FCMNotificationPayload({
    required this.title,
    required this.body,
    required this.type,
    required this.data,
  });

  /// Passenger notifications
  static const String passengerDriverAssigned = 'DRIVER_ASSIGNED';
  static const String passengerDriverAccepted = 'DRIVER_ACCEPTED';
  static const String passengerDriverRejected = 'DRIVER_REJECTED';
  static const String passengerDriverArrived = 'DRIVER_ARRIVED';
  static const String passengerTripStarted = 'TRIP_STARTED';
  static const String passengerTripCompleted = 'TRIP_COMPLETED';
  static const String passengerTripCancelled = 'TRIP_CANCELLED';
  static const String passengerNoDriversAvailable = 'NO_DRIVERS_AVAILABLE';

  /// Driver notifications
  static const String driverNewTripRequest = 'NEW_TRIP_REQUEST';
  static const String driverTripCancelled = 'TRIP_CANCELLED';
  static const String driverTripCompleted = 'TRIP_COMPLETED';
  static const String driverRatingReceived = 'RATING_RECEIVED';
}

/// Notification event for stream
class NotificationEvent {
  final NotificationModel notification;
  final String source; // 'fcm', 'local', 'api'

  NotificationEvent({required this.notification, required this.source});
}
