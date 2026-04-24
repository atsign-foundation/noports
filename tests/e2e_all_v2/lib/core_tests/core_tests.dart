import 'dart:io';
import 'dart:async';
import 'package:e2e_all_v2/core_tests/core_tests_docker_utils.dart';
import 'package:e2e_all_v2/print_test_utils.dart';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/core_tests/tests/minus_u_flag.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/tests/001_minus_s_flag.dart';
import 'package:e2e_all_v2/core_tests/core_tests_apkam_setup.dart';
import 'package:e2e_all_v2/core_tests/core_tests_client_binary_utils.dart';
import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
import 'package:e2e_all_v2/core_tests/core_tests_print_utils.dart';
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

const String remoteUsername = 'atsign';

Future<void> coreTests(CoreTestsParams params) async {
  final Stopwatch overallStopwatch = Stopwatch()..start();

  final List<NoPortsVersion> clientVersions = params.clientVersions.split(',').map((entry) {
    return NoPortsVersion.fromLanguageVersionString(entry.trim());
  }).toList();
  final List<NoPortsVersion> daemonVersions = params.daemonVersions.split(',').map((entry) {
    return NoPortsVersion.fromLanguageVersionString(entry.trim());
  }).toList();

  // 2. Get testRunId - use provided value or default to git commit hash
  final String testRunId = params.testRunId ?? await getShortenedGitCommitHash();
  print('testRunId: $testRunId\n');

  // 3. create directory structure:
  //  ./e2e_all_v2/$testRunId/
  //    ├── apkamKeys/
  //    ├── logs/
  //    │   └── daemons/
  //    └── binaries/
  //            v5.9.4/
  //            v5.11.2/
  //            v5.13.0/
  //            current/
  final Directory baseDirectory = Directory('${params.baseDirectory}/$testRunId');
  await ensureDirectoryExists(baseDirectory);

  final Directory apkamKeysDirectory = Directory('${baseDirectory.path}/apkamKeys');
  await ensureDirectoryExists(apkamKeysDirectory);

  final Directory logsDirectory = Directory('${baseDirectory.path}/logs');
  await ensureDirectoryExists(logsDirectory);

  final Directory binariesDirectory = Directory('${baseDirectory.path}/binaries');
  await ensureDirectoryExists(binariesDirectory);

  final Directory sshDirectory = Directory(path.join(getHomeDirectory()!, '.ssh'));
  await ensureDirectoryExists(sshDirectory);

  final Directory daemonLogsDirectory = Directory('${logsDirectory.path}/daemons');
  await ensureDirectoryExists(daemonLogsDirectory);

  // 4. Prepare client binaries list based on clientVersions to test against
  final List<(NoPortsVersion, ClientBinaryType)> clientBinariesToDownload = [];
  for(final NoPortsVersion clientVersion in clientVersions) {
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.sshnp));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.npt));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.srv));
  }
  clientBinariesToDownload.add((NoPortsVersion(language: Language.dart, version: 'current'), ClientBinaryType.at_activate));

  // 5. Run setup flows in parallel
  final Stopwatch setUpStopwatch = Stopwatch()..start();
  print('Running setup flows in asynchronously...');
  print('\tFlow 1: Fetch client binarines --> APKAM set up');
  print('\tFlow 2: Try pull Docker images, and Build Docker images');
  print('\tFlow 3: Start docker instances (depends on Flow 1 & 2)');
  print('');

  // Flow 1:
  // Flow 1.1: Fetch client binaries in parallel (sorted by language and version to optimize caching)
  final Future<List<ClientBinary>> clientBinariesFuture = fetchClientBinariesParallel(
    clientBinariesToDownload: clientBinariesToDownload,
    binariesDirectory: binariesDirectory,
  );
  
  // Flow 1.2: Once we have the client binaries, set up APKAM keys (which depends on at_activate binary)
  final Future<Map<String, File>> apkamKeysFuture = Future.microtask(() async {
    final List<ClientBinary> clientBinaries = await clientBinariesFuture;
    final ClientBinary atActivateClientBinary = clientBinaries.firstWhere(
      (cb) => cb.binaryType == ClientBinaryType.at_activate
        && cb.noPortsVersion.version == 'current'
    );
    return setUpApkamKeysParallel(
      atActivateClientBinary: atActivateClientBinary,
      clientAtsign: params.clientAtsign,
      daemonAtsign: params.daemonAtsign,
      rootDomain: params.rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId,
    );
  });

  final Future<List<DockerImage>> dockerImagesFuture = ensureDockerDaemonsBuiltParallel(
    daemonVersions: daemonVersions,
    skipBuildCurrent: false,
  );

  final List<dynamic> results = await Future.wait([clientBinariesFuture, apkamKeysFuture, dockerImagesFuture]);
  final List<ClientBinary> clientBinaries = results[0] as List<ClientBinary>;
  final Map<String, File> apkamKeys = results[1] as Map<String, File>;
  final List<DockerImage> dockerImages = results[2] as List<DockerImage>;

  print('');
  print('Done flow 1 and 2');
  print('');

  print('Fetched client binaries (${clientBinaries.length}):');
  for(final ClientBinary clientBinary in clientBinaries) {
    print('    ${clientBinary.binaryType.name} | ${clientBinary.noPortsVersion.language.name} | ${clientBinary.noPortsVersion.version} | ${clientBinary.file.path}');
  }
  print('');

  print('APKAM keys ready:');
  for(final String atsign in apkamKeys.keys) {
    print('    $atsign: ${apkamKeys[atsign]!.path}');
  }
  print('');

  print('Docker images ready (${dockerImages.length}):');
  for(final DockerImage dockerImage in dockerImages) {
    print('    ${dockerImage.fullImageName}');
  }
  print('');

  // Flow 3: Start Docker daemon instances
  print('Starting docker daemon instances...');
  final List<(String, DockerInstance)> dockerInstances = await startDockerDaemonsParallel(
    allDockerImages: dockerImages,
    daemonVersions: daemonVersions,
    clientAtsign: params.clientAtsign,
    daemonAtsign: params.daemonAtsign,
    rootDomain: params.rootDomain,
    testRunId: testRunId,
    daemonLogsDirectory: daemonLogsDirectory,
    daemonApkamKeysFile: apkamKeys[params.daemonAtsign]!,
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

  setUpStopwatch.stop();
  print('Set up completed in ${setUpStopwatch.elapsed.inMinutes}m ${setUpStopwatch.elapsed.inSeconds % 60}s');

  // // 8. Run tests
  // final Stopwatch testExecutionStopwatch = Stopwatch()..start();
  // final List<CoreTestResult> allTestResults = [];
  //
  // final CoreTestsContext context = CoreTestsContext(
  //   testRunId: testRunId,
  //   clientAtsign: params.clientAtsign,
  //   daemonAtsign: params.daemonAtsign,
  //   relayAtsign: params.relayAtsign,
  //   rootDomain: params.rootDomain,
  //   remoteUsername: remoteUsername,
  //   identityFilePath: identityFile.path,
  //   clientBinaries: clientBinaries,
  //   dockerInstances: dockerInstances,
  //   apkamKeys: apkamKeys,
  //   logsDirectory: logsDirectory,
  //   alwaysOutputLogs: params.alwaysOutputLogs,
  // );
  //
  // // Phase 1: Run 001_minus_s_flag tests (with max 6 concurrent at a time to set up public keys)
  // final List<Future<CoreTestResult> Function()> minusSFlagTestFunctions = run001MinusSFlagTests(
  //   context: context,
  //   daemonVersions: daemonVersions,
  // );
  //
  // final List<CoreTestResult> minusSFlagResults = await _runTestsWithConcurrencyLimit(
  //   minusSFlagTestFunctions,
  //   maxConcurrency: 6,
  // );
  // allTestResults.addAll(minusSFlagResults);
  //
  // // Phase 2: Collect all other test functions
  // final List<Future<CoreTestResult> Function()> otherTestFunctions = [];
  //
  // // b. minus_r_flag
  // otherTestFunctions.addAll(runMinusRFlagTests(
  //   context: context,
  //   clientVersions: clientVersions,
  //   daemonVersions: daemonVersions,
  // ));
  //
  // // c. minus_u_flag
  // otherTestFunctions.addAll(runMinusUFlagTests(
  //   context: context,
  //   clientVersions: clientVersions,
  //   daemonVersions: daemonVersions,
  // ));
  //
  // // d. npt_to_port_22
  // otherTestFunctions.addAll(runNptToPort22Tests(
  //   context: context,
  //   clientVersions: clientVersions,
  //   daemonVersions: daemonVersions,
  // ));
  //
  // // e. npt_to_port_22_no_encrypt_traffic
  // otherTestFunctions.addAll(runNptToPort22NoEncryptTrafficTests(
  //   context: context,
  // ));
  //
  // // // f. v4_dart_inline
  // // otherTestFunctions.addAll(runV4DartInlineTests(
  // //   context: context,
  // //   clientVersions: clientVersions,
  // //   daemonVersions: daemonVersions,
  // // ));
  // //
  // // // g. v4_openssh_print
  // // otherTestFunctions.addAll(runV4OpensshPrintTests(
  // //   context: context,
  // //   clientVersions: clientVersions,
  // //   daemonVersions: daemonVersions,
  // // ));
  // //
  // // // h. v5_dart_inline
  // // otherTestFunctions.addAll(runV5DartInlineTests(
  // //   context: context,
  // //   clientVersions: clientVersions,
  // //   daemonVersions: daemonVersions,
  // // ));
  // //
  // // // i. v5_openssh_inline
  // // otherTestFunctions.addAll(runV5OpensshInlineTests(
  // //   context: context,
  // //   clientVersions: clientVersions,
  // //   daemonVersions: daemonVersions,
  // // ));
  // //
  // // // j. v5_openssh_print
  // // otherTestFunctions.addAll(runV5OpensshPrintTests(
  // //   context: context,
  // //   clientVersions: clientVersions,
  // //   daemonVersions: daemonVersions,
  // // ));
  //
  // // Run Phase 2 tests with max 6 concurrent at a time
  // final List<CoreTestResult> otherTestResults = await _runTestsWithConcurrencyLimit(
  //   otherTestFunctions,
  //   maxConcurrency: 6,
  // );
  // allTestResults.addAll(otherTestResults);
  //
  // testExecutionStopwatch.stop();
  //
  // // 8. Print test results summary
  //
  // print('');
  // print('\tResults:');
  // for(final CoreTestResult testResult in allTestResults) {
  //   printTestResult(testResult: testResult, extra: generateExtraString(testResult.clientVersion, testResult.daemonVersion, useShortLanguageName: true));
  // }
  // print('');
  //
  // final int totalTests = allTestResults.length;
  // final int passedTests = allTestResults.where((tr) => tr.status == TestStatus.passed).length;
  // final int failedTests = allTestResults.where((tr) => tr.status == TestStatus.failed).length;
  //
  // print('');
  // print('Test Results Summary:');
  // print('    Total tests: $totalTests');
  // print('    Passed: $passedTests');
  // print('    Failed: $failedTests');
  // print('');
  //
  // if(failedTests > 0) {
  //   print('Failed Tests:');
  //   for(final CoreTestResult testResult in allTestResults.where((tr) => tr.status == TestStatus.failed)) {
  //     final String extra = generateExtraString(testResult.clientVersion, testResult.daemonVersion, useShortLanguageName: true);
  //     print('    ${testResult.testName} $extra - Exit code: ${testResult.exitCode}');
  //   }
  // }
  //
  // overallStopwatch.stop();
  // print('');
  // print('Execution Time Summary:');
  // print('    Setup time: ${setupStopwatch.elapsed.inSeconds}s');
  // print('    Test execution time: ${testExecutionStopwatch.elapsed.inSeconds}s');
  // print('    Overall time: ${overallStopwatch.elapsed.inSeconds}s');
}

