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
        final List<String> events = await _runCases([
          ('@policy', _longRun),
          ('@policy', _longRun),
        ]);

        expect(events, [
          'a#1 started',
          'a#1 finished',
          'b#1 started',
          'b#1 finished',
        ], reason: 'the second case starts only once the first has finished');
      },
    );

    test(
      'Cases administering different policy atSigns run at once: when two'
      ' cases in one batch administer @policy and @other and run with a batch'
      ' size of 2, then the second starts while the first is running',
      () async {
        final List<String> events = await _runCases([
          ('@policy', _longRun),
          ('@other', _longRun),
        ]);

        expect(events, [
          'a#1 started',
          'b#1 started',
          'a#1 finished',
          'b#1 finished',
        ], reason: 'the second case starts while the first is running');
      },
    );

    test('Concurrent policy cases do not share a policy atSign: when the first'
        ' case times out and is retried, then neither its retry nor the second'
        ' case starts until the timed-out run has ended', () async {
      final List<String> events = await _runCases(
        [
          ('@policy', const Duration(seconds: 2)),
          ('@policy', const Duration(milliseconds: 100)),
        ],
        testTimeout: const Duration(milliseconds: 500),
        maxRetries: 1,
      );

      expect(events, [
        'a#1 started',
        'a#1 finished',
        'a#2 started',
        'a#2 finished',
        'b#1 started',
        'b#1 finished',
      ], reason: 'a timed-out run keeps the policy atSign until it has ended');
    });
  });
}

/// Longer than the runner waits between starts.
const Duration _longRun = Duration(seconds: 3);

/// Runs one case per entry in [cases], named a, b, ... in order, each
/// administering its policy atSign and running for its duration, with a
/// batch size of 2, and returns when each attempt of each started and
/// finished, as `a#1 started`.
Future<List<String>> _runCases(
  List<(String, Duration)> cases, {
  Duration testTimeout = const Duration(seconds: 30),
  int maxRetries = 0,
}) async {
  final List<String> events = [];
  final List<int> attempts = List.filled(cases.length, 0);
  final NoPortsVersion current = NoPortsVersion(
    language: Language.dart,
    version: 'current',
  );
  final List<PolicyTestCase> testCases = [
    for (final (int i, (String policyAtsign, Duration runs)) in cases.indexed)
      PolicyTestCase(
        testName: 'npp_test',
        tag: String.fromCharCode('a'.codeUnitAt(0) + i),
        clientVersion: current,
        daemonVersion: current,
        policyVersion: current,
        policyAtsign: policyAtsign,
        run: () async {
          final String tag = String.fromCharCode('a'.codeUnitAt(0) + i);
          final int attempt = ++attempts[i];
          events.add('$tag#$attempt started');
          await Future<void>.delayed(runs);
          events.add('$tag#$attempt finished');
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
    maxRetries: maxRetries,
    testTimeout: testTimeout,
  );
  return events;
}
