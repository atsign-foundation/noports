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
import 'package:npe2e/transcript.dart';
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
const Duration policyAdminRpcTimeout = Duration(seconds: 20);
const int policyAdminRpcMaxAttempts = 3;

/// How long a single npt attempt may take before it is killed. Hitting this is
/// always a failure, never a policy denial.
const Duration nptAttemptTimeout = Duration(seconds: 45);

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
  final Transcript transcript;
  String? _clientId;
  String? _clientGroupId;
  String? _daemonId;
  String? _serviceId;
  final Set<String> _permitOpens = {};

  NppPolicyRules(this.client, {required this.transcript});

  Future<T> _nppAdminRpc<T>(String operation, Future<T> Function() send) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await send().timeout(policyAdminRpcTimeout);
      } on TimeoutException {
        transcript.warn(
          'npp admin RPC "$operation" timed out after '
          '${policyAdminRpcTimeout.inSeconds}s '
          '(attempt $attempt/$policyAdminRpcMaxAttempts)',
        );
        if (attempt >= policyAdminRpcMaxAttempts) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<void> clear() async {
    // Deleting an id the server no longer has throws server-side, so a
    // delete whose response was lost must not be blindly resent. Instead,
    // retry the whole pass: it re-fetches the surviving ids each time, so
    // repeating it is idempotent.
    for (var attempt = 1; ; attempt++) {
      try {
        await _clearOnce();
        break;
      } on TimeoutException {
        transcript.warn(
          'npp admin clear() pass timed out '
          '(attempt $attempt/$policyAdminRpcMaxAttempts)',
        );
        if (attempt >= policyAdminRpcMaxAttempts) {
          rethrow;
        }
      }
    }
    _clientId = null;
    _clientGroupId = null;
    _daemonId = null;
    _serviceId = null;
    _permitOpens.clear();
  }

  Future<void> _clearOnce() async {
    final serviceACLs = await client.getAllServiceACLs().timeout(
      policyAdminRpcTimeout,
    );
    for (final acl in serviceACLs) {
      await client.deleteServiceACL(acl.id!).timeout(policyAdminRpcTimeout);
    }
    final services = await client.getAllServices().timeout(
      policyAdminRpcTimeout,
    );
    for (final service in services) {
      await client.deleteService(service.id!).timeout(policyAdminRpcTimeout);
    }
    final daemons = await client.getAllDaemons().timeout(policyAdminRpcTimeout);
    for (final daemon in daemons) {
      await client.deleteDaemon(daemon.id!).timeout(policyAdminRpcTimeout);
    }
    final members = await client.getAllClientGroupMembers().timeout(
      policyAdminRpcTimeout,
    );
    for (final member in members) {
      await client
          .deleteClientGroupMember(member.id!)
          .timeout(policyAdminRpcTimeout);
    }
    final groups = await client.getAllClientGroups().timeout(
      policyAdminRpcTimeout,
    );
    for (final group in groups) {
      await client.deleteClientGroup(group.id!).timeout(policyAdminRpcTimeout);
    }
    final clients = await client.getAllClients().timeout(policyAdminRpcTimeout);
    for (final policyClient in clients) {
      await client
          .deleteClient(policyClient.id!)
          .timeout(policyAdminRpcTimeout);
    }
  }

  @override
  Future<List<String>> permitOpensFor({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
  }) async {
    final clients = await _nppAdminRpc(
      'getAllClients',
      () => client.getAllClients(),
    );
    final clientIds = clients
        .where((policyClient) => policyClient.atSign == clientAtsign)
        .map((policyClient) => policyClient.id)
        .whereType<String>()
        .toSet();
    if (clientIds.isEmpty) {
      return const [];
    }

    final members = await _nppAdminRpc(
      'getAllClientGroupMembers',
      () => client.getAllClientGroupMembers(),
    );
    final clientGroupIds = members
        .where((member) => clientIds.contains(member.clientId))
        .map((member) => member.clientGroupId)
        .toSet();
    if (clientGroupIds.isEmpty) {
      return const [];
    }

    final daemons = await _nppAdminRpc(
      'getAllDaemons',
      () => client.getAllDaemons(),
    );
    final daemonIds = daemons
        .where((daemon) => daemon.atSign == daemonAtsign)
        .map((daemon) => daemon.id)
        .whereType<String>()
        .toSet();
    if (daemonIds.isEmpty) {
      return const [];
    }

    final services = await _nppAdminRpc(
      'getAllServices',
      () => client.getAllServices(),
    );
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

    final serviceACLs = await _nppAdminRpc(
      'getAllServiceACLs',
      () => client.getAllServiceACLs(),
    );
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
    // A resent put whose original succeeded (response lost) creates a
    // duplicate entity. That is benign here: permitOpensFor collects every
    // matching id, the rule checks compare sets, and clear() deletes
    // everything it can find.
    if (_clientId == null ||
        _clientGroupId == null ||
        _daemonId == null ||
        _serviceId == null) {
      _clientId = await _nppAdminRpc(
        'putClient',
        () => client.putClient(
          npp.Client(name: clientAtsign, atSign: clientAtsign),
        ),
      );
      _clientGroupId = await _nppAdminRpc(
        'putClientGroup',
        () =>
            client.putClientGroup(npp.ClientGroup(name: 'policy_e2e_clients')),
      );
      await _nppAdminRpc(
        'putClientGroupMember',
        () => client.putClientGroupMember(
          npp.ClientGroupMember(
            clientId: _clientId!,
            clientGroupId: _clientGroupId!,
          ),
        ),
      );
      _daemonId = await _nppAdminRpc(
        'putDaemon',
        () => client.putDaemon(npp.Daemon(atSign: daemonAtsign)),
      );
      _serviceId = await _nppAdminRpc(
        'putService',
        () => client.putService(
          npp.Service(
            daemonId: _daemonId!,
            deviceName: deviceName,
            deviceGroupName: policyDeviceGroupName,
          ),
        ),
      );
    }
    if (!_permitOpens.add(permitOpen)) {
      return;
    }
    await _nppAdminRpc(
      'putServiceACL',
      () => client.putServiceACL(
        npp.ServiceACL(
          serviceId: _serviceId!,
          clientGroupId: _clientGroupId!,
          permitOpen: permitOpen,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {}
}

class NppAtServerPolicyRules implements PolicyRules {
  final admin.PolicyServiceWithAtClient service;
  final Transcript transcript;
  int _generation = 0;
  final Set<String> _permitOpens = {};

  NppAtServerPolicyRules(this.service, {required this.transcript});

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
  required Transcript transcript,
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
    transcript.info(
      'rule check ($stage): observed permitOpens=$actual (any allowed)',
    );
    return;
  }
  final expected =
      expectedPermitOpens ??
      (expectedPermitOpen == null
          ? const <String>{}
          : <String>{expectedPermitOpen});
  if (actual.length == expected.length && actual.containsAll(expected)) {
    transcript.info('rule check ($stage): permitOpens=$actual as expected');
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
  required Transcript transcript,
  required String testName,
  required String policyLabel,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required NoPortsVersion policyVersion,
  required String policyManagerAtsign,
  required PolicyRules policyRules,
  required DockerInstance policyServer,
}) async {
  final String deviceName = getPolicyFlowDeviceName(
    context: context,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    policyLabel: policyLabel,
  );
  String stage = 'daemon startup';
  DockerInstance? daemon;
  try {
    transcript.section(
      '$testName $policyLabel: client=${clientVersion.language.name}:'
      '${clientVersion.version} daemon=${daemonVersion.language.name}:'
      '${daemonVersion.version} policy=${policyVersion.language.name}:'
      '${policyVersion.version}',
    );
    transcript.info(
      'client=${context.clientAtsign} daemon=${context.daemonAtsign} '
      'relay=${context.relayAtsign} policyManager=$policyManagerAtsign '
      'device=$deviceName',
    );
    transcript.info('policy server container: ${policyServer.containerName}');

    daemon = await startPolicyFlowDaemon(
      context: context,
      transcript: transcript,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      clientVersion: clientVersion,
      policyLabel: policyLabel,
      policyManagerAtsign: policyManagerAtsign,
      deviceName: deviceName,
    );

    stage = 'initial check';
    await _checkPolicyRules(
      policyRules: policyRules,
      transcript: transcript,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: null,
      stage: stage,
      allowAny: true,
    );

    stage = 'after initial teardown';
    transcript.info('clearing any pre-existing policy rules');
    await policyRules.clear();
    await _checkPolicyRules(
      policyRules: policyRules,
      transcript: transcript,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: null,
      stage: stage,
    );
    await _waitBeforePolicyStage(transcript);

    stage = '01_no_rules';
    final result1 = await runNptPolicyExpectation(
      context: context,
      testLogger: testLogger,
      transcript: transcript,
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: 22,
      expectSuccess: false,
      metadata: stage,
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    if (result1 != null) return result1;

    stage = 'after wrong-port put';
    transcript.info('allowing permitOpen=$policyWrongPortPermitOpen');
    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policyWrongPortPermitOpen,
    );
    await _checkPolicyRules(
      policyRules: policyRules,
      transcript: transcript,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: policyWrongPortPermitOpen,
      stage: stage,
    );
    await _waitBeforePolicyStage(transcript);

    stage = '02_wrong_policy_port';
    final result2 = await runNptPolicyExpectation(
      context: context,
      testLogger: testLogger,
      transcript: transcript,
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: 22,
      expectSuccess: false,
      metadata: stage,
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    if (result2 != null) return result2;

    stage = 'after allowed put';
    transcript.info('allowing permitOpen=$policySshPermitOpen');
    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policySshPermitOpen,
    );
    await _checkPolicyRules(
      policyRules: policyRules,
      transcript: transcript,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: policySshPermitOpen,
      expectedPermitOpens: {policyWrongPortPermitOpen, policySshPermitOpen},
      stage: stage,
    );
    await _waitBeforePolicyStage(transcript);

    stage = '03_allowed';
    final result3 = await runNptPolicyExpectation(
      context: context,
      testLogger: testLogger,
      transcript: transcript,
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: 22,
      expectSuccess: true,
      metadata: stage,
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    if (result3 != null) return result3;

    stage = 'after daemon-denied put';
    transcript.info('allowing permitOpen=$policyDaemonDeniedPermitOpen');
    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policyDaemonDeniedPermitOpen,
    );
    await _checkPolicyRules(
      policyRules: policyRules,
      transcript: transcript,
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      expectedPermitOpen: policyDaemonDeniedPermitOpen,
      expectedPermitOpens: {
        policyWrongPortPermitOpen,
        policySshPermitOpen,
        policyDaemonDeniedPermitOpen,
      },
      stage: stage,
    );
    await _waitBeforePolicyStage(transcript);

    stage = '04_daemon_permit_open_denied';
    final result4 = await runNptPolicyExpectation(
      context: context,
      testLogger: testLogger,
      transcript: transcript,
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      daemon: daemon,
      deviceName: deviceName,
      remotePort: 2233,
      expectSuccess: false,
      metadata: stage,
      policyLabel: policyLabel,
      policyServer: policyServer,
    );
    if (result4 != null) return result4;

    transcript.ok('all 4 policy stages behaved as expected');
    final policyTestResult = PolicyTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      status: TestStatus.passed,
      exitCode: 0,
      tag: deviceName,
    );
    return policyTestResult;
  } catch (e, st) {
    transcript.error('threw ${e.runtimeType} during "$stage"', e, st);
    return PolicyTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      status: TestStatus.failed,
      exitCode: 1,
      tag: deviceName,
      failure: PolicyTestFailure(
        stage: stage,
        reason: 'threw ${e.runtimeType} during "$stage"',
        reproduceCommand: null,
        logFiles: [
          if (daemon?.stdoutLogFile != null) daemon!.stdoutLogFile!,
          if (policyServer.stdoutLogFile != null) policyServer.stdoutLogFile!,
        ],
        error: e,
        stackTrace: st,
      ),
    );
  } finally {
    try {
      await policyRules.clear();
    } catch (e) {
      // Leftover rules are exactly what makes the NEXT test's 'after initial
      // teardown' check fail, so swallowing this silently erases the real cause.
      transcript.warn('teardown: policyRules.clear() failed: $e');
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
  required Transcript transcript,
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

  final String sshnpdCommand =
      '/usr/local/bin/sshnpd '
      '-a ${context.daemonAtsign} '
      '-p $policyManagerAtsign '
      '-k $daemonAtsignContainerKeyFilePath '
      '--root-domain ${context.rootDomain} '
      '-d $deviceName '
      '--permit-open "$policySshPermitOpen" '
      '-v -s -u';

  transcript.info('starting daemon from image ${dockerImage.fullImageName}');
  transcript.command('sshnpd', [sshnpdCommand]);

  final DockerInstance daemon = await runDockerInstance(
    dockerImage: dockerImage,
    testRunId: context.testRunId,
    logsDirectory: context.daemonLogsDirectory,
    uniqueIdentifier:
        '_daemon_$policyLabel'
        '_${clientVersion.language.name}_${clientVersion.version}'
        '_${daemonVersion.language.name}_${daemonVersion.version}'
        '_${policyVersion.language.name}_${policyVersion.version}',
    entrypoint: ['/bin/bash', '-c', 'sudo service ssh start && $sshnpdCommand'],
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
  transcript.info('daemon container: ${daemon.containerName}');
  await waitForLogMessage(daemon, 'Daemon is running', transcript: transcript);
  transcript.ok('daemon is running (device=$deviceName)');
  return daemon;
}

Future<PolicyTestResult?> runNptPolicyExpectation({
  required PolicyTestsContext context,
  required PolicyTestLogger testLogger,
  required Transcript transcript,
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
    orElse: () => throw Exception(
      'No npt client binary for ${clientVersion.language.name}:'
      '${clientVersion.version}. Available: '
      '${context.clientBinaries.map((cb) => '${cb.binaryType.name}@'
          '${cb.noPortsVersion.language.name}:${cb.noPortsVersion.version}').join(', ')}',
    ),
  );
  ProcessOutputCapture? lastNptOutput;
  LogFragment? lastDaemonLogFragment;
  LogFragment? lastPolicyLogFragment;
  String lastMetadata = metadata;
  int lastExitCode = 1;
  String? lastNptCommand;
  final List<String> attemptOutcomes = [];

  transcript.section(
    'stage $metadata: npt --remote-port $remotePort, '
    'expecting ${expectSuccess ? 'SUCCESS' : 'FAILURE'}',
  );

  for (var attempt = 1; attempt <= policyNptMaxAttempts; attempt++) {
    final attemptMetadata = _attemptMetadata(metadata, attempt);
    lastMetadata = attemptMetadata;
    final attemptResult = await _runPolicyConnectionAttempt(
      context: context,
      testLogger: testLogger,
      transcript: transcript,
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
    lastNptCommand = attemptResult.nptCommand;

    // A hang is not a policy denial. Before this, exit 124 satisfied
    // `exitCode != 0`, so a permanently hanging npt silently PASSED all three
    // expectSuccess: false stages.
    final bool passed = attemptResult.timedOut
        ? false
        : (expectSuccess
              ? attemptResult.exitCode == 0
              : attemptResult.exitCode != 0);
    attemptOutcomes.add(
      'attempt $attempt/$policyNptMaxAttempts: exit ${attemptResult.exitCode}'
      '${attemptResult.timedOut ? ' (TIMED OUT)' : ''} in '
      '${attemptResult.elapsed.inMilliseconds}ms → ${passed ? 'as expected' : 'unexpected'}',
    );
    if (passed) {
      transcript.ok('stage $metadata: ${attemptOutcomes.last}');
      return null;
    }
    transcript.warn('stage $metadata: ${attemptOutcomes.last}');

    if (attempt < policyNptMaxAttempts) {
      transcript.info('retrying in ${policyNptRetryWait.inSeconds}s');
      await Future<void>.delayed(policyNptRetryWait);
    }
  }

  final String reason =
      'npt did not behave as expected on any of $policyNptMaxAttempts attempts: '
      'expected ${expectSuccess ? 'exit 0' : 'a non-zero exit'} for '
      '--remote-port $remotePort, last exit was $lastExitCode';
  transcript.error('stage $metadata failed. $reason');

  final List<File> logFiles = [
    testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      testMetadata: '${lastMetadata}_npt',
    ),
    testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      testMetadata: '${lastMetadata}_npt',
    ),
    testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: lastMetadata,
    ),
    testLogger.getPolicyStdoutLogFile(
      policyVersion: policyVersion,
      policyName: policyLabel,
      testMetadata: lastMetadata,
    ),
  ];

  final policyTestResult = PolicyTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    policyVersion: policyVersion,
    status: TestStatus.failed,
    exitCode: lastExitCode,
    tag: deviceName,
    failure: PolicyTestFailure(
      stage: metadata,
      reason: reason,
      detail: attemptOutcomes.join('\n'),
      reproduceCommand: lastNptCommand,
      logFiles: logFiles,
    ),
  );
  printClientLogs(lastNptOutput!, label: '${lastMetadata}_npt');
  printDaemonLogFragments(lastDaemonLogFragment!, label: lastMetadata);
  printPolicyLogFragments(lastPolicyLogFragment!, label: lastMetadata);
  return policyTestResult;
}

