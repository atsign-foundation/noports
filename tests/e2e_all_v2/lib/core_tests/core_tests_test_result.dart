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
    // ANSI color codes
    const String green = '\x1B[32m';
    const String red = '\x1B[31m';
    const String reset = '\x1B[0m';

    String statusText;
    String color;

    if (status == TestStatus.passed) {
      statusText = 'TEST PASSED';
      color = green;
    } else {
      statusText = 'TEST FAILED';
      color = red;
    }

    print('\t$testName (client: $clientVersion, daemon: $daemonVersion) $color$statusText$reset');

    if (printStdout && stdout != null && stdout!.isNotEmpty) {
      print('STDOUT:\n$stdout');
    }
    if (printStderr && stderr != null && stderr!.isNotEmpty) {
      print('STDERR:\n$stderr');
    }
  }
}
