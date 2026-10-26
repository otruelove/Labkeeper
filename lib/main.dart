import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/database/app_database.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.initialize();
  runApp(const LabKeeperApp());
}

class LabKeeperApp extends StatelessWidget {
  const LabKeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
