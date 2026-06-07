import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/ride_sharing_app.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/rides/presentation/chat/ride_chat_screen.dart';
import 'firebase_app_check_bootstrap.dart';
import 'firebase_options.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await activateFirebaseAppCheck();

  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.initializeNotifications(
    onMessageTap: (rideId) async {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => RideChatScreen(rideId: rideId),
        ),
      );
    },
  );

  runApp(const RideSharingApp());
}
