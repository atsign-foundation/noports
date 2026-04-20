import 'dart:io';
import 'package:e2e_all_v2/core_tests/tests/minus_u_flag.dart';
import 'package:path/path.dart' as path;
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/tests/001_minus_s_flag.dart';
import 'package:e2e_all_v2/core_tests/core_tests_apkam_setup.dart';
import 'package:e2e_all_v2/core_tests/core_tests_client_binary_utils.dart';
import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/core_tests/core_tests_params.dart';
import 'package:e2e_all_v2/core_tests/core_tests_docker_utils.dart';
import 'package:e2e_all_v2/core_tests/tests/minus_r_flag.dart';
import 'package:e2e_all_v2/core_tests/tests/npt_to_port_22.dart';
import 'package:e2e_all_v2/core_tests/tests/npt_to_port_22_no_encrypt_traffic.dart';
import 'package:e2e_all_v2/core_tests/tests/v4_dart_inline.dart';
import 'package:e2e_all_v2/core_tests/tests/v4_openssh_print.dart';
import 'package:e2e_all_v2/core_tests/tests/v5_dart_inline.dart';
import 'package:e2e_all_v2/core_tests/tests/v5_openssh_inline.dart';
import 'package:e2e_all_v2/core_tests/tests/v5_openssh_print.dart';
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
  final String testRunId = params.testRunId ?? await getShortenedGitCommitHash();
  print('\ntestRunId: $testRunId\n');

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
  ensureDirectoryExists(baseDirectory);

  final Directory apkamKeysDirectory = Directory('${baseDirectory.path}/apkamKeys');
  final Directory logsDirectory = Directory('${baseDirectory.path}/logs');
  final Directory binariesDirectory = Directory('${baseDirectory.path}/binaries');
  ensureDirectoryExists(apkamKeysDirectory);
  ensureDirectoryExists(logsDirectory);
  ensureDirectoryExists(binariesDirectory);

  // 4. download client binaries
  final List<(NoPortsVersion, ClientBinaryType)> clientBinariesToDownload = [];
  for(final NoPortsVersion clientVersion in clientVersions) {
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.sshnp));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.npt));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.srv));
  }
  clientBinariesToDownload.add((NoPortsVersion(language: Language.dart, version: 'current'), ClientBinaryType.at_activate));

  print('Fetching ${clientBinariesToDownload.length} client binaries...');
  final List<ClientBinary> clientBinaries = await fetchClientBinaries(
      clientBinariesToDownload: clientBinariesToDownload,
      binariesDirectory: binariesDirectory);

  print('');
  print('Fetched client binaries (${clientBinaries.length}):');
  for(final ClientBinary clientBinary in clientBinaries) {
    print('    ${clientBinary.binaryType.name} | ${clientBinary.noPortsVersion.language.name} | ${clientBinary.noPortsVersion.version} | ${clientBinary.file.path}');
  }
  print('');

  // 5. set up client and daemon apkam keys
  final ClientBinary atActivateClientBinary = clientBinaries.firstWhere((cb) => cb.binaryType == ClientBinaryType.at_activate && cb.noPortsVersion.version == 'current');
  final Map<String, File> apkamKeys = await setUpApkamKeys(
    atActivateClientBinary: atActivateClientBinary,
    clientAtsign: params.clientAtsign,
    daemonAtsign: params.daemonAtsign,
    rootDomain: params.rootDomain,
    apkamKeysDirectory: apkamKeysDirectory,
    testRunId: testRunId
  );

  // 6. set up docker daemons
  final List<(String, DockerInstance)> dockerInstances = await startDockerDaemons(
    clientAtsign: params.clientAtsign,
    daemonVersions: daemonVersions,
    daemonAtsign: params.daemonAtsign,
    daemonAtsignContainerKeyFilePath: '/atsign/.atsign/keys/${apkamKeys[params.daemonAtsign]!.path.split('/').last}',
    rootDomain: params.rootDomain,
    testRunId: testRunId,
    apkamKeysDirectory: apkamKeysDirectory,
    logsDirectory: logsDirectory,
  );
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

  // // b. minus_r_flag
  // allTestResults.addAll(
  //   (await runMinusRFlagTests(
  //     context: context,
  //     clientVersions: clientVersions,
  //     daemonVersions: daemonVersions,
  //   )));
  //
  // // c. minus_u_flag
  // allTestResults.addAll(
  //   (await runMinusUFlagTests(
  //     context: context
  //   )));
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
