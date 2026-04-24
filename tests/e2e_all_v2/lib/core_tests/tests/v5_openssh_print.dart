import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
import 'package:e2e_all_v2/core_tests/core_tests_logging.dart';
import 'package:e2e_all_v2/core_tests/core_tests_print_utils.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/log_fragment.dart';
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
List<Future<CoreTestResult> Function()> runV5OpensshPrintTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final List<Future<CoreTestResult> Function()> testFunctions = [];
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

    testFunctions.add(() => _runV5OpensshPrintTest(
      context: context,
      testLogger: testLogger,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
    ));
  }

  return testFunctions;
}

Future<CoreTestResult> _runV5OpensshPrintTest({
  required final CoreTestsContext context,
  required final CoreTestLogger testLogger,
  required final NoPortsVersion clientVersion,
  required final NoPortsVersion daemonVersion,
}) async {
  final String extra = generateExtraString(clientVersion, daemonVersion, useShortLanguageName: true);
  printTestStart(testName: testName, extra: extra);

  final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere((cb) =>
    cb.binaryType == ClientBinaryType.sshnp &&
    cb.noPortsVersion == clientVersion);

  final String deviceName = '${getDeviceNameNoFlags(
    testRunId: context.testRunId,
    noPortsVersion: daemonVersion)}_f';

  final List<String> sshnpArgs = _buildSshnpArgs(
    context: context,
    clientVersion: clientVersion,
    daemonLanguage: daemonVersion.language,
    deviceName: deviceName,
  );

  final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
  final LogFragment daemonLogFragment1 = daemonDockerInstance.createLogFragment(
    stdoutFile: testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataSshnpExecution,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataSshnpExecution,
    ),
  );
  daemonLogFragment1.start();

  // 1. Execute sshnp to get the SSH command
  final ProcessOutputCapture sshnpCapture = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    sshnpArgs,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataSshnpExecution,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataSshnpExecution,
    ),
  );

  final int sshnpExitCode = await sshnpCapture.exitCode;
  daemonLogFragment1.stop();

  if(sshnpExitCode != 0) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: sshnpExitCode,
    );
    printTestResult(testResult: result, extra: extra);
    printAllLogs(clientCapture: sshnpCapture, daemonLogFragment: daemonLogFragment1);
    return result;
  }

  // 2. Parse the SSH command from sshnp output
  String sshCommand = sshnpCapture.stdout.trim();
  if(sshCommand.startsWith('ssh ')) {
    sshCommand = sshCommand.substring(4);
  } else {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: 1,
    );
    printTestResult(testResult: result, extra: extra);
    print('Expected stdout from sshnp to start with "ssh ". Actual output: "$sshCommand"');
    printAllLogs(clientCapture: sshnpCapture, daemonLogFragment: daemonLogFragment1);
    return result;
  }

  // 3. Parse SSH command into args and add test command
  List<String> sshCommandArgs = sshCommand.split(' ');
  sshCommandArgs.add('echo');
  sshCommandArgs.add('`date`');
  sshCommandArgs.add('`whoami`');
  sshCommandArgs.add('`hostname`');
  sshCommandArgs.add('TEST');
  sshCommandArgs.add('PASSED');

  final LogFragment daemonLogFragment2 = daemonDockerInstance.createLogFragment(
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
  daemonLogFragment2.start();

  // 4. Execute the SSH command
  final ProcessOutputCapture sshCapture = await startCommandWithCapture(
    'ssh',
    sshCommandArgs,
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
  final int sshExitCode = await sshCapture.exitCode;
  daemonLogFragment2.stop();

  final CoreTestResult result = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: sshExitCode == 0 ? TestStatus.passed : TestStatus.failed,
    exitCode: sshExitCode,
  );
  printTestResult(testResult: result, extra: extra);
  if(sshExitCode != 0) {
    print('Failed SSH execution. sshnp logs:');
    printAllLogs(clientCapture: sshnpCapture, daemonLogFragment: daemonLogFragment1, clientLabel: 'Client (sshnp)', daemonLabel: 'Daemon (sshnp execution)');
    print('SSH execution logs:');
    printAllLogs(clientCapture: sshCapture, daemonLogFragment: daemonLogFragment2, clientLabel: 'Client (ssh)', daemonLabel: 'Daemon (ssh execution)');
  }
  return result;
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
    '-i', context.identityFilePath,
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
