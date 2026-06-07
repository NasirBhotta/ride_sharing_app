import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef MessageHandler = Future<void> Function(String rideId);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  MessageHandler? _onMessageTap;

  /// Initialize notifications - call this once on app startup
  Future<void> initializeNotifications({MessageHandler? onMessageTap}) async {
    _onMessageTap = onMessageTap;

    // Initialize Firebase Messaging
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/closed
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationFromTap);
  }

  /// Show a local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required String rideId,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'ride_messages',
          'Ride Messages',
          channelDescription: 'Notifications for ride messages',
          importance: Importance.max,
          priority: Priority.high,
          autoCancel: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      platformDetails,
      payload: rideId,
    );
  }

  /// Subscribe to notifications for a specific ride
  Future<void> subscribeToRideTopic(String rideId) async {
    await _firebaseMessaging.subscribeToTopic('ride_$rideId');
  }

  /// Unsubscribe from notifications for a specific ride
  Future<void> unsubscribeFromRideTopic(String rideId) async {
    await _firebaseMessaging.unsubscribeFromTopic('ride_$rideId');
  }

  /// Handle foreground message (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final rideId = message.data['rideId'] as String?;
    if (rideId != null) {
      final senderRole = message.data['senderRole'] as String? ?? 'rider';
      await showLocalNotification(
        title: 'Message from your $senderRole',
        body: 'New message in your ride',
        rideId: rideId,
      );
    }
  }

  /// Handle notification tap when app is in background/closed
  void _handleNotificationFromTap(RemoteMessage message) {
    final rideId = message.data['rideId'] as String?;
    if (rideId != null && _onMessageTap != null) {
      _onMessageTap!(rideId);
    }
  }

  /// Handle local notification tap (any state)
  void _handleNotificationTap(NotificationResponse response) {
    final rideId = response.payload;
    if (rideId != null && _onMessageTap != null) {
      _onMessageTap!(rideId);
    }
  }

  /// Request notification permission (already called in init, but can be called again)
  Future<bool> requestNotificationPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
