import 'dart:async';
import 'dart:io';

import 'package:npe2e/apkam_setup.dart';
import 'package:npe2e/client_binary.dart';
import 'package:npe2e/client_binary_utils.dart';
import 'package:npe2e/docker_image.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/policy_tests/policy_tests_print_utils.dart';
import 'package:npe2e/policy_tests/policy_tests_context.dart';
import 'package:npe2e/policy_tests/policy_tests_docker_utils.dart';
import 'package:npe2e/policy_tests/policy_tests_params.dart';
import 'package:npe2e/policy_tests/policy_tests_test_result.dart';
import 'package:npe2e/policy_tests/tests/npp_atserver_test.dart';
import 'package:npe2e/policy_tests/tests/npp_test.dart';
import 'package:npe2e/print_test_utils.dart';
import 'package:npe2e/test_result.dart';
import 'package:npe2e/utils.dart';

const String policyTestsApkamApp = 'npe2e_policy';

Future<void> policyTests(PolicyTestsParams params) async {
  final Stopwatch overallStopwatch = Stopwatch()..start();

  // 1. Parse versions
  final List<NoPortsVersion> clientVersions = _parseVersions(
    params.clientVersions,
  );
  final List<NoPortsVersion> daemonVersions = _parseVersions(
    params.daemonVersions,
  );
  final List<NoPortsVersion> nppAtServerVersions = _parseVersions(
    params.nppAtServerVersions,
  );
  final List<NoPortsVersion> nppVersions = _parseVersions(params.nppVersions);

  // 2. Get testRunId
  final String testRunId =
      params.testRunId ?? await getShortenedGitCommitHash();
  print('testRunId: $testRunId\n');

  // 3. Set up directories
  final Directory baseDirectory = Directory(
    '${params.baseDirectory}/$testRunId',
  );
  await ensureDirectoryExists(baseDirectory);

  final Directory apkamKeysDirectory = Directory(
    '${baseDirectory.path}/apkamKeys',
  );
  final Directory binariesDirectory = Directory(
    '${baseDirectory.path}/binaries',
  );
  final Directory logsDirectory = Directory('${baseDirectory.path}/logs');
  await ensureDirectoryExists(apkamKeysDirectory);
  await ensureDirectoryExists(binariesDirectory);
  await ensureDirectoryExists(logsDirectory);

  final Directory daemonLogsDirectory = Directory(
    '${logsDirectory.path}/daemons',
  );
  final Directory nppLogsDirectory = Directory('${logsDirectory.path}/npp');
  final Directory nppAtServerLogsDirectory = Directory(
    '${logsDirectory.path}/npp_atserver',
  );
  await ensureDirectoryExists(daemonLogsDirectory);
  await ensureDirectoryExists(nppLogsDirectory);
  await ensureDirectoryExists(nppAtServerLogsDirectory);

  // 4. Set up Flow 1
  // Set up `clientBinariesToDownload` List of tuples e.g. (d:current, sshnp),...
  final List<(NoPortsVersion, ClientBinaryType)> clientBinariesToDownload = [];
  for (final NoPortsVersion clientVersion in clientVersions) {
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.sshnp));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.npt));
    clientBinariesToDownload.add((clientVersion, ClientBinaryType.srv));
  }
  // Add d:current at_activate so we can apkam with that
  clientBinariesToDownload.add((
    NoPortsVersion(language: Language.dart, version: 'current'),
    ClientBinaryType.at_activate,
  ));

  final Stopwatch setUpStopwatch = Stopwatch()..start();
  print('Running policy setup flows asynchronously...');
  print('\tFlow 1: Fetch client binaries --> APKAM setup');
  print('\tFlow 2: Pull/build daemon, NPP, and NPP atServer Docker images');
  print('');

  // Flow 1:
  final Future<List<ClientBinary>> clientBinariesFuture =
      fetchClientBinariesParallel(
        clientBinariesToDownload: clientBinariesToDownload,
        binariesDirectory: binariesDirectory,
      );

  final Future<Map<String, File>> apkamKeysFuture = Future.microtask(() async {
    final List<ClientBinary> clientBinaries = await clientBinariesFuture;
    final ClientBinary atActivateClientBinary = clientBinaries.firstWhere(
      (cb) =>
          cb.binaryType == ClientBinaryType.at_activate &&
          cb.noPortsVersion.version == 'current',
    );
    // Set up 4 Atsigns:
    // 1. clientAtsign: for the client binary to use in tests
    // 2. daemonAtsign: for the daemon to use in tests
    // 3. nppAtsign: for the NPP to use in tests
    // 4. nppAtServerAtsign: for the NPP atServer
    return setUpApkamKeysParallel(
      atActivateClientBinary: atActivateClientBinary,
      atsigns: [
        (which: 'client', atsign: params.clientAtsign),
        (which: 'daemon', atsign: params.daemonAtsign),
        (which: 'npp', atsign: params.nppAtsign),
        (which: 'npp_atserver', atsign: params.nppAtServerAtsign),
      ],
      rootDomain: params.rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId,
      apkamApp: policyTestsApkamApp,
    );
  });

  // 5. Set up Flow 2
  final Future<List<DockerImage>> dockerImagesFuture =
      ensureDockerImagesVersionBuiltParallel(
        versions: [...daemonVersions, ...nppVersions, ...nppAtServerVersions],
      );

  // 6. Run Flow 1 and Flow 2 in parallel
  final List<dynamic> setupResults = await Future.wait([
    clientBinariesFuture,
    apkamKeysFuture,
    dockerImagesFuture,
  ]);
  final List<ClientBinary> clientBinaries =
      setupResults[0] as List<ClientBinary>;
  final Map<String, File> apkamKeys = setupResults[1] as Map<String, File>;
  final List<DockerImage> allDockerImages =
      setupResults[2] as List<DockerImage>;

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

  print('Docker images ready (${allDockerImages.length}):');
  for (final DockerImage dockerImage in allDockerImages) {
    print('    ${dockerImage.fullImageName}');
  }
  print('');

  // 7. Prepare context object to pass to tests
  final PolicyTestsContext context = PolicyTestsContext(
    testRunId: testRunId,
    baseDirectory: baseDirectory,
    logsDirectory: logsDirectory,
    daemonLogsDirectory: daemonLogsDirectory,
    nppLogsDirectory: nppLogsDirectory,
    nppAtServerLogsDirectory: nppAtServerLogsDirectory,
    apkamKeys: apkamKeys,
    clientBinaries: clientBinaries,
    dockerImages: allDockerImages,
    clientAtsign: params.clientAtsign,
    daemonAtsign: params.daemonAtsign,
    relayAtsign: params.relayAtsign,
    nppAtsign: params.nppAtsign,
    nppAtServerAtsign: params.nppAtServerAtsign,
    rootDomain: params.rootDomain,
  );
  setUpStopwatch.stop();

  // 8. Run the tests
  final List<List<Future<PolicyTestResult> Function()>> nppTestFactoryBatches =
      getNppTestFactoryBatchesByPolicyVersion(
        context: context,
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
        nppVersions: nppVersions,
      );
  final List<Future<PolicyTestResult> Function()> nppAtServerTestFactories =
      getNppAtServerTestFactories(
        context: context,
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
        nppAtServerVersions: nppAtServerVersions,
      );
  final Stopwatch testExecutionStopwatch = Stopwatch()..start();
  final Duration testTimeout = Duration(seconds: params.testTimeoutSeconds);
  final Future<List<PolicyTestResult>> nppResultsFuture =
      _runFactoryBatchesWithConcurrency(
        nppTestFactoryBatches,
        batchSize: params.batchSize,
        maxRetries: params.maxRetries,
        testTimeout: testTimeout,
      );
  final Future<List<PolicyTestResult>> nppAtServerResultsFuture =
      _runFuturesWithConcurrency(
        nppAtServerTestFactories,
        batchSize: params.batchSize,
        maxRetries: params.maxRetries,
        testTimeout: testTimeout,
      );
  final List<List<PolicyTestResult>> parallelResults = await Future.wait([
    nppResultsFuture,
    nppAtServerResultsFuture,
  ]);
  final List<PolicyTestResult> testResults = [
    ...parallelResults[0],
    ...parallelResults[1],
  ];
  testExecutionStopwatch.stop();

  print('Results:');
  for (final PolicyTestResult testResult in testResults) {
    printTestResult(
      testResult: testResult,
      extra: generatePolicyExtraString(
        testResult.clientVersion,
        testResult.daemonVersion,
        testResult.policyVersion,
        useShortLanguageName: true,
      ),
    );
  }
  print('');

  final int totalTests = testResults.length;
  final int passedTests = testResults
      .where((tr) => tr.status == TestStatus.passed)
      .length;
  final int failedCount = testResults
      .where((result) => result.status == TestStatus.failed)
      .length;

  overallStopwatch.stop();
  print('Test Results Summary:');
  print('    Total tests: $totalTests');
  print('    Passed: $passedTests');
  print('    Failed: $failedCount');
  print('');

  if (failedCount > 0) {
    print('Failed Tests:');
    for (final PolicyTestResult testResult in testResults.where(
      (tr) => tr.status == TestStatus.failed,
    )) {
      final String extra = generatePolicyExtraString(
        testResult.clientVersion,
        testResult.daemonVersion,
        testResult.policyVersion,
        useShortLanguageName: true,
      );
      print(
        '    ${testResult.testName} $extra - Exit code: ${testResult.exitCode}',
      );
    }
  }

  print('');
  print('Execution Time Summary:');
  print('    Setup time: ${formatDuration(setUpStopwatch.elapsed)}');
  print(
    '    Test execution time: ${formatDuration(testExecutionStopwatch.elapsed)}',
  );
  print('    Overall time: ${formatDuration(overallStopwatch.elapsed)}');

  if (failedCount > 0) {
    throw Exception('$failedCount policy test(s) failed');
  }
}

