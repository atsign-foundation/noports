import 'dart:io';

import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/noports_version.dart';

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
}) async {
  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations = 
    _generateVersionCombinations(
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    );
  print('Generated version combinations:');
  for(final (clientVersion, daemonVersion) in versionCombinations) {
    print('Client: ${clientVersion.version}, Daemon: ${daemonVersion.version}'); 
  }



  final List<CoreTestResult> results = [];
  return results;
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
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
