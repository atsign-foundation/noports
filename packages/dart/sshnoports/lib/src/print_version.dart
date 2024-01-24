import 'dart:io';

import 'package:sshnoports/src/version.dart' as release;
import 'package:noports_core/version.dart' as package;

/// Print version number
void printVersion() {
  stderr.writeln('Version : ${release.packageVersion} (core: ${package.packageVersion})');
}
