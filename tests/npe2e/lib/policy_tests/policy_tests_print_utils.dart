import 'dart:io';

import 'package:npe2e/log_fragment.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/policy_tests/policy_tests_test_result.dart';
import 'package:npe2e/process_utils.dart';

/// Generates a string describing the client, daemon, and policy versions for
/// policy test output.
String generatePolicyExtraString(
  NoPortsVersion clientVersion,
  NoPortsVersion daemonVersion,
  NoPortsVersion policyVersion, {
  bool useShortLanguageName = false,
}) {
  final String clientLanguage = useShortLanguageName
      ? clientVersion.language.name[0]
      : clientVersion.language.name;
  final String daemonLanguage = useShortLanguageName
      ? daemonVersion.language.name[0]
      : daemonVersion.language.name;
  final String policyLanguage = useShortLanguageName
      ? policyVersion.language.name[0]
      : policyVersion.language.name;

  return '(client: $clientLanguage:${clientVersion.version}, daemon: $daemonLanguage:${daemonVersion.version}, policy: $policyLanguage:${policyVersion.version})';
}

void printPolicyFailureReport(
  PolicyTestResult testResult, {
  required File transcriptLogFile,
}) {
  const String red = '\x1B[31m';
  const String reset = '\x1B[0m';
  final String extra = generatePolicyExtraString(
    testResult.clientVersion,
    testResult.daemonVersion,
    testResult.policyVersion,
    useShortLanguageName: true,
  );
  print('  $red✗$reset ${testResult.testName} $extra');

  if (testResult.tag != null) {
    _printFailureField('tag', testResult.tag!);
  }

  final PolicyTestFailure? failure = testResult.failure;
  if (failure == null) {
    // Nothing recorded: the failure predates this reporting, or came from a
    // construction site that has not been taught to fill it in.
    _printFailureField(
      'reason',
      'not recorded (exit code ${testResult.exitCode})',
    );
  } else {
    _printFailureField('stage', failure.stage);
    _printFailureField('reason', failure.reason);
    if (failure.detail != null) {
      _printFailureField('detail', failure.detail!);
    }
    if (failure.error != null) {
      _printFailureField('error', failure.error.toString());
    }
    if (failure.reproduceCommand != null) {
      _printFailureField('reproduce', failure.reproduceCommand!);
    }
    if (failure.logFiles.isNotEmpty) {
      _printFailureField(
        'logs',
        failure.logFiles.map((file) => file.path).join('\n'),
      );
    }
  }
  _printFailureField('transcript', transcriptLogFile.path);
}

/// Prints `      <label>:    <value>`, aligning continuation lines of a
/// multi-line value under the first one.
void _printFailureField(final String label, final String value) {
  const String indent = '      ';
  const int labelWidth = 11; // widest label is 'transcript:'
  final String head = '$label:'.padRight(labelWidth);
  final List<String> lines = value.split('\n');
  print('$indent$head ${lines.first}');
  for (final String line in lines.skip(1)) {
    print('$indent${' ' * labelWidth} $line');
  }
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

void printPolicyStdoutFragment(File stdoutFragmentFile, {String? label}) {
  if (stdoutFragmentFile.existsSync()) {
    print(label ?? 'Policy stdout fragment:');
    print(stdoutFragmentFile.readAsStringSync());
  }
}

void printPolicyStderrFragment(File stderrFragmentFile, {String? label}) {
  if (stderrFragmentFile.existsSync()) {
    print(label ?? 'Policy stderr fragment:');
    print(stderrFragmentFile.readAsStringSync());
  }
}

void printPolicyLogFragments(LogFragment policyLogCapture, {String? label}) {
  printPolicyStdoutFragment(
    policyLogCapture.stdoutFile,
    label: label != null ? '$label stdout fragment:' : null,
  );
  printPolicyStderrFragment(
    policyLogCapture.stderrFile,
    label: label != null ? '$label stderr fragment:' : null,
  );
}

void printAllLogs({
  required ProcessOutputCapture clientCapture,
  required LogFragment daemonLogFragment,
  LogFragment? policyLogFragment,
  String? clientLabel,
  String? daemonLabel,
  String? policyLabel,
}) {
  printClientLogs(clientCapture, label: clientLabel);
  printDaemonLogFragments(daemonLogFragment, label: daemonLabel);
  if (policyLogFragment != null) {
    printPolicyLogFragments(policyLogFragment, label: policyLabel);
  }
}

void printAllLogsFromStringBuffers({
  required StringBuffer clientStdoutBuffer,
  required StringBuffer clientStderrBuffer,
  required StringBuffer daemonStdoutBuffer,
  required StringBuffer daemonStderrBuffer,
  StringBuffer? policyStdoutBuffer,
  StringBuffer? policyStderrBuffer,
  String? clientLabel,
  String? daemonLabel,
  String? policyLabel,
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
  if (policyStdoutBuffer != null) {
    printClientStdout(
      policyStdoutBuffer.toString(),
      label: policyLabel != null
          ? '$policyLabel stdout fragment:'
          : 'Policy stdout fragment:',
    );
  }
  if (policyStderrBuffer != null) {
    printClientStderr(
      policyStderrBuffer.toString(),
      label: policyLabel != null
          ? '$policyLabel stderr fragment:'
          : 'Policy stderr fragment:',
    );
  }
}
