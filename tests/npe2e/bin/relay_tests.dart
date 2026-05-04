import 'dart:io';

import 'package:npe2e/print_test_utils.dart';
import 'package:npe2e/relay_tests/relay_tests.dart';
import 'package:npe2e/relay_tests/relay_tests_params.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    RelayTestsParams.printUsage();
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

  final RelayTestsParams params;
  try {
    params = RelayTestsParams.parse(args);
    if (params.help) {
      RelayTestsParams.printUsage();
      exit(0);
    }
  } catch (e) {
    print('Error parsing arguments: $e');
    print('');
    RelayTestsParams.printUsage();
    exit(1);
  }

  _printLoadedParameters(params);
  print('');

  try {
    final DateTime startTime = DateTime.now();
    await relayTests(params);
    final DateTime endTime = DateTime.now();
    final Duration duration = endTime.difference(startTime);
    print('Relay tests completed in ${formatDuration(duration)}');
    exit(0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

void _printLoadedParameters(RelayTestsParams params) {
  print('relay_tests Loaded Parameters:');
  print('    help: ${params.help}');
  print('    client-atsign: ${params.clientAtsign}');
  print('    daemon-atsign: ${params.daemonAtsign}');
  print('    prod-relay: ${params.prodRelayAtsign}');
  print('    self-relay-atsigns: ${params.selfRelayAtsigns}');
  print('    root-domain: ${params.rootDomain}');
  print('    verbose: ${params.verbose}');
  print('    base-directory: ${params.baseDirectory}');
  print('    client-versions: ${params.clientVersions}');
  print('    daemon-versions: ${params.daemonVersions}');
  print('    self-relay-versions: ${params.selfRelayVersions}');
  print('    batch-size: ${params.batchSize}');
}
