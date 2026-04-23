import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
import 'package:e2e_all_v2/core_tests/core_tests_logging.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/print_test_utils.dart';
import 'package:e2e_all_v2/test_result.dart';

const String _metadataNptExecution = 'nptExecution';
const String _metadataSshExecution = 'sshExecution';
const String testName = 'npt_to_port_22_no_encrypt_traffic';

// Test: npt_to_port_22_no_encrypt_traffic
// 1. Execute npt command with --no-encrypt-rvd-traffic flag to create an unencrypted tunnel to remote port 22
// 2. Capture the local port returned by npt
// 3. Execute SSH connection to localhost on that port
// 4. Verify the SSH connection succeeds
// Requirements:
// - Feature only available in v5.6.2+ (current versions only)
// - Only runs with BOTH client and daemon as d:current
List<Future<CoreTestResult>> runNptToPort22NoEncryptTrafficTests({
  required final CoreTestsContext context,
}) {
  final List<Future<CoreTestResult>> testFutures = [];
  final CoreTestLogger testLogger = CoreTestLogger(logsDirectory: context.logsDirectory, testName: testName);

  // This test only runs with current client and current daemon (v5.6.2+ feature)
  final ClientBinary currentNptClientBinary = context.clientBinaries.firstWhere((cb) =>
    cb.binaryType == ClientBinaryType.npt &&
    cb.noPortsVersion.version == 'current' &&
    cb.noPortsVersion.language == Language.dart);

  final List<(NoPortsVersion, NoPortsVersion)> versionPermutations = _generateVersionPermutations(
    clientVersions: [currentNptClientBinary.noPortsVersion],
    daemonVersions: [currentNptClientBinary.noPortsVersion],
  );

  for(final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion) in versionPermutations) {
    final Future<CoreTestResult> testFuture = _runNptToPort22NoEncryptTrafficTest(
      context: context,
      testLogger: testLogger,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
    );
    testFutures.add(testFuture);
  }

  return testFutures;
}

Future<CoreTestResult> _runNptToPort22NoEncryptTrafficTest({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) async {
  final String extra = '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version})';
  printTestStart(testName: testName, extra: extra);

  final int exitCode2 = 0;
  final CoreTestResult coreTestResult = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: TestStatus.failed, // default to failed, will update to passed if test succeeds
    exitCode: exitCode2, // default to -1, will update with actual exit code from npt process
  );
  return coreTestResult;
}

List<String> _buildNptArgs({
  required CoreTestsContext context,
  required String deviceName,
}) {
  final List<String> args = [
    '-f', context.clientAtsign,
    '-t', context.daemonAtsign,
    '-d', deviceName,
    '-r', context.relayAtsign,
    '--root-domain', context.rootDomain,
    '--remote-port', '22',
    '--exit-when-connected',
    '--no-encrypt-rvd-traffic',
    '--verbose',
    '-k', context.apkamKeys[context.clientAtsign]!.path,
  ];

  return args;
}

List<(NoPortsVersion, NoPortsVersion)> _generateVersionPermutations({
  required List<NoPortsVersion> clientVersions,
  required List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> permutations = [];
  for(final clientVersion in clientVersions) {
    for(final daemonVersion in daemonVersions) {
      if(clientVersion.version != 'current' || daemonVersion.version != 'current') {
        continue;
      }
      permutations.add((clientVersion, daemonVersion));
    }
  }
  return permutations;
}
