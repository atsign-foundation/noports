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
const String testName = 'npt_to_port_22';

// Test: npt_to_port_22
// 1. Execute npt command to create a tunnel to remote port 22
// 2. Capture the local port returned by npt
// 3. Execute SSH connection to localhost on the local port, verify succeeds
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: C (current)
// - Client: Dart v5.9.4 | Daemon: C (current)
// - Client: Dart v5.11.2 | Daemon: C (current)
// - Client: Dart v5.13.0 | Daemon: C (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0
List<Future<CoreTestResult> Function()> runNptToPort22Tests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final List<Future<CoreTestResult> Function()> testFactories = [];
  final CoreTestLogger testLogger = CoreTestLogger(
    logsDirectory: context.logsDirectory,
    testName: testName,
  );

  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations =
      _generateVersionCombinations(
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
      );

  for (final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion)
      in versionCombinations) {
    testFactories.add(
      () => _runNptToPort22Test(
        context: context,
        testLogger: testLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
      ),
    );
  }

  return testFactories;
}

Future<CoreTestResult> _runNptToPort22Test({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) async {
  final String extra = generateExtraString(clientVersion, daemonVersion);
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
    clientVersion: clientVersion,
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
  final String nptStdout = nptOutput.stdout;
  final int localPort = int.parse(nptStdout.trim());
  const String executable = 'ssh';
  final List<String> sshArgs = [
    '-p',
    localPort.toString(),
    '-o',
    'StrictHostKeyChecking=accept-new',
    '-o',
    'IdentitiesOnly=yes',
    '${context.remoteUsername}@localhost',
    '-i',
    context.identityFilePath,
    'echo',
    '`whoami`',
    '`date`',
    '`hostname`',
    'TEST PASSED',
  ];
  logFragment2.start();
  final ProcessOutputCapture sshOutput = await startCommandWithCapture(
    executable,
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
  if (exitCode2 != 0) {
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
  required NoPortsVersion clientVersion,
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

List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> combinations = [];
  for (final clientVersion in clientVersions) {
    for (final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      // Skip if both are not current (released client already tested with released daemon)
      if (!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      if (versionIsAtLeast(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.3.0'),
      )) {}
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
