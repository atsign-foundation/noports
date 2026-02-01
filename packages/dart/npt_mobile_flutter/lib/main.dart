import 'package:flutter/material.dart';

import 'app.dart';
import 'util/background_service.dart';
import 'util/app_lifecycle_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background service for maintaining network connections
  await BackgroundService.init();
  
  // Initialize app lifecycle manager for iOS background handling
  AppLifecycleManager().init();

  // AtSignLogger.root_level = 'FINEST';
  runApp(const App());
}
