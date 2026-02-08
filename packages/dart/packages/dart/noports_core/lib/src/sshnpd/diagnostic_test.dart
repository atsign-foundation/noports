/// Base class for all diagnostic tests
abstract class DiagnosticTest {
  /// Name of the test
  String get name;

  /// Description of what this test checks
  String get description;

  /// Run the test and return the result
  Future<TestResult> run();
}

/// Result of a diagnostic test
class TestResult {
  final String testName;
  final TestStatus status;
  final String message;
  final Map<String, dynamic>? details;
  final Duration duration;

  TestResult({
    required this.testName,
    required this.status,
    required this.message,
    this.details,
    required this.duration,
  });

  bool get passed => status == TestStatus.pass;
  bool get failed => status == TestStatus.fail;
  bool get hasWarning => status == TestStatus.warning;
  bool get skipped => status == TestStatus.skip;

  @override
  String toString() {
    final icon = status.icon;
    final statusStr = status.name.toUpperCase();
    return '$icon [$statusStr] $testName: $message';
  }

  /// Detailed output including any additional details
  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.writeln(toString());
    if (details != null && details!.isNotEmpty) {
      buffer.writeln('  Details:');
      details!.forEach((key, value) {
        buffer.writeln('    $key: $value');
      });
    }
    buffer.writeln('  Duration: ${duration.inMilliseconds}ms');
    return buffer.toString();
  }
}

/// Status of a test
enum TestStatus {
  pass('✓', 'PASS'),
  fail('✗', 'FAIL'),
  warning('⚠', 'WARN'),
  skip('○', 'SKIP');

  final String icon;
  final String displayName;

  const TestStatus(this.icon, this.displayName);
}
