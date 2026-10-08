import 'package:npe2e/noports_version.dart';
import 'package:npe2e/test_result.dart';

class CoreTestResult extends TestResult {
  final NoPortsVersion clientVersion;
  final NoPortsVersion daemonVersion;

  CoreTestResult({
    required super.testName,
    required this.clientVersion,
    required this.daemonVersion,
    required super.status,
    required super.exitCode,
  });
}
