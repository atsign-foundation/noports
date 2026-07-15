import 'dart:io';

import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/docker_utils.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/log_fragment.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/print_test_utils.dart';
import 'package:npe2e/relay_tests/relay_tests_context.dart';
import 'package:npe2e/relay_tests/relay_tests_logging.dart';
import 'package:npe2e/relay_tests/relay_tests_test_result.dart';
import 'package:npe2e/relay_tests/relay_tests_utils.dart';
import 'package:npe2e/test_result.dart';
import 'package:path/path.dart' as path;

const String nptRelayTestName = 'npt_relay';
const String relay001MinusSFlagTestName = '001_minus_s_flag';
const String payloadRelayAuthMode = 'payload';
const String escrRelayAuthMode = 'escr';
const String _remoteUsername = 'atsign';

class RelayInstanceCase {
  final NoPortsVersion relayVersion;
  final String relayAtsign;
  final bool relayOnly443;
  final DockerInstance relayInstance;
  final String relayAlias;
  final String metadata;

  const RelayInstanceCase({
    required this.relayVersion,
    required this.relayAtsign,
    required this.relayOnly443,
    required this.relayInstance,
    required this.relayAlias,
    required this.metadata,
  });

  String get optionName => relayOnly443 ? 'self_443' : 'self_normal';
}

class RelayVersionPair {
  final NoPortsVersion relayVersion;
  final RelayInstanceCase normalRelay;
  final RelayInstanceCase relay443;

  const RelayVersionPair({
    required this.relayVersion,
    required this.normalRelay,
    required this.relay443,
  });
}

class RelayDaemonTarget {
  final NoPortsVersion daemonVersion;
  final String deviceName;
  final DockerInstance daemonInstance;

  const RelayDaemonTarget({
    required this.daemonVersion,
    required this.deviceName,
    required this.daemonInstance,
  });
}

class NptRelayCase {
  final String name;
  final String metadata;
  final bool clientUses443;
  final String relayAuthMode;
  final bool relayUses443;
  final bool expectSuccess;

  const NptRelayCase({
    required this.name,
    required this.metadata,
    required this.clientUses443,
    required this.relayAuthMode,
    required this.relayUses443,
    required this.expectSuccess,
  });

  String get testName => '${nptRelayTestName}_$metadata';

  String get optionName => metadata;
}

class NptRelayEnvironment {
  final String networkName;
  final List<RelayDaemonTarget> daemonTargets;
  final List<RelayVersionPair> relayPairs;

  const NptRelayEnvironment({
    required this.networkName,
    required this.daemonTargets,
    required this.relayPairs,
  });
}

class _RelayStartPlan {
  final NoPortsVersion relayVersion;
  final String normalRelayAtsign;
  final String relay443Atsign;

  const _RelayStartPlan({
    required this.relayVersion,
    required this.normalRelayAtsign,
    required this.relay443Atsign,
  });
}

Future<NptRelayEnvironment> startNptRelayEnvironment({
  required RelayTestsContext context,
  required List<NoPortsVersion> daemonVersions,
  required List<NoPortsVersion> selfRelayVersions,
}) async {
  final RelayTestLogger testLogger = RelayTestLogger(
    logsDirectory: context.logsDirectory,
    testName: nptRelayTestName,
  );
  final String networkName = sanitizeForDockerName(
    'npe2e_relay_${context.testRunId}',
    maxLength: 48,
  );

  await createDockerNetwork(networkName);

  final List<_RelayStartPlan> relayStartPlans = _relayStartPlans(
    context: context,
    selfRelayVersions: selfRelayVersions,
  );
  final List<RelayVersionPair> relayPairs = await Future.wait([
    for (final _RelayStartPlan plan in relayStartPlans)
      _startRelayVersionPair(
        context: context,
        testLogger: testLogger,
        relayVersion: plan.relayVersion,
        normalRelayAtsign: plan.normalRelayAtsign,
        relay443Atsign: plan.relay443Atsign,
        networkName: networkName,
      ),
  ]);

  final List<RelayDaemonTarget> daemonTargets = await Future.wait([
    for (final NoPortsVersion daemonVersion in daemonVersions)
      _startDaemonTarget(
        context: context,
        testLogger: testLogger,
        daemonVersion: daemonVersion,
        networkName: networkName,
      ),
  ]);

  return NptRelayEnvironment(
    networkName: networkName,
    daemonTargets: daemonTargets,
    relayPairs: relayPairs,
  );
}

