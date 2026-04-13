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
