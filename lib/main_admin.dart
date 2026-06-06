import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/admin_app.dart';
import 'firebase_app_check_bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await activateFirebaseAppCheck();
  runApp(const AdminApp());
}