List<Future<RelayTestResult> Function()> runRelay001MinusSFlagSetup({
  required RelayTestsContext context,
  required NptRelayEnvironment environment,
}) {
  final RelayTestLogger testLogger = RelayTestLogger(
    logsDirectory: context.logsDirectory,
    testName: relay001MinusSFlagTestName,
  );
  final NoPortsVersion clientVersion = NoPortsVersion(
    language: Language.dart,
    version: 'current',
  );

  return [
    for (final RelayDaemonTarget daemonTarget in environment.daemonTargets)
      () => _runRelay001MinusSFlagSetup(
        context: context,
        testLogger: testLogger,
        environment: environment,
        clientVersion: clientVersion,
        daemonTarget: daemonTarget,
      ),
  ];
}

Future<void> stopNptRelayEnvironment(NptRelayEnvironment? environment) async {
  if (environment == null) {
    return;
  }
  await Future.wait([
    for (final RelayDaemonTarget daemonTarget in environment.daemonTargets)
      stopDockerInstanceQuietly(daemonTarget.daemonInstance),
    for (final RelayVersionPair relayPair in environment.relayPairs) ...[
      stopDockerInstanceQuietly(relayPair.normalRelay.relayInstance),
      stopDockerInstanceQuietly(relayPair.relay443.relayInstance),
    ],
  ]);
  await removeDockerNetwork(environment.networkName);
}

List<Future<RelayTestResult> Function()> runNptRelayCaseTests({
  required RelayTestsContext context,
  required NptRelayEnvironment environment,
  required List<NoPortsVersion> clientVersions,
  required NptRelayCase relayCase,
}) {
  final RelayTestLogger testLogger = RelayTestLogger(
    logsDirectory: context.logsDirectory,
    testName: relayCase.testName,
  );
  final List<Future<RelayTestResult> Function()> testFactories = [];

  for (final NoPortsVersion clientVersion in clientVersions) {
    for (final RelayDaemonTarget daemonTarget in environment.daemonTargets) {
      for (final RelayVersionPair relayPair in environment.relayPairs) {
        if (!_hasCurrentVersion(
          clientVersion,
          daemonTarget.daemonVersion,
          relayPair.relayVersion,
        )) {
          continue;
        }
        if (!_supportsRelayCase(
          clientVersion,
          daemonTarget.daemonVersion,
          relayPair.relayVersion,
          relayCase,
        )) {
          continue;
        }
        testFactories.add(
          () => _runNptRelayTest(
            context: context,
            testLogger: testLogger,
            environment: environment,
            clientVersion: clientVersion,
            daemonTarget: daemonTarget,
            relayPair: relayPair,
            relayCase: relayCase,
          ),
        );
      }
    }
  }

  return testFactories;
}

bool _hasCurrentVersion(
  NoPortsVersion clientVersion,
  NoPortsVersion daemonVersion,
  NoPortsVersion relayVersion,
) {
  return clientVersion.version == 'current' ||
      daemonVersion.version == 'current' ||
      relayVersion.version == 'current';
}

List<_RelayStartPlan> _relayStartPlans({
  required RelayTestsContext context,
  required List<NoPortsVersion> selfRelayVersions,
}) {
  final List<_RelayStartPlan> plans = [];
  int atsignIndex = 0;
  for (final NoPortsVersion selfRelayVersion in selfRelayVersions) {
    plans.add(
      _RelayStartPlan(
        relayVersion: selfRelayVersion,
        normalRelayAtsign: context.selfRelayAtsigns[atsignIndex],
        relay443Atsign: context.selfRelayAtsigns[atsignIndex + 1],
      ),
    );
    atsignIndex += 2;
  }
  return plans;
}

Future<RelayVersionPair> _startRelayVersionPair({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion relayVersion,
  required String normalRelayAtsign,
  required String relay443Atsign,
  required String networkName,
}) async {
  final List<RelayInstanceCase> relays = await Future.wait([
    _startRelayInstanceCase(
      context: context,
      testLogger: testLogger,
      relayVersion: relayVersion,
      relayAtsign: normalRelayAtsign,
      relayOnly443: false,
      networkName: networkName,
    ),
    _startRelayInstanceCase(
      context: context,
      testLogger: testLogger,
      relayVersion: relayVersion,
      relayAtsign: relay443Atsign,
      relayOnly443: true,
      networkName: networkName,
    ),
  ]);
  return RelayVersionPair(
    relayVersion: relayVersion,
    normalRelay: relays.firstWhere((relay) => !relay.relayOnly443),
    relay443: relays.firstWhere((relay) => relay.relayOnly443),
  );
}

