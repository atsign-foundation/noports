import 'dart:async';
import 'dart:io';

import 'package:e2e_all_v2/apkam_setup.dart';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/client_binary_utils.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_utils.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/print_test_utils.dart';
import 'package:e2e_all_v2/relay_tests/relay_tests_context.dart';
import 'package:e2e_all_v2/relay_tests/relay_tests_params.dart';
import 'package:e2e_all_v2/relay_tests/relay_tests_test_result.dart';
import 'package:e2e_all_v2/relay_tests/tests/npt_relay_test.dart';
import 'package:e2e_all_v2/test_result.dart';
import 'package:e2e_all_v2/utils.dart';

const String relayTestsApkamApp = 'npe2e_relay';

Future<void> relayTests(RelayTestsParams params) async {
  final Stopwatch overallStopwatch = Stopwatch()..start();

  final List<NoPortsVersion> clientVersions = _parseVersions(
    params.clientVersions,
  );
  final List<NoPortsVersion> daemonVersions = _parseVersions(
    params.daemonVersions,
  );
  final List<NoPortsVersion> selfRelayVersions = _parseVersions(
    params.selfRelayVersions,
  );
  List<String> selfRelayAtsigns = _parseAtsigns(params.selfRelayAtsigns);
  final int requiredSelfRelayAtsigns = selfRelayVersions.length * 3;
  if (selfRelayAtsigns.length < requiredSelfRelayAtsigns) {
    throw ArgumentError(
      'self-relay-atsigns must contain at least $requiredSelfRelayAtsigns '
      'atSigns for ${selfRelayVersions.length} self relay version(s)',
    );
  }
  if (selfRelayAtsigns.length > requiredSelfRelayAtsigns) {
    print(
      'self-relay-atsigns has ${selfRelayAtsigns.length} atSigns; '
      'only the first $requiredSelfRelayAtsigns are required and will be used.',
    );
    print('');
    selfRelayAtsigns = selfRelayAtsigns.take(requiredSelfRelayAtsigns).toList();
  }
  if (selfRelayAtsigns.toSet().length != selfRelayAtsigns.length) {
    throw ArgumentError('self-relay-atsigns must be distinct');
  }
  if (selfRelayAtsigns.contains(params.prodRelayAtsign)) {
    throw ArgumentError(
      'prod-relay-atsign and self-relay-atsigns must be distinct',
    );
  }

  final String testRunId =
      params.testRunId ?? await getShortenedGitCommitHash();
  print('testRunId: $testRunId\n');

  final Directory baseDirectory = Directory(
    '${params.baseDirectory}/$testRunId',
  );
  final Directory apkamKeysDirectory = Directory(
    '${baseDirectory.path}/apkamKeys',
  );
  final Directory binariesDirectory = Directory(
    '${baseDirectory.path}/binaries',
  );
  final Directory logsDirectory = Directory('${baseDirectory.path}/logs');
  await ensureDirectoryExists(baseDirectory);
  await ensureDirectoryExists(apkamKeysDirectory);
  await ensureDirectoryExists(binariesDirectory);
  await ensureDirectoryExists(logsDirectory);

  final Stopwatch setUpStopwatch = Stopwatch()..start();
  print('Running relay setup flows asynchronously...');
  print('\tFlow 1: Fetch at_activate --> APKAM setup');
  print('\tFlow 2: Pull/build client, daemon, and relay Docker images');
  print('');

  final Future<List<ClientBinary>> clientBinariesFuture =
      fetchClientBinariesParallel(
        binariesDirectory: binariesDirectory,
        clientBinariesToDownload: [
          (
            NoPortsVersion(language: Language.dart, version: 'current'),
            ClientBinaryType.at_activate,
          ),
        ],
      );

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
        for (int i = 0; i < selfRelayAtsigns.length; i++)
          (which: 'self_relay_$i', atsign: selfRelayAtsigns[i]),
      ],
      rootDomain: params.rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId,
      apkamApp: relayTestsApkamApp,
    );
  });

  final Future<List<DockerImage>> dockerImagesFuture =
      ensureDockerImagesVersionBuiltParallel(
        versions: [...clientVersions, ...daemonVersions, ...selfRelayVersions],
      );

  final List<dynamic> setupResults = await Future.wait([
    clientBinariesFuture,
    apkamKeysFuture,
    dockerImagesFuture,
  ]);
  final Map<String, File> apkamKeys = setupResults[1] as Map<String, File>;
  final List<DockerImage> dockerImages = setupResults[2] as List<DockerImage>;

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

  final RelayTestsContext context = RelayTestsContext(
    testRunId: testRunId,
    baseDirectory: baseDirectory,
    logsDirectory: logsDirectory,
    apkamKeys: apkamKeys,
    dockerImages: dockerImages,
    clientAtsign: params.clientAtsign,
    daemonAtsign: params.daemonAtsign,
    prodRelayAtsign: params.prodRelayAtsign,
    selfRelayAtsigns: selfRelayAtsigns,
    rootDomain: params.rootDomain,
  );

  NptRelayEnvironment? environment;
  final List<RelayTestResult> testResults = [];
  final Stopwatch testExecutionStopwatch = Stopwatch()..start();
  try {
    print('Starting relay daemon and self-relay Docker instances...');
    environment = await startNptRelayEnvironment(
      context: context,
      daemonVersions: daemonVersions,
      selfRelayVersions: selfRelayVersions,
    );
    print('');
    print('Started ${environment.daemonTargets.length} relay daemon(s):');
    for (final RelayDaemonTarget daemonTarget in environment.daemonTargets) {
      print(
        '    Daemon (-d ${daemonTarget.deviceName}): ${daemonTarget.daemonInstance.containerName}',
      );
    }
    print('');
    print('Prepared ${environment.relayCases.length} relay option(s):');
    for (final RelayCase relayCase in environment.relayCases) {
      final String relay = relayCase.relayVersion == null
          ? 'prod'
          : '${relayCase.relayVersion!.language.name[0]}:${relayCase.relayVersion!.version}';
      print(
        '    ${relayCase.optionName}: ${relayCase.relayKind.name}:$relay'
        '${relayCase.relayAlias == null ? '' : ' (${relayCase.relayAlias})'}',
      );
    }
    print('');
    setUpStopwatch.stop();
    print('Set up completed in ${formatDuration(setUpStopwatch.elapsed)}');
    print('');

    final List<Future<RelayTestResult> Function()> testFactories =
        runNptRelayTests(
          context: context,
          environment: environment,
          clientVersions: clientVersions,
        );

    print('Running ${testFactories.length} relay test(s)...');
    testResults.addAll(
      await _runFuturesWithConcurrency(
        testFactories,
        batchSize: params.batchSize,
      ),
    );
  } finally {
    await stopNptRelayEnvironment(environment);
  }
  testExecutionStopwatch.stop();

  print('');
  print('\tResults:');
  for (final RelayTestResult testResult in testResults) {
    printTestResult(
      testResult: testResult,
      extra: generateRelayExtraString(testResult),
    );
  }

  final int totalTests = testResults.length;
  final int passedTests = testResults
      .where((tr) => tr.status == TestStatus.passed)
      .length;
  final int failedTests = testResults
      .where((tr) => tr.status == TestStatus.failed)
      .length;

  overallStopwatch.stop();
  print('');
  print('Test Results Summary:');
  print('    Total tests: $totalTests');
  print('    Passed: $passedTests');
  print('    Failed: $failedTests');
  print('');

  if (failedTests > 0) {
    print('Failed Tests:');
    for (final RelayTestResult testResult in testResults.where(
      (tr) => tr.status == TestStatus.failed,
    )) {
      print(
        '    ${testResult.testName} ${generateRelayExtraString(testResult)} - Exit code: ${testResult.exitCode}',
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

  if (failedTests > 0) {
    throw Exception('$failedTests relay test(s) failed');
  }
}

String generateRelayExtraString(RelayTestResult result) {
  final String relay = result.relayVersion == null
      ? 'prod'
      : '${result.relayVersion!.language.name[0]}:${result.relayVersion!.version}';
  final String mode = result.only443
      ? '${result.relayAuthMode},443'
      : result.relayAuthMode;
  return '(client: ${result.clientVersion.language.name[0]}:${result.clientVersion.version}, '
      'daemon: ${result.daemonVersion.language.name[0]}:${result.daemonVersion.version}, '
      'relay: ${result.relayKind}:$relay, mode: $mode)';
}

List<NoPortsVersion> _parseVersions(String versions) {
  return versions
      .split(',')
      .map((entry) => NoPortsVersion.fromLanguageVersionString(entry.trim()))
      .toList();
}

List<String> _parseAtsigns(String atsigns) {
  return atsigns
      .split(',')
      .map((atsign) => atsign.trim())
      .where((atsign) => atsign.isNotEmpty)
      .toList();
}

Future<List<RelayTestResult>> _runFuturesWithConcurrency(
  List<Future<RelayTestResult> Function()> testFactories, {
  required int batchSize,
}) async {
  if (testFactories.isEmpty) {
    return [];
  }

  final List<RelayTestResult> allResults = [];
  final List<(Future<RelayTestResult>, int)> active = [];
  int nextIndex = 0;
  int completedCount = 0;

  Future<void> startNextTest() async {
    if (nextIndex < testFactories.length) {
      if (nextIndex > 0) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      final int testIndex = nextIndex;
      final Future<RelayTestResult> testFuture = testFactories[nextIndex]();
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
        final RelayTestResult result = await entry.$1;
        return (entry, result);
      }),
    );

    final ((Future<RelayTestResult>, int) entry, RelayTestResult testResult) =
        completedEntry;

    active.remove(entry);
    allResults.add(testResult);
    completedCount++;

    final String status = testResult.status == TestStatus.passed ? '✓' : '✗';
    print(
      '$status ($completedCount/${testFactories.length}) ${testResult.testName} ${generateRelayExtraString(testResult)}',
    );

    await startNextTest();
  }

  return allResults;
}
