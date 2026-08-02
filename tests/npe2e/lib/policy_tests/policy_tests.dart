import 'dart:async';
import 'dart:io';

import 'package:npe2e/apkam_setup.dart';
import 'package:npe2e/client_binary.dart';
import 'package:npe2e/client_binary_utils.dart';
import 'package:npe2e/docker_image.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/policy_tests/policy_test_case.dart';
import 'package:npe2e/policy_tests/policy_tests_print_utils.dart';
import 'package:npe2e/policy_tests/policy_tests_context.dart';
import 'package:npe2e/policy_tests/policy_tests_docker_utils.dart';
import 'package:npe2e/policy_tests/policy_tests_params.dart';
import 'package:npe2e/policy_tests/policy_tests_test_result.dart';
import 'package:npe2e/policy_tests/tests/npp_atserver_test.dart';
import 'package:npe2e/policy_tests/tests/npp_test.dart';
import 'package:npe2e/print_test_utils.dart';
import 'package:npe2e/test_result.dart';
import 'package:npe2e/transcript.dart';
import 'package:npe2e/utils.dart';

const String policyTestsApkamApp = 'npe2e_policy';
const String policyTranscriptFileName = 'npe2e_policy_transcript.log';

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

  final File transcriptLogFile = File(
    '${logsDirectory.path}/$policyTranscriptFileName',
  );
  await transcriptLogFile.writeAsString(
    'npe2e policy_tests transcript, testRunId=$testRunId, '
    'started ${DateTime.now().toIso8601String()}\n',
  );
  final Transcript transcript = Transcript(tag: 'run', file: transcriptLogFile);
  transcript.info('transcript: ${transcriptLogFile.path}');

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
  transcript.section('Setup');
  transcript.info('Flow 1: Fetch client binaries --> APKAM setup');
  transcript.info(
    'Flow 2: Pull/build daemon, NPP, and NPP atServer Docker images',
  );

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
      orElse: () => throw Exception(
        'No at_activate binary for version "current" was fetched; cannot set '
        'up APKAM keys. Fetched: '
        '${clientBinaries.map((cb) => '${cb.binaryType.name}@${cb.noPortsVersion.version}').join(', ')}',
      ),
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

  transcript.info('Fetched client binaries (${clientBinaries.length}):');
  for (final ClientBinary clientBinary in clientBinaries) {
    transcript.info(
      '    ${clientBinary.binaryType.name} | ${clientBinary.noPortsVersion.language.name} | ${clientBinary.noPortsVersion.version} | ${clientBinary.file.path}',
    );
  }

  transcript.info('APKAM keys ready:');
  for (final String atsign in apkamKeys.keys) {
    transcript.info('    $atsign: ${apkamKeys[atsign]!.path}');
  }

  transcript.info('Docker images ready (${allDockerImages.length}):');
  for (final DockerImage dockerImage in allDockerImages) {
    transcript.info('    ${dockerImage.fullImageName}');
  }

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
    transcriptLogFile: transcriptLogFile,
    verbose: params.verbose,
  );
  setUpStopwatch.stop();
  transcript.ok('setup complete in ${formatDuration(setUpStopwatch.elapsed)}');

  // 8. Run the tests
  final List<List<PolicyTestCase>> nppTestCaseBatches =
      getNppTestFactoryBatchesByPolicyVersion(
        context: context,
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
        nppVersions: nppVersions,
      );
  final List<PolicyTestCase> nppAtServerTestCases = getNppAtServerTestFactories(
    context: context,
    clientVersions: clientVersions,
    daemonVersions: daemonVersions,
    nppAtServerVersions: nppAtServerVersions,
  );

  final int plannedTestCount =
      nppTestCaseBatches.fold<int>(0, (sum, batch) => sum + batch.length) +
      nppAtServerTestCases.length;
  transcript.info(
    'planned tests: $plannedTestCount '
    '(npp: ${plannedTestCount - nppAtServerTestCases.length}, '
    'npp_atserver: ${nppAtServerTestCases.length}); '
    'batchSize=${params.batchSize} maxRetries=${params.maxRetries} '
    'testTimeout=${params.testTimeoutSeconds}s',
  );

  final Stopwatch testExecutionStopwatch = Stopwatch()..start();
  final Duration testTimeout = Duration(seconds: params.testTimeoutSeconds);
  // Run the npp and npp_atserver flows sequentially, not concurrently.
  // Both flows create their admin AtClient through the per-isolate
  // AtClientManager singleton and share the client/daemon atSigns, and the
  // npp flow's notification-based admin RPCs are sensitive to monitor
  // disruption: concurrent flows were the standing trigger for lost RPC
  // response notifications (intermittent 30+ minute hangs / red builds).
  final List<PolicyTestResult> nppResults =
      await _runFactoryBatchesWithConcurrency(
        nppTestCaseBatches,
        transcript: transcript,
        batchSize: params.batchSize,
        maxRetries: params.maxRetries,
        testTimeout: testTimeout,
      );
  final List<PolicyTestResult> nppAtServerResults =
      await _runFuturesWithConcurrency(
        nppAtServerTestCases,
        transcript: transcript,
        batchSize: params.batchSize,
        maxRetries: params.maxRetries,
        testTimeout: testTimeout,
      );
  final List<PolicyTestResult> testResults = [
    ...nppResults,
    ...nppAtServerResults,
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

  if (totalTests == 0) {
    transcript.warn(
      'NO POLICY TESTS RAN. Every (client, daemon, policy) permutation was '
      'filtered out. A permutation is kept only if the policy version is at '
      'least the minimum for its suite AND at least one of the three versions '
      'is "current". Check --client-versions, --daemon-versions, '
      '--npp-versions and --npp-atserver-versions.',
    );
  }

  if (failedCount > 0) {
    print('Failed Tests:');
    for (final PolicyTestResult testResult in testResults.where(
      (tr) => tr.status == TestStatus.failed,
    )) {
      printPolicyFailureReport(
        testResult,
        transcriptLogFile: transcriptLogFile,
      );
      print('');
    }
  }

  print('');
  print('Execution Time Summary:');
  print('    Setup time: ${formatDuration(setUpStopwatch.elapsed)}');
  print(
    '    Test execution time: ${formatDuration(testExecutionStopwatch.elapsed)}',
  );
  print('    Overall time: ${formatDuration(overallStopwatch.elapsed)}');
  print('');
  print('Transcript: ${transcriptLogFile.path}');
  print('Logs: ${logsDirectory.path}');

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
  List<PolicyTestCase> testCases, {
  required Transcript transcript,
  required int batchSize,
  required int maxRetries,
  required Duration testTimeout,
}) async {
  if (testCases.isEmpty) {
    return [];
  }

  final List<PolicyTestResult> allResults = [];
  final List<(Future<PolicyTestResult>, PolicyTestCase)> active = [];
  int nextIndex = 0;
  int completedCount = 0;

  Future<PolicyTestResult> runWithRetry(
    PolicyTestCase testCase,
    int attempt,
  ) async {
    final Transcript caseTranscript = transcript.withTag(testCase.tag);
    PolicyTestResult result;
    try {
      result = await testCase.run().timeout(testTimeout);
    } on TimeoutException {
      if (attempt < maxRetries) {
        caseTranscript.warn(
          '↺ ${testCase.testName} timed out after ${testTimeout.inSeconds}s '
          '(attempt ${attempt + 1}/$maxRetries), retrying...',
        );
        return runWithRetry(testCase, attempt + 1);
      }
      // Rethrowing here used to propagate all the way out of policyTests(),
      // discarding every result collected so far — so the run that most needed
      // a summary was the one that never printed one. Report it as a failure
      // instead; the run still fails on failedCount > 0.
      final PolicyTestResult timedOut = testCase.failedResult(
        stage: 'test timeout',
        reason:
            'timed out after ${testTimeout.inSeconds}s on all '
            '${attempt + 1} attempt(s)',
        detail:
            'The harness gave up from outside the test, so there is no '
            'stage-level detail. The transcript shows the last step reached; '
            'note that a timed-out attempt is not cancelled, so its containers '
            'may have still been running when the retry started.',
      );
      caseTranscript.error(
        '${testCase.testName} gave up: ${timedOut.failure!.reason}',
      );
      return timedOut;
    }
    if (result.status == TestStatus.failed && attempt < maxRetries) {
      caseTranscript.warn(
        '↺ ${testCase.testName} failed (attempt ${attempt + 1}/$maxRetries)'
        '${result.failure != null ? ': ${result.failure!.reason}' : ''}, '
        'retrying...',
      );
      return runWithRetry(testCase, attempt + 1);
    }
    return result;
  }

  Future<void> startNextTest() async {
    if (nextIndex < testCases.length) {
      if (nextIndex > 0) {
        await Future.delayed(Duration(seconds: 1));
      }

      final PolicyTestCase testCase = testCases[nextIndex];
      final Future<PolicyTestResult> testFuture = runWithRetry(testCase, 0);
      active.add((testFuture, testCase));
      nextIndex++;
    }
  }

  for (int i = 0; i < batchSize && i < testCases.length; i++) {
    await startNextTest();
  }

  while (active.isNotEmpty) {
    final completedEntry = await Future.any(
      active.map((entry) async {
        final PolicyTestResult result = await entry.$1;
        return (entry, result);
      }),
    );

    final (
      (Future<PolicyTestResult>, PolicyTestCase) entry,
      PolicyTestResult testResult,
    ) = completedEntry;

    active.remove(entry);
    allResults.add(testResult);
    completedCount++;

    final PolicyTestCase testCase = entry.$2;
    final Transcript caseTranscript = transcript.withTag(testCase.tag);
    final String progress =
        '($completedCount/${testCases.length}) ${testResult.testName} '
        '${testCase.extra}';
    if (testResult.status == TestStatus.passed) {
      caseTranscript.ok('✓ $progress');
    } else {
      caseTranscript.error('✗ $progress');
    }

    await startNextTest();
  }

  return allResults;
}

Future<List<PolicyTestResult>> _runFactoryBatchesWithConcurrency(
  List<List<PolicyTestCase>> testCaseBatches, {
  required Transcript transcript,
  required int batchSize,
  required int maxRetries,
  required Duration testTimeout,
}) async {
  final List<PolicyTestResult> allResults = [];
  for (final List<PolicyTestCase> testCases in testCaseBatches) {
    allResults.addAll(
      await _runFuturesWithConcurrency(
        testCases,
        transcript: transcript,
        batchSize: batchSize,
        maxRetries: maxRetries,
        testTimeout: testTimeout,
      ),
    );
  }
  return allResults;
}
