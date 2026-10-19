import 'dart:io';

import 'package:at_utils/at_logger.dart';
import 'package:npe2e/print_test_utils.dart';
import 'package:npe2e/revocation_tests/revocation_tests.dart';
import 'package:npe2e/revocation_tests/revocation_tests_params.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    RevocationTestsParams.printUsage();
    exit(0);
  }
  if (!Platform.isMacOS && !Platform.isLinux) {
    print('ERROR: this script only supports macOS and Linux');
    exit(1);
  }
  for (final String command in ['docker', 'git', 'chmod', 'sh']) {
    if ((await Process.run('which', [command])).exitCode != 0) {
      print('Please install $command and ensure it is in your PATH');
      exit(1);
    }
  }

  final RevocationTestsParams params;
  try {
    params = RevocationTestsParams.parse(args);
  } catch (e) {
    print('Error parsing arguments: $e\n');
    RevocationTestsParams.printUsage();
    exit(1);
  }
  AtSignLogger.root_level = 'SEVERE';

  final DateTime startTime = DateTime.now();
  final bool passed;
  try {
    passed = await revocationTests(params);
  } catch (e, st) {
    print('Error: $e\n$st');
    exit(1);
  }
  print('Revocation tests completed in'
      ' ${formatDuration(DateTime.now().difference(startTime))}');
  exit(passed ? 0 : 1);
}
