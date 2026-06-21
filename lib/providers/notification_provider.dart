import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../models/notification_model.dart';

// ──────────────────────────────────────────────────────────────────────
// NOTIFICATION SERVICE
// ──────────────────────────────────────────────────────────────────────

class NotificationService {
  final FirebaseMessaging _firebaseMessaging;
  final Logger _logger;

  NotificationService({FirebaseMessaging? firebaseMessaging, Logger? logger})
    : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
      _logger = logger ?? Logger();

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      // Request permissions
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Get FCM token
      final fcmToken = await _firebaseMessaging.getToken();
      _logger.d('FCM Token: $fcmToken');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.d(
          'Foreground message received: ${message.notification?.title}',
        );
        _handleForegroundMessage(message);
      });

      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.d(
          'Message opened from background: ${message.notification?.title}',
        );
        _handleBackgroundMessage(message);
      });

      _logger.d('Notification service initialized');
    } catch (e) {
      _logger.e('Error initializing notification service', error: e);
      rethrow;
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      final model = NotificationModel(
        id: message.messageId ?? '',
        title: notification.title ?? '',
        body: notification.body ?? '',
        type: message.data['type'] ?? 'UNKNOWN',
        data: message.data,
        timestamp: DateTime.now(),
        isRead: false,
      );

      _logger.d('Foreground notification model created: ${model.id}');
    }
  }

  /// Handle background messages
  void _handleBackgroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _logger.d('Background message handled: ${notification.title}');
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      _logger.e('Error getting FCM token', error: e);
      return null;
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      _logger.d('Subscribed to topic: $topic');
    } catch (e) {
      _logger.e('Error subscribing to topic', error: e);
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      _logger.d('Unsubscribed from topic: $topic');
    } catch (e) {
      _logger.e('Error unsubscribing from topic', error: e);
    }
  }

  /// Get initial message (when app is launched from notification)
  Future<RemoteMessage?> getInitialMessage() async {
    try {
      return await _firebaseMessaging.getInitialMessage();
    } catch (e) {
      _logger.e('Error getting initial message', error: e);
      return null;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────
// NOTIFICATION STATE NOTIFIER
// ──────────────────────────────────────────────────────────────────────

class NotificationNotifier
    extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  final NotificationService _notificationService;
  final Logger _logger;
  final List<NotificationModel> _notifications = [];

  NotificationNotifier({
    required NotificationService notificationService,
    required Logger logger,
  }) : _notificationService = notificationService,
       _logger = logger,
       super(const AsyncValue.data([]));

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      await _notificationService.initialize();
      _logger.d('Notification notifier initialized');
    } catch (e, st) {
      _logger.e(
        'Error initializing notification notifier',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.error(e, st);
    }
  }

  /// Add notification
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    state = AsyncValue.data(_notifications.toList());
    _logger.d('Notification added: ${notification.title}');
  }

  /// Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notification = _notifications[index];
      _notifications[index] = NotificationModel(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        type: notification.type,
        data: notification.data,
        timestamp: notification.timestamp,
        isRead: true,
      );
      state = AsyncValue.data(_notifications.toList());
    }
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    state = const AsyncValue.data([]);
  }

  /// Get unread count
  int getUnreadCount() {
    return _notifications.where((n) => !n.isRead).length;
  }
}

final loggerProvider = Provider((ref) => Logger());

final notificationServiceProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return NotificationService(logger: logger);
});

final notificationProvider = StateNotifierProvider.autoDispose<
  NotificationNotifier,
  AsyncValue<List<NotificationModel>>
>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final logger = ref.watch(loggerProvider);

  final notifier = NotificationNotifier(
    notificationService: notificationService,
    logger: logger,
  );

  // Initialize on creation
  notifier.initialize();

  return notifier;
});

// ──────────────────────────────────────────────────────────────────────
// NOTIFICATION HELPERS
// ──────────────────────────────────────────────────────────────────────

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationProvider);
  return notifications.when(
    data: (list) => list.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final notificationFCMTokenProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final notificationService = ref.watch(notificationServiceProvider);
  return await notificationService.getFCMToken();
});

final demandOpportunityProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseMessaging.onMessage
      .where((msg) => msg.data['type'] == 'demand_opportunity')
      .map((msg) => msg.data);
});

