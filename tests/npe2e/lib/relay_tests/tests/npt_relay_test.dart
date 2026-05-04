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
const String _remoteUsername = 'atsign';
const String _payloadMode = 'payload';
const String _escrMode = 'escr';

enum RelayKind { prod, self }

class RelayCase {
  final RelayKind relayKind;
  final String relayAuthMode;
  final bool only443;
  final NoPortsVersion? relayVersion;
  final DockerInstance? relayInstance;
  final String relayAtsign;
  final String? relayAlias;
  final String metadata;

  const RelayCase({
    required this.relayKind,
    required this.relayAuthMode,
    required this.only443,
    required this.relayVersion,
    required this.relayInstance,
    required this.relayAtsign,
    required this.relayAlias,
    required this.metadata,
  });

  String get optionName {
    final String relay = relayKind == RelayKind.prod ? 'prod' : 'self';
    final String port = only443 ? '_443' : '';
    return '${relay}_${relayAuthMode}$port';
  }
}

class RelayDaemonTarget {
  final NoPortsVersion daemonVersion;
  final RelayCase relayCase;
  final String deviceName;
  final DockerInstance daemonInstance;

  const RelayDaemonTarget({
    required this.daemonVersion,
    required this.relayCase,
    required this.deviceName,
    required this.daemonInstance,
  });
}

class NptRelayEnvironment {
  final String networkName;
  final List<RelayDaemonTarget> daemonTargets;
  final List<RelayCase> relayCases;

  const NptRelayEnvironment({
    required this.networkName,
    required this.daemonTargets,
    required this.relayCases,
  });
}

class _SelfRelayPlan {
  final NoPortsVersion relayVersion;
  final String relayAtsign;
  final String relayAuthMode;
  final bool only443;

