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
  });
}
