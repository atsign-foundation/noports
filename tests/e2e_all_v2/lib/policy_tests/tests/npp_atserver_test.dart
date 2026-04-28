import 'dart:io';

import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/policy_tests/policy_server.dart';
import 'package:e2e_all_v2/policy_tests/policy_tests_context.dart';
import 'package:e2e_all_v2/policy_tests/policy_tests_test_result.dart';
import 'package:e2e_all_v2/print_test_utils.dart';
import 'package:e2e_all_v2/test_result.dart';

const String nppAtServerTestName = 'npp_atserver_test';
final NoPortsVersion _minimumNppAtServerVersion = NoPortsVersion(
  language: Language.dart,
  version: 'v5.13.0',
);

List<Future<PolicyTestResult> Function()> runNppAtServerTests({
  required final PolicyTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
  required final List<NoPortsVersion> nppAtServerVersions,
}) {
  final List<Future<PolicyTestResult> Function()> testFactories = [];
  final List<(NoPortsVersion, NoPortsVersion, NoPortsVersion)> permutations =
      _generateVersionPermutationsNppAtServer(
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
        nppAtServerVersions: nppAtServerVersions,
      );

  for (final (NoPortsVersion, NoPortsVersion, NoPortsVersion) permutation
      in permutations) {
    final (clientVersion, daemonVersion, policyVersion) = permutation;
    testFactories.add(
      () => _runNppAtServerTest(
        context: context,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
        policyVersion: policyVersion,
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
        permutations.add((clientVersion, daemonVersion, nppAtServerVersion));
      }
    }
  }
  return permutations;
}

Future<PolicyTestResult> _runNppAtServerTest({
  required final PolicyTestsContext context,
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
    final PolicyTestResult testResult = PolicyTestResult(
      testName: nppAtServerTestName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      status: TestStatus.failed,
      exitCode: 1,
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
  final PolicyServer policyServer = PolicyServer(
    type: PolicyServerType.nppAtServer,
    version: policyVersion,
    atsign: context.nppAtServerAtsign,
    rootDomain: context.rootDomain,
    testRunId: context.testRunId,
    logsDirectory: Directory('${context.logsDirectory.path}/policies'),
    apkamKeysFile: policyApkamKeysFile,
    dockerImage: policyDockerImage,
  );
  await policyServer.start();
  await policyServer.ensureProcessMessage();

  return PolicyTestResult(
    testName: nppAtServerTestName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    policyVersion: policyVersion,
    status: TestStatus.passed,
    exitCode: 0,
  );
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
