import 'dart:io';

import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/print_test_utils.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/test_result.dart';

// 1. Run with --host
//  - expect this test to pass
// 2. Run with -h && -r (-h set to an invalid rvd atSign)
//  - expect this test to pass
//
// TODO: Would like to add a test for, but this causes the test to timeout waiting for the bad srvd
// 3. Run with -h && -r (-r set to an invalid rvd atSign)
//  - expect this test to fail
//
// 1. Run sshnp with `--host` (expect to pass)
// 2. Run sshnp with `-h` invalid and `-r` valid (expect to pass)
// 3. Run sshnp with `-h` valid and `-r` invalid (expect to fail)
//
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0
Future<List<CoreTestResult>> runMinusRFlagTests({
  required final String testRunId,
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String relayAtsign,
  required final String rootDomain,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
  required final List<ClientBinary> clientBinaries,
  required final List<(String, DockerInstance)> dockerInstances,
  required final Map<String, File> apkamKeys,
  required final String remoteUsername,
  required final String identityFilePath,
}) async {
  const String testName = 'minus_r_flag';
  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations = 
    _generateVersionCombinations(
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    );
  print('Generated version combinations:');
  for(final (clientVersion, daemonVersion) in versionCombinations) {
    print('client: ${clientVersion.language.name[0]}:${clientVersion.version}, daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version}'); 
  }

  final List<CoreTestResult> testResults = [];
  for(final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion) in versionCombinations) {
    if(versionIsLessThan(daemonVersion, NoPortsVersion(language: Language.dart, version: 'v5.2.0'))) {
      // N/A C daemon doesn't need to test a client-side only feature
      continue;
    }
    if(versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.2.0'))) {
      // -r was added in v5.2.0
      continue; 
    }
    final String extra = 'client: ${clientVersion.language.name[0]}:${clientVersion.version}, daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version}';
    printTestStart(testName: testName, extra: extra);
    final ClientBinary sshnpClientBinary = clientBinaries.firstWhere((cb) => cb.noPortsVersion == clientVersion);
    final String deviceName = '${getDeviceNameNoFlags(testRunId: testRunId, language: daemonVersion.language, version: daemonVersion.version)}_f';
    final List<String> baseArgs = _generateBaseSshnpArgs(
      clientVersion: clientVersion,
      testRunId: testRunId, 
      clientAtsign: clientAtsign,
      daemonAtsign: daemonAtsign,
      localClientAtsignAtKeysFilePath: apkamKeys[clientAtsign]!.path,
      identityFilePath: identityFilePath,
      remoteUsername: remoteUsername,
      rootDomain: rootDomain,
      deviceName: deviceName,
    );

    // 1. Run with --host (expect to pass)
    final List<String> args1 = List.from(baseArgs)..addAll(['--host', relayAtsign]);
    final ProcessResult processResult1 = await runCommand(
      sshnpClientBinary.file.path,
      args1,
    );
    final StringBuffer stdoutBuffer1 = StringBuffer();
    final StringBuffer stderrBuffer1 = StringBuffer();
    stdoutBuffer1.writeln(processResult1.stdout.toString());
    stderrBuffer1.writeln(processResult1.stderr.toString());
    if(processResult1.exitCode != 0) {
      final CoreTestResult coreTestResult = CoreTestResult(
        testName: testName,
        clientVersion: clientVersion.version,
        daemonVersion: daemonVersion.version,
        status: TestStatus.failed,
        exitCode: processResult1.exitCode,
      );
      printTestResult(testResult: coreTestResult, extra: extra);
      testResults.add(coreTestResult);
    } else {
      final CoreTestResult coreTestResult = CoreTestResult(
        testName: testName,
        clientVersion: clientVersion.version,
        daemonVersion: daemonVersion.version,
        status: TestStatus.passed,
        exitCode: processResult1.exitCode,
        stdout: processResult1.stdout,
        stderr: processResult1.stderr,
      );
      printTestResult(testResult: coreTestResult, extra: extra);
      testResults.add(coreTestResult);
    }
  }
  return testResults;
}

List<String> _generateBaseSshnpArgs({
  required final NoPortsVersion clientVersion,
  required final String testRunId,
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String localClientAtsignAtKeysFilePath,
  required final String identityFilePath,
  required final String remoteUsername,
  required final String rootDomain,
  required final String deviceName,
}) {
  final List<String> args = [];
  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
    args.add('-x');
    args.add('--no-ad');
    args.add('--no-et');
  }
  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
    args.add('-k');
    args.add(localClientAtsignAtKeysFilePath);
  }
  args.addAll([
    '-f', clientAtsign,
    '-t', daemonAtsign,
    '-i', identityFilePath,
    '-u', remoteUsername,
    '--root-domain', rootDomain,
    '-d', deviceName,
    '-s',
  ]);
  return args;
}


// we only want to check:
//   a. non-current client with current daemon
//   b. current cleint with non-current daemon
List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> combinations = [];
  for(final clientVersion in clientVersions) {
    for(final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      // skip if both client and daemon are not current
      if(!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      if(daemonVersion.language == Language.c) {
        // C daemon doesn't need to test a client side only feature
        continue;
      }
      if(clientVersion.language == Language.dart && versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.2.0'))) {
        // -r was added in v5.2.0
        continue; 
      }
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