Future<RelayInstanceCase> _startRelayInstanceCase({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion relayVersion,
  required String relayAtsign,
  required bool relayOnly443,
  required String networkName,
}) async {
  final String metadata = sanitizeForDockerName(
    'self_${relayOnly443 ? '443' : 'normal'}'
    '_r_${relayVersion.language.name}_${relayVersion.version}',
    maxLength: 48,
  );
  final String relayAlias = sanitizeForDockerName(
    'relay_${context.testRunId}_$metadata',
    maxLength: 48,
  );
  final DockerInstance relay = await _startSelfRelay(
    context: context,
    testLogger: testLogger,
    relayVersion: relayVersion,
    relayAtsign: relayAtsign,
    relayOnly443: relayOnly443,
    networkName: networkName,
    relayAlias: relayAlias,
    metadata: metadata,
  );
  await waitForLogMessage(relay, 'monitor started');
  return RelayInstanceCase(
    relayVersion: relayVersion,
    relayAtsign: relayAtsign,
    relayOnly443: relayOnly443,
    relayInstance: relay,
    relayAlias: relayAlias,
    metadata: metadata,
  );
}

Future<RelayDaemonTarget> _startDaemonTarget({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion daemonVersion,
  required String networkName,
}) async {
  final String deviceName = _daemonDeviceName(context, daemonVersion);
  final DockerInstance daemon = await _startDaemon(
    context: context,
    testLogger: testLogger,
    daemonVersion: daemonVersion,
    networkName: networkName,
    deviceName: deviceName,
  );
  await waitForLogMessage(daemon, 'monitor started');
  return RelayDaemonTarget(
    daemonVersion: daemonVersion,
    deviceName: deviceName,
    daemonInstance: daemon,
  );
}

Future<RelayTestResult> _runNptRelayTest({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NptRelayEnvironment environment,
  required NoPortsVersion clientVersion,
  required RelayDaemonTarget daemonTarget,
  required RelayVersionPair relayPair,
  required NptRelayCase relayCase,
}) async {
  final RelayInstanceCase relayInstanceCase = relayCase.relayUses443
      ? relayPair.relay443
      : relayPair.normalRelay;
  final String metadata = _metadata(
    context: context,
    clientVersion: clientVersion,
    daemonVersion: daemonTarget.daemonVersion,
    relayInstanceCase: relayInstanceCase,
    relayCase: relayCase,
  );
  final String extra = _extra(
    clientVersion: clientVersion,
    daemonVersion: daemonTarget.daemonVersion,
    relayInstanceCase: relayInstanceCase,
    relayCase: relayCase,
  );
  printTestStart(testName: relayCase.testName, extra: extra);

  DockerInstance? client;
  LogFragment? daemonLogFragment;
  LogFragment? relayLogFragment;
  try {
    int exitCode = 1;
    for (int attempt = 1; attempt <= 2; attempt++) {
      final String attemptMetadata = attempt == 1
          ? metadata
          : '${metadata}_retry$attempt';
      daemonLogFragment = _createDaemonLogFragment(
        testLogger: testLogger,
        daemonTarget: daemonTarget,
        metadata: attemptMetadata,
      );
      relayLogFragment = _createRelayLogFragment(
        testLogger: testLogger,
        relayInstanceCase: relayInstanceCase,
        metadata: attemptMetadata,
      );
      await daemonLogFragment.start();
      await relayLogFragment.start();
      client = await _runClientCommand(
        context: context,
        testLogger: testLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonTarget.daemonVersion,
        relayInstanceCase: relayInstanceCase,
        relayCase: relayCase,
        networkName: environment.networkName,
        deviceName: daemonTarget.deviceName,
        metadata: attemptMetadata,
      );
      exitCode = await client.process!.exitCode.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          client!.process!.kill(ProcessSignal.sigterm);
          return 124;
        },
      );
      await daemonLogFragment.stop();
      await relayLogFragment.stop();
      if (relayCase.expectSuccess && exitCode != 0 && attempt < 2) {
        print(
          'Retrying ${relayCase.testName} $extra after client command exit code $exitCode',
        );
        await stopDockerInstanceQuietly(client);
        client = null;
        await Future<void>.delayed(const Duration(seconds: 3));
        continue;
      }
      break;
    }

    final bool passed = relayCase.expectSuccess ? exitCode == 0 : exitCode != 0;
    final RelayTestResult result = _relayTestResult(
      testName: relayCase.testName,
      clientVersion: clientVersion,
      daemonVersion: daemonTarget.daemonVersion,
      relayInstanceCase: relayInstanceCase,
      relayCase: relayCase,
      status: passed ? TestStatus.passed : TestStatus.failed,
      exitCode: exitCode,
    );
    printTestResult(testResult: result, extra: extra);
    if (!passed) {
      await _printFailureLogs(
        client,
        daemonTarget.daemonInstance,
        relayInstanceCase: relayInstanceCase,
        daemonLogFragment: daemonLogFragment,
        relayLogFragment: relayLogFragment,
      );
    }
    return result;
  } catch (e) {
    await _stopLogFragmentQuietly(daemonLogFragment);
    await _stopLogFragmentQuietly(relayLogFragment);
    final RelayTestResult result = _relayTestResult(
      testName: relayCase.testName,
      clientVersion: clientVersion,
      daemonVersion: daemonTarget.daemonVersion,
      relayInstanceCase: relayInstanceCase,
      relayCase: relayCase,
      status: TestStatus.failed,
      exitCode: 1,
    );
    printTestResult(testResult: result, extra: extra);
    print('Relay test exception: $e');
    await _printFailureLogs(
      client,
      daemonTarget.daemonInstance,
      relayInstanceCase: relayInstanceCase,
      daemonLogFragment: daemonLogFragment,
      relayLogFragment: relayLogFragment,
    );
    return result;
  } finally {
    await _stopLogFragmentQuietly(daemonLogFragment);
    await _stopLogFragmentQuietly(relayLogFragment);
    await stopDockerInstanceQuietly(client);
  }
}

