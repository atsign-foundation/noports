import 'dart:io';
import 'package:e2e_all_v2/log_fragment.dart';
import 'package:e2e_all_v2/process_utils.dart';

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
