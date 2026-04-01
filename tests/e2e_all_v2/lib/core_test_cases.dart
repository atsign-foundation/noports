import 'dart:io';

import 'package:e2e_all_v2/client_binaries.dart';
import 'package:e2e_all_v2/docker_manager.dart';
import 'package:e2e_all_v2/test_result.dart';

Future<void> runCoreTestCases({
  required final String testRunId,
  required final String logDirectory,
  required final String daemonAtSign,
  required final String clientAtSign,
  required final VolumeMapping atKeysVolumeMapping,
}) async {

  // Goals:
  // 1. Set up Client binaries put them in a $testId/$version/* folder
  //  (v5.9.4, v5.11.2, v5.13.0, current)
  //  for versions, download from github.com/atsign-foundation/noports/releases
  //  for current, compile dart binaries using `dart compile exe`
  // 2. Set up the Docker daemons
  //  run Dart (current), v5.9.4, v5.11.2, v5.13.0, and C (current) in Docker containers
  // 3. Run tests via executing Client binaries, and save logs

  const List<String> clientVersions = [
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
    'd:current',
  ];

  const List<String> daemonVersions = [
    'd:current',
    'c:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];

  // Start Phase 1
  ClientBinaryManager clientBinaryManager =
    ClientBinaryManager(testRunId: testRunId);

  // Parse client versions to extract language and version
  List<(ClientLanguage, String)> parsedClientVersions = [];
  for (final String clientVersion in clientVersions) {
    final List<String> parts = clientVersion.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid client version format: $clientVersion. Expected format: "d:v5.9.4" or "c:current"');
    }
    final ClientLanguage language = parts[0] == 'd' ? ClientLanguage.dart : ClientLanguage.c;
    final String version = parts[1];
    parsedClientVersions.add((language, version));
  }

  List<(ClientBinaryType, ClientLanguage, String)> requiredBinaries = [];
  for (final (language, version) in parsedClientVersions) {
    requiredBinaries.add((ClientBinaryType.sshnp, language, version));
    requiredBinaries.add((ClientBinaryType.npt, language, version));
  }

  List<ClientBinary> clientBinaries = await clientBinaryManager.ensureBinaries(
    required: requiredBinaries,
    logDirectory: logDirectory,
  );
  print('Available client binaries: length=${clientBinaries.length}');
  for(final ClientBinary clientBinary in clientBinaries) {
    print('  ${clientBinary.binaryType.name} | ${clientBinary.language.name} | ${clientBinary.version}');
  }
  // End Phase 1

  // Start Phase 2
  List<(ClientLanguage, String)> parsedDaemonVersions = [];
  for (final String daemonVersion in daemonVersions) {
    final List<String> parts = daemonVersion.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid daemon version format: $daemonVersion. Expected format: "d:v5.9.4" or "c:current"');
    }
    final ClientLanguage language = parts[0] == 'd' ? ClientLanguage.dart : ClientLanguage.c;
    final String version = parts[1];
    parsedDaemonVersions.add((language, version));
  }

  // Build/pull Docker images for each daemon version
  List<DockerImage> dockerImages = [];
  for (final (language, version) in parsedDaemonVersions) {
    final Language dockerLanguage = language == ClientLanguage.dart ? Language.dart : Language.c;

    DockerImage dockerImage;
    if (version == 'current') {
      dockerImage = DockerImage.current(language: dockerLanguage);
    } else if (version.startsWith('v')) {
      dockerImage = DockerImage.release(language: dockerLanguage, version: version);
    } else {
      dockerImage = DockerImage.branch(language: dockerLanguage, branch: version);
    }

    // Check if image exists
    final bool existsOnMachine = await dockerImage.existsOnMachine();
    if (!existsOnMachine) {
      print('Docker image ${dockerImage.fullImageName} not found, attempting to pull...');
      final Process pullProcess = await dockerImage.pull(logDirectory: logDirectory);
      final int pullExitCode = await pullProcess.exitCode;

      if (pullExitCode != 0) {
        print('Pull failed for ${dockerImage.fullImageName}, building locally...');
        final Process buildProcess = await dockerImage.build(
          forceOverwriteCache: false,
          quiet: false,
          logDirectory: logDirectory,
        );
        final int buildExitCode = await buildProcess.exitCode;

        if (buildExitCode == 0) {
          print('Successfully built ${dockerImage.fullImageName}');
          dockerImages.add(dockerImage);
        } else {
          print('ERROR: Failed to build ${dockerImage.fullImageName}');
        }
      } else {
        print('Successfully pulled ${dockerImage.fullImageName}');
        dockerImages.add(dockerImage);
      }
    } else {
      print('Docker image ${dockerImage.fullImageName} already exists');
      dockerImages.add(dockerImage);
    }
  }

  print('Available Docker images: length=${dockerImages.length}');
  for (final dockerImage in dockerImages) {
    print('  ${dockerImage.fullImageName}');
  }

  // Start Docker instances for each daemon version
  List<DockerInstance> dockerInstances = [];
  for (final dockerImage in dockerImages) {
    final String deviceNameWithoutFlags = '${testRunId}${dockerImage.language.name[0]}${dockerImage.tag.replaceAll('.', '')}';
    final String deviceNameWithFlags = '${deviceNameWithoutFlags}f';

    // 1. create a docker instance with -s -u (container 1)
    final DockerInstance dockerInstance1 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
    );

    print('Starting Docker instance: ${dockerInstance1.containerName}');
    await dockerInstance1.run(
      quiet: false,
      volumeMappings: [atKeysVolumeMapping],
      removeWhenStopped: true,
      logDirectory: logDirectory,
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && '
          'sshnpd -a $daemonAtSign -m $clientAtSign -v '
          '-d ${deviceNameWithFlags} '
          '-s -u',
      ],
    );

    dockerInstances.add(dockerInstance1);
    print('Started Docker instance: ${dockerInstance1.containerName}');
  }

  print('Running Docker instances: ${dockerInstances.length}');
  for (final instance in dockerInstances) {
    print('  ${instance.containerName}');
  }
  // End Phase 2

  // Start Phase 3 - Run Tests
  List<TestResult> testResults = [];

  // Run all tests in order
  print('\n========== Running Tests ==========\n');

  // Test #1: 001_minus_s_flag (only runs with current client)
  for (final (daemonLanguage, daemonVersion) in parsedDaemonVersions) {
    final result = await _test001MinusSFlag(
      allClientBinaries: clientBinaries,
      allDockerInstances: dockerInstances,
      daemonLanguage: daemonLanguage,
      daemonVersion: daemonVersion,
      testRunId: testRunId,
      logDirectory: logDirectory,
    );
    if (result != null) testResults.add(result);
  }

  // TODO: Add remaining tests following the same pattern

  // End Phase 3

  // Print Summary
  print('\n========== Test Summary ==========\n');
  int passed = 0;
  int failed = 0;

  for (final result in testResults) {
    if (result.status == TestStatus.passed) {
      passed++;
      print('✓ ${result.testName} [${result.clientVersion} -> ${result.daemonVersion}]: PASSED');
    } else if (result.status == TestStatus.failed) {
      failed++;
      print('✗ ${result.testName} [${result.clientVersion} -> ${result.daemonVersion}]: FAILED');
      if (result.stderr.isNotEmpty) {
        print('  Error output:');
        for (final line in result.stderr.split('\n').take(10)) {
          print('    $line');
        }
      }
    }
  }

  print('\nTotal: ${testResults.length} tests');
  print('Passed: $passed');
  print('Failed: $failed');

  if (failed > 0) {
    print('\n⚠️  Some tests failed. Check logs for details.');
  } else {
    print('\n✓ All tests passed!');
  }

  // Tear down Docker instances
  print('\n========== Tearing Down Docker Instances ==========\n');
  for (final instance in dockerInstances) {
    print('Stopping Docker instance: ${instance.containerName}');
    final int stopExitCode = await instance.stop(logDirectory: logDirectory);
    if (stopExitCode == 0) {
      print('Stopped: ${instance.containerName}');
    } else {
      print('Failed to stop: ${instance.containerName} (exit code: $stopExitCode)');
    }
  }
  print('All Docker instances stopped.');
}