Future<RelayTestResult> _runRelay001MinusSFlagSetup({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NptRelayEnvironment environment,
  required NoPortsVersion clientVersion,
  required RelayDaemonTarget daemonTarget,
}) async {
  const NptRelayCase bootstrapCase = NptRelayCase(
    name: 'bootstrap ssh key setup',
    metadata: 'bootstrap_ssh_key_setup',
    clientUses443: false,
    relayAuthMode: payloadRelayAuthMode,
    relayUses443: false,
    expectSuccess: true,
  );
  final String metadata = _prodRelayMetadata(
    context: context,
    clientVersion: clientVersion,
    daemonVersion: daemonTarget.daemonVersion,
    relayCase: bootstrapCase,
  );
  final String extra = _prodRelayExtra(
    context: context,
    clientVersion: clientVersion,
    daemonVersion: daemonTarget.daemonVersion,
  );
  printTestStart(testName: relay001MinusSFlagTestName, extra: extra);

  DockerInstance? client;
  LogFragment? daemonLogFragment;
  try {
    daemonLogFragment = _createDaemonLogFragment(
      testLogger: testLogger,
      daemonTarget: daemonTarget,
      metadata: metadata,
    );
    await daemonLogFragment.start();
    client = await _runSshnpPrimeCommand(
      context: context,
      testLogger: testLogger,
      clientVersion: clientVersion,
      daemonVersion: daemonTarget.daemonVersion,
      relayAtsign: context.prodRelayAtsign,
      networkName: environment.networkName,
      deviceName: daemonTarget.deviceName,
      metadata: metadata,
    );
    final int exitCode = await client.process!.exitCode.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        client!.process!.kill(ProcessSignal.sigterm);
        return 124;
      },
    );
    await daemonLogFragment.stop();
    final RelayTestResult result = _prodRelayTestResult(
      testName: relay001MinusSFlagTestName,
      clientVersion: clientVersion,
      daemonVersion: daemonTarget.daemonVersion,
      relayCase: bootstrapCase,
      status: exitCode == 0 ? TestStatus.passed : TestStatus.failed,
      exitCode: exitCode,
    );
    printTestResult(testResult: result, extra: extra);
    if (exitCode != 0) {
      await _printFailureLogs(
        client,
        daemonTarget.daemonInstance,
        daemonLogFragment: daemonLogFragment,
      );
    }
    return result;
  } catch (e) {
    await _stopLogFragmentQuietly(daemonLogFragment);
    final RelayTestResult result = _prodRelayTestResult(
      testName: relay001MinusSFlagTestName,
      clientVersion: clientVersion,
      daemonVersion: daemonTarget.daemonVersion,
      relayCase: bootstrapCase,
      status: TestStatus.failed,
      exitCode: 1,
    );
    printTestResult(testResult: result, extra: extra);
    print('Relay $relay001MinusSFlagTestName exception: $e');
    await _printFailureLogs(
      client,
      daemonTarget.daemonInstance,
      daemonLogFragment: daemonLogFragment,
    );
    return result;
  } finally {
    await _stopLogFragmentQuietly(daemonLogFragment);
    await stopDockerInstanceQuietly(client);
  }
}

