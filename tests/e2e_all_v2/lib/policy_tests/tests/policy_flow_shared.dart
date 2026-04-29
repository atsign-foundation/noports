import 'dart:async';
import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/docker_utils.dart';
import 'package:e2e_all_v2/log_fragment.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/policy_tests/policy_tests_context.dart';
import 'package:e2e_all_v2/policy_tests/policy_tests_logging.dart';
import 'package:e2e_all_v2/policy_tests/policy_tests_print_utils.dart';
import 'package:e2e_all_v2/policy_tests/policy_tests_test_result.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/test_result.dart';
import 'package:noports_core/admin.dart' as admin;
import 'package:noports_core/npp.dart' as npp;
import 'package:path/path.dart' as path;

const String policyDeviceGroupName = '__none__';
const String policySshPermitOpen = 'localhost:22';
const String policyWrongPortPermitOpen = 'localhost:222';
const String policyDaemonDeniedPermitOpen = 'localhost:2233';

abstract class PolicyRules {
  Future<void> clear();

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
  String? _clientGroupMemberId;
  String? _daemonId;
  String? _serviceId;
  final Set<String> _permitOpens = <String>{};

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
    _clientGroupMemberId = null;
    _daemonId = null;
    _serviceId = null;
    _permitOpens.clear();
  }

  @override
  Future<void> allowPermitOpen({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
    required String permitOpen,
  }) async {
    _clientId ??= await client.putClient(
      npp.Client(name: clientAtsign, atSign: clientAtsign),
    );
    _clientGroupId ??= await client.putClientGroup(
      npp.ClientGroup(name: 'policy_e2e_clients'),
    );
    _clientGroupMemberId ??= await client.putClientGroupMember(
      npp.ClientGroupMember(
        clientId: _clientId!,
        clientGroupId: _clientGroupId!,
      ),
    );
    _daemonId ??= await client.putDaemon(npp.Daemon(atSign: daemonAtsign));
    _serviceId ??= await client.putService(
      npp.Service(
        daemonId: _daemonId!,
        deviceName: deviceName,
        deviceGroupName: policyDeviceGroupName,
      ),
    );
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
  admin.UserGroup? _group;
  final Set<String> _permitOpens = <String>{};

  NppAtServerPolicyRules(this.service);

  @override
  Future<void> clear() async {
    final groups = await service.getUserGroups();
    for (final group in groups) {
      if (group.id != null) {
        await service.deleteUserGroup(group.id!);
      }
    }
    _group = null;
    _permitOpens.clear();
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  @override
  Future<void> allowPermitOpen({
    required String clientAtsign,
    required String daemonAtsign,
    required String deviceName,
    required String permitOpen,
  }) async {
    _permitOpens.add(permitOpen);
    final permitOpens = _permitOpens.toList()..sort();
    final group = admin.UserGroup(
      id: _group?.id,
      name: 'policy_e2e_clients',
      description: 'Policy e2e generated group',
      userAtSigns: [clientAtsign],
      daemonAtSigns: [daemonAtsign],
      devices: [admin.Device(name: deviceName, permitOpens: permitOpens)],
      deviceGroups: const [],
    );
    if (_group == null) {
      _group = await service.createUserGroup(group);
    } else {
      await service.updateUserGroup(group);
      _group = group;
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }

  @override
  Future<void> close() async {}
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
}) async {
  final String extra =
      '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, '
      'daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version}, '
      '$policyLabel: ${policyVersion.language.name[0]}:${policyVersion.version})';

  DockerInstance? daemon;
  try {
    final String deviceName = getPolicyFlowDeviceName(
      context: context,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyLabel: policyLabel,
    );

    Future<void> stopDaemon() async {
      if (daemon == null) {
        return;
      }
      await daemon!.stopAllLogFragments();
      await daemon!.stop();
      daemon = null;
    }

    Future<PolicyTestResult?> runCase({
      required int remotePort,
      required bool expectSuccess,
      required String metadata,
    }) async {
      await stopDaemon();
      daemon = await startPolicyFlowDaemon(
        context: context,
        testLogger: testLogger,
        daemonVersion: daemonVersion,
        policyVersion: policyVersion,
        clientVersion: clientVersion,
        policyLabel: policyLabel,
        policyManagerAtsign: policyManagerAtsign,
        deviceName: deviceName,
      );
      final result = await runNptPolicyExpectation(
        context: context,
        testLogger: testLogger,
        testName: testName,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
        policyVersion: policyVersion,
        daemon: daemon!,
        deviceName: deviceName,
        remotePort: remotePort,
        expectSuccess: expectSuccess,
        metadata: metadata,
        extra: extra,
      );
      await stopDaemon();
      return result;
    }

    await policyRules.clear();
    final result1 = await runCase(
      remotePort: 22,
      expectSuccess: false,
      metadata: '01_no_rules',
    );
    if (result1 != null) return result1;

    await policyRules.clear();
    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policyWrongPortPermitOpen,
    );
    final result2 = await runCase(
      remotePort: 22,
      expectSuccess: false,
      metadata: '02_wrong_policy_port',
    );
    if (result2 != null) return result2;

    await policyRules.clear();
    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policySshPermitOpen,
    );
    final result3 = await runCase(
      remotePort: 22,
      expectSuccess: true,
      metadata: '03_allowed',
    );
    if (result3 != null) return result3;

    await policyRules.clear();
    await policyRules.allowPermitOpen(
      clientAtsign: context.clientAtsign,
      daemonAtsign: context.daemonAtsign,
      deviceName: deviceName,
      permitOpen: policyDaemonDeniedPermitOpen,
    );
    final result4 = await runCase(
      remotePort: 2233,
      expectSuccess: false,
      metadata: '04_daemon_permit_open_denied',
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
    return PolicyTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      status: TestStatus.failed,
      exitCode: 1,
    );
  } finally {
    try {
      await policyRules.clear();
    } catch (_) {}
    await policyRules.close();
    final runningDaemon = daemon;
    if (runningDaemon != null) {
      await runningDaemon.stopAllLogFragments();
      await runningDaemon.stop();
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
  required PolicyTestLogger testLogger,
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
    logsDirectory: testLogger.daemonsDirectory,
    uniqueIdentifier:
        '_daemon_${policyLabel}_${clientVersion.language.name}_${clientVersion.version}'
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
    volumeMappings: [
      VolumeMapping(
        local: daemonApkamKeysFile.absolute.path,
        container: daemonAtsignContainerKeyFilePath,
      ),
    ],
  );
  await waitForLogMessage(daemon, 'monitor started');
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
  required String extra,
}) async {
  final ClientBinary nptClientBinary = context.clientBinaries.firstWhere(
    (cb) =>
        cb.binaryType == ClientBinaryType.npt &&
        cb.noPortsVersion == clientVersion,
  );
  final LogFragment daemonLogFragment = daemon.createLogFragment(
    stdoutFile: testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: metadata,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: metadata,
    ),
  );
  daemonLogFragment.start();
  final ProcessOutputCapture output = await startCommandWithCapture(
    nptClientBinary.file.path,
    _buildNptArgs(
      context: context,
      clientVersion: clientVersion,
      deviceName: deviceName,
      remotePort: remotePort,
    ),
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      testMetadata: metadata,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      testMetadata: metadata,
    ),
  );
  final int exitCode = await output.exitCode.timeout(
    const Duration(seconds: 45),
    onTimeout: () {
      output.process.kill(ProcessSignal.sigterm);
      return 124;
    },
  );
  await daemonLogFragment.stop();

  final bool passed = expectSuccess ? exitCode == 0 : exitCode != 0;
  if (passed) {
    return null;
  }

  final policyTestResult = PolicyTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    policyVersion: policyVersion,
    status: TestStatus.failed,
    exitCode: exitCode,
  );
  printAllLogs(
    clientCapture: output,
    daemonLogFragment: daemonLogFragment,
    clientLabel: metadata,
    daemonLabel: metadata,
  );
  return policyTestResult;
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
  while (stopwatch.elapsed < timeout) {
    final stdout = dockerInstance.stdoutLogFile;
    final stderr = dockerInstance.stderrLogFile;
    final stdoutText = stdout != null && await stdout.exists()
        ? await stdout.readAsString()
        : '';
    final stderrText = stderr != null && await stderr.exists()
        ? await stderr.readAsString()
        : '';
    if (stdoutText.contains(message) || stderrText.contains(message)) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw TimeoutException(
    'Did not find "$message" in ${dockerInstance.containerName} logs',
  );
}
