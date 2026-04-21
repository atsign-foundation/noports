import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/core_tests/tests/minus_u_flag.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/tests/001_minus_s_flag.dart';
import 'package:e2e_all_v2/core_tests/core_tests_apkam_setup.dart';
import 'package:e2e_all_v2/core_tests/core_tests_client_binary_utils.dart';
import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/core_tests/core_tests_params.dart';
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/core_tests/tests/minus_r_flag.dart';
import 'package:e2e_all_v2/core_tests/tests/npt_to_port_22.dart';
import 'package:e2e_all_v2/core_tests/tests/npt_to_port_22_no_encrypt_traffic.dart';
import 'package:e2e_all_v2/core_tests/tests/v4_dart_inline.dart';
import 'package:e2e_all_v2/core_tests/tests/v4_openssh_print.dart';
import 'package:e2e_all_v2/core_tests/tests/v5_dart_inline.dart';
import 'package:e2e_all_v2/core_tests/tests/v5_openssh_inline.dart';
import 'package:e2e_all_v2/core_tests/tests/v5_openssh_print.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/test_result.dart';
import 'package:e2e_all_v2/utils.dart';

/// Main entry point for running core tests
/// Takes parsed parameters and returns test results
Future<void> coreTests(CoreTestsParams params) async {
  // Parse version strings from params
  final List<NoPortsVersion> clientVersions = params.clientVersions.split(',').map((entry) {
    return NoPortsVersion.fromLanguageVersionString(entry.trim());
  }).toList();
  final List<NoPortsVersion> daemonVersions = params.daemonVersions.split(',').map((entry) {
    return NoPortsVersion.fromLanguageVersionString(entry.trim());
  }).toList();

  // 2. Get testRunId - use provided value or default to git commit hash
  print('');
  final String testRunId = params.testRunId ?? await getShortenedGitCommitHash();
  print('testRunId: $testRunId');

  // 3. create directory structure:
  //  ./e2e_all_v2/$testRunId/
  //    ├── apkamKeys/
  //    ├── logs/
  //    └── binaries/
  //            v5.9.4/
  //            v5.11.2/
  //            v5.13.0/
  //            current/
  final Directory baseDirectory = Directory('${params.baseDirectory}/$testRunId');
  await ensureDirectoryExists(baseDirectory);

  final Directory apkamKeysDirectory = Directory('${baseDirectory.path}/apkamKeys');
  final Directory logsDirectory = Directory('${baseDirectory.path}/logs');
  final Directory binariesDirectory = Directory('${baseDirectory.path}/binaries');
  await ensureDirectoryExists(apkamKeysDirectory);
  await ensureDirectoryExists(logsDirectory);
  await ensureDirectoryExists(binariesDirectory);

  final Directory sshDirectory = Directory(path.join(getHomeDirectory()!, '.ssh'));
  ensureDirectoryExists(sshDirectory);

  // 4. Prepare client binaries list
  final List<(NoPortsVersion, ClientBinaryType)> clientBinariesToDownload = [];
  for(final NoPortsVersion clientVersion in clientVersions) {
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.sshnp));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.npt));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.srv));
  }
  clientBinariesToDownload.add((NoPortsVersion(language: Language.dart, version: 'current'), ClientBinaryType.at_activate));

  // 5. Run setup flows in parallel
  print('\nRunning setup flows in parallel...');
  print('  Flow 1: Fetching ${clientBinariesToDownload.length} client binaries...');
  print('  Flow 2: Building/pulling docker images...');
  print('  Flow 3: Setting up APKAM keys (will start after at_activate binary is available)...');

  // Flow 1: Fetch client binaries
  final Future<List<ClientBinary>> clientBinariesFuture = fetchClientBinaries(
    clientBinariesToDownload: clientBinariesToDownload,
    binariesDirectory: binariesDirectory,
  );

  // Flow 2: Build docker images (independent of binaries and APKAM keys)
  final Future<List<DockerImage>> dockerImagesFuture = _buildDockerImages(
    daemonVersions: daemonVersions,
  );

  // Flow 3: Setup APKAM keys (needs at_activate binary first)
  final Future<Map<String, File>> apkamKeysFuture = clientBinariesFuture.then((clientBinaries) async {
    final ClientBinary atActivateClientBinary = clientBinaries.firstWhere(
      (cb) => cb.binaryType == ClientBinaryType.at_activate && cb.noPortsVersion.version == 'current'
    );
    return setUpApkamKeys(
      atActivateClientBinary: atActivateClientBinary,
      clientAtsign: params.clientAtsign,
      daemonAtsign: params.daemonAtsign,
      rootDomain: params.rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId,
    );
  });

  // Wait for all three flows to complete
  final results = await Future.wait([
    clientBinariesFuture,
    apkamKeysFuture,
    dockerImagesFuture,
  ]);

  final List<ClientBinary> clientBinaries = results[0] as List<ClientBinary>;
  final Map<String, File> apkamKeys = results[1] as Map<String, File>;
  final List<DockerImage> dockerImages = results[2] as List<DockerImage>;

  // Now start docker instances (needs APKAM keys)
  print('\nStarting docker daemon instances...');
  final List<(String, DockerInstance)> dockerInstances = await _startDockerInstances(
    dockerImages: dockerImages,
    clientAtsign: params.clientAtsign,
    daemonAtsign: params.daemonAtsign,
    daemonAtsignContainerKeyFilePath: '/atsign/.atsign/keys/${apkamKeys[params.daemonAtsign]!.path.split('/').last}',
    rootDomain: params.rootDomain,
    testRunId: testRunId,
    apkamKeysDirectory: apkamKeysDirectory,
    logsDirectory: logsDirectory,
  );

  // Print results
  print('\nFetched client binaries (${clientBinaries.length}):');
  for(final ClientBinary clientBinary in clientBinaries) {
    print('    ${clientBinary.binaryType.name} | ${clientBinary.noPortsVersion.language.name} | ${clientBinary.noPortsVersion.version} | ${clientBinary.file.path}');
  }

  print('');
  print('Started ${dockerInstances.length} docker daemon instances');
  for(final (String, DockerInstance) dockerInstance in dockerInstances) {
    print('    Daemon (-d ${dockerInstance.$1}): ${dockerInstance.$2.containerName}');
  }
  print('');

  // 7. generate new ssh key
  final (File, File) sshKeys = await _generateNewSshKey(testRunId: testRunId);
  final File identityFile = sshKeys.$2;
  print('Generated ${sshKeys.$1.path} and ${sshKeys.$2.path}');

  // 8. Run tests
  final List<CoreTestResult> allTestResults = [];

  final CoreTestsContext context = CoreTestsContext(
    testRunId: testRunId,
    clientAtsign: params.clientAtsign,
    daemonAtsign: params.daemonAtsign,
    relayAtsign: params.relayAtsign,
    rootDomain: params.rootDomain,
    remoteUsername: 'atsign',
    identityFilePath: identityFile.path,
    clientBinaries: clientBinaries,
    dockerInstances: dockerInstances,
    apkamKeys: apkamKeys,
    logsDirectory: logsDirectory,
    alwaysOutputLogs: params.alwaysOutputLogs,
  );

  // a. 001_minus_s_flag
  allTestResults.addAll(
    (await run001MinusSFlagTests(
      context: context,
      daemonVersions: daemonVersions,
    )));

  // b. minus_r_flag
  allTestResults.addAll(
    (await runMinusRFlagTests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    )));

  // c. minus_u_flag
  allTestResults.addAll(
    (await runMinusUFlagTests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    )));
  //
  // // d. npt_to_port_22
  // allTestResults.addAll(
  //   (await runNptToPort22Tests(
  //     context: context,
  //     clientVersions: clientVersions,
  //     daemonVersions: daemonVersions,
  //   )));
  //
  // // e. npt_to_port_22_no_encrypt_traffic
  // allTestResults.addAll(
  //   (await runNptToPort22NoEncryptTrafficTests(
  //     context: context,
  //   )));
  //
  // // f. v4_dart_inline
  // allTestResults.addAll(
  //   (await runV4DartInlineTests(
  //     context: context,
  //     clientVersions: clientVersions,
  //     daemonVersions: daemonVersions,
  //   )));
  //
  // // g. v4_openssh_print
  // allTestResults.addAll(
  //   (await runV4OpensshPrintTests(
  //     context: context,
  //     clientVersions: clientVersions,
  //     daemonVersions: daemonVersions,
  //   )));
  //
  // // h. v5_dart_inline
  // allTestResults.addAll(
  //   (await runV5DartInlineTests(
  //     context: context,
  //     clientVersions: clientVersions,
  //     daemonVersions: daemonVersions,
  //   )));
  //
  // // i. v5_openssh_inline
  // allTestResults.addAll(
  //   (await runV5OpensshInlineTests(
  //     context: context,
  //     clientVersions: clientVersions,
  //     daemonVersions: daemonVersions,
  //   )));
  //
  // // j. v5_openssh_print
  // allTestResults.addAll(
  //   (await runV5OpensshPrintTests(
  //     context: context,
  //     clientVersions: clientVersions,
  //     daemonVersions: daemonVersions,
  //   )));

  // 8. Print test results summary
  final int totalTests = allTestResults.length;
  final int passedTests = allTestResults.where((tr) => tr.status == TestStatus.passed).length;
  final int failedTests = allTestResults.where((tr) => tr.status == TestStatus.failed).length;

  print('');
  print('Test Results Summary:');
  print('    Total tests: $totalTests');
  print('    Passed: $passedTests');
  print('    Failed: $failedTests');
  print('');
}

