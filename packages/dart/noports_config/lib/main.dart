import 'package:flutter/material.dart';
import 'package:noports_config/app.dart';
import 'package:noports_config/platform/elevation.dart';
import 'package:noports_config/styles/sizes.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // macOS / Linux: relaunch as root through the system prompt if needed.
  await Elevation.relaunchAsRootIfNeeded();
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    title: 'NoPorts Configuration',
    size: Size(1100, 760),
    minimumSize: kMinWindowSize,
    center: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const App());
}
