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

const String _metadataSshnpExecution = 'sshnpExecution';
const String _metadataSshExecution = 'sshExecution';
const String testName = 'v5_openssh_print';

// Test: v5_openssh_print
// Tests v5 daemon features with OpenSSH client in print mode
// - Uses --ssh-client openssh flag with -x (print mode)
// - sshnp prints the SSH command, test executes it manually
// - Tests traditional OpenSSH workflow with v5 features
// Requirements:
// - Requires v5+ client to test v5 features and for print mode support
// - Requires v5+ daemon to test v5 features
// - v5.0.x clients have a bug preventing this from working in scripts
// - C daemon requires v5.3.0+ client for compatibility
// Test matrix:
// - Released client with current daemon
// - Current client with released daemon
// - Skips v5.0.x clients (bug prevents running from script)
Future<List<CoreTestResult>> runV5OpensshPrintTests({
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
    // Require v5+ client for v5 features
    if(versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
      continue;
    }

    // Skip v5.0.x clients due to bug
    if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0')) &&
       versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.1.0'))) {
      continue;
    }

    // Require v5+ daemon for v5 features
    if(versionIsLessThan(daemonVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
      continue;
    }

    // C daemon requires v5.3.0+ client
    if(daemonVersion.language == Language.c &&
       versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
      continue;
    }

    final String extra = '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version})';
    final String clientVersionStr = clientVersion.version;
    final String daemonVersionStr = daemonVersion.version;

    final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere((cb) =>
      cb.binaryType == ClientBinaryType.sshnp &&
      cb.noPortsVersion == clientVersion);

    final String deviceName = '${getDeviceNameNoFlags(
      testRunId: context.testRunId,
      language: daemonVersion.language,
      version: daemonVersionStr)}_f';
    final String daemonInfo = '${daemonVersion.language.name}_${daemonVersionStr}';

    final List<String> sshnpArgs = _buildSshnpArgs(
      context: context,
      clientVersion: clientVersion,
      daemonLanguage: daemonVersion.language,
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
        testMetadata: _metadataSshnpExecution,
      ),
      stderrFragmentFile: testLogger.getDaemonStderrLogFile(
        language: daemonVersion.language,
        version: daemonVersionStr,
        deviceName: deviceName,
        testMetadata: _metadataSshnpExecution,
      ),
    );
    await daemonLogCapture.start();

    // 1. Execute sshnp to get the SSH command
    final ProcessOutputCapture sshnpCapture = await startCommandWithCapture(
      sshnpClientBinary.file.path,
      sshnpArgs,
      stdoutLogFile: testLogger.getClientStdoutLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataSshnpExecution,
        daemonInfo: daemonInfo,
      ),
      stderrLogFile: testLogger.getClientStderrLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataSshnpExecution,
        daemonInfo: daemonInfo,
      ),
    );

    final int sshnpExitCode = await sshnpCapture.exitCode;
    await daemonLogCapture.stop();

    if(sshnpExitCode != 0) {
      final CoreTestResult result = CoreTestResult(
        testName: testName,
        clientVersion: clientVersionStr,
        daemonVersion: daemonVersionStr,
        status: TestStatus.failed,
        exitCode: sshnpExitCode,
        stdout: StringBuffer(sshnpCapture.stdout),
        stderr: StringBuffer(sshnpCapture.stderr),
      );
      printTestResult(testResult: result, extra: extra);
      printAllLogs(clientCapture: sshnpCapture, daemonLogCapture: daemonLogCapture);
      testResults.add(result);
      continue;
    }

    // 2. Parse the SSH command from sshnp output
    String sshCommand = sshnpCapture.stdout.trim();
    if(sshCommand.startsWith('ssh ')) {
      sshCommand = sshCommand.substring(4);
    } else {
      final CoreTestResult result = CoreTestResult(
        testName: testName,
        clientVersion: clientVersionStr,
        daemonVersion: daemonVersionStr,
        status: TestStatus.failed,
        exitCode: 1,
        stdout: StringBuffer('Expected stdout from sshnp to start with "ssh ". Actual output: "$sshCommand"'),
      );
      printTestResult(testResult: result, extra: extra);
      printAllLogs(clientCapture: sshnpCapture, daemonLogCapture: daemonLogCapture);
      testResults.add(result);
      continue;
    }

    // 3. Parse SSH command into args and add test command
    List<String> sshCommandArgs = sshCommand.split(' ');
    sshCommandArgs.add('echo');
    sshCommandArgs.add('`date`');
    sshCommandArgs.add('`whoami`');
    sshCommandArgs.add('`hostname`');
    sshCommandArgs.add('TEST');
    sshCommandArgs.add('PASSED');

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

    // 4. Execute the SSH command
    final ProcessOutputCapture sshCapture = await startCommandWithCapture('ssh', sshCommandArgs);
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
          clientCapture: sshnpCapture,
          daemonLogCapture: daemonLogCapture,
          clientLabel: 'Client (sshnp)',
          daemonLabel: 'Daemon (sshnp execution)',
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
        clientCapture: sshnpCapture,
        daemonLogCapture: daemonLogCapture,
        clientLabel: 'Client (sshnp)',
        daemonLabel: 'Daemon (sshnp execution)',
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

List<String> _buildSshnpArgs({
  required CoreTestsContext context,
  required NoPortsVersion clientVersion,
  required Language daemonLanguage,
  required String deviceName,
}) {
  final List<String> args = [
    '-f', context.clientAtsign,
    '-t', context.daemonAtsign,
    '-d', deviceName,
    '-h', context.relayAtsign,
    '-u', context.remoteUsername,
    '--root-domain', context.rootDomain,
    '-s',
    '--ssh-client', 'openssh',
    '-x', // Print mode
  ];

  // C daemon requires -x flag (already added above)

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

      // Skip if both are not current
      if(!isClientCurrent && !isDaemonCurrent) {
        continue;
      }

      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
