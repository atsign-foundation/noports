import 'dart:io';

import 'package:e2e_all_v2/client_binaries.dart';
import 'package:e2e_all_v2/docker_manager.dart';

Future<void> runCoreTestCases({
  required final String testRunId,
  required final String logDirectory,
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
  // assume Dart

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

  print('Parsed daemon versions: length=${parsedDaemonVersions.length}');
  for (final (language, version) in parsedDaemonVersions) {
    print('  ${language.name} | $version');
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
    final DockerInstance dockerInstance = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
    );

    print('Starting Docker instance: ${dockerInstance.containerName}');
    await dockerInstance.run(
      quiet: false,
      removeWhenStopped: true,
      logDirectory: logDirectory,
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && tail -f /dev/null', // Keep container running
      ],
    );

    dockerInstances.add(dockerInstance);
    print('Started Docker instance: ${dockerInstance.containerName}');
  }

  print('Running Docker instances: ${dockerInstances.length}');
  for (final instance in dockerInstances) {
    print('  ${instance.containerName}');
  }
  // End Phase 2

  // Test coverage

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
}
