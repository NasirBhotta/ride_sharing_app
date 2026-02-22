import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/ride_sharing_app.dart';
import 'firebase_options.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RideSharingApp());
}
