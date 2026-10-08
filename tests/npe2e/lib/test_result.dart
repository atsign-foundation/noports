enum TestStatus { passed, failed }

class TestResult {
  final String testName;
  final TestStatus status;
  final int exitCode;

  TestResult({
    required this.testName,
    required this.status,
    required this.exitCode,
  });
}
