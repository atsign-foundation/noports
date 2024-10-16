import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  windowManager.ensureInitialized();
  var windowOptions = const WindowOptions(
    title: "NoPorts Desktop",
    skipTaskbar: true,
  );
  windowManager.waitUntilReadyToShow(windowOptions);
  runApp(const App());
}
