import 'package:flutter/material.dart';

import 'app.dart';
import 'util/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background service for maintaining network connections
  await BackgroundService.init();

  // AtSignLogger.root_level = 'FINEST';
  runApp(const App());
}
