import 'dart:io';
import 'package:e2e_all_v2/log_fragment.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/process_utils.dart';

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
  printClientStdout(capture.stdout, label: label != null ? '$label stdout:' : null);
  printClientStderr(capture.stderr, label: label != null ? '$label stderr:' : null);
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

/// Prints client logs from log files instead of capture buffers
/// Useful when logs were written to files but capture is not available
void printClientLogsFromFiles({
  required File stdoutFile,
  required File stderrFile,
  String? label,
}) {
  if (stdoutFile.existsSync()) {
    print(label != null ? '$label stdout:' : 'Client stdout:');
    print(stdoutFile.readAsStringSync());
  }
  if (stderrFile.existsSync()) {
    print(label != null ? '$label stderr:' : 'Client stderr:');
    print(stderrFile.readAsStringSync());
  }
}

/// Prints all logs from files (client and daemon)
/// Useful when using ProcessResult instead of ProcessOutputCapture
void printAllLogsFromFiles({
  required File clientStdoutFile,
  required File clientStderrFile,
  required LogFragment daemonLogFragment,
  String? clientLabel,
  String? daemonLabel,
}) {
  printClientLogsFromFiles(
    stdoutFile: clientStdoutFile,
    stderrFile: clientStderrFile,
    label: clientLabel,
  );
  printDaemonLogFragments(daemonLogFragment, label: daemonLabel);
}
