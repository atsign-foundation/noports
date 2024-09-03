import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  windowManager.ensureInitialized();
  try {
    await windowManager.setSkipTaskbar(true); // Don't show the app icon in dock
  } catch (_) {
    log("Failed to setSkipTaskbar");
  } finally {
    runApp(const App());
  }
}
