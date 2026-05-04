import 'dart:io';
import 'dart:async';
import 'package:npe2e/core_tests/core_tests_docker_utils.dart';
import 'package:npe2e/core_tests/tests/minus_r_flag.dart';
import 'package:npe2e/core_tests/tests/minus_u_flag.dart';
import 'package:npe2e/core_tests/tests/npt_to_port_22.dart';
import 'package:npe2e/core_tests/tests/npt_to_port_22_no_encrypt_traffic.dart';
import 'package:npe2e/print_test_utils.dart';
import 'package:path/path.dart' as path;
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:npe2e/apkam_setup.dart';
import 'package:npe2e/client_binary.dart';
import 'package:npe2e/client_binary_utils.dart';
import 'package:npe2e/core_tests/tests/001_minus_s_flag.dart';
import 'package:npe2e/core_tests/core_tests_context.dart';
import 'package:npe2e/core_tests/core_tests_print_utils.dart';
import 'package:npe2e/core_tests/core_tests_test_result.dart';
import 'package:npe2e/core_tests/core_tests_params.dart';
import 'package:npe2e/core_tests/tests/v4_dart_inline.dart';
import 'package:npe2e/core_tests/tests/v4_openssh_print.dart';
import 'package:npe2e/core_tests/tests/v5_dart_inline.dart';
import 'package:npe2e/core_tests/tests/v5_openssh_inline.dart';
import 'package:npe2e/core_tests/tests/v5_openssh_print.dart';
import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/ssh_key_utils.dart';
import 'package:npe2e/test_result.dart';
import 'package:npe2e/utils.dart';

const String remoteUsername = 'atsign';
const String coreTestsApkamApp = 'npe2e_core';