  const _SelfRelayPlan({
    required this.relayVersion,
    required this.relayAtsign,
    required this.relayAuthMode,
    required this.only443,
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

  final List<RelayCase> relayCases = [
    RelayCase(
      relayKind: RelayKind.prod,
      relayAuthMode: _payloadMode,
      only443: false,
      relayVersion: null,
      relayInstance: null,
      relayAtsign: context.prodRelayAtsign,
      relayAlias: null,
      metadata: 'prod_payload',
    ),
    RelayCase(
      relayKind: RelayKind.prod,
      relayAuthMode: _escrMode,
      only443: false,
      relayVersion: null,
      relayInstance: null,
      relayAtsign: context.prodRelayAtsign,
      relayAlias: null,
      metadata: 'prod_escr',
    ),
    RelayCase(
      relayKind: RelayKind.prod,
      relayAuthMode: _escrMode,
      only443: true,
      relayVersion: null,
      relayInstance: null,
      relayAtsign: context.prodRelayAtsign,
      relayAlias: null,
      metadata: 'prod_escr_443',
    ),
  ];

  final List<_SelfRelayPlan> selfRelayPlans = _selfRelayPlans(
    context: context,
    selfRelayVersions: selfRelayVersions,
  );
  final List<RelayCase> selfRelayCases = await Future.wait([
    for (final _SelfRelayPlan plan in selfRelayPlans)
      _startSelfRelayCase(
        context: context,
        testLogger: testLogger,
        relayVersion: plan.relayVersion,
        relayAtsign: plan.relayAtsign,
        relayAuthMode: plan.relayAuthMode,
        only443: plan.only443,
        networkName: networkName,
      ),
  ]);
  relayCases.addAll(selfRelayCases);

  final List<RelayDaemonTarget> daemonTargets = await Future.wait([
    for (final NoPortsVersion daemonVersion in daemonVersions)
      for (final RelayCase relayCase in relayCases)
        _startDaemonTarget(
          context: context,
          testLogger: testLogger,
          daemonVersion: daemonVersion,
          relayCase: relayCase,
          networkName: networkName,
        ),
  ]);

  return NptRelayEnvironment(
    networkName: networkName,
    daemonTargets: daemonTargets,
    relayCases: relayCases,
  );
}

Future<void> stopNptRelayEnvironment(NptRelayEnvironment? environment) async {
  if (environment == null) {
    return;
  }
  await Future.wait([
    for (final RelayDaemonTarget daemonTarget in environment.daemonTargets)
      stopDockerInstanceQuietly(daemonTarget.daemonInstance),
    for (final RelayCase relayCase in environment.relayCases)
      stopDockerInstanceQuietly(relayCase.relayInstance),
  ]);
  await removeDockerNetwork(environment.networkName);
}

List<_SelfRelayPlan> _selfRelayPlans({
  required RelayTestsContext context,
  required List<NoPortsVersion> selfRelayVersions,
}) {
  final List<_SelfRelayPlan> plans = [];
  int atsignIndex = 0;
  for (final NoPortsVersion selfRelayVersion in selfRelayVersions) {
    for (final (String relayAuthMode, bool only443) in const [
      (_payloadMode, false),
      (_escrMode, false),
      (_escrMode, true),
    ]) {
      plans.add(
        _SelfRelayPlan(
          relayVersion: selfRelayVersion,
          relayAtsign: context.selfRelayAtsigns[atsignIndex],
          relayAuthMode: relayAuthMode,
          only443: only443,
        ),
      );
      atsignIndex++;
    }
  }
  return plans;
}

List<Future<RelayTestResult> Function()> runNptRelayTests({
  required RelayTestsContext context,
  required NptRelayEnvironment environment,
  required List<NoPortsVersion> clientVersions,
}) {
  final RelayTestLogger testLogger = RelayTestLogger(
    logsDirectory: context.logsDirectory,
    testName: nptRelayTestName,
  );
  final List<Future<RelayTestResult> Function()> testFactories = [];

  for (final NoPortsVersion clientVersion in clientVersions) {
    for (final RelayDaemonTarget daemonTarget in environment.daemonTargets) {
      if (!_supportsRelayCase(
        clientVersion,
        daemonTarget.daemonVersion,
        daemonTarget.relayCase,
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
          relayCase: daemonTarget.relayCase,
        ),
      );
    }
  }

  return testFactories;
}

Future<RelayDaemonTarget> _startDaemonTarget({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion daemonVersion,
  required RelayCase relayCase,
  required String networkName,
}) async {
  final String deviceName = _daemonDeviceName(
    context,
    daemonVersion,
    relayCase,
  );
  final DockerInstance daemon = await _startDaemon(
    context: context,
    testLogger: testLogger,
    daemonVersion: daemonVersion,
    relayCase: relayCase,
    networkName: networkName,
    deviceName: deviceName,
  );
  await waitForLogMessage(daemon, 'monitor started');
  return RelayDaemonTarget(
    daemonVersion: daemonVersion,
    relayCase: relayCase,
    deviceName: deviceName,
    daemonInstance: daemon,
  );
}

Future<RelayCase> _startSelfRelayCase({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion relayVersion,
  required String relayAtsign,
  required String relayAuthMode,
  required bool only443,
  required String networkName,
}) async {
  final String metadata = sanitizeForDockerName(
    'self_${relayAuthMode}${only443 ? '_443' : ''}'
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
    relayAuthMode: relayAuthMode,
    only443: only443,
    networkName: networkName,
    relayAlias: relayAlias,
    metadata: metadata,
  );
  await waitForLogMessage(relay, 'monitor started');
  return RelayCase(
    relayKind: RelayKind.self,
    relayAuthMode: relayAuthMode,
    only443: only443,
    relayVersion: relayVersion,
    relayInstance: relay,
    relayAtsign: relayAtsign,
    relayAlias: relayAlias,
    metadata: metadata,
  );
}

Future<RelayTestResult> _runNptRelayTest({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NptRelayEnvironment environment,
  required NoPortsVersion clientVersion,
  required RelayDaemonTarget daemonTarget,
  required RelayCase relayCase,
}) async {
  final String metadata = _metadata(
    context: context,
    clientVersion: clientVersion,
    daemonVersion: daemonTarget.daemonVersion,
    relayCase: relayCase,
  );
  final String extra = _extra(
    clientVersion: clientVersion,
    daemonVersion: daemonTarget.daemonVersion,
    relayCase: relayCase,
  );
  printTestStart(testName: nptRelayTestName, extra: extra);

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
        relayCase: relayCase,
        metadata: attemptMetadata,
      );
      await daemonLogFragment.start();
      await relayLogFragment?.start();
      client = await _runClientCommand(
        context: context,
        testLogger: testLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonTarget.daemonVersion,
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
      await relayLogFragment?.stop();
      if (exitCode == 0 || attempt == 2) {
        break;
      }
      print(
        'Retrying $nptRelayTestName $extra after client command exit code $exitCode',
      );
      await stopDockerInstanceQuietly(client);
      client = null;
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    final RelayTestResult result = RelayTestResult(
      testName: nptRelayTestName,
      clientVersion: clientVersion,
      daemonVersion: daemonTarget.daemonVersion,
      relayVersion: relayCase.relayVersion,
      relayKind: relayCase.relayKind.name,
      relayAuthMode: relayCase.relayAuthMode,
      only443: relayCase.only443,
      status: exitCode == 0 ? TestStatus.passed : TestStatus.failed,
      exitCode: exitCode,
    );
    printTestResult(testResult: result, extra: extra);
    if (exitCode != 0) {
      await _printFailureLogs(
        client,
        daemonTarget.daemonInstance,
        relayCase,
        daemonLogFragment: daemonLogFragment,
        relayLogFragment: relayLogFragment,
      );
    }
    return result;
  } catch (e) {
    await _stopLogFragmentQuietly(daemonLogFragment);
    await _stopLogFragmentQuietly(relayLogFragment);
    final RelayTestResult result = RelayTestResult(
      testName: nptRelayTestName,
      clientVersion: clientVersion,
      daemonVersion: daemonTarget.daemonVersion,
      relayVersion: relayCase.relayVersion,
      relayKind: relayCase.relayKind.name,
      relayAuthMode: relayCase.relayAuthMode,
      only443: relayCase.only443,
      status: TestStatus.failed,
      exitCode: 1,
    );
    printTestResult(testResult: result, extra: extra);
    print('Relay test exception: $e');
    await _printFailureLogs(
      client,
      daemonTarget.daemonInstance,
      relayCase,
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

Future<DockerInstance> _startDaemon({
  required RelayTestsContext context,
  required RelayTestLogger testLogger,
  required NoPortsVersion daemonVersion,
  required RelayCase relayCase,
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
        '_relay_daemon_${daemonVersion.language.name}_${daemonVersion.version}_${relayCase.metadata}',
    networkName: networkName,
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
  required String relayAuthMode,
  required bool only443,
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
    if (only443) ...['--443'],
  ];
  return runDockerInstance(
    dockerImage: dockerImage,
    testRunId: context.testRunId,
    logsDirectory: testLogger.relaysDirectory,
    uniqueIdentifier:
        '_relay_${relayVersion.language.name}_${relayVersion.version}_$metadata',
    networkName: networkName,
    networkAlias: relayAlias,
    additionalDockerArgs: only443 ? ['--user', 'root'] : const [],
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

LogFragment? _createRelayLogFragment({
  required RelayTestLogger testLogger,
  required RelayCase relayCase,
  required String metadata,
}) {
  if (relayCase.relayInstance == null || relayCase.relayVersion == null) {
    return null;
  }
  return relayCase.relayInstance!.createLogFragment(
    stdoutFile: testLogger.getRelayStdoutLogFile(
      relayVersion: relayCase.relayVersion!,
      relayKind: relayCase.relayKind.name,
      testMetadata: metadata,
    ),
    stderrFile: testLogger.getRelayStderrLogFile(
      relayVersion: relayCase.relayVersion!,
      relayKind: relayCase.relayKind.name,
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
  required RelayCase relayCase,
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
    relayCase: relayCase,
    deviceName: deviceName,
    clientKeyPath: containerKeyFilePath,
  );
  final DockerInstance dockerInstance = DockerInstance(
    dockerImage: dockerImage,
    testRunId: context.testRunId,
    uniqueIdentifier:
        '_client_${daemonVersion.language.name}_${daemonVersion.version}'
        '_${relayCase.relayVersion == null ? 'prod' : '${relayCase.relayVersion!.language.name}_${relayCase.relayVersion!.version}'}'
        '_${relayCase.optionName}',
  );
  return dockerInstance
      .run(
        networkName: networkName,
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
          relayVersion: relayCase.relayVersion,
          testMetadata: metadata,
        ),
        stderrLogFile: testLogger.getClientStderrLogFile(
          clientVersion: clientVersion,
          daemonVersion: daemonVersion,
          relayVersion: relayCase.relayVersion,
          testMetadata: metadata,
        ),
      )
      .then((_) => dockerInstance);
}

String _clientScript({
  required RelayTestsContext context,
  required RelayCase relayCase,
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
    relayCase.relayAtsign,
    '--root-domain',
    context.rootDomain,
    '--remote-port',
    '22',
    '--exit-when-connected',
    '--verbose',
    '-k',
    clientKeyPath,
    if (relayCase.relayAuthMode == _escrMode) ...['--relay-auth-mode', 'escr'],
    if (relayCase.only443) '--443',
  ];
  final String nptCommand = nptArgs.map(_shellQuote).join(' ');
  return '''
set -e
PORT=\$($nptCommand)
echo "npt local port: \$PORT"
ssh -p "\$PORT" -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i /atsign/.ssh/id_ed25519 $_remoteUsername@localhost echo TEST PASSED
''';
}

Future<void> _printFailureLogs(
  DockerInstance? client,
  DockerInstance daemon,
  RelayCase relayCase, {
  LogFragment? daemonLogFragment,
  LogFragment? relayLogFragment,
}) async {
  for (final (String label, DockerInstance? instance) in [
    ('client', client),
    ('daemon', daemon),
    ('relay', relayCase.relayInstance),
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
  RelayCase relayCase,
) {
  if (relayCase.relayAuthMode == _payloadMode) {
    return !relayCase.only443;
  }
  final NoPortsVersion earliestEscr = NoPortsVersion(
    language: Language.dart,
    version: 'v5.10.0',
  );
  return versionIsAtLeast(clientVersion, earliestEscr) &&
      versionIsAtLeast(daemonVersion, earliestEscr);
}

String _metadata({
  required RelayTestsContext context,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required RelayCase relayCase,
}) {
  return sanitizeForDockerName(
    '${context.testRunId}_${relayCase.metadata}'
    '_c_${clientVersion.language.name}_${clientVersion.version}'
    '_d_${daemonVersion.language.name}_${daemonVersion.version}',
    maxLength: 64,
  );
}

String _daemonDeviceName(
  RelayTestsContext context,
  NoPortsVersion daemonVersion,
  RelayCase relayCase,
) {
  return sanitizeForDeviceName(
    'r${context.testRunId}'
    'd${daemonVersion.language.name[0]}${_shortVersion(daemonVersion.version)}'
    '_${relayCase.metadata}',
    maxLength: 32,
  );
}

String _extra({
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required RelayCase relayCase,
}) {
  final String relay = relayCase.relayVersion == null
      ? 'prod'
      : '${relayCase.relayVersion!.language.name[0]}:${relayCase.relayVersion!.version}';
  final String mode = relayCase.only443
      ? '${relayCase.relayAuthMode},443'
      : relayCase.relayAuthMode;
  return '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, '
      'daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version}, '
      'relay: ${relayCase.relayKind.name}:$relay, mode: $mode)';
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