String _getIdentitfyFilePath({required final String testRunId}) {
  final String? homeDirectoryPath = getHomeDirectory(throwIfNull: false);
  if(homeDirectoryPath == null) {
    throw Exception('Unable to determine home directory path for current user.');
  }
  return path.join(homeDirectoryPath, '.ssh', 'e2e_all_v2.${testRunId}');
}

Future<(File, File)> _generateNewSshKey({required final String testRunId}) async {
  final String? homeDirectoryPath = getHomeDirectory(throwIfNull: false);
  if(homeDirectoryPath == null) {
    throw Exception('Unable to determine home directory path for current user.');
  }

  final Directory sshDirectory = Directory(path.join(homeDirectoryPath, '.ssh'));
  if(!(await sshDirectory.exists())) {
    throw Exception('SSH directory does not exist: ${sshDirectory.path}');
  }

  // Change the permissions of the authorized_keys file so that we can add public keys to it
  await runCommand(
    'chmod',
    ['go-rwx', path.join(sshDirectory.path, 'authorized_keys')],
  );

  // ssh-keygen -t ed25519 -q -N '' -f $identityFileName -C $testRunId <<<y >/dev/null 2>&1
  final String identityFilePath = _getIdentitfyFilePath(testRunId: testRunId);
  await runCommand(
    'ssh-keygen',
    [
      '-t', 'ed25519',
      '-q',
      '-N', '',
      '-f', identityFilePath,
      '-C', testRunId,
    ],
  );

  final File identityFile = File(identityFilePath);
  final File publicIdentityFile = File('$identityFilePath.pub');
  if(!(await identityFile.exists()) || !(await publicIdentityFile.exists())) {
    throw Exception('Failed to generate ssh key pair. Expected files not found: $identityFilePath and ${publicIdentityFile.path}');
  }
  return (publicIdentityFile, identityFile);
}

