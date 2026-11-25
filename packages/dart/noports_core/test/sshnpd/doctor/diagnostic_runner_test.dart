import 'dart:io';

import 'package:noports_core/src/sshnpd/doctor/diagnostic_check.dart';
import 'package:noports_core/src/sshnpd/doctor/diagnostic_runner.dart';
import 'package:test/test.dart';

class ThrowingCheck extends DiagnosticCheck {
  @override
  String get name => 'Throwing check';

  @override
  String get description => 'Throws while it runs';

  @override
  Future<CheckResult> run(Map<String, dynamic> context) async =>
      throw const ProcessException(
        'powershell',
        ['-NoProfile'],
        'No such file or directory',
        2,
      );
}

class ThrowingBeforeReturningCheck extends DiagnosticCheck {
  @override
  String get name => 'Throwing before returning';

  @override
  String get description => 'Throws before it returns a future';

  @override
  Future<CheckResult> run(Map<String, dynamic> context) =>
      throw StateError('not ready');
}

class MultiLineErrorCheck extends DiagnosticCheck {
  @override
  String get name => 'Multi-line error';

  @override
  String get description => 'Throws an error whose text spans lines';

  @override
  Future<CheckResult> run(Map<String, dynamic> context) async =>
      throw const FormatException('first line\n  second line');
}

class FailingCheck extends DiagnosticCheck {
  @override
  String get name => 'Failing check';

  @override
  String get description => 'Fails';

  @override
  Future<CheckResult> run(Map<String, dynamic> context) async => CheckResult(
    checkName: name,
    status: CheckStatus.fail,
    message: 'No sshnpd.yaml',
    duration: Duration.zero,
  );
}

class PassingCheck extends DiagnosticCheck {
  @override
  String get name => 'Passing check';

  @override
  String get description => 'Passes';

  @override
  Future<CheckResult> run(Map<String, dynamic> context) async => CheckResult(
    checkName: name,
    status: CheckStatus.pass,
    message: 'Passed',
    duration: Duration.zero,
  );
}

void main() {
  group('Given a check that throws', () {
    test(
      'when the doctor runs its checks, then that check is reported as a warning naming the error and the remaining checks still run',
      () async {
        final results = await DiagnosticRunner(
          checks: [ThrowingCheck(), PassingCheck()],
        ).runAll();

        expect(
          results,
          hasLength(2),
          reason: 'a check that throws does not end the run',
        );
        expect(results.first.checkName, 'Throwing check');
        expect(
          results.first.status,
          CheckStatus.warning,
          reason: 'a check that throws is reported as a warning',
        );
        expect(
          results.first.message,
          contains('No such file or directory'),
          reason: 'the warning names the error',
        );
        expect(
          results.last.status,
          CheckStatus.pass,
          reason: 'the check after the one that throws still runs',
        );
      },
    );

    test(
      'when the doctor runs its checks, then the warning keeps where the error was thrown',
      () async {
        final results = await DiagnosticRunner(
          checks: [ThrowingCheck()],
        ).runAll();

        expect(
          results.single.details?['stack'],
          contains('ThrowingCheck.run'),
          reason: 'the details hold the stack the error was thrown with',
        );
      },
    );
  });

  group('Given a check that throws before it returns', () {
    test(
      'when the doctor runs its checks, then that check is reported as a warning and the remaining checks still run',
      () async {
        final results = await DiagnosticRunner(
          checks: [ThrowingBeforeReturningCheck(), PassingCheck()],
        ).runAll();

        expect(results, hasLength(2));
        expect(
          results.first.status,
          CheckStatus.warning,
          reason: 'a check that throws before returning is reported',
        );
        expect(results.first.message, contains('not ready'));
        expect(results.last.status, CheckStatus.pass);
      },
    );
  });

  group('Given a check that cannot start a program', () {
    test(
      'when the doctor runs it, then the warning names the program and the error on one line',
      () async {
        final results = await DiagnosticRunner(
          checks: [ThrowingCheck()],
        ).runAll();

        expect(
          results.single.message,
          'Could not complete this check: '
          'could not run powershell: No such file or directory',
        );
      },
    );
  });

  group('Given a check whose error spans several lines', () {
    test(
      'when the doctor runs it, then the warning shows the error on one line',
      () async {
        final results = await DiagnosticRunner(
          checks: [MultiLineErrorCheck()],
        ).runAll();

        expect(
          results.single.message,
          'Could not complete this check: '
          'FormatException: first line second line',
        );
      },
    );
  });

  group('Given a check that throws and another that fails', () {
    test(
      'when the doctor writes its summary, then the summary names the failure and the thrown error',
      () async {
        final runner = DiagnosticRunner(
          checks: [ThrowingCheck(), FailingCheck()],
        );
        final summary = runner.generateSummary(await runner.runAll());

        expect(summary, contains('Failing check: No sshnpd.yaml'));
        expect(
          summary,
          contains('Throwing check: Could not complete this check'),
          reason: 'warnings are listed even when a check failed',
        );
      },
    );
  });
}
