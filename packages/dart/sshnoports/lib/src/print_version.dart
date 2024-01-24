import 'dart:io';

import 'package:sshnoports/src/version.dart' as binaries;
import 'package:noports_core/version.dart' as core;

/// Print version number
void printVersion() {
  stderr.writeln('Version : ${binaries.packageVersion}'
      ' (core: ${core.packageVersion}');
}
