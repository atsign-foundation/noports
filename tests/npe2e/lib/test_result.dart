enum TestStatus { passed, failed }

class TestResult {
  final String testName;
  final TestStatus status;
  final int exitCode;
  final String? failureReason;
  final List<String> logFilePaths;

  TestResult({
    required this.testName,
    required this.status,
    required this.exitCode,
    this.failureReason,
    this.logFilePaths = const [],
  });
}
