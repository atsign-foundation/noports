import 'dart:io';

import 'package:at_utils/at_logger.dart';
import 'package:npe2e/policy_tests/policy_tests.dart';
import 'package:npe2e/policy_tests/policy_tests_params.dart';
import 'package:npe2e/print_test_utils.dart';

Future<void> main(List<String> args) async {
  AtSignLogger.root_level = 'SEVERE';

  if (args.contains('--help') || args.contains('-h')) {
    PolicyTestsParams.printUsage();
    exit(0);
  }

  if (!Platform.isMacOS && !Platform.isLinux) {
    print('ERROR: This script only supports macOS and Linux');
    print('Current platform: ${Platform.operatingSystem}');
    exit(1);
  }

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

  final PolicyTestsParams params;
  try {
    params = PolicyTestsParams.parse(args);
    if (params.help) {
      PolicyTestsParams.printUsage();
      exit(0);
    }
  } catch (e) {
    print('Error parsing arguments: $e');
    print('');
    PolicyTestsParams.printUsage();
    exit(1);
  }

  _printLoadedParameters(params);
  print('');

  try {
    final DateTime startTime = DateTime.now();
    await policyTests(params);
    final DateTime endTime = DateTime.now();
    final Duration duration = endTime.difference(startTime);
    print('Policy tests completed in ${formatDuration(duration)}');
    exit(0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

void _printLoadedParameters(PolicyTestsParams params) {
  print('policy_tests Loaded Parameters:');
  print('    help: ${params.help}');
  print('    client-atsign: ${params.clientAtsign}');
  print('    daemon-atsign: ${params.daemonAtsign}');
  print('    relay-atsign: ${params.relayAtsign}');
  print('    npp-atsign: ${params.nppAtsign}');
  print('    npp-atserver-atsign: ${params.nppAtServerAtsign}');
  print('    root-domain: ${params.rootDomain}');
  print('    verbose: ${params.verbose}');
  print('    base-directory: ${params.baseDirectory}');
  print('    client-versions: ${params.clientVersions}');
  print('    daemon-versions: ${params.daemonVersions}');
  print('    npp-versions: ${params.nppVersions}');
  print('    npp-atserver-versions: ${params.nppAtServerVersions}');
  print('    batch-size: ${params.batchSize}');
  print('    max-retries: ${params.maxRetries}');
  print('    test-timeout-seconds: ${params.testTimeoutSeconds}');
}
