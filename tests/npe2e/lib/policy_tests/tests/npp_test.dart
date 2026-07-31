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
import 'package:noports_core/npp.dart' as npp;

const String nppTestName = 'npp_test';
const String nppPolicyLabel = 'npp';
final NoPortsVersion _minimumNppVersion = NoPortsVersion(
  language: Language.dart,
  version: 'v5.14.13',
);

List<PolicyTestCase> getNppTestFactories({
  required final PolicyTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
  required final List<NoPortsVersion> nppVersions,
}) {
  return getNppTestFactoryBatchesByPolicyVersion(
    context: context,
    clientVersions: clientVersions,
    daemonVersions: daemonVersions,
    nppVersions: nppVersions,
  ).expand((testFactories) => testFactories).toList();
}

List<List<PolicyTestCase>> getNppTestFactoryBatchesByPolicyVersion({
  required final PolicyTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
  required final List<NoPortsVersion> nppVersions,
}) {
  final List<List<PolicyTestCase>> batches = [];
  for (final NoPortsVersion nppVersion in nppVersions) {
    final List<PolicyTestCase> testFactories =
        _getNppTestFactoriesForPolicyVersions(
          context: context,
          clientVersions: clientVersions,
          daemonVersions: daemonVersions,
          nppVersions: [nppVersion],
        );
    if (testFactories.isNotEmpty) {
      batches.add(testFactories);
    }
  }
  return batches;
}

List<PolicyTestCase> _getNppTestFactoriesForPolicyVersions({
  required final PolicyTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
  required final List<NoPortsVersion> nppVersions,
}) {
  final List<PolicyTestCase> testFactories = [];
  final PolicyTestLogger testLogger = PolicyTestLogger(
    logsDirectory: context.logsDirectory,
    testName: nppTestName,
  );
  final List<(NoPortsVersion, NoPortsVersion, NoPortsVersion)> permutations =
      _generateVersionPermutations(
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
        nppVersions: nppVersions,
      );

  for (final (
        NoPortsVersion clientVersion,
        NoPortsVersion daemonVersion,
        NoPortsVersion policyVersion,
      )
      in permutations) {
    // Same value the daemon container name and the per-stage log filenames are
    // built from, so a tagged line points straight at a container and a file.
    final String tag = getPolicyFlowDeviceName(
      context: context,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyLabel: nppPolicyLabel,
    );
    testFactories.add(
      PolicyTestCase(
        testName: nppTestName,
        tag: tag,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
        policyVersion: policyVersion,
        run: () => _runNppTest(
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
_generateVersionPermutations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
  required final List<NoPortsVersion> nppVersions,
}) {
  final List<(NoPortsVersion, NoPortsVersion, NoPortsVersion)> permutations =
      [];
  for (final NoPortsVersion clientVersion in clientVersions) {
    for (final NoPortsVersion daemonVersion in daemonVersions) {
      for (final NoPortsVersion nppVersion in nppVersions) {
        if (!versionIsAtLeast(nppVersion, _minimumNppVersion)) {
          continue;
        }
        if (!_hasCurrentVersion(clientVersion, daemonVersion, nppVersion)) {
          continue;
        }
        permutations.add((clientVersion, daemonVersion, nppVersion));
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

Future<PolicyTestResult> _runNppTest({
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
  printTestStart(testName: nppTestName, extra: extra);

  final File policyApkamKeysFile = context.apkamKeys[context.nppAtsign]!;
  if (!(await policyApkamKeysFile.exists())) {
    final String reason =
        'APKAM keys for ${context.nppAtsign} do not exist at '
        '${policyApkamKeysFile.path}';
    transcript.error(reason);
    final PolicyTestResult testResult = PolicyTestResult(
      testName: nppTestName,
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
    type: PolicyServerType.npp,
    version: policyVersion,
    atsign: context.nppAtsign,
    rootDomain: context.rootDomain,
    testRunId: context.testRunId,
    logsDirectory: context.nppLogsDirectory,
    apkamKeysFile: policyApkamKeysFile,
    dockerImage: policyDockerImage,
    uniqueIdentifierSuffix: uniqueIdentifier,
    additionalArgs: [
      '--persistence-method',
      'none',
      '--manager-allow-list',
      context.nppAtsign,
    ],
  );

  try {
    transcript.info(
      'starting npp policy server ${policyDockerImage.fullImageName} '
      'for ${context.nppAtsign}',
    );
    await policyServer.start();
    await policyServer.ensureProcessMessage();
    transcript.ok('npp policy server ready: ${policyServer.containerName}');

    transcript.info('authenticating admin AtClient as ${context.nppAtsign}');
    final atClient = await createPolicyAtClient(
      atsign: context.nppAtsign,
      apkamKeysFile: policyApkamKeysFile,
      rootDomain: context.rootDomain,
      storageDirectory: Directory(
        '${context.baseDirectory.path}/atClientStorage/npp$uniqueIdentifier',
      ),
    );
    transcript.ok('admin AtClient authenticated');
    final policyRules = NppPolicyRules(
      npp.NppClient(
        atClient: atClient,
        serverAtSign: context.nppAtsign,
        baseNameSpace: 'sshnp',
        domainNameSpace: 'npp',
      ),
      transcript: transcript,
    );
    final PolicyTestResult testResult = await runPolicyFlow(
      context: context,
      testLogger: testLogger,
      transcript: transcript,
      testName: nppTestName,
      policyLabel: nppPolicyLabel,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      policyManagerAtsign: context.nppAtsign,
      policyRules: policyRules,
      policyServer: policyServer.dockerInstance,
    );
    printTestResult(testResult: testResult, extra: extra);
    return testResult;
  } finally {
    try {
      await policyServer.stop();
    } catch (e) {
      // A container left running collides with the next run's `docker run
      // --name`, so this is worth knowing about even though it cannot fail the
      // test. Note dockerInstance is `late`: if start() threw, this is a
      // LateInitializationError.
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
  s += 'npp: ${policyVersion.language.name[0]}:${policyVersion.version})';
  return s;
}
