import 'dart:io';

import 'package:npe2e/core_tests/core_tests.dart';
import 'package:npe2e/core_tests/core_tests_params.dart';
import 'package:npe2e/print_test_utils.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    CoreTestsParams.printUsage();
    exit(0);
  }

  // 1. Check OS compatibility
  if (!Platform.isMacOS && !Platform.isLinux) {
    print('ERROR: This script only supports macOS and Linux');
    print('Current platform: ${Platform.operatingSystem}');
    exit(1);
  }

  // 2. Check required commands are available
  const List<String> requiredCommands = [
    'docker',
    'git',
    'ssh-keygen',
    'chmod',
    'sh',
    'expect',
  ];

  print('Checking required commands...');
  for (final String command in requiredCommands) {
    final ProcessResult result = await Process.run('which', [command]);
    if (result.exitCode != 0) {
      print('Please install $command and ensure it is in your PATH');
      exit(1);
    }
    print('  ✓ $command: ${result.stdout.toString().trim()}');
  }
  print('');

  // 3. parse args
  CoreTestsParams params;
  try {
    params = CoreTestsParams.parse(args);
    if (params.help) {
      CoreTestsParams.printUsage();
      exit(0);
    }
  } catch (e) {
    CoreTestsParams.printUsage();
    exit(1);
  }
  _printLoadedParameters(params);
  print('');

  try {
    // 4. Run core tests
    final DateTime startTime = DateTime.now();
    await coreTests(params);
    final DateTime endTime = DateTime.now();
    final Duration duration = endTime.difference(startTime);
    print('Core tests completed in ${formatDuration(duration)}');
    exit(0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

void _printLoadedParameters(CoreTestsParams params) {
  print('npe2e Loaded Parameters:');
  print('    help: ${params.help}');
  print('    client-atsign: ${params.clientAtsign}');
  print('    daemon-atsign: ${params.daemonAtsign}');
  print('    relay-atsign: ${params.relayAtsign}');
  print('    root-domain: ${params.rootDomain}');
  print('    verbose: ${params.verbose}');
  print('    base-directory: ${params.baseDirectory}');
  print('    batch-size: ${params.batchSize}');
}
