import 'dart:io';

import 'package:npe2e/noports_version.dart';
import 'package:npe2e/test_result.dart';

class PolicyTestFailure {
  /// Where in the flow this happened, e.g. `daemon startup`, `after allowed
  /// put`, or an npt stage's metadata such as `03_allowed`.
  final String stage;

  /// One-line summary, suitable for the end-of-run failure list.
  final String reason;

  /// Optional multi-line detail: expected vs. observed, per-attempt exit codes.
  final String? detail;

  /// The command line that failed, so the step can be reproduced by hand.
  final String? reproduceCommand;

  /// Client, daemon and policy logs covering the failing stage.
  final List<File> logFiles;

  final Object? error;
  final StackTrace? stackTrace;

  PolicyTestFailure({
    required this.stage,
    required this.reason,
    this.detail,
    this.reproduceCommand,
    this.logFiles = const <File>[],
    this.error,
    this.stackTrace,
  });
}

class PolicyTestResult extends TestResult {
  final NoPortsVersion clientVersion;
  final NoPortsVersion daemonVersion;
  final NoPortsVersion policyVersion;

  /// Short identity for this permutation, shared with the daemon container name
  /// and the per-stage log filenames. See `getPolicyFlowDeviceName`.
  final String? tag;

  /// Null when [status] is passed.
  final PolicyTestFailure? failure;

  PolicyTestResult({
    required super.testName,
    required this.clientVersion,
    required this.daemonVersion,
    required this.policyVersion,
    required super.status,
    required super.exitCode,
    this.tag,
    this.failure,
  });
}
