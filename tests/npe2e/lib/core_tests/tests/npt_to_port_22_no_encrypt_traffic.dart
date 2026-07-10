import 'package:npe2e/client_binary.dart';
import 'package:npe2e/core_tests/core_tests_context.dart';
import 'package:npe2e/core_tests/core_tests_logging.dart';
import 'package:npe2e/core_tests/core_tests_print_utils.dart';
import 'package:npe2e/core_tests/core_tests_test_result.dart';
import 'package:npe2e/core_tests/core_tests_docker_utils.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/log_fragment.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/print_test_utils.dart';
import 'package:npe2e/process_utils.dart';
import 'package:npe2e/test_result.dart';

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
List<Future<CoreTestResult> Function()> runNptToPort22NoEncryptTrafficTests({
  required final CoreTestsContext context,
}) {
  final List<Future<CoreTestResult> Function()> testFactories = [];
  final CoreTestLogger testLogger = CoreTestLogger(
    logsDirectory: context.logsDirectory,
    testName: testName,
  );

  final List<(NoPortsVersion, NoPortsVersion)> versionPermutations =
      _generateVersionPermutations(
        clientVersions: [
          NoPortsVersion(language: Language.dart, version: 'current'),
        ],
        daemonVersions: [
          NoPortsVersion(language: Language.dart, version: 'current'),
        ],
      );

  for (final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion)
      in versionPermutations) {
    testFactories.add(
      () => _runNptToPort22NoEncryptTrafficTest(
        context: context,
        testLogger: testLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
      ),
    );
  }

  return testFactories;
}

Future<CoreTestResult> _runNptToPort22NoEncryptTrafficTest({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) async {
  final String extra = generateExtraString(
    clientVersion,
    daemonVersion,
    useShortLanguageName: true,
  );
  printTestStart(testName: testName, extra: extra);
  final String deviceName =
      '${getDeviceNameNoFlags(testRunId: context.testRunId, noPortsVersion: daemonVersion)}_f';
  final ClientBinary nptClientBinary = context.clientBinaries.firstWhere(
    (cb) =>
        cb.binaryType == ClientBinaryType.npt &&
        cb.noPortsVersion == clientVersion,
  );
  final List<String> nptArgs = _buildNptArgs(
    context: context,
    deviceName: deviceName,
  );

  final DockerInstance dockerInstance = context.dockerInstances
      .firstWhere((di) => di.$1 == deviceName)
      .$2;
  final LogFragment logFragment1 = await dockerInstance.createLogFragment(
    stdoutFile: testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataNptExecution,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataNptExecution,
    ),
  );
  logFragment1.start();
  final ProcessOutputCapture nptOutput = await startCommandWithCapture(
    nptClientBinary.file.path,
    nptArgs,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataNptExecution,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataNptExecution,
    ),
  );
  final int exitCode1 = await nptOutput.exitCode;
  logFragment1.stop();
  if (exitCode1 != 0) {
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode1,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: nptOutput, daemonLogFragment: logFragment1);
    return coreTestResult;
  }

  final String localPortStr = nptOutput.stdout;
  final int? localPort = int.tryParse(localPortStr.trim());
  if (localPort == null) {
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode1,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: nptOutput, daemonLogFragment: logFragment1);
    return coreTestResult;
  }

  final String remoteUsername = context.remoteUsername;

  final List<String> sshArgs = [
    '-p',
    localPort.toString(),
    '-o',
    'StrictHostKeyChecking=accept-new',
    '-o',
    'IdentitiesOnly=yes',
    '-i',
    context.identityFilePath,
    '${remoteUsername}@localhost',
    'echo',
    '`whoami`',
    '`date`',
    '`hostname`',
    'TEST PASSED',
  ];
  final LogFragment logFragment2 = await dockerInstance.createLogFragment(
    stdoutFile: testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataSshExecution,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataSshExecution,
    ),
  );
  logFragment2.start();
  final ProcessOutputCapture sshOutput = await startCommandWithCapture(
    'ssh',
    sshArgs,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataSshExecution,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataSshExecution,
    ),
  );
  final int exitCode2 = await sshOutput.exitCode;
  logFragment2.stop();
  // Match e2e_all's pass criterion: the ssh must exit 0 AND the remote command
  // must actually have run (its output contains the 'TEST PASSED' marker).
  if (exitCode2 != 0 || !sshOutput.stdout.contains('TEST PASSED')) {
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode2,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: sshOutput, daemonLogFragment: logFragment2);
    return coreTestResult;
  }

  final CoreTestResult coreTestResult = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: TestStatus.passed,
    exitCode: exitCode2,
  );
  printTestResult(testResult: coreTestResult, extra: extra);
  return coreTestResult;
}

List<String> _buildNptArgs({
  required CoreTestsContext context,
  required String deviceName,
}) {
  final List<String> args = [
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
    '22',
    '--exit-when-connected',
    '--no-encrypt-rvd-traffic',
    '--verbose',
    '-k',
    context.apkamKeys[context.clientAtsign]!.path,
  ];

  return args;
}

List<(NoPortsVersion, NoPortsVersion)> _generateVersionPermutations({
  required List<NoPortsVersion> clientVersions,
  required List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> permutations = [];
  for (final clientVersion in clientVersions) {
    for (final daemonVersion in daemonVersions) {
      if (clientVersion.version != 'current' ||
          daemonVersion.version != 'current') {
        continue;
      }
      permutations.add((clientVersion, daemonVersion));
    }
  }
  return permutations;
}
