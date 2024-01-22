import 'dart:io';

import 'package:sshnoports/src/version.dart';

/// Print version number
void printVersion() {
  stderr.writeln('Version : $packageVersion');
}