Future<DockerInstance> _startDaemon({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion daemonVersion,
  required String networkName,
  required String deviceName,
}) async {
  final DockerImage dockerImage = _dockerImageForVersion(
    context: context,
    version: daemonVersion,
  );
  final File daemonApkamKeysFile = context.apkamKeys[context.daemonAtsign]!;
  final String containerKeyFilePath =
      '/atsign/.atsign/keys/${path.basename(daemonApkamKeysFile.path)}';
  return runDockerInstance(
    dockerImage: dockerImage,
    testRunId: context.testRunId,
    logsDirectory: testLogger.daemonsDirectory,
    uniqueIdentifier:
        '_relay_daemon_${daemonVersion.language.name}_${daemonVersion.version}',
    networkName: networkName,
    // Local-run aid: let the container resolve *.atsign.zone back to the host.
    additionalDockerArgs: hostGatewayAddHostArgs(),
    entrypoint: [
      '/bin/bash',
      '-c',
      'sudo service ssh start && '
          '/usr/local/bin/sshnpd '
          '-a ${context.daemonAtsign} '
          '-m ${context.clientAtsign} '
          '-k $containerKeyFilePath '
          '--root-domain ${context.rootDomain} '
          '-d $deviceName '
          '-v -s -u',
    ],
    volumeMappings: [
      VolumeMapping(
        local: daemonApkamKeysFile.absolute.path,
        container: containerKeyFilePath,
      ),
    ],
  );
}

Future<DockerInstance> _startSelfRelay({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion relayVersion,
  required String relayAtsign,
  required bool relayOnly443,
  required String networkName,
  required String relayAlias,
  required String metadata,
}) async {
  final DockerImage dockerImage = _dockerImageForVersion(
    context: context,
    version: relayVersion,
  );
  final File relayApkamKeysFile = context.apkamKeys[relayAtsign]!;
  final String containerKeyFilePath =
      '/atsign/.atsign/keys/${path.basename(relayApkamKeysFile.path)}';
  final List<String> srvdArgs = [
    '/usr/local/bin/srvd',
    '-a',
    relayAtsign,
    '-k',
    containerKeyFilePath,
    '--root-domain',
    context.rootDomain,
    '--ip',
    relayAlias,
    '-v',
    if (relayOnly443) ...['--443'],
  ];
  return runDockerInstance(
    dockerImage: dockerImage,
    testRunId: context.testRunId,
    logsDirectory: testLogger.relaysDirectory,
    uniqueIdentifier:
        '_relay_${relayVersion.language.name}_${relayVersion.version}_$metadata',
    networkName: networkName,
    networkAlias: relayAlias,
    // Local-run aid: let the container resolve *.atsign.zone back to the host,
    // alongside the --user root needed by the 443 relay.
    additionalDockerArgs: [
      ...hostGatewayAddHostArgs(),
      if (relayOnly443) ...['--user', 'root'],
    ],
    entrypoint: srvdArgs,
    volumeMappings: [
      VolumeMapping(
        local: relayApkamKeysFile.absolute.path,
        container: containerKeyFilePath,
      ),
    ],
  );
}

LogFragment _createDaemonLogFragment({
  required RelayTestLogger testLogger,
  required RelayDaemonTarget daemonTarget,
  required String metadata,
}) {
  return daemonTarget.daemonInstance.createLogFragment(
    stdoutFile: testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonTarget.daemonVersion,
      deviceName: daemonTarget.deviceName,
      testMetadata: metadata,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonTarget.daemonVersion,
      deviceName: daemonTarget.deviceName,
      testMetadata: metadata,
    ),
    printCommand: false,
  );
}

