import 'package:flutter/material.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var windowOptions = const WindowOptions(
    title: "NoPorts Desktop",
    minimumSize: Constants.kWindowsMinWindowSize,
    skipTaskbar: false,
  );
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(windowOptions);
  // AtSignLogger.root_level = 'FINEST';
  runApp(const App());
}
