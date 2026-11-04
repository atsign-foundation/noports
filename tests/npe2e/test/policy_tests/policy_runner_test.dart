import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/policy_tests/policy_test_case.dart';
import 'package:npe2e/policy_tests/policy_tests.dart';
import 'package:npe2e/policy_tests/policy_tests_test_result.dart';
import 'package:npe2e/test_result.dart';
import 'package:npe2e/transcript.dart';
import 'package:test/test.dart';

void main() {
  group('policy_tests runs cases that share a policy atSign one at a time', () {
    test(
      'Concurrent policy cases do not share a policy atSign: when two cases in'
      ' one batch both administer @policy and run with a batch size of 2,'
      ' then the second starts only once the first has finished',
      () async {
        final List<String> events = await _runCasesFor(['@policy', '@policy']);

        expect(events, [
          'a started',
          'a finished',
          'b started',
          'b finished',
        ], reason: 'the second case starts only once the first has finished');
      },
    );

    test(
      'Cases administering different policy atSigns run at once: when two'
      ' cases in one batch administer @policy and @other and run with a batch'
      ' size of 2, then the second starts while the first is running',
      () async {
        final List<String> events = await _runCasesFor(['@policy', '@other']);

        expect(events, [
          'a started',
          'b started',
          'a finished',
          'b finished',
        ], reason: 'the second case starts while the first is running');
      },
    );
  });
}

/// Runs one case per atSign in [policyAtsigns], named a, b, ... in order, with
/// a batch size of 2, and returns when each started and finished. Each case
/// runs for longer than the runner waits between starts.
Future<List<String>> _runCasesFor(List<String> policyAtsigns) async {
  final List<String> events = [];
  final NoPortsVersion current = NoPortsVersion(
    language: Language.dart,
    version: 'current',
  );
  final List<PolicyTestCase> testCases = [
    for (final (int i, String policyAtsign) in policyAtsigns.indexed)
      PolicyTestCase(
        testName: 'npp_test',
        tag: String.fromCharCode('a'.codeUnitAt(0) + i),
        clientVersion: current,
        daemonVersion: current,
        policyVersion: current,
        policyAtsign: policyAtsign,
        run: () async {
          final String tag = String.fromCharCode('a'.codeUnitAt(0) + i);
          events.add('$tag started');
          await Future<void>.delayed(const Duration(seconds: 3));
          events.add('$tag finished');
          return PolicyTestResult(
            testName: 'npp_test',
            clientVersion: current,
            daemonVersion: current,
            policyVersion: current,
            status: TestStatus.passed,
            exitCode: 0,
            tag: tag,
          );
        },
      ),
  ];
  await runPolicyTestCases(
    testCases,
    transcript: Transcript(tag: 'runner'),
    batchSize: 2,
    maxRetries: 0,
    testTimeout: const Duration(seconds: 30),
  );
  return events;
}
