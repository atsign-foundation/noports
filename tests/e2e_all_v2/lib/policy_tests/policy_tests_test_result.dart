import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/test_result.dart';

class PolicyTestResult extends TestResult {
  final NoPortsVersion clientVersion;
  final NoPortsVersion daemonVersion;
  final NoPortsVersion policyVersion;

  PolicyTestResult({
    required super.testName,
    required this.clientVersion,
    required this.daemonVersion,
    required this.policyVersion,
    required super.status,
    required super.exitCode,
  });
}
