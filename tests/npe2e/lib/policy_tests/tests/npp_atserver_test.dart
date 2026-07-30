import 'dart:io';

import 'package:npe2e/docker_image.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/policy_tests/policy_server.dart';
import 'package:npe2e/policy_tests/policy_test_case.dart';
import 'package:npe2e/policy_tests/policy_tests_context.dart';
import 'package:npe2e/policy_tests/policy_tests_logging.dart';
import 'package:npe2e/policy_tests/policy_tests_test_result.dart';
import 'package:npe2e/policy_tests/policy_flow_shared.dart';
import 'package:npe2e/print_test_utils.dart';
import 'package:npe2e/test_result.dart';
import 'package:npe2e/transcript.dart';
import 'package:noports_core/admin.dart' as admin;

const String nppAtServerTestName = 'npp_atserver_test';
const String nppAtServerPolicyLabel = 'npp_atserver';
final NoPortsVersion _minimumNppAtServerVersion = NoPortsVersion(
  language: Language.dart,
  version: 'v5.13.0',
);

List<PolicyTestCase> getNppAtServerTestFactories({
  required final PolicyTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
  required final List<NoPortsVersion> nppAtServerVersions,
}) {
  final List<PolicyTestCase> testFactories = [];
  final PolicyTestLogger testLogger = PolicyTestLogger(
    logsDirectory: context.logsDirectory,
    testName: nppAtServerTestName,
  );
  final List<(NoPortsVersion, NoPortsVersion, NoPortsVersion)> permutations =
      _generateVersionPermutationsNppAtServer(
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
        nppAtServerVersions: nppAtServerVersions,
      );

  for (final (NoPortsVersion, NoPortsVersion, NoPortsVersion) permutation
      in permutations) {
    final (clientVersion, daemonVersion, policyVersion) = permutation;
    final String tag = getPolicyFlowDeviceName(
      context: context,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyLabel: nppAtServerPolicyLabel,
    );
    testFactories.add(
      PolicyTestCase(
        testName: nppAtServerTestName,
        tag: tag,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
        policyVersion: policyVersion,
        run: () => _runNppAtServerTest(
          context: context,
          testLogger: testLogger,
          transcript: Transcript(tag: tag, file: context.transcriptLogFile),
          clientVersion: clientVersion,
          daemonVersion: daemonVersion,
          policyVersion: policyVersion,
        ),
      ),
    );
  }

  return testFactories;
}

List<(NoPortsVersion, NoPortsVersion, NoPortsVersion)>
_generateVersionPermutationsNppAtServer({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
  required final List<NoPortsVersion> nppAtServerVersions,
}) {
  final List<(NoPortsVersion, NoPortsVersion, NoPortsVersion)> permutations =
      [];
  for (final NoPortsVersion clientVersion in clientVersions) {
    for (final NoPortsVersion daemonVersion in daemonVersions) {
      for (final NoPortsVersion nppAtServerVersion in nppAtServerVersions) {
        if (!versionIsAtLeast(nppAtServerVersion, _minimumNppAtServerVersion)) {
          continue;
        }
        if (!_hasCurrentVersion(
          clientVersion,
          daemonVersion,
          nppAtServerVersion,
        )) {
          continue;
        }
        permutations.add((clientVersion, daemonVersion, nppAtServerVersion));
      }
    }
  }
  return permutations;
}

bool _hasCurrentVersion(
  NoPortsVersion clientVersion,
  NoPortsVersion daemonVersion,
  NoPortsVersion policyVersion,
) {
  return clientVersion.version == 'current' ||
      daemonVersion.version == 'current' ||
      policyVersion.version == 'current';
}

