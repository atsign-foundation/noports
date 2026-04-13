enum TestStatus {
  passed,
  failed,
}

class TestResult {
  final String testName;
  final TestStatus status;
  final int exitCode;
  final StringBuffer? stdout;
  final StringBuffer? stderr;

  TestResult({
    required this.testName,
    required this.status,
    required this.exitCode,
    this.stdout,
    this.stderr
  });

}

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
