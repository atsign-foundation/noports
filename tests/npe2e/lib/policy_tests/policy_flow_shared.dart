import 'dart:async';
import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:npe2e/client_binary.dart';
import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/docker_utils.dart';
import 'package:npe2e/log_fragment.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/policy_tests/policy_tests_context.dart';
import 'package:npe2e/policy_tests/policy_tests_logging.dart';
import 'package:npe2e/policy_tests/policy_tests_print_utils.dart';
import 'package:npe2e/policy_tests/policy_tests_test_result.dart';
import 'package:npe2e/process_utils.dart';
import 'package:npe2e/test_result.dart';
import 'package:noports_core/admin.dart' as admin;
import 'package:noports_core/npp.dart' as npp;
import 'package:path/path.dart' as path;

const String policyDeviceGroupName = '__none__';
const String policySshPermitOpen = 'localhost:22';
const String policyWrongPortPermitOpen = 'localhost:222';
const String policyDaemonDeniedPermitOpen = 'localhost:2233';
const Duration policyStageWait = Duration(seconds: 15);
const Duration policyNptRetryWait = Duration(seconds: 2);
const int policyNptMaxAttempts = 3;

abstract class PolicyRules {
  Future<void> clear();

  Future<List<String>> permitOpensFor({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
  });

  Future<void> allowPermitOpen({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
    required String permitOpen,
  });

  Future<void> close();
}

class NppPolicyRules implements PolicyRules {
  final npp.NppClient client;
  String? _clientId;
  String? _clientGroupId;
  String? _daemonId;
  String? _serviceId;
  final Set<String> _permitOpens = {};

  NppPolicyRules(this.client);

  @override
  Future<void> clear() async {
    final serviceACLs = await client.getAllServiceACLs();
    for (final acl in serviceACLs) {
      await client.deleteServiceACL(acl.id!);
    }
    final services = await client.getAllServices();
    for (final service in services) {
      await client.deleteService(service.id!);
    }
    final daemons = await client.getAllDaemons();
    for (final daemon in daemons) {
      await client.deleteDaemon(daemon.id!);
    }
    final members = await client.getAllClientGroupMembers();
    for (final member in members) {
      await client.deleteClientGroupMember(member.id!);
    }
    final groups = await client.getAllClientGroups();
    for (final group in groups) {
      await client.deleteClientGroup(group.id!);
    }
    final clients = await client.getAllClients();
    for (final policyClient in clients) {
      await client.deleteClient(policyClient.id!);
    }
    _clientId = null;
    _clientGroupId = null;
    _daemonId = null;
    _serviceId = null;
    _permitOpens.clear();
  }

  @override
  Future<List<String>> permitOpensFor({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
  }) async {
    final clients = await client.getAllClients();
    final clientIds = clients
        .where((policyClient) => policyClient.atSign == clientAtsign)
        .map((policyClient) => policyClient.id)
        .whereType<String>()
        .toSet();
    if (clientIds.isEmpty) {
      return const [];
    }

    final members = await client.getAllClientGroupMembers();
    final clientGroupIds = members
        .where((member) => clientIds.contains(member.clientId))
        .map((member) => member.clientGroupId)
        .toSet();
    if (clientGroupIds.isEmpty) {
      return const [];
    }

    final daemons = await client.getAllDaemons();
    final daemonIds = daemons
        .where((daemon) => daemon.atSign == daemonAtsign)
        .map((daemon) => daemon.id)
        .whereType<String>()
        .toSet();
    if (daemonIds.isEmpty) {
      return const [];
    }

    final services = await client.getAllServices();
    final serviceIds = services
        .where(
          (service) =>
              daemonIds.contains(service.daemonId) &&
              service.deviceName == deviceName &&
              service.deviceGroupName == policyDeviceGroupName,
        )
        .map((service) => service.id)
        .whereType<String>()
        .toSet();
    if (serviceIds.isEmpty) {
      return const [];
    }

    final serviceACLs = await client.getAllServiceACLs();
    return serviceACLs
        .where(
          (acl) =>
              serviceIds.contains(acl.serviceId) &&
              clientGroupIds.contains(acl.clientGroupId),
        )
        .map((acl) => acl.permitOpen)
        .toList();
  }