Future<void> coreTests(CoreTestsParams params) async {
  final Stopwatch overallStopwatch = Stopwatch()..start();

  final List<NoPortsVersion> clientVersions = params.clientVersions
      .split(',')
      .map((entry) {
        return NoPortsVersion.fromLanguageVersionString(entry.trim());
      })
      .toList();
  final List<NoPortsVersion> daemonVersions = params.daemonVersions
      .split(',')
      .map((entry) {
        return NoPortsVersion.fromLanguageVersionString(entry.trim());
      })
      .toList();

  // 2. Get testRunId - use provided value or default to git commit hash
  final String testRunId =
      params.testRunId ?? await getShortenedGitCommitHash();
  print('testRunId: $testRunId\n');

  // 3. create directory structure:
  //  ./npe2e_core/$testRunId/
  //    ├── apkamKeys/
  //    ├── logs/
  //    │   └── daemons/
  //    └── binaries/
  //            v5.9.4/
  //            v5.11.2/
  //            v5.13.0/
  //            current/
  final Directory baseDirectory = Directory(
    '${params.baseDirectory}/$testRunId',
  );
  await ensureDirectoryExists(baseDirectory);

  final Directory apkamKeysDirectory = Directory(
    '${baseDirectory.path}/apkamKeys',
  );
  await ensureDirectoryExists(apkamKeysDirectory);

  final Directory logsDirectory = Directory('${baseDirectory.path}/logs');
  await ensureDirectoryExists(logsDirectory);

  final Directory binariesDirectory = Directory(
    '${baseDirectory.path}/binaries',
  );
  await ensureDirectoryExists(binariesDirectory);

  final Directory sshDirectory = Directory(
    path.join(getHomeDirectory()!, '.ssh'),
  );
  await ensureDirectoryExists(sshDirectory);

  final Directory daemonLogsDirectory = Directory(
    '${logsDirectory.path}/daemons',
  );
  await ensureDirectoryExists(daemonLogsDirectory);

  // 4. Prepare client binaries list based on clientVersions to test against
  final List<(NoPortsVersion, ClientBinaryType)> clientBinariesToDownload = [];
  for (final NoPortsVersion clientVersion in clientVersions) {
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.sshnp));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.npt));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.srv));
  }
  clientBinariesToDownload.add((
    NoPortsVersion(language: Language.dart, version: 'current'),
    ClientBinaryType.at_activate,
  ));

  // 5. Run setup flows in parallel
  final Stopwatch setUpStopwatch = Stopwatch()..start();
  print('Running setup flows in asynchronously...');
  print('\tFlow 1: Fetch client binarines --> APKAM set up');
  print('\tFlow 2: Try pull Docker images, and Build Docker images');
  print('\tFlow 3: Start docker instances (depends on Flow 1 & 2)');
  print('');

  // Flow 1:
  // Flow 1.1: Fetch client binaries in parallel (sorted by language and version to optimize caching)
  final Future<List<ClientBinary>> clientBinariesFuture =
      fetchClientBinariesParallel(
        clientBinariesToDownload: clientBinariesToDownload,
        binariesDirectory: binariesDirectory,
      );

  // Flow 1.2: Once we have the client binaries, set up APKAM keys (which depends on at_activate binary)
  final Future<Map<String, File>> apkamKeysFuture = Future.microtask(() async {
    final List<ClientBinary> clientBinaries = await clientBinariesFuture;
    final ClientBinary atActivateClientBinary = clientBinaries.firstWhere(
      (cb) =>
          cb.binaryType == ClientBinaryType.at_activate &&
          cb.noPortsVersion.version == 'current',
    );
    return setUpApkamKeysParallel(
      atActivateClientBinary: atActivateClientBinary,
      atsigns: [
        (which: 'client', atsign: params.clientAtsign),
        (which: 'daemon', atsign: params.daemonAtsign),
      ],
      rootDomain: params.rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId,
      apkamApp: coreTestsApkamApp,
    );
  });

  final Future<List<DockerImage>> dockerImagesFuture =
      ensureDockerDaemonsBuiltParallel(
        daemonVersions: daemonVersions,
        skipBuildCurrent: false,
      );

  final List<dynamic> results = await Future.wait([
    clientBinariesFuture,
    apkamKeysFuture,
    dockerImagesFuture,
  ]);
  final List<ClientBinary> clientBinaries = results[0] as List<ClientBinary>;
  final Map<String, File> apkamKeys = results[1] as Map<String, File>;
  final List<DockerImage> dockerImages = results[2] as List<DockerImage>;

  print('');
  print('Done flow 1 and 2');
  print('');

  print('Fetched client binaries (${clientBinaries.length}):');
  for (final ClientBinary clientBinary in clientBinaries) {
    print(
      '    ${clientBinary.binaryType.name} | ${clientBinary.noPortsVersion.language.name} | ${clientBinary.noPortsVersion.version} | ${clientBinary.file.path}',
    );
  }
  print('');

  print('APKAM keys ready:');
  for (final String atsign in apkamKeys.keys) {
    print('    $atsign: ${apkamKeys[atsign]!.path}');
  }
  print('');

  print('Docker images ready (${dockerImages.length}):');
  for (final DockerImage dockerImage in dockerImages) {
    print('    ${dockerImage.fullImageName}');
  }
  print('');

  // Flow 3: Start Docker daemon instances
  print('Starting docker daemon instances...');
  final List<(String, DockerInstance)> dockerInstances =
      await startDockerDaemonsParallel(
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
  for (final (String, DockerInstance) dockerInstance in dockerInstances) {
    print(
      '    Daemon (-d ${dockerInstance.$1}): ${dockerInstance.$2.containerName}',
    );
  }
  print('');

  // 7. generate new ssh key
  final (File, File) sshKeys = await generateNewSshKey(testRunId: testRunId);
  final File identityFile = sshKeys.$2;
  print('Generated ${sshKeys.$1.path} and ${sshKeys.$2.path}');

  setUpStopwatch.stop();
  print('Set up completed in ${formatDuration(setUpStopwatch.elapsed)}');

  // // 8. Run tests
  final Stopwatch testExecutionStopwatch = Stopwatch()..start();
  final List<CoreTestResult> allTestResults = [];
  final CoreTestsContext context = CoreTestsContext(
    testRunId: testRunId,
    clientAtsign: params.clientAtsign,
    daemonAtsign: params.daemonAtsign,
    relayAtsign: params.relayAtsign,
    rootDomain: params.rootDomain,
    remoteUsername: remoteUsername,
    identityFilePath: identityFile.path,
    clientBinaries: clientBinaries,
    dockerInstances: dockerInstances,
    apkamKeys: apkamKeys,
    logsDirectory: logsDirectory,
  );

  // Part 1: Do all 001_minus_s_flag tests first, since they bootstrap the daemons.
  final List<Future<CoreTestResult> Function()> minusSFlagFactories =
      run001MinusSFlagTests(context: context, daemonVersions: daemonVersions);
  final List<CoreTestResult> minusSFlagResults =
      await _runFuturesWithConcurrency(
        minusSFlagFactories,
        batchSize: params.batchSize,
      );
  allTestResults.addAll(minusSFlagResults);

  // Check if any of the minus_s_flag tests failed. If so, we should not proceed with the other tests since they depend on the daemons being properly set up and running.
  final List<CoreTestResult> failedMinusSFlagResults = minusSFlagResults
      .where((tr) => tr.status == TestStatus.failed)
      .toList();
  if (failedMinusSFlagResults.isNotEmpty) {
    print('');
    print(
      'One or more 001_minus_s_flag tests failed. Since these tests are critical for verifying that the daemons are properly set up and running, we will not proceed with the other tests. Please investigate the failed 001_minus_s_flag tests and fix the underlying issues before re-running the tests.',
    );
    print('Failed 001_minus_s_flag tests:');
    for (final CoreTestResult testResult in failedMinusSFlagResults) {
      final String extra = generateExtraString(
        testResult.clientVersion,
        testResult.daemonVersion,
        useShortLanguageName: true,
      );
      print(
        '    ${testResult.testName} $extra - Exit code: ${testResult.exitCode}',
      );
    }
    return;
  }

  // Part 2: do all other tests
  final List<Future<CoreTestResult> Function()> remainingTestFactories = [];

  remainingTestFactories.addAll(
    runMinusRFlagTests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    ),
  );

  remainingTestFactories.addAll(
    runMinusUFlagTests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    ),
  );

  remainingTestFactories.addAll(
    runNptToPort22Tests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    ),
  );

  remainingTestFactories.addAll(
    runNptToPort22NoEncryptTrafficTests(context: context),
  );

  remainingTestFactories.addAll(
    getV4DartInLineFactories(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    ),
  );

  remainingTestFactories.addAll(
    runV4OpensshPrintTests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    ),
  );

  remainingTestFactories.addAll(
    runV5DartInlineTests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    ),
  );

  remainingTestFactories.addAll(
    runV5OpensshInlineTests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    ),
  );

  remainingTestFactories.addAll(
    runV5OpensshPrintTests(
      context: context,
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    ),
  );

  final List<CoreTestResult> remainingResults =
      await _runFuturesWithConcurrency(
        remainingTestFactories,
        batchSize: params.batchSize,
      );
  allTestResults.addAll(remainingResults);
  testExecutionStopwatch.stop();

  // 8. Print test results summary
  print('');
  print('\tResults:');
  for (final CoreTestResult testResult in allTestResults) {
    printTestResult(
      testResult: testResult,
      extra: generateExtraString(
        testResult.clientVersion,
        testResult.daemonVersion,
        useShortLanguageName: true,
      ),
    );
  }
  print('');

  final int totalTests = allTestResults.length;
  final int passedTests = allTestResults
      .where((tr) => tr.status == TestStatus.passed)
      .length;
  final int failedTests = allTestResults
      .where((tr) => tr.status == TestStatus.failed)
      .length;

  print('');
  print('Test Results Summary:');
  print('    Total tests: $totalTests');
  print('    Passed: $passedTests');
  print('    Failed: $failedTests');
  print('');

  if (failedTests > 0) {
    print('Failed Tests:');
    for (final CoreTestResult testResult in allTestResults.where(
      (tr) => tr.status == TestStatus.failed,
    )) {
      final String extra = generateExtraString(
        testResult.clientVersion,
        testResult.daemonVersion,
        useShortLanguageName: true,
      );
      print(
        '    ${testResult.testName} $extra - Exit code: ${testResult.exitCode}',
      );
    }
  }

  overallStopwatch.stop();
  print('');
  print('Execution Time Summary:');
  print('    Setup time: ${formatDuration(setUpStopwatch.elapsed)}');
  print(
    '    Test execution time: ${formatDuration(testExecutionStopwatch.elapsed)}',
  );
  print('    Overall time: ${formatDuration(overallStopwatch.elapsed)}');
}