LogFragment _createRelayLogFragment({
  required RelayTestLogger testLogger,
  required RelayInstanceCase relayInstanceCase,
  required String metadata,
}) {
  return relayInstanceCase.relayInstance.createLogFragment(
    stdoutFile: testLogger.getRelayStdoutLogFile(
      relayVersion: relayInstanceCase.relayVersion,
      relayKind: relayInstanceCase.optionName,
      testMetadata: metadata,
    ),
    stderrFile: testLogger.getRelayStderrLogFile(
      relayVersion: relayInstanceCase.relayVersion,
      relayKind: relayInstanceCase.optionName,
      testMetadata: metadata,
    ),
    printCommand: false,
  );
}

Future<DockerInstance> _runClientCommand({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required RelayInstanceCase relayInstanceCase,
  required NptRelayCase relayCase,
  required String networkName,
  required String deviceName,
  required String metadata,
}) {
  final DockerImage dockerImage = _dockerImageForVersion(
    context: context,
    version: clientVersion,
  );
  final File clientApkamKeysFile = context.apkamKeys[context.clientAtsign]!;
  final String containerKeyFilePath =
      '/atsign/.atsign/keys/${path.basename(clientApkamKeysFile.path)}';
  final String script = _clientScript(
    context: context,
    relayInstanceCase: relayInstanceCase,
    relayCase: relayCase,
    deviceName: deviceName,
    clientKeyPath: containerKeyFilePath,
  );
  final DockerInstance dockerInstance = DockerInstance(
    dockerImage: dockerImage,
    testRunId: context.testRunId,
    uniqueIdentifier:
        '_client_${clientVersion.language.name}_${clientVersion.version}'
        '_daemon_${daemonVersion.language.name}_${daemonVersion.version}'
        '_relay_${relayInstanceCase.relayVersion.language.name}_${relayInstanceCase.relayVersion.version}'
        '_${relayCase.optionName}',
  );
  return dockerInstance
      .run(
        networkName: networkName,
        // Local-run aid: let the container resolve *.atsign.zone to the host.
        additionalDockerArgs: hostGatewayAddHostArgs(),
        entrypoint: ['/bin/bash', '-c', script],
        volumeMappings: [
          VolumeMapping(
            local: clientApkamKeysFile.absolute.path,
            container: containerKeyFilePath,
          ),
        ],
        stdoutLogFile: testLogger.getClientStdoutLogFile(
          clientVersion: clientVersion,
          daemonVersion: daemonVersion,
          relayVersion: relayInstanceCase.relayVersion,
          testMetadata: metadata,
        ),
        stderrLogFile: testLogger.getClientStderrLogFile(
          clientVersion: clientVersion,
          daemonVersion: daemonVersion,
          relayVersion: relayInstanceCase.relayVersion,
          testMetadata: metadata,
        ),
      )
      .then((_) => dockerInstance);
}

Future<DockerInstance> _runSshnpPrimeCommand({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required String relayAtsign,
  required String networkName,
  required String deviceName,
  required String metadata,
}) {
  final DockerImage dockerImage = _dockerImageForVersion(
    context: context,
    version: clientVersion,
  );
  final File clientApkamKeysFile = context.apkamKeys[context.clientAtsign]!;
  final String containerKeyFilePath =
      '/atsign/.atsign/keys/${path.basename(clientApkamKeysFile.path)}';
  final String script = _sshnpPrimeScript(
    context: context,
    relayAtsign: relayAtsign,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    deviceName: deviceName,
    clientKeyPath: containerKeyFilePath,
  );
  final DockerInstance dockerInstance = DockerInstance(
    dockerImage: dockerImage,
    testRunId: context.testRunId,
    uniqueIdentifier:
        '_relay_001_client_${clientVersion.language.name}_${clientVersion.version}'
        '_daemon_${daemonVersion.language.name}_${daemonVersion.version}',
  );
  return dockerInstance
      .run(
        networkName: networkName,
        // Local-run aid: let the container resolve *.atsign.zone to the host.
        additionalDockerArgs: hostGatewayAddHostArgs(),
        entrypoint: ['/bin/bash', '-c', script],
        volumeMappings: [
          VolumeMapping(
            local: clientApkamKeysFile.absolute.path,
            container: containerKeyFilePath,
          ),
        ],
        stdoutLogFile: testLogger.getClientStdoutLogFile(
          clientVersion: clientVersion,
          daemonVersion: daemonVersion,
          testMetadata: metadata,
        ),
        stderrLogFile: testLogger.getClientStderrLogFile(
          clientVersion: clientVersion,
          daemonVersion: daemonVersion,
          testMetadata: metadata,
        ),
      )
      .then((_) => dockerInstance);
}