  @override
  Future<void> allowPermitOpen({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
    required String permitOpen,
  }) async {
    if (_clientId == null ||
        _clientGroupId == null ||
        _daemonId == null ||
        _serviceId == null) {
      _clientId = await client.putClient(
        npp.Client(name: clientAtsign, atSign: clientAtsign),
      );
      _clientGroupId = await client.putClientGroup(
        npp.ClientGroup(name: 'policy_e2e_clients'),
      );
      await client.putClientGroupMember(
        npp.ClientGroupMember(
          clientId: _clientId!,
          clientGroupId: _clientGroupId!,
        ),
      );
      _daemonId = await client.putDaemon(npp.Daemon(atSign: daemonAtsign));
      _serviceId = await client.putService(
        npp.Service(
          daemonId: _daemonId!,
          deviceName: deviceName,
          deviceGroupName: policyDeviceGroupName,
        ),
      );
    }
    if (!_permitOpens.add(permitOpen)) {
      return;
    }
    await client.putServiceACL(
      npp.ServiceACL(
        serviceId: _serviceId!,
        clientGroupId: _clientGroupId!,
        permitOpen: permitOpen,
      ),
    );
  }

  @override
  Future<void> close() async {}
}

class NppAtServerPolicyRules implements PolicyRules {
  final admin.PolicyServiceWithAtClient service;
  int _generation = 0;
  final Set<String> _permitOpens = {};

  NppAtServerPolicyRules(this.service);

  @override
  Future<void> clear() async {
    _permitOpens.clear();
    await _clearRemote();
  }

