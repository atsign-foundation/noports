enum TestStatus {
  passed,
  failed,
  skipped,
}

class TestResult {
  final String testName;
  final String clientVersion;
  final String daemonVersion;
  final TestStatus status;
  final String stdout;
  final String stderr;
  final int exitCode;

  TestResult({
    required this.testName,
    required this.clientVersion,
    required this.daemonVersion,
    required this.status,
    this.stdout = '',
    this.stderr = '',
    this.exitCode = 0,
  });
}
