import 'dart:convert';
import 'dart:io';

/// The file name, without extension, of the currently running program,
/// derived from [Platform.script]. For example `sshnpd`, whether running the
/// compiled binary (`/usr/local/bin/sshnpd`) or running from source
/// (`dart run bin/sshnpd.dart`).
String get binaryName {
  if (Platform.script.pathSegments.isEmpty) {
    return 'noports';
  }
  final String fileName = Platform.script.pathSegments.last;
  final int dotIndex = fileName.indexOf('.');
  return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
}

/// Formats a `--help` message in the GNU layout:
///
/// ```text
/// Usage: <binaryName> <synopsis>
///
/// <description>
///
/// Options:
///   <optionsUsage, indented by two spaces>
/// ```
///
/// Man pages are generated from `--help` output by `help2man`, which requires
/// this layout in order to render `SYNOPSIS`, `DESCRIPTION` and `OPTIONS`
/// sections correctly. In particular the two-space indent matters:
/// `ArgParser.usage` places abbreviated options (e.g. `-a, --atsign`) at
/// column zero, where `help2man` does not recognise them as options and runs
/// them together as plain text.
/// See https://github.com/atsign-foundation/noports/issues/2650
String formatCliHelp({
  required String description,
  required String optionsUsage,
  String synopsis = '[options]',
}) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('Usage: $binaryName $synopsis')
    ..writeln()
    ..writeln(description)
    ..writeln()
    ..writeln('Options:');
  for (final String line in const LineSplitter().convert(optionsUsage)) {
    buffer.writeln(line.isEmpty ? '' : '  $line');
  }
  return buffer.toString();
}
