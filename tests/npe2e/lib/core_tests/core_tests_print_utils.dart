import 'dart:io';
import 'package:npe2e/log_fragment.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/process_utils.dart';

/// Generates a string describing the client and daemon versions for test output
///
/// Examples:
/// - `generateExtraString(dartV5_9_4, dartCurrent)` → "(client: dart:v5.9.4, daemon: dart:current)"
/// - `generateExtraString(dartV5_9_4, dartCurrent, useShortLanguageName: true)` → "(client: d:v5.9.4, daemon: d:current)"
String generateExtraString(
  NoPortsVersion clientVersion,
  NoPortsVersion daemonVersion, {
  bool useShortLanguageName = false,
}) {
  final String clientLanguage = useShortLanguageName
      ? clientVersion.language.name[0]
      : clientVersion.language.name;
  final String daemonLanguage = useShortLanguageName
      ? daemonVersion.language.name[0]
      : daemonVersion.language.name;

  return '(client: $clientLanguage:${clientVersion.version}, daemon: $daemonLanguage:${daemonVersion.version})';
}

void printClientStdout(String stdout, {String? label}) {
  if (stdout.isNotEmpty) {
    print(label ?? 'Client stdout:');
    print(stdout);
  }
}

void printClientStderr(String stderr, {String? label}) {
  if (stderr.isNotEmpty) {
    print(label ?? 'Client stderr:');
    print(stderr);
  }
}

void printClientLogs(ProcessOutputCapture capture, {String? label}) {
  printClientStdout(
    capture.stdout,
    label: label != null ? '$label stdout:' : null,
  );
  printClientStderr(
    capture.stderr,
    label: label != null ? '$label stderr:' : null,
  );
}

void printDaemonStdoutFragment(File stdoutFragmentFile, {String? label}) {
  if (stdoutFragmentFile.existsSync()) {
    print(label ?? 'Daemon stdout fragment:');
    print(stdoutFragmentFile.readAsStringSync());
  }
}

void printDaemonStderrFragment(File stderrFragmentFile, {String? label}) {
  if (stderrFragmentFile.existsSync()) {
    print(label ?? 'Daemon stderr fragment:');
    print(stderrFragmentFile.readAsStringSync());
  }
}

void printDaemonLogFragments(LogFragment daemonLogCapture, {String? label}) {
  printDaemonStdoutFragment(
    daemonLogCapture.stdoutFile,
    label: label != null ? '$label stdout fragment:' : null,
  );
  printDaemonStderrFragment(
    daemonLogCapture.stderrFile,
    label: label != null ? '$label stderr fragment:' : null,
  );
}

void printAllLogs({
  required ProcessOutputCapture clientCapture,
  required LogFragment daemonLogFragment,
  String? clientLabel,
  String? daemonLabel,
}) {
  printClientLogs(clientCapture, label: clientLabel);
  printDaemonLogFragments(daemonLogFragment, label: daemonLabel);
}

void printAllLogsFromStringBuffers({
  required StringBuffer clientStdoutBuffer,
  required StringBuffer clientStderrBuffer,
  required StringBuffer daemonStdoutBuffer,
  required StringBuffer daemonStderrBuffer,
  String? clientLabel,
  String? daemonLabel,
}) {
  printClientStdout(
    clientStdoutBuffer.toString(),
    label: clientLabel != null ? '$clientLabel stdout:' : null,
  );
  printClientStderr(
    clientStderrBuffer.toString(),
    label: clientLabel != null ? '$clientLabel stderr:' : null,
  );
  printClientStdout(
    daemonStdoutBuffer.toString(),
    label: daemonLabel != null
        ? '$daemonLabel stdout fragment:'
        : 'Daemon stdout fragment:',
  );
  printClientStderr(
    daemonStderrBuffer.toString(),
    label: daemonLabel != null
        ? '$daemonLabel stderr fragment:'
        : 'Daemon stderr fragment:',
  );
}