Future<List<CoreTestResult>> _runTestsWithConcurrencyLimit(
  List<Future<CoreTestResult> Function()> testFunctions, {
  int maxConcurrency = 6,
}) async {
  final List<CoreTestResult> results = [];
  final List<Future<CoreTestResult>> running = [];
  int nextTestIndex = 0;

  while (nextTestIndex < testFunctions.length || running.isNotEmpty) {
    while (running.length < maxConcurrency && nextTestIndex < testFunctions.length) {
      final testFunction = testFunctions[nextTestIndex];
      running.add(_runTestWithRetries(testFunction));
      nextTestIndex++;

      if (running.length < maxConcurrency && nextTestIndex < testFunctions.length) {
        await Future.delayed(Duration(seconds: 2));
      }
    }

    if (running.isNotEmpty) {
      final completedResult = await Future.any(running.map((future) async {
        final result = await future;
        return (future, result);
      }));

      running.remove(completedResult.$1);
      results.add(completedResult.$2);

      if (nextTestIndex < testFunctions.length) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }

  return results;
}

Future<CoreTestResult> _runTestWithRetries(
  Future<CoreTestResult> Function() testFunction, {
  int maxAttempts = 3,
}) async {
  CoreTestResult? lastResult;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    lastResult = await testFunction();

    if (lastResult.status == TestStatus.passed) {
      return lastResult;
    }

    if (attempt < maxAttempts) {
      final String extra = generateExtraString(lastResult.clientVersion, lastResult.daemonVersion, useShortLanguageName: true);
      print('Test ${lastResult.testName} $extra failed (attempt $attempt/$maxAttempts), retrying...');
    }
  }

  return lastResult!;
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