String _clientScript({
  required RelayTestsContext context,
  required RelayInstanceCase relayInstanceCase,
  required NptRelayCase relayCase,
  required String deviceName,
  required String clientKeyPath,
}) {
  final List<String> nptArgs = [
    '/usr/local/bin/npt',
    '-f',
    context.clientAtsign,
    '-t',
    context.daemonAtsign,
    '-d',
    deviceName,
    '-r',
    relayInstanceCase.relayAtsign,
    '--root-domain',
    context.rootDomain,
    '--remote-port',
    '22',
    '--exit-when-connected',
    '--verbose',
    '-k',
    clientKeyPath,
    if (relayCase.relayAuthMode == escrRelayAuthMode) ...[
      '--relay-auth-mode',
      'escr',
    ],
    if (relayCase.clientUses443) '--443',
  ];
  final String nptCommand = nptArgs.map(_shellQuote).join(' ');
  return '''
set -e
PORT=\$($nptCommand)
echo "npt local port: \$PORT"
ssh -p "\$PORT" -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i /atsign/.ssh/id_ed25519 $_remoteUsername@localhost echo TEST PASSED
''';
}

String _sshnpPrimeScript({
  required RelayTestsContext context,
  required String relayAtsign,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required String deviceName,
  required String clientKeyPath,
}) {
  final List<String> sshnpArgs = [
    '/usr/local/bin/sshnp',
    '-f',
    context.clientAtsign,
    '-t',
    context.daemonAtsign,
    '-i',
    '/atsign/.ssh/id_ed25519',
    '-d',
    deviceName,
    '-h',
    relayAtsign,
    '-u',
    _remoteUsername,
    '--root-domain',
    context.rootDomain,
    '-s',
    '-k',
    clientKeyPath,
    ..._sshnpNonInteractiveArgs(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
    ),
  ];
  final String sshnpCommand = sshnpArgs.map(_shellQuote).join(' ');
  return '''
set -e
$sshnpCommand
''';
}

List<String> _sshnpNonInteractiveArgs({
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) {
  if (daemonVersion.language == Language.c) {
    return ['-x'];
  }
  if (versionIsAtLeast(
    clientVersion,
    NoPortsVersion(language: Language.dart, version: 'v5.0.0'),
  )) {
    return ['-x', '--no-ad', '--no-et'];
  }
  return const [];
}

Future<void> _printFailureLogs(
  DockerInstance? client,
  DockerInstance daemon, {
  RelayInstanceCase? relayInstanceCase,
  LogFragment? daemonLogFragment,
  LogFragment? relayLogFragment,
}) async {
  for (final (String label, DockerInstance? instance) in [
    ('client', client),
    ('daemon', daemon),
    ('relay', relayInstanceCase?.relayInstance),
  ]) {
    if (instance == null) {
      continue;
    }
    final File? stdout = instance.stdoutLogFile;
    final File? stderr = instance.stderrLogFile;
    if (stdout != null && await stdout.exists()) {
      print('$label stdout:\n${await stdout.readAsString()}');
    }
    if (stderr != null && await stderr.exists()) {
      print('$label stderr:\n${await stderr.readAsString()}');
    }
  }
  await _printLogFragment('daemon', daemonLogFragment);
  await _printLogFragment('relay', relayLogFragment);
}

Future<void> _printLogFragment(String label, LogFragment? fragment) async {
  if (fragment == null) {
    return;
  }
  if (await fragment.stdoutFile.exists()) {
    print(
      '$label stdout fragment:\n${await fragment.stdoutFile.readAsString()}',
    );
  }
  if (await fragment.stderrFile.exists()) {
    print(
      '$label stderr fragment:\n${await fragment.stderrFile.readAsString()}',
    );
  }
}

Future<void> _stopLogFragmentQuietly(LogFragment? fragment) async {
  if (fragment == null) {
    return;
  }
  try {
    await fragment.stop();
  } catch (_) {
    // Best-effort cleanup for log followers; test failure logging is still useful.
  }
}

DockerImage _dockerImageForVersion({
  required RelayTestsContext context,
  required NoPortsVersion version,
}) {
  return context.dockerImages.firstWhere(
    (image) =>
        image.language == version.language && image.tag == version.version,
    orElse: () => throw Exception(
      'Docker image for language ${version.language.name} and version ${version.version} not found in dockerImages list',
    ),
  );
}

bool _supportsRelayCase(
  NoPortsVersion clientVersion,
  NoPortsVersion daemonVersion,
  NoPortsVersion relayVersion,
  NptRelayCase relayCase,
) {
  if (!relayCase.clientUses443) {
    return true;
  }
  final NoPortsVersion earliestEscr = NoPortsVersion(
    language: Language.dart,
    version: 'v5.10.0',
  );
  return versionIsAtLeast(clientVersion, earliestEscr) &&
      versionIsAtLeast(daemonVersion, earliestEscr) &&
      versionIsAtLeast(relayVersion, earliestEscr);
}

RelayTestResult _relayTestResult({
  required String testName,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required RelayInstanceCase relayInstanceCase,
  required NptRelayCase relayCase,
  required TestStatus status,
  required int exitCode,
}) {
  return RelayTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    relayVersion: relayInstanceCase.relayVersion,
    relayKind: 'self',
    relayAuthMode: relayCase.relayAuthMode,
    clientOnly443: relayCase.clientUses443,
    relayOnly443: relayInstanceCase.relayOnly443,
    caseName: relayCase.metadata,
    expectedSuccess: relayCase.expectSuccess,
    status: status,
    exitCode: exitCode,
  );
}