/// Build docker images for all daemon versions (can run in parallel with other setup)
Future<List<DockerImage>> _buildDockerImages({
  required final List<NoPortsVersion> daemonVersions,
}) async {
  final List<DockerImage> dockerImages = [];
  for(final NoPortsVersion daemonVersion in daemonVersions) {
    final Language language = daemonVersion.language;
    final String version = daemonVersion.version;

    DockerImage dockerImage;
    if(version == 'current') {
      dockerImage = DockerImage.current(language: language);
    } else if(version.startsWith('v')) {
      dockerImage = DockerImage.release(language: language, version: version);
    } else {
      dockerImage = DockerImage.branch(language: language, branch: version);
    }
    dockerImages.add(dockerImage);
  }

  // Build/pull all docker images in parallel
  final List<Future<void>> imageFutures = [];

  for (final DockerImage dockerImage in dockerImages) {
    imageFutures.add(_ensureDockerImageExists(dockerImage));
  }

  await Future.wait(imageFutures);

  return dockerImages;
}

/// Ensure a single docker image exists (pull or build if needed)
Future<void> _ensureDockerImageExists(DockerImage dockerImage) async {
  if (dockerImage.tag != 'current' && await dockerImage.existsOnMachine()) {
    print('Docker image found on machine: ${dockerImage.fullImageName}');
    return;
  }

  if (dockerImage.tag != 'current') {
    print('Docker image not found on machine: ${dockerImage.fullImageName}. Attempting docker pull from registry...');
    final pullProcess = await dockerImage.pull(quiet: true);
    final pullExitCode = await pullProcess.exitCode;
    if (pullExitCode == 0) {
      print('Successfully pulled docker image ${dockerImage.fullImageName} from registry');
      return;
    }
    print('Failed to pull docker image ${dockerImage.fullImageName}. Exit code: $pullExitCode');
  }

  print('Building DockerImage ${dockerImage.fullImageName} locally...');
  final buildProcess = await dockerImage.build(quiet: true);
  final buildExitCode = await buildProcess.exitCode;
  if (buildExitCode != 0) {
    throw Exception('Failed to build docker image ${dockerImage.fullImageName}. Exit code: $buildExitCode');
  }
}

