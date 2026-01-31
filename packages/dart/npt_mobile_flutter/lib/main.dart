import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // AtSignLogger.root_level = 'FINEST';
  runApp(const App());
}