// Test coverage

// Test #2: minus_r_flag
// 1. Run sshnp with `--host` (expect to pass)
// 2. Run sshnp with `-h` invalid and `-r` valid (expect to pass)
// 3. Run sshnp with `-h` valid and `-r` invalid (expect to fail)
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0

// Test #3: minus_u_flag
// - Client: Dart (current) | Daemon: Dart (current)

// Test #4: npt_to_port_22
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: C (current)
// - Client: Dart v5.9.4 | Daemon: C (current)
// - Client: Dart v5.11.2 | Daemon: C (current)
// - Client: Dart v5.13.0 | Daemon: C (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0

// Test #5: npt_to_port_22_no_encrypt_traffic
// - Client: Dart (current) | Daemon: Dart (current)

// Test #6: v4_dart_inline
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0

// Test #7: v4_openssh_print
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0

// Test #8: v5_dart_inline
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: C (current)
// - Client: Dart v5.9.4 | Daemon: C (current)
// - Client: Dart v5.11.2 | Daemon: C (current)
// - Client: Dart v5.13.0 | Daemon: C (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0

// Test #9: v5_openssh_inline
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: C (current)
// - Client: Dart v5.9.4 | Daemon: C (current)
// - Client: Dart v5.11.2 | Daemon: C (current)
// - Client: Dart v5.13.0 | Daemon: C (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0

// Test #10: v5_openssh_print
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: C (current)
// - Client: Dart v5.9.4 | Daemon: C (current)
// - Client: Dart v5.11.2 | Daemon: C (current)
// - Client: Dart v5.13.0 | Daemon: C (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0


