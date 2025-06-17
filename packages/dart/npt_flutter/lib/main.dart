import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:npt_flutter/args.dart';
import 'package:npt_flutter/constants.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main(List<String> args) async {
  try {
    var parser = createArgParser();
    parseArgsAndHandleConstants(parser, args);
  } catch (e) {
    // ignore: avoid_print
    print("Failed to parse arguments:$e");
    exit(1);
  }

  WidgetsFlutterBinding.ensureInitialized();

  var windowOptions = const WindowOptions(
    title: "NoPorts Desktop",
    minimumSize: Constants.kWindowsMinWindowSize,
    skipTaskbar: false,
  );
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(windowOptions);
  runApp(const App());
}