/// Runs a list of test factory functions with controlled concurrency
///
/// This function maintains a pool of at most [batchSize] running tests at any time.
/// As tests complete, new tests are started (with a 1-second delay between starts)
/// to keep the pool at capacity until all tests are complete.
///
/// [testFactories] - List of functions that create test futures when called
/// [batchSize] - Maximum number of tests to run in parallel at once
///
/// Returns a list of CoreTestResult from all test executions
Future<List<CoreTestResult>> _runFuturesWithConcurrency(
  List<Future<CoreTestResult> Function()> testFactories, {
  required int batchSize,
}) async {
  if (testFactories.isEmpty) {
    return [];
  }

  final List<CoreTestResult> allResults = [];
  final List<(Future<CoreTestResult>, int)> active = [];
  int nextIndex = 0;
  int completedCount = 0;

  Future<void> startNextTest() async {
    if (nextIndex < testFactories.length) {
      if (nextIndex > 0) {
        await Future.delayed(Duration(seconds: 1));
      }

      final testIndex = nextIndex;
      final Future<CoreTestResult> testFuture = testFactories[nextIndex]();
      active.add((testFuture, testIndex));
      nextIndex++;
    }
  }

  for (int i = 0; i < batchSize && i < testFactories.length; i++) {
    await startNextTest();
  }

  while (active.isNotEmpty) {
    final completedEntry = await Future.any(
      active.map((entry) async {
        final result = await entry.$1;
        return (entry, result);
      }),
    );

    final ((Future<CoreTestResult>, int) entry, CoreTestResult testResult) =
        completedEntry;

    active.remove(entry);
    allResults.add(testResult);
    completedCount++;

    final String status = testResult.status == TestStatus.passed ? '✓' : '✗';
    final String extra = generateExtraString(
      testResult.clientVersion,
      testResult.daemonVersion,
      useShortLanguageName: true,
    );
    print(
      '$status ($completedCount/${testFactories.length}) ${testResult.testName} $extra',
    );

    await startNextTest();
  }

  return allResults;
}
