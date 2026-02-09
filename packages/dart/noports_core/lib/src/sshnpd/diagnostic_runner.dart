import 'diagnostic_test.dart';

/// Manages and runs a suite of diagnostic tests
class DiagnosticRunner {
  final List<DiagnosticTest> tests;
  final bool verbose;

  DiagnosticRunner({required this.tests, this.verbose = false});

  /// Run all tests and return results
  Future<List<TestResult>> runAll() async {
    final results = <TestResult>[];

    for (final test in tests) {
      if (verbose) {
        print('\n🔍 Running: ${test.name}');
        print('   ${test.description}');
      }

      final result = await test.run();
      results.add(result);

      if (verbose) {
        print(result.toDetailedString());
      } else {
        print(result.toString());
      }
    }

    return results;
  }

  /// Generate a summary report (Version Simplifiée pour sshnpd)
  String generateSummary(List<TestResult> results) {
    final buffer = StringBuffer();

    // 1. Les Compteurs
    final passed = results.where((r) => r.passed).length;
    final failed = results.where((r) => r.failed).length;
    final warnings = results.where((r) => r.hasWarning).length;
    final skipped = results.where((r) => r.skipped).length;

    // 2. L'En-tête
    buffer.writeln('\n${'=' * 60}');
    buffer.writeln('DIAGNOSTIC SUMMARY');
    buffer.writeln('=' * 60);
    buffer.writeln('Total Tests: ${results.length}');
    buffer.writeln('Success:   $passed');
    buffer.writeln('Failures:  $failed');
    buffer.writeln('Warnings:  $warnings');
    buffer.writeln('Skipped:   $skipped');

    // 3. La Logique de Conclusion (Simple et efficace)
    if (failed > 0) {
      buffer.writeln(
          '\n PROBLEMS DETECTED : sshnpd cannot start correctly.');
      buffer.writeln('\nError details :');
      for (final result in results.where((r) => r.failed)) {
        buffer.writeln('  • ${result.testName}: ${result.message}');
      }
    } else if (warnings > 0) {
      buffer.writeln(
          '\n  WARNING : sshnpd may work, but check the items above.');
      buffer.writeln('\nWarnings :');
      for (final result in results.where((r) => r.hasWarning)) {
        buffer.writeln('  • ${result.testName}: ${result.message}');
      }
    } else {
      buffer.writeln('\n SUCCESS : Everything seems ready to use sshnpd !');
    }

    // 4. Durée totale
    final totalDuration =
        results.fold<Duration>(Duration.zero, (sum, r) => sum + r.duration);
    buffer.writeln('\nTotal duration: ${totalDuration.inMilliseconds}ms');
    buffer.writeln('=' * 60);

    return buffer.toString();
  }

  /// Register a new test dynamically
  void addTest(DiagnosticTest test) {
    tests.add(test);
  }
}
