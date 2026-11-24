import 'dart:io';

import 'package:noports_core/srv.dart';

/// Prints the name this program was run by, then the srv it would run.
Future<void> main() async {
  stdout.writeln(Platform.executable);
  stdout.writeln(await Srv.getLocalBinaryPath());
}
