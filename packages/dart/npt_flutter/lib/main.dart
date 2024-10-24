import 'dart:io';

import 'package:flutter/material.dart';
import 'package:npt_flutter/constants.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    final wm = WindowManager.instance;
    await wm.ensureInitialized();
    await wm.setMinimumSize(Constants.kWindowsMinWindowSize);
  }

  var windowOptions = const WindowOptions(
    title: "NoPorts Desktop",
    skipTaskbar: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions);
  runApp(const App());
}
