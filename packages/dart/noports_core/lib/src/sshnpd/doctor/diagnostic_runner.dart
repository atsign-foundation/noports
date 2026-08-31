import 'diagnostic_check.dart';

/// Manages and runs a suite of diagnostic tests
class DiagnosticRunner {
  final List<DiagnosticCheck> checks;
  final bool verbose;

  DiagnosticRunner({required this.checks, this.verbose = false});

  /// Run all tests and return results
  Future<List<CheckResult>> runAll() async {
    final results = <CheckResult>[];
    final context = <String, dynamic>{};

    for (final check in checks) {
      if (verbose) {
        print('\n Running: ${check.name}');
        print('   ${check.description}');
      }

      final result = await check.run(context);
      results.add(result);

      if (verbose) {
        print(result.toDetailedString());
      } else {
        print(result.toString());
      }
    }

    return results;
  }

  /// Generate a summary report (simplified version for sshnpd)
  String generateSummary(List<CheckResult> results) {
    final buffer = StringBuffer();

  
    final passed = results.where((r) => r.passed).length;
    final failed = results.where((r) => r.failed).length;
    final warnings = results.where((r) => r.hasWarning).length;
    final skipped = results.where((r) => r.skipped).length;


    buffer.writeln('\n${'=' * 60}');
    buffer.writeln('DIAGNOSTIC SUMMARY');
    buffer.writeln('=' * 60);
    buffer.writeln('Total Tests: ${results.length}');
    buffer.writeln('Success:   $passed');
    buffer.writeln('Failures:  $failed');
    buffer.writeln('Warnings:  $warnings');
    buffer.writeln('Skipped:   $skipped');


    if (failed > 0) {
      buffer.writeln(
          '\n PROBLEMS DETECTED: sshnpd cannot start correctly.');
      buffer.writeln('\nError details:');
      for (final result in results.where((r) => r.failed)) {
        buffer.writeln('  • ${result.checkName}: ${result.message}');
      }
    }

    if (warnings > 0) {
      buffer.writeln('\nWarnings:');
      for (final result in results.where((r) => r.hasWarning)) {
        buffer.writeln('  • ${result.checkName}: ${result.message}');
      }
    }

    if (failed == 0 && warnings == 0) {
      buffer.writeln('\n SUCCESS: Everything seems ready to use sshnpd!');
    }

    if (passed > 0) {
      buffer.writeln('\nPassed Tests:');
      for (final result in results.where((r) => r.passed)) {
        buffer.writeln('  • ${result.checkName}: ${result.message}');
      }
    }


    final totalDuration =
        results.fold<Duration>(Duration.zero, (sum, r) => sum + r.duration);
    buffer.writeln('\nTotal duration: ${totalDuration.inMilliseconds}ms');
    buffer.writeln('=' * 60);

    return buffer.toString();
  }

  /// Register a new test dynamically
  void addTest(DiagnosticCheck test) {
    checks.add(test);
  }
}
