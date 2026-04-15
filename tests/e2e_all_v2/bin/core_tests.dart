import 'dart:io';

import 'package:e2e_all_v2/core_tests.dart';
import 'package:e2e_all_v2/core_tests/core_tests_params.dart';

Future<void> main(List<String> args) async {
  // 1. Check OS compatibility
  if (!Platform.isMacOS && !Platform.isLinux) {
    print('ERROR: This script only supports macOS and Linux');
    print('Current platform: ${Platform.operatingSystem}');
    exit(1);
  }

  // 2. Check required commands are available
  final List<String> requiredCommands = [
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
      print('ERROR: Required command not found: $command');
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
    if(params.help) {
      CoreTestsParams.printUsage();
      exit(1);
    }
  } catch(e) {
    CoreTestsParams.printUsage();
    exit(1);
  }
  print('');
  _printLoadedParameters(params);
  print('');

  try {
    // 4. Run core tests
    await coreTests(params);
    exit(0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

void _printLoadedParameters(CoreTestsParams params) {
  print('e2e_all_v2 Loaded Parameters:');
  print('    help: ${params.help}');
  print('    client-atsign: ${params.clientAtsign}');
  print('    daemon-atsign: ${params.daemonAtsign}');
  print('    relay-atsign: ${params.relayAtsign}');
  print('    policy-atsign: ${params.policyAtsign}');
  print('    events-atsign: ${params.eventsAtsign}');
  print('    root-domain: ${params.rootDomain}');
  print('    verbose: ${params.verbose}');
  print('    base-directory: ${params.baseDirectory}');
}