Future<
  ({
    ProcessOutputCapture nptOutput,
    LogFragment daemonLogFragment,
    LogFragment policyLogFragment,
    int exitCode,
    bool timedOut,
    Duration elapsed,
    String nptCommand,
  })
>
_runPolicyConnectionAttempt({
  required PolicyTestsContext context,
  required PolicyTestLogger testLogger,
  required Transcript transcript,
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
  // Must be awaited: start() is what creates the fragment files. Fire-and-forget
  // left them missing often enough that the failure dump printed nothing at all
  // (every printer here guards on existsSync).
  await daemonLogFragment.start();
  await policyLogFragment.start();

  final List<String> nptArgs = _buildNptArgs(
    context: context,
    clientVersion: clientVersion,
    deviceName: deviceName,
    remotePort: remotePort,
  );
  transcript.command(nptClientBinary.file.path, nptArgs);

  final Stopwatch attemptStopwatch = Stopwatch()..start();
  final ProcessOutputCapture nptOutput = await startCommandWithCapture(
    nptClientBinary.file.path,
    nptArgs,
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
  bool timedOut = false;
  final int nptExitCode = await nptOutput.exitCode.timeout(
    nptAttemptTimeout,
    onTimeout: () {
      timedOut = true;
      transcript.error(
        'npt did not exit within ${nptAttemptTimeout.inSeconds}s; '
        'sending SIGTERM and treating the attempt as failed',
      );
      nptOutput.process.kill(ProcessSignal.sigterm);
      return 124;
    },
  );
  attemptStopwatch.stop();
  await daemonLogFragment.stop();
  await policyLogFragment.stop();
  return (
    nptOutput: nptOutput,
    daemonLogFragment: daemonLogFragment,
    policyLogFragment: policyLogFragment,
    exitCode: nptExitCode,
    timedOut: timedOut,
    elapsed: attemptStopwatch.elapsed,
    nptCommand: '${nptClientBinary.file.path} ${nptArgs.join(' ')}',
  );
}

String _attemptMetadata(String metadata, int attempt) {
  if (attempt == 1) {
    return metadata;
  }
  return '${metadata}_attempt_$attempt';
}

Future<void> _waitBeforePolicyStage(Transcript transcript) async {
  transcript.info(
    'waiting ${policyStageWait.inSeconds}s for the policy change to propagate',
  );
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
  Transcript? transcript,
}) async {
  transcript?.info(
    'waiting up to ${timeout.inSeconds}s for "$message" in '
    '${dockerInstance.containerName} logs',
  );
  final stopwatch = Stopwatch()..start();
  String logs = '';
  while (stopwatch.elapsed < timeout) {
    logs = await _readContainerLogs(dockerInstance);
    if (logs.contains(message)) {
      return;
    }
    // A container that has already died will never print the message. Reporting
    // that (with its logs) beats waiting out the full timeout and then saying
    // nothing — this is what a `docker run --name` collision looks like.
    final int? exitCode = await _containerExitCodeIfComplete(dockerInstance);
    if (exitCode != null) {
      throw TimeoutException(
        '${dockerInstance.containerName} exited with code $exitCode before '
        'printing "$message". Logs:\n${_logTail(logs)}',
      );
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw TimeoutException(
    'Did not find "$message" in ${dockerInstance.containerName} logs within '
    '${timeout.inSeconds}s. Logs:\n${_logTail(logs)}',
  );
}

Future<String> _readContainerLogs(DockerInstance dockerInstance) async {
  final File? stdoutFile = dockerInstance.stdoutLogFile;
  final File? stderrFile = dockerInstance.stderrLogFile;
  final String stdoutText = stdoutFile != null && await stdoutFile.exists()
      ? await stdoutFile.readAsString()
      : '';
  final String stderrText = stderrFile != null && await stderrFile.exists()
      ? await stderrFile.readAsString()
      : '';
  return '$stdoutText$stderrText';
}

/// Non-blocking poll of the attached `docker run` process, same trick as
/// `PolicyServer._processExitCodeIfComplete`.
Future<int?> _containerExitCodeIfComplete(DockerInstance dockerInstance) async {
  final Process? process = dockerInstance.process;
  if (process == null) {
    return null;
  }
  try {
    return await process.exitCode.timeout(Duration.zero);
  } on TimeoutException {
    return null;
  }
}

String _logTail(String logs, {int maxLines = 60}) {
  if (logs.trim().isEmpty) {
    return '(no container output was captured)';
  }
  final List<String> lines = logs.trimRight().split('\n');
  if (lines.length <= maxLines) {
    return lines.join('\n');
  }
  return [
    '... ${lines.length - maxLines} earlier line(s) omitted ...',
    ...lines.skip(lines.length - maxLines),
  ].join('\n');
}
