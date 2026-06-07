import 'package:flutter/material.dart';

import '../features/onboarding/presentation/app_launch_gate.dart';
import '../features/rides/presentation/chat/ride_chat_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class RideSharingApp extends StatelessWidget {
  const RideSharingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Ride Sharing App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AppLaunchGate(),
      routes: {
        '/chat': (context) {
          final rideId = ModalRoute.of(context)?.settings.arguments as String?;
          if (rideId == null) {
            return const Scaffold(
              body: Center(child: Text('Missing ride id')),
            );
          }
          return RideChatScreen(rideId: rideId);
        },
      },
    );
  }
}