// Test #1: 001_minus_s_flag
// 1. Generates a new ssh key
// 2. 
//     a. Run sshnp against a daemon without the `-s` flag with that new key
//     b. Verify it fails
// 3.
//     a. Run against a daemon with the `-s` flag
//     b. Verify it succeeds
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: C (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0
Future<List<TestResult>> _test001MinusSFlag({
  required List<ClientBinary> allClientBinaries,
  required List<DockerInstance> allDockerInstances,
  required String testRunId,
  required String logDirectory,
}) async {
  List<TestResult> testResults = [];

  const String testName = '001_minus_s_flag';
  const List<String> clientVersions = [
    'd:current',
  ];
  const List<String> daemonVersions = [
    'd:current',
    'c:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];
  final List<ClientBinary> matchingClientBinaries = _getMatchingClientBinaries(
    allClientBinaries: allClientBinaries,
    clientVersions: clientVersions,
  );
  final List<DockerInstance> matchingDockerInstances = _getMatchingDockerInstancaes(
    allDockerInstances: allDockerInstances,
    daemonVersions: daemonVersions,
  );

  if (matchingClientBinaries.isEmpty) {
    throw Exception('Required client binary not found for test $testName: sshnp, Dart, current');
  }
  final ClientBinary clientBinary = matchingClientBinaries.firstWhere((binary) =>
    binary.binaryType == ClientBinaryType.sshnp &&
    binary.language == ClientLanguage.dart &&
    binary.version == 'current'
  );

  _generateNewSshKey(testRunId: testRunId);

  for(final DockerInstance dockerInstance in matchingDockerInstances) {
    final String daemonVersion = '${dockerInstance.dockerImage.language == Language.dart ? 'd' : 'c'}:${dockerInstance.dockerImage.tag}';
    print('\nRunning test $testName with client ${clientBinary.version} against daemon $daemonVersion');
  }

}

List<ClientBinary> _getMatchingClientBinaries({
  required List<ClientBinary> allClientBinaries,
  required List<String> clientVersions,
}) {
  List<ClientBinary> matchingBinaries = [];
  for (final String clientVersion in clientVersions) {
    final List<ClientBinary> matches = allClientBinaries.where((binary) =>
      binary.version == clientVersion.split(':')[1] &&
      binary.language == (clientVersion.startsWith('d:') ? ClientLanguage.dart : ClientLanguage.c)
    ).toList();

    if (matches.isEmpty) {
      print('WARNING: No matching client binary found for client version $clientVersion');
    } else {
      matchingBinaries.addAll(matches);
    }
  }
  return matchingBinaries;
}

List<DockerInstance> _getMatchingDockerInstancaes({
  required List<DockerInstance> allDockerInstances,
  required List<String> daemonVersions,
}) {
  List<DockerInstance> matchingInstances = [];
  for (final String daemonVersion in daemonVersions) {
    final List<DockerInstance> matches = allDockerInstances.where((instance) =>
      instance.dockerImage.tag == daemonVersion.split(':')[1] &&
      instance.dockerImage.language == (daemonVersion.startsWith('d:') ? Language.dart : Language.c)
    ).toList();

    if (matches.isEmpty) {
      print('WARNING: No matching Docker instance found for daemon version $daemonVersion');
    } else {
      matchingInstances.addAll(matches);
    }
  }
  return matchingInstances;
}

void _generateNewSshKey({required final String testRunId}) {
  // mkdir -p $HOME/.ssh
  final String sshDirPath = '${Platform.environment['HOME']}/.ssh';
  final Directory sshDir = Directory(sshDirPath);
  if (!sshDir.existsSync()) {
    sshDir.createSync(recursive: true);
    print('Created .ssh directory at $sshDirPath');
  }

  // chmod go-rwx $HOME/.ssh (remove group and other permissions)
  // TODO make OS fluid
  Process.runSync('chmod', ['go-rwx', sshDirPath]);

  // touch authkeysFile = $HOME/.ssh/authorized_keys
  final String authKeysFilePath = '$sshDirPath/authorized_keys';
  final File authKeysFile = File(authKeysFilePath);
  if (!authKeysFile.existsSync()) {
    authKeysFile.createSync();
    print('Created authorized_keys file at $authKeysFilePath');
  }

  // chmod go-rwx $HOME/.ssh/authorized_keys
  // TODO make OS fluid
  Process.runSync('chmod', ['go-rwx', authKeysFilePath]);

  // identityFileName = $HOME/.ssh/e2e_all.${testRunId}
  final String identityFileName = '$sshDirPath/e2e_all.$testRunId';

  // ssh-keygen -t ed25519 -q -N '' -f "${identityFilename}" -C "$testRunId"
  final ProcessResult keyGenResult = Process.runSync(
    'ssh-keygen',
    ['-t', 'ed25519', '-q', '-N', '', '-f', identityFileName, '-C', testRunId],
  );

  if (keyGenResult.exitCode != 0) {
    throw Exception('Failed to generate SSH key: ${keyGenResult.stderr}');
  }

  // print('Generated SSH key: $identityFileName');

  // Read the public key and append it to authorized_keys
  final String publicKey = File('$identityFileName.pub').readAsStringSync().trim();
  authKeysFile.writeAsStringSync('$publicKey\n', mode: FileMode.append);
  print('Added public key to authorized_keys');
}

