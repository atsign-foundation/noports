import 'package:npe2e/test_result.dart';

void printCommand(String executable, List<String> arguments) {
  print('> $executable ${arguments.join(' ')}');
}

String formatDuration(Duration duration) {
  return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
}

void printTestResult({
  required final TestResult testResult,
  final String extra = '',
}) {
  final String testName = testResult.testName;
  final String statusText = testResult.status == TestStatus.passed
      ? 'TEST PASSED'
      : 'TEST FAILED';
  final String color = testResult.status == TestStatus.passed
      ? '\x1B[32m'
      : '\x1B[31m'; // Green for passed, Red for failed
  const String reset = '\x1B[0m';
  print('\t$color$statusText$reset $testName $extra\n');
}

void printTestStart({required final String testName, final String extra = ''}) {
  final String color = '\x1B[34m'; // Blue for test start
  const String reset = '\x1B[0m';
  print('\n\t${color}STARTING TEST:$reset $testName $extra\n');
}