/// Start docker instances from already-built images (requires APKAM keys)
Future<List<(String, DockerInstance)>> _startDockerInstances({
  required final List<DockerImage> dockerImages,
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String daemonAtsignContainerKeyFilePath,
  required final String rootDomain,
  required final String testRunId,
  required final Directory apkamKeysDirectory,
  required final Directory logsDirectory,
}) async {
  // create log directory structure
  final Directory daemonsLogsDirectory = Directory(path.join(logsDirectory.path, 'daemons'));
  if (!daemonsLogsDirectory.existsSync()) {
    daemonsLogsDirectory.createSync(recursive: true);
  }

  final List<(String, DockerInstance)> dockerInstances = [];
  for(final DockerImage dockerImage in dockerImages) {
    final DockerInstance dockerInstance1 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
    );
    final String deviceNameNoFlags = getDeviceNameNoFlags(
      testRunId: testRunId,
      noPortsVersion: NoPortsVersion(
        language: dockerInstance1.dockerImage.language,
        version: dockerInstance1.dockerImage.tag),
    );

    final File stdout1 = File('${daemonsLogsDirectory.path}/${dockerInstance1.containerName}_stdout.log');
    final File stderr1 = File('${daemonsLogsDirectory.path}/${dockerInstance1.containerName}_stderr.log');

    await dockerInstance1.run(
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && '
        '/usr/local/bin/sshnpd '
          '-a ${daemonAtsign} '
          '-m ${clientAtsign} '
          '-k ${daemonAtsignContainerKeyFilePath} '
          '--root-domain ${rootDomain} '
          '-d ${deviceNameNoFlags} '
          '-v '
      ],
      quiet: false,
      removeWhenStopped: true,
      volumeMappings: [
        VolumeMapping(
          localDirectory: apkamKeysDirectory,
          containerDirectory: '/atsign/.atsign/keys',
        ),
      ],
      stdoutLogFile: stdout1,
      stderrLogFile: stderr1,
    );
    dockerInstances.add((deviceNameNoFlags, dockerInstance1));

    final DockerInstance dockerInstance2 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
      uniqueIdentifier: '_f',
    );
    final String deviceNameWithFlags = '${deviceNameNoFlags}_f';

    final File stdout2 = File('${daemonsLogsDirectory.path}/${dockerInstance2.containerName}_stdout.log');
    final File stderr2 = File('${daemonsLogsDirectory.path}/${dockerInstance2.containerName}_stderr.log');

    await dockerInstance2.run(
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && '
        '/usr/local/bin/sshnpd '
        '-a ${daemonAtsign} '
        '-m ${clientAtsign} '
        '-k ${daemonAtsignContainerKeyFilePath} '
        '--root-domain ${rootDomain} '
        '-d ${deviceNameWithFlags} '
        '-v -s -u'
      ],
      quiet: false,
      removeWhenStopped: true,
      volumeMappings: [
        VolumeMapping(
          localDirectory: apkamKeysDirectory,
          containerDirectory: '/atsign/.atsign/keys',
        ),
      ],
      stdoutLogFile: stdout2,
      stderrLogFile: stderr2,
    );
    dockerInstances.add((deviceNameWithFlags, dockerInstance2));
  }

  sleep(Duration(seconds: 5));

  // now wait for all monitors to complete by polling log files
  const String monitorMessage = 'monitor started';
  for(final (String deviceName, DockerInstance dockerInstance) in dockerInstances) {
    final File? stdoutLog = dockerInstance.stdoutLogFile;
    final File? stderrLog = dockerInstance.stderrLogFile;
    if (stdoutLog == null || stderrLog == null) {
      throw Exception('[${dockerInstance.containerName}] Log files not set on docker instance');
    }

    final DateTime startTime = DateTime.now();
    const Duration timeout = Duration(seconds: 60);
    bool monitorStarted = false;

    while (!monitorStarted && DateTime.now().difference(startTime) < timeout) {
      // Check if log files exist and contain the monitor started message
      if (stderrLog.existsSync()) {
        final String content = stderrLog.readAsStringSync();
        if (content.toLowerCase().contains(monitorMessage)) {
          print('Daemon ${dockerInstance.dockerImage.language.name} ${dockerInstance.dockerImage.tag} (container: ${dockerInstance.containerName}) Monitor started');
          monitorStarted = true;
          break;
        }
      }
      await Future.delayed(Duration(seconds: 1));
    }

    if (!monitorStarted) {
      print('[${dockerInstance.containerName}] TIMEOUT: Monitor did not start within 60 seconds');
      print('[${dockerInstance.containerName}] Dumping recent stderr logs:');

      if (stderrLog.existsSync()) {
        final String stderrContent = stderrLog.readAsStringSync();
        print(stderrContent);
      } else {
        throw Exception('[${dockerInstance.containerName}] Monitor did not start and stderr log file is missing');
      }

      if (stdoutLog.existsSync()) {
        final String stdoutContent = stdoutLog.readAsStringSync();
        print(stdoutContent);
      } else {
        throw Exception('[$deviceName] Monitor did not start and stdout log file is missing');
      }

      throw TimeoutException('[${dockerInstance.containerName}] Monitor did not start within 60 seconds');
    }
  }

  return dockerInstances;
}
