/// Base class for all diagnostic tests
abstract class DiagnosticCheck {
  /// Name of the test
  String get name;

  /// Description of what this test checks
  String get description;

  /// Run the test and return the result
  Future<CheckResult> run(Map<String, dynamic> context);
}

/// Result of a diagnostic test
class CheckResult {
  final String checkName;
  final CheckStatus status;
  final String message;
  final Map<String, dynamic>? details;
  final Duration duration;

  CheckResult({
    required this.checkName,
    required this.status,
    required this.message,
    this.details,
    required this.duration,
  });

  bool get passed => status == CheckStatus.pass;
  bool get failed => status == CheckStatus.fail;
  bool get hasWarning => status == CheckStatus.warning;
  bool get skipped => status == CheckStatus.skip;

  @override
  String toString() {
    final statusStr = status.name.toUpperCase();
    return '[$statusStr] $checkName: $message';
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
enum CheckStatus {
  pass('PASS'),
  fail('FAIL'),
  warning('WARN'),
  skip('SKIP');

  final String displayName;

  const CheckStatus(this.displayName);
}
