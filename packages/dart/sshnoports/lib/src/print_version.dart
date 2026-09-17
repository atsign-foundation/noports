import 'dart:io';

import 'package:noports_core/utils.dart';
import 'package:noports_core/version.dart' as core;
import 'package:sshnoports/src/version.dart' as binaries;

/// The version string, in the GNU convention of leading with the program
/// name, e.g. `sshnpd 5.15.1 (core 6.12.1)`.
///
/// The format matters: man pages are generated from `--version` and `--help`
/// output by `help2man`, which titles the man page using the first word of
/// the `--version` output.
/// See https://github.com/atsign-foundation/noports/issues/2650
String get versionString =>
    '$binaryName ${binaries.packageVersion} (core ${core.packageVersion})';

/// Prints [versionString] to [sink], which defaults to [stdout] as is
/// conventional for `--version` output.
void printVersion({IOSink? sink}) {
  (sink ?? stdout).writeln(versionString);
}