List<NoPortsVersion> _parseVersions(final String versions) {
  return versions
      .split(',')
      .map((entry) => NoPortsVersion.fromLanguageVersionString(entry.trim()))
      .toList();
}

Future<List<PolicyTestResult>> _runFuturesWithConcurrency(
  List<Future<PolicyTestResult> Function()> testFactories, {
  required int batchSize,
  required int maxRetries,
  required Duration testTimeout,
}) async {
  if (testFactories.isEmpty) {
    return [];
  }

  final List<PolicyTestResult> allResults = [];
  final List<(Future<PolicyTestResult>, int)> active = [];
  int nextIndex = 0;
  int completedCount = 0;

  Future<PolicyTestResult> runWithRetry(
    Future<PolicyTestResult> Function() factory,
    int attempt,
  ) async {
    PolicyTestResult result;
    try {
      result = await factory().timeout(testTimeout);
    } on TimeoutException {
      if (attempt < maxRetries) {
        print(
          '  ↺ Test timed out after ${testTimeout.inSeconds}s (attempt ${attempt + 1}/$maxRetries), retrying...',
        );
        return runWithRetry(factory, attempt + 1);
      }
      rethrow;
    }
    if (result.status == TestStatus.failed && attempt < maxRetries) {
      print(
        '  ↺ Test failed (attempt ${attempt + 1}/$maxRetries), retrying...',
      );
      return runWithRetry(factory, attempt + 1);
    }
    return result;
  }

  Future<void> startNextTest() async {
    if (nextIndex < testFactories.length) {
      if (nextIndex > 0) {
        await Future.delayed(Duration(seconds: 1));
      }

      final int testIndex = nextIndex;
      final Future<PolicyTestResult> Function() factory =
          testFactories[nextIndex];
      final Future<PolicyTestResult> testFuture = runWithRetry(factory, 0);
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
        final PolicyTestResult result = await entry.$1;
        return (entry, result);
      }),
    );

    final ((Future<PolicyTestResult>, int) entry, PolicyTestResult testResult) =
        completedEntry;

    active.remove(entry);
    allResults.add(testResult);
    completedCount++;

    final String status = testResult.status == TestStatus.passed ? '✓' : '✗';
    print(
      '$status ($completedCount/${testFactories.length}) ${testResult.testName}',
    );

    await startNextTest();
  }

  return allResults;
}

Future<List<PolicyTestResult>> _runFactoryBatchesWithConcurrency(
  List<List<Future<PolicyTestResult> Function()>> testFactoryBatches, {
  required int batchSize,
  required int maxRetries,
  required Duration testTimeout,
}) async {
  final List<PolicyTestResult> allResults = [];
  for (final List<Future<PolicyTestResult> Function()> testFactories
      in testFactoryBatches) {
    allResults.addAll(
      await _runFuturesWithConcurrency(
        testFactories,
        batchSize: batchSize,
        maxRetries: maxRetries,
        testTimeout: testTimeout,
      ),
    );
  }
  return allResults;
}
