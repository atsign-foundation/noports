import 'package:npe2e/noports_version.dart';
import 'package:npe2e/policy_tests/policy_tests_test_result.dart';
import 'package:npe2e/policy_tests/policy_tests_print_utils.dart';
import 'package:npe2e/test_result.dart';

class PolicyTestCase {
  final String testName;

  final String tag; // Short unique identity, shared with daemon container and per-stage log file names. See `getPolicyFlowDeviceName` 

  final NoPortsVersion clientVersion;
  final NoPortsVersion daemonVersion;
  final NoPortsVersion policyVersion;

  final Future<PolicyTestResult> Function() run;

  PolicyTestCase({
    required this.testName,
    required this.tag,
    required this.clientVersion,
    required this.daemonVersion,
    required this.policyVersion,
    required this.run,
  });

  /// `(client: d:current, daemon: d:current, policy: d:current)`
  String get extra => generatePolicyExtraString(
    clientVersion,
    daemonVersion,
    policyVersion,
    useShortLanguageName: true,
  );

  PolicyTestResult failedResult({
    required final String stage,
    required final String reason,
    final String? detail,
  }) {
    return PolicyTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      status: TestStatus.failed,
      exitCode: 1,
      tag: tag,
      failure: PolicyTestFailure(stage: stage, reason: reason, detail: detail),
    );
  }
}