RelayTestResult _prodRelayTestResult({
  required String testName,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required NptRelayCase relayCase,
  required TestStatus status,
  required int exitCode,
}) {
  return RelayTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    relayVersion: null,
    relayKind: 'prod',
    relayAuthMode: relayCase.relayAuthMode,
    clientOnly443: relayCase.clientUses443,
    relayOnly443: false,
    caseName: relayCase.metadata,
    expectedSuccess: relayCase.expectSuccess,
    status: status,
    exitCode: exitCode,
  );
}

String _metadata({
  required RelayTestsContext context,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required RelayInstanceCase relayInstanceCase,
  required NptRelayCase relayCase,
}) {
  return sanitizeForDockerName(
    '${context.testRunId}_${relayCase.metadata}'
    '_${relayInstanceCase.metadata}'
    '_c_${clientVersion.language.name}_${clientVersion.version}'
    '_d_${daemonVersion.language.name}_${daemonVersion.version}',
    maxLength: 64,
  );
}

String _prodRelayMetadata({
  required RelayTestsContext context,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required NptRelayCase relayCase,
}) {
  return sanitizeForDockerName(
    '${context.testRunId}_${relayCase.metadata}'
    '_prod'
    '_c_${clientVersion.language.name}_${clientVersion.version}'
    '_d_${daemonVersion.language.name}_${daemonVersion.version}',
    maxLength: 64,
  );
}

String _daemonDeviceName(
  RelayTestsContext context,
  NoPortsVersion daemonVersion,
) {
  final String runId = sanitizeForDeviceName(context.testRunId, maxLength: 7);
  final String daemon =
      '${daemonVersion.language.name[0]}${_shortVersion(daemonVersion.version)}';
  return sanitizeForDeviceName('r${runId}_d$daemon', maxLength: 32);
}

String _extra({
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required RelayInstanceCase relayInstanceCase,
  required NptRelayCase relayCase,
}) {
  final String clientMode = relayCase.clientUses443
      ? '${relayCase.relayAuthMode},443'
      : relayCase.relayAuthMode;
  final String relayMode = relayInstanceCase.relayOnly443 ? '443' : 'normal';
  return '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, '
      'daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version}, '
      'relay: self:${relayInstanceCase.relayVersion.language.name[0]}:${relayInstanceCase.relayVersion.version}, '
      'case: ${relayCase.metadata}, clientMode: $clientMode, relayMode: $relayMode)';
}

String _prodRelayExtra({
  required RelayTestsContext context,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) {
  return '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, '
      'daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version}, '
      'relay: ${context.prodRelayAtsign})';
}

String _shortVersion(String version) {
  if (version == 'current') {
    return 'c';
  }
  return version.replaceAll(RegExp(r'[^0-9]'), '');
}

String _shellQuote(String value) {
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}
