import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
import 'package:e2e_all_v2/core_tests/core_tests_logging.dart';
import 'package:e2e_all_v2/core_tests/core_tests_print_utils.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/print_test_utils.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/test_result.dart';

const String _metadataNptExecution = 'nptExecution';
const String _metadataSshExecution = 'sshExecution';
const String testName = 'npt_to_port_22';

// Test: npt_to_port_22
// 1. Execute npt command to create a tunnel to remote port 22
// 2. Capture the local port returned by npt
// 3. Execute SSH connection to localhost on that port
// 4. Verify the SSH connection succeeds
// Test matrix:
// - Released client with current daemon
// - Current client with released daemon
// Requirements:
// - Client AND daemon must be v5.1.0 or greater (npt requires v5.1+)
Future<List<CoreTestResult>> runNptToPort22Tests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) async {
  final List<CoreTestResult> testResults = [];
  final CoreTestLogger testLogger = CoreTestLogger(logsDirectory: context.logsDirectory, testName: testName);

  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations =
    _generateVersionCombinations(
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    );

  for(final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion) in versionCombinations) {
    // Require v5.1.0 or greater for both client and daemon
    if(versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.1.0'))) {
      continue;
    }
    if(versionIsLessThan(daemonVersion, NoPortsVersion(language: Language.dart, version: 'v5.1.0'))) {
      continue;
    }

    final String extra = '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version})';
    final String clientVersionStr = clientVersion.version;
    final String daemonVersionStr = daemonVersion.version;

    final ClientBinary nptClientBinary = context.clientBinaries.firstWhere((cb) =>
      cb.binaryType == ClientBinaryType.npt &&
      cb.noPortsVersion == clientVersion);

    final String deviceName = '${getDeviceNameNoFlags(
      testRunId: context.testRunId,
      language: daemonVersion.language,
      version: daemonVersionStr)}_f';
    final String daemonInfo = '${daemonVersion.language.name}_${daemonVersionStr}';

    final List<String> nptArgs = _buildNptArgs(
      context: context,
      clientVersion: clientVersion,
      deviceName: deviceName,
    );

    printTestStart(testName: testName, extra: extra);

    final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
    final DaemonLogCapture daemonLogCapture = DaemonLogCapture(
      dockerInstance: daemonDockerInstance,
      stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
        language: daemonVersion.language,
        version: daemonVersionStr,
        deviceName: deviceName,
        testMetadata: _metadataNptExecution,
      ),
      stderrFragmentFile: testLogger.getDaemonStderrLogFile(
        language: daemonVersion.language,
        version: daemonVersionStr,
        deviceName: deviceName,
        testMetadata: _metadataNptExecution,
      ),
    );
    await daemonLogCapture.start();

    // 1. Execute npt command
    final ProcessOutputCapture nptCapture = await startCommandWithCapture(
      nptClientBinary.file.path,
      nptArgs,
      stdoutLogFile: testLogger.getClientStdoutLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataNptExecution,
        daemonInfo: daemonInfo,
      ),
      stderrLogFile: testLogger.getClientStderrLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataNptExecution,
        daemonInfo: daemonInfo,
      ),
    );

    final int nptExitCode = await nptCapture.exitCode;
    await daemonLogCapture.stop();

    if(nptExitCode != 0) {
      final CoreTestResult result = CoreTestResult(
        testName: testName,
        clientVersion: clientVersionStr,
        daemonVersion: daemonVersionStr,
        status: TestStatus.failed,
        exitCode: nptExitCode,
        stdout: StringBuffer(nptCapture.stdout),
        stderr: StringBuffer(nptCapture.stderr),
      );
      printTestResult(testResult: result, extra: extra);
      printAllLogs(clientCapture: nptCapture, daemonLogCapture: daemonLogCapture);
      testResults.add(result);
      continue;
    }

    // 2. Parse the local port from npt output
    final String nptOutput = nptCapture.stdout.trim();
    final int? localPort = int.tryParse(nptOutput);

    if(localPort == null) {
      final CoreTestResult result = CoreTestResult(
        testName: testName,
        clientVersion: clientVersionStr,
        daemonVersion: daemonVersionStr,
        status: TestStatus.failed,
        exitCode: 1,
        stdout: StringBuffer('Failed to parse local port from npt output: "$nptOutput"'),
      );
      printTestResult(testResult: result, extra: extra);
      printAllLogs(clientCapture: nptCapture, daemonLogCapture: daemonLogCapture);
      testResults.add(result);
      continue;
    }

    print('npt OK, local port is $localPort');

    // 3. Execute SSH connection
    final List<String> sshArgs = [
      '-p', localPort.toString(),
      '-o', 'StrictHostKeyChecking=accept-new',
      '-o', 'IdentitiesOnly=yes',
      '-i', context.identityFilePath,
      '${context.remoteUsername}@localhost',
      'echo', '`date`', '`whoami`', '`hostname`', 'TEST', 'PASSED',
    ];

    final DaemonLogCapture daemonLogCapture2 = DaemonLogCapture(
      dockerInstance: daemonDockerInstance,
      stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
        language: daemonVersion.language,
        version: daemonVersionStr,
        deviceName: deviceName,
        testMetadata: _metadataSshExecution,
      ),
      stderrFragmentFile: testLogger.getDaemonStderrLogFile(
        language: daemonVersion.language,
        version: daemonVersionStr,
        deviceName: deviceName,
        testMetadata: _metadataSshExecution,
      ),
    );
    await daemonLogCapture2.start();

    final ProcessOutputCapture sshCapture = await startCommandWithCapture('ssh', sshArgs);
    final int sshExitCode = await sshCapture.exitCode;
    await daemonLogCapture2.stop();

    if(sshExitCode == 0) {
      final CoreTestResult result = CoreTestResult(
        testName: testName,
        clientVersion: clientVersionStr,
        daemonVersion: daemonVersionStr,
        status: TestStatus.passed,
        exitCode: sshExitCode,
      );
      printTestResult(testResult: result, extra: extra);
      if(context.alwaysOutputLogs) {
        printAllLogs(
          clientCapture: nptCapture,
          daemonLogCapture: daemonLogCapture,
          clientLabel: 'Client (npt)',
          daemonLabel: 'Daemon (npt execution)',
        );
        printAllLogs(
          clientCapture: sshCapture,
          daemonLogCapture: daemonLogCapture2,
          clientLabel: 'Client (ssh)',
          daemonLabel: 'Daemon (ssh execution)',
        );
      }
      testResults.add(result);
    } else {
      final CoreTestResult result = CoreTestResult(
        testName: testName,
        clientVersion: clientVersionStr,
        daemonVersion: daemonVersionStr,
        status: TestStatus.failed,
        exitCode: sshExitCode,
        stdout: StringBuffer(sshCapture.stdout),
        stderr: StringBuffer(sshCapture.stderr),
      );
      printTestResult(testResult: result, extra: extra);
      printAllLogs(
        clientCapture: nptCapture,
        daemonLogCapture: daemonLogCapture,
        clientLabel: 'Client (npt)',
        daemonLabel: 'Daemon (npt execution)',
      );
      printAllLogs(
        clientCapture: sshCapture,
        daemonLogCapture: daemonLogCapture2,
        clientLabel: 'Client (ssh)',
        daemonLabel: 'Daemon (ssh execution)',
      );
      testResults.add(result);
    }
  }

  return testResults;
}

List<String> _buildNptArgs({
  required CoreTestsContext context,
  required NoPortsVersion clientVersion,
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
    '--verbose',
  ];

  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
    args.add('-k');
    args.add(context.apkamKeys[context.clientAtsign]!.path);
  }

  return args;
}

// Generate version combinations:
// - Released client with current daemon
// - Current client with released daemon
// Skip: released client with released daemon (already tested)
List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> combinations = [];
  for(final clientVersion in clientVersions) {
    for(final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      // Skip if both are not current (released client already tested with released daemon)
      if(!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
