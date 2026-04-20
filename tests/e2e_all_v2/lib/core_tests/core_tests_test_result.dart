import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/test_result.dart';

class CoreTestResult extends TestResult {
  final NoPortsVersion clientVersion;
  final NoPortsVersion daemonVersion;

  CoreTestResult({
    required super.testName,
    required this.clientVersion,
    required this.daemonVersion,
    required super.status,
    required super.exitCode
  });
}