  Future<void> _clearRemote() async {
    final groups = await service.getUserGroups();
    for (final group in groups) {
      if (group.id != null) {
        await service.deleteUserGroup(group.id!);
      }
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  @override
  Future<List<String>> permitOpensFor({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
  }) async {
    final groups = await service.getUserGroups();
    final permitOpens = <String>[];
    for (final group in groups) {
      if (!group.userAtSigns.contains(clientAtsign) ||
          !group.daemonAtSigns.contains(daemonAtsign)) {
        continue;
      }
      for (final device in group.devices) {
        if (device.name == deviceName) {
          permitOpens.addAll(device.permitOpens);
        }
      }
      for (final deviceGroup in group.deviceGroups) {
        if (deviceGroup.name == policyDeviceGroupName) {
          permitOpens.addAll(deviceGroup.permitOpens);
        }
      }
    }
    return permitOpens;
  }

  @override
  Future<void> allowPermitOpen({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
    required String permitOpen,
  }) async {
    _permitOpens.add(permitOpen);
    await _clearRemote();
    _generation++;
    for (int i = 0; i < _generation; i++) {
      await service.createUserGroup(
        admin.UserGroup(
          name: 'policy_e2e_generation_$i',
          description: 'Policy e2e non-matching generation marker',
          userAtSigns: ['@policy_e2e_generation_$i'],
          daemonAtSigns: ['@policy_e2e_generation_$i'],
          devices: const [],
          deviceGroups: const [],
        ),
      );
    }
    await service.createUserGroup(
      admin.UserGroup(
        name: 'policy_e2e_clients',
        description: 'Policy e2e generated group',
        userAtSigns: [clientAtsign],
        daemonAtSigns: [daemonAtsign],
        devices: [
          admin.Device(name: deviceName, permitOpens: _permitOpens.toList()),
        ],
        deviceGroups: const [],
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  @override
  Future<void> close() async {}
}

Future<void> _checkPolicyRules({
  required PolicyRules policyRules,
  required String clientAtsign,
  required String daemonAtsign,
  required String deviceName,
  required String? expectedPermitOpen,
  Set<String>? expectedPermitOpens,
  required String stage,
  bool allowAny = false,
}) async {
  final permitOpens = await policyRules.permitOpensFor(
    clientAtsign: clientAtsign,
    daemonAtsign: daemonAtsign,
    deviceName: deviceName,
  );
  final actual = permitOpens.toSet();
  if (allowAny) {
    return;
  }
  final expected =
      expectedPermitOpens ??
      (expectedPermitOpen == null
          ? const <String>{}
          : <String>{expectedPermitOpen});
  if (actual.length == expected.length && actual.containsAll(expected)) {
    return;
  }
  throw StateError(
    'Policy rule check failed ($stage) for client=$clientAtsign '
    'daemon=$daemonAtsign device=$deviceName. '
    'Expected permitOpen=$expected but found $actual',
  );
}

Future<AtClient> createPolicyAtClient({
  required String atsign,
  required File apkamKeysFile,
  required String rootDomain,
  required Directory storageDirectory,
}) async {
  final AtRootDomain parsedRootDomain = AtRootDomain.parse(rootDomain);
  final AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = storageDirectory.path
    ..namespace = 'sshnp'
    ..downloadPath = path.join(storageDirectory.path, 'downloads')
    // ignore: deprecated_member_use
    ..isLocalStoreRequired = true
    ..commitLogPath = path.join(storageDirectory.path, 'commitLog')
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = apkamKeysFile.path
    ..passPhrase = ''
    ..rootDomain = parsedRootDomain.rootDomain
    ..rootPort = parsedRootDomain.rootPort;

  final onboardingService = AtOnboardingServiceImpl(
    atsign,
    atOnboardingConfig,
    atServiceFactory: ServiceFactoryWithNoOpSyncService(),
  );

  await onboardingService.authenticate();
  return AtClientManager.getInstance().atClient;
}

Future<PolicyTestResult> runPolicyFlow({
  required PolicyTestsContext context,
  required PolicyTestLogger testLogger,
  required String testName,
  required String policyLabel,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required NoPortsVersion policyVersion,
  required String policyManagerAtsign,
  required PolicyRules policyRules,
  required DockerInstance policyServer,
}) async {
  DockerInstance? daemon;
  try {
    final String deviceName = getPolicyFlowDeviceName(
      context: context,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyLabel: policyLabel,
    );
    daemon = await startPolicyFlowDaemon(
      context: context,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      clientVersion: clientVersion,
      policyLabel: policyLabel,
      policyManagerAtsign: policyManagerAtsign,
      deviceName: deviceName,
    );

    await _checkPolicyRules(
      policyRules: policyRules,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: null,
      stage: 'initial check',
      allowAny: true,
    );
    await policyRules.clear();
    await _checkPolicyRules(
      policyRules: policyRules,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: null,
      stage: 'after initial teardown',
    );
    await _waitBeforePolicyStage();
    final result1 = await runNptPolicyExpectation(
      context: context,
      testLogger: testLogger,
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: 22,
      expectSuccess: false,
      metadata: '01_no_rules',
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    if (result1 != null) return result1;

    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policyWrongPortPermitOpen,
    );
    await _checkPolicyRules(
      policyRules: policyRules,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: policyWrongPortPermitOpen,
      stage: 'after wrong-port put',
    );
    await _waitBeforePolicyStage();
    final result2 = await runNptPolicyExpectation(
      context: context,
      testLogger: testLogger,
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: 22,
      expectSuccess: false,
      metadata: '02_wrong_policy_port',
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    if (result2 != null) return result2;

    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policySshPermitOpen,
    );
    await _checkPolicyRules(
      policyRules: policyRules,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: policySshPermitOpen,
      expectedPermitOpens: {policyWrongPortPermitOpen, policySshPermitOpen},
      stage: 'after allowed put',
    );
    await _waitBeforePolicyStage();
    final result3 = await runNptPolicyExpectation(
      context: context,
      testLogger: testLogger,
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: 22,
      expectSuccess: true,
      metadata: '03_allowed',
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    if (result3 != null) return result3;

    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policyDaemonDeniedPermitOpen,
    );
    await _checkPolicyRules(
      policyRules: policyRules,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: policyDaemonDeniedPermitOpen,
      expectedPermitOpens: {
        policyWrongPortPermitOpen,
        policySshPermitOpen,
        policyDaemonDeniedPermitOpen,
      },
      stage: 'after daemon-denied put',
    );
    await _waitBeforePolicyStage();
    final result4 = await runNptPolicyExpectation(
      context: context,
      testLogger: testLogger,
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: 2233,
      expectSuccess: false,
      metadata: '04_daemon_permit_open_denied',
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    if (result4 != null) return result4;

    final policyTestResult = PolicyTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      status: TestStatus.passed,
      exitCode: 0,
    );
    return policyTestResult;
  } catch (e, st) {
    stderr.writeln(e);
    stderr.writeln(st);
    final List<String> logFilePaths = [];
    if (daemon?.stdoutLogFile != null) {
      logFilePaths.add(daemon!.stdoutLogFile!.path);
    }
    if (daemon?.stderrLogFile != null) {
      logFilePaths.add(daemon!.stderrLogFile!.path);
    }
    return PolicyTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      status: TestStatus.failed,
      exitCode: 1,
      failureReason: e.toString(),
      logFilePaths: logFilePaths,
    );
  } finally {
    try {
      await policyRules.clear();
    } catch (e) {
      print(
        '  ⚠ Warning: policyRules.clear() failed during teardown for $testName: $e',
      );
    }
    await policyRules.close();
    if (daemon != null) {
      await daemon.stopAllLogFragments();
      await daemon.stop();
    }
  }
}

String getPolicyFlowDeviceName({
  required PolicyTestsContext context,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required String policyLabel,
}) {
  final runId = _deviceNamePart(context.testRunId, maxLength: 8);
  final label = policyLabel == 'npp_atserver' ? 'nppas' : policyLabel;
  final clientVersionPart = _deviceNamePart(clientVersion.version);
  final daemonVersionPart = _deviceNamePart(daemonVersion.version);
  return '${runId}_${label}_'
      '${clientVersion.language.name[0]}$clientVersionPart'
      '_${daemonVersion.language.name[0]}$daemonVersionPart';
}

String _deviceNamePart(String value, {int maxLength = 6}) {
  final cleaned = value == 'current'
      ? 'c'
      : value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  if (cleaned.length <= maxLength) {
    return cleaned.toLowerCase();
  }
  return cleaned.substring(0, maxLength).toLowerCase();
}

Future<DockerInstance> startPolicyFlowDaemon({
  required PolicyTestsContext context,
  required NoPortsVersion daemonVersion,
  required NoPortsVersion policyVersion,
  required NoPortsVersion clientVersion,
  required String policyLabel,
  required String policyManagerAtsign,
  required String deviceName,
}) async {
  final DockerImage dockerImage = context.dockerImages.firstWhere(
    (image) =>
        image.language == daemonVersion.language &&
        image.tag == daemonVersion.version,
    orElse: () => throw Exception(
      'Docker image for language ${daemonVersion.language.name} and version ${daemonVersion.version} not found in dockerImages list',
    ),
  );
  final File daemonApkamKeysFile = context.apkamKeys[context.daemonAtsign]!;
  final String daemonAtsignContainerKeyFilePath =
      '/atsign/.atsign/keys/${path.basename(daemonApkamKeysFile.path)}';

  final DockerInstance daemon = await runDockerInstance(
    dockerImage: dockerImage,
    testRunId: context.testRunId,
    logsDirectory: context.daemonLogsDirectory,
    uniqueIdentifier:
        '_daemon_$policyLabel'
        '_${clientVersion.language.name}_${clientVersion.version}'
        '_${daemonVersion.language.name}_${daemonVersion.version}'
        '_${policyVersion.language.name}_${policyVersion.version}',
    entrypoint: [
      '/bin/bash',
      '-c',
      'sudo service ssh start && '
          '/usr/local/bin/sshnpd '
          '-a ${context.daemonAtsign} '
          '-p $policyManagerAtsign '
          '-k $daemonAtsignContainerKeyFilePath '
          '--root-domain ${context.rootDomain} '
          '-d $deviceName '
          '--permit-open "$policySshPermitOpen" '
          '-v -s -u',
    ],
    printCommand: false,
    // Local-run aid: let the container resolve *.atsign.zone back to the host.
    additionalDockerArgs: hostGatewayAddHostArgs(),
    volumeMappings: [
      VolumeMapping(
        local: daemonApkamKeysFile.absolute.path,
        container: daemonAtsignContainerKeyFilePath,
      ),
    ],
  );
  try {
    await waitForLogMessage(daemon, 'Daemon is running');
  } catch (e) {
    await daemon.stop();
    rethrow;
  }
  return daemon;
}

Future<PolicyTestResult?> runNptPolicyExpectation({
  required PolicyTestsContext context,
  required PolicyTestLogger testLogger,
  required String testName,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required NoPortsVersion policyVersion,
  required DockerInstance daemon,
  required String deviceName,
  required int remotePort,
  required bool expectSuccess,
  required String metadata,
  required String policyLabel,
  required DockerInstance policyServer,
}) async {
  final ClientBinary nptClientBinary = context.clientBinaries.firstWhere(
    (cb) =>
        cb.binaryType == ClientBinaryType.npt &&
        cb.noPortsVersion == clientVersion,
  );
  ProcessOutputCapture? lastNptOutput;
  LogFragment? lastDaemonLogFragment;
  LogFragment? lastPolicyLogFragment;
  String lastMetadata = metadata;
  int lastExitCode = 1;

  for (var attempt = 1; attempt <= policyNptMaxAttempts; attempt++) {
    final attemptMetadata = _attemptMetadata(metadata, attempt);
    lastMetadata = attemptMetadata;
    final attemptResult = await _runPolicyConnectionAttempt(
      context: context,
      testLogger: testLogger,
      nptClientBinary: nptClientBinary,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: remotePort,
      attemptMetadata: attemptMetadata,
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    lastNptOutput = attemptResult.nptOutput;
    lastDaemonLogFragment = attemptResult.daemonLogFragment;
    lastPolicyLogFragment = attemptResult.policyLogFragment;
    lastExitCode = attemptResult.exitCode;

    final bool passed = expectSuccess
        ? attemptResult.exitCode == 0
        : attemptResult.exitCode != 0;
    if (passed) {
      return null;
    }

    final bool willRetry = attempt < policyNptMaxAttempts;
    print(
      '  ✗ [$testName $attemptMetadata] npt exited ${attemptResult.exitCode} '
      '(attempt $attempt/$policyNptMaxAttempts)${willRetry ? ", retrying..." : ""}',
    );
    if (willRetry && context.verbose) {
      printClientLogs(attemptResult.nptOutput, label: '${attemptMetadata}_npt');
      printDaemonLogFragments(
        attemptResult.daemonLogFragment,
        label: attemptMetadata,
      );
      printPolicyLogFragments(
        attemptResult.policyLogFragment,
        label: attemptMetadata,
      );
    }

    if (willRetry) {
      await Future<void>.delayed(policyNptRetryWait);
    }
  }

  final List<String> logFilePaths = [
    if (lastNptOutput?.stdoutLogFile != null)
      lastNptOutput!.stdoutLogFile!.path,
    if (lastNptOutput?.stderrLogFile != null)
      lastNptOutput!.stderrLogFile!.path,
    lastDaemonLogFragment!.stdoutFile.path,
    lastDaemonLogFragment.stderrFile.path,
    lastPolicyLogFragment!.stdoutFile.path,
    lastPolicyLogFragment.stderrFile.path,
  ];
  final policyTestResult = PolicyTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    policyVersion: policyVersion,
    status: TestStatus.failed,
    exitCode: lastExitCode,
    failureReason:
        'npt exited with code $lastExitCode (expected '
        '${expectSuccess ? "0" : "non-zero"}) at stage "$metadata" '
        'after $policyNptMaxAttempts attempt(s)',
    logFilePaths: logFilePaths,
  );
  printClientLogs(lastNptOutput!, label: '${lastMetadata}_npt');
  printDaemonLogFragments(lastDaemonLogFragment, label: lastMetadata);
  printPolicyLogFragments(lastPolicyLogFragment, label: lastMetadata);
  return policyTestResult;
}

Future<
  ({
    ProcessOutputCapture nptOutput,
    LogFragment daemonLogFragment,
    LogFragment policyLogFragment,
    int exitCode,
  })
>
_runPolicyConnectionAttempt({
  required PolicyTestsContext context,
  required PolicyTestLogger testLogger,
  required ClientBinary nptClientBinary,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required NoPortsVersion policyVersion,
  required DockerInstance daemon,
  required String deviceName,
  required int remotePort,
  required String attemptMetadata,
  required String policyLabel,
  required DockerInstance policyServer,
}) async {
  final LogFragment daemonLogFragment = daemon.createLogFragment(
    stdoutFile: testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: attemptMetadata,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: attemptMetadata,
    ),
    printCommand: false,
  );
  final LogFragment policyLogFragment = policyServer.createLogFragment(
    stdoutFile: testLogger.getPolicyStdoutLogFile(
      policyVersion: policyVersion,
      policyName: policyLabel,
      testMetadata: attemptMetadata,
    ),
    stderrFile: testLogger.getPolicyStderrLogFile(
      policyVersion: policyVersion,
      policyName: policyLabel,
      testMetadata: attemptMetadata,
    ),
    printCommand: false,
  );
  daemonLogFragment.start();
  policyLogFragment.start();
  final ProcessOutputCapture nptOutput = await startCommandWithCapture(
    nptClientBinary.file.path,
    _buildNptArgs(
      context: context,
      clientVersion: clientVersion,
      deviceName: deviceName,
      remotePort: remotePort,
    ),
    printCommand: false,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      testMetadata: '${attemptMetadata}_npt',
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      testMetadata: '${attemptMetadata}_npt',
    ),
  );
  final int nptExitCode = await nptOutput.exitCode.timeout(
    const Duration(seconds: 45),
    onTimeout: () {
      nptOutput.process.kill(ProcessSignal.sigterm);
      return 124;
    },
  );
  await daemonLogFragment.stop();
  await policyLogFragment.stop();
  return (
    nptOutput: nptOutput,
    daemonLogFragment: daemonLogFragment,
    policyLogFragment: policyLogFragment,
    exitCode: nptExitCode,
  );
}

String _attemptMetadata(String metadata, int attempt) {
  if (attempt == 1) {
    return metadata;
  }
  return '${metadata}_attempt_$attempt';
}

Future<void> _waitBeforePolicyStage() async {
  await Future<void>.delayed(policyStageWait);
}

List<String> _buildNptArgs({
  required PolicyTestsContext context,
  required NoPortsVersion clientVersion,
  required String deviceName,
  required int remotePort,
}) {
  final args = [
    '-f',
    context.clientAtsign,
    '-t',
    context.daemonAtsign,
    '-d',
    deviceName,
    '-r',
    context.relayAtsign,
    '--root-domain',
    context.rootDomain,
    '--remote-port',
    remotePort.toString(),
    '--exit-when-connected',
    '--verbose',
  ];
  if (versionIsAtLeast(
    clientVersion,
    NoPortsVersion(language: Language.dart, version: 'v5.3.0'),
  )) {
    args.add('-k');
    args.add(context.apkamKeys[context.clientAtsign]!.path);
  }
  return args;
}

Future<void> waitForLogMessage(
  DockerInstance dockerInstance,
  String message, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final stopwatch = Stopwatch()..start();
  String lastStdoutText = '';
  String lastStderrText = '';
  while (stopwatch.elapsed < timeout) {
    final stdout = dockerInstance.stdoutLogFile;
    final stderr = dockerInstance.stderrLogFile;
    lastStdoutText = stdout != null && await stdout.exists()
        ? await stdout.readAsString()
        : '';
    lastStderrText = stderr != null && await stderr.exists()
        ? await stderr.readAsString()
        : '';
    if (lastStdoutText.contains(message) || lastStderrText.contains(message)) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw TimeoutException(
    'Did not find "$message" in ${dockerInstance.containerName} logs within $timeout.'
    '\nstdout:\n$lastStdoutText'
    '\nstderr:\n$lastStderrText',
  );
}
