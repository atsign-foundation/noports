import 'dart:io';
import 'package:e2e_all_v2/core_tests/core_tests_logging.dart';
import 'package:e2e_all_v2/process_utils.dart';

/// Prints client stdout if not empty
/// [label] - Optional custom label (defaults to 'Client stdout:')
void printClientStdout(String stdout, {String? label}) {
  if (stdout.isNotEmpty) {
    print(label ?? 'Client stdout:');
    print(stdout);
  }
}

/// Prints client stderr if not empty
/// [label] - Optional custom label (defaults to 'Client stderr:')
void printClientStderr(String stderr, {String? label}) {
  if (stderr.isNotEmpty) {
    print(label ?? 'Client stderr:');
    print(stderr);
  }
}

/// Prints both client stdout and stderr from a ProcessOutputCapture
/// [label] - Optional custom label prefix
void printClientLogs(ProcessOutputCapture capture, {String? label}) {
  printClientStdout(capture.stdout, label: label != null ? '$label stdout:' : null);
  printClientStderr(capture.stderr, label: label != null ? '$label stderr:' : null);
}

/// Prints daemon stdout fragment from a log file if it exists
/// [label] - Optional custom label (defaults to 'Daemon stdout fragment:')
void printDaemonStdoutFragment(File stdoutFragmentFile, {String? label}) {
  if (stdoutFragmentFile.existsSync()) {
    print(label ?? 'Daemon stdout fragment:');
    print(stdoutFragmentFile.readAsStringSync());
  }
}

/// Prints daemon stderr fragment from a log file if it exists
/// [label] - Optional custom label (defaults to 'Daemon stderr fragment:')
void printDaemonStderrFragment(File stderrFragmentFile, {String? label}) {
  if (stderrFragmentFile.existsSync()) {
    print(label ?? 'Daemon stderr fragment:');
    print(stderrFragmentFile.readAsStringSync());
  }
}

/// Prints both daemon stdout and stderr fragments from a DaemonLogCapture
/// [label] - Optional custom label prefix
void printDaemonLogFragments(DaemonLogCapture daemonLogCapture, {String? label}) {
  printDaemonStdoutFragment(
    daemonLogCapture.stdoutFragmentFile,
    label: label != null ? '$label stdout fragment:' : null,
  );
  printDaemonStderrFragment(
    daemonLogCapture.stderrFragmentFile,
    label: label != null ? '$label stderr fragment:' : null,
  );
}

/// Prints all client and daemon logs (convenience method)
/// Typically used when a test fails or when alwaysOutputLogs is true
void printAllLogs({
  required ProcessOutputCapture clientCapture,
  required DaemonLogCapture daemonLogCapture,
  String? clientLabel,
  String? daemonLabel,
}) {
  printClientLogs(clientCapture, label: clientLabel);
  printDaemonLogFragments(daemonLogCapture, label: daemonLabel);
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
  required DaemonLogCapture daemonLogCapture,
  String? clientLabel,
  String? daemonLabel,
}) {
  printClientLogsFromFiles(
    stdoutFile: clientStdoutFile,
    stderrFile: clientStderrFile,
    label: clientLabel,
  );
  printDaemonLogFragments(daemonLogCapture, label: daemonLabel);
}