Future<PolicyTestResult> _runNppAtServerTest({
  required final PolicyTestsContext context,
  required final PolicyTestLogger testLogger,
  required final Transcript transcript,
  required final NoPortsVersion clientVersion,
  required final NoPortsVersion daemonVersion,
  required final NoPortsVersion policyVersion,
}) async {
  final String extra = _generateExtraString(
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    policyVersion: policyVersion,
  );
  printTestStart(testName: nppAtServerTestName, extra: extra);

  final File policyApkamKeysFile =
      context.apkamKeys[context.nppAtServerAtsign]!;
  if (!(await policyApkamKeysFile.exists())) {
    final String reason =
        'APKAM keys for ${context.nppAtServerAtsign} do not exist at '
        '${policyApkamKeysFile.path}';
    transcript.error(reason);
    final PolicyTestResult testResult = PolicyTestResult(
      testName: nppAtServerTestName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      status: TestStatus.failed,
      exitCode: 1,
      tag: transcript.tag,
      failure: PolicyTestFailure(stage: 'apkam keys', reason: reason),
    );
    printTestResult(testResult: testResult, extra: extra);
    return testResult;
  }

  final DockerImage policyDockerImage = context.dockerImages.firstWhere(
    (image) =>
        image.language == policyVersion.language &&
        image.tag == policyVersion.version,
    orElse: () => throw Exception(
      'Docker image for language ${policyVersion.language.name} and version ${policyVersion.version} not found in dockerImages list',
    ),
  );
  final String uniqueIdentifier = _uniqueIdentifier(
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
  );
  final PolicyServer policyServer = PolicyServer(
    type: PolicyServerType.nppAtServer,
    version: policyVersion,
    atsign: context.nppAtServerAtsign,
    rootDomain: context.rootDomain,
    testRunId: context.testRunId,
    logsDirectory: context.nppAtServerLogsDirectory,
    apkamKeysFile: policyApkamKeysFile,
    dockerImage: policyDockerImage,
    uniqueIdentifierSuffix: uniqueIdentifier,
  );

  try {
    transcript.info(
      'starting npp_atserver policy server '
      '${policyDockerImage.fullImageName} for ${context.nppAtServerAtsign}',
    );
    await policyServer.start();
    await policyServer.ensureProcessMessage();
    transcript.ok(
      'npp_atserver policy server ready: ${policyServer.containerName}',
    );

    transcript.info(
      'authenticating admin AtClient as ${context.nppAtServerAtsign}',
    );
    final atClient = await createPolicyAtClient(
      atsign: context.nppAtServerAtsign,
      apkamKeysFile: policyApkamKeysFile,
      rootDomain: context.rootDomain,
      storageDirectory: Directory(
        '${context.baseDirectory.path}/atClientStorage/npp_atserver$uniqueIdentifier',
      ),
    );
    transcript.ok('admin AtClient authenticated');
    final policyService = admin.PolicyServiceWithAtClient(atClient: atClient);
    await policyService.init();
    transcript.ok('policy service initialised');
    final PolicyTestResult testResult = await runPolicyFlow(
      context: context,
      testLogger: testLogger,
      transcript: transcript,
      testName: nppAtServerTestName,
      policyLabel: nppAtServerPolicyLabel,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      policyManagerAtsign: context.nppAtServerAtsign,
      policyRules: NppAtServerPolicyRules(
        policyService,
        transcript: transcript,
      ),
      policyServer: policyServer.dockerInstance,
    );
    printTestResult(testResult: testResult, extra: extra);
    return testResult;
  } finally {
    try {
      await policyServer.stop();
    } catch (e) {
      transcript.warn('teardown: policyServer.stop() failed: $e');
    }
  }
}

String _uniqueIdentifier({
  required final NoPortsVersion clientVersion,
  required final NoPortsVersion daemonVersion,
}) {
  return '_${clientVersion.language.name}_${clientVersion.version}'
      '_${daemonVersion.language.name}_${daemonVersion.version}';
}

String _generateExtraString({
  required final NoPortsVersion clientVersion,
  required final NoPortsVersion daemonVersion,
  required final NoPortsVersion policyVersion,
}) {
  String s = '';
  s += '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, ';
  s += 'daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version}, ';
  s +=
      'npp_atserver: ${policyVersion.language.name[0]}:${policyVersion.version})';
  return s;
}
