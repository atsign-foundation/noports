import 'package:e2e_all_v2/test_result.dart';

class CoreTestResult extends TestResult {
  final String clientVersion;
  final String daemonVersion;

  CoreTestResult({
    required super.testName,
    required this.clientVersion,
    required this.daemonVersion,
    required super.status,
    required super.exitCode,
    super.stdout,
    super.stderr
  });

  void printResult({bool printStdout = false, bool printStderr = false}) {
    print('$testName (client: $clientVersion, daemon: $daemonVersion) - ${status.name.toUpperCase()} (exit code: $exitCode)');
    if (stdout != null && stdout!.isNotEmpty) {
      print('STDOUT:\n$stdout');
    }
    if (stderr != null && stderr!.isNotEmpty) {
      print('STDERR:\n$stderr');
    }
  }
}
