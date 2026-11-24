import 'dart:io';

import 'package:noports_core/srv.dart';

/// Prints the srv that this program, compiled as atsc, would start for a
/// session: the lookup sshnpd and the clients make before they start srv.
Future<void> main(List<String> args) async {
  stdout.writeln(await Srv.getLocalBinaryPath());
}
