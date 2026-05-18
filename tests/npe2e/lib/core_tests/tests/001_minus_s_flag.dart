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

const String testName = '001_minus_s_flag';
const String _metadataNoFlags = 'noFlags';
const String _metadataWithFlags = 'withFlags';
const String _metadataSshTest = 'sshTest';

// Test: 001_minus_s_flag
// 1. Generate a new SSH key
// 2.
//     a. Run sshnp against a dameon without the `-s` flag with that new key
//     b. Verify it fails
// 3.
//     a. Run against a daemon with the `-s` flag
//     b. Verify it succeeds
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: C (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0
List<Future<CoreTestResult> Function()> run001MinusSFlagTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> daemonVersions,
}) {
  // an object that helps with managing logs
  final CoreTestLogger coreTestLogger = CoreTestLogger(
    logsDirectory: context.logsDirectory,
    testName: testName,
  );

  final List<Future<CoreTestResult> Function()> testFactories = [];
  for (final NoPortsVersion daemonVersion in daemonVersions) {
    // Create a factory function that will create the future when called
    testFactories.add(
      () => _run001MinusSFlagTest(
        context: context,
        coreTestLogger: coreTestLogger,
        daemonVersion: daemonVersion,
        clientVersion: context.clientBinaries
            .firstWhere((cb) => cb.binaryType == ClientBinaryType.sshnp)
            .noPortsVersion,
      ),
    );
  }

  return testFactories;
}

Future<CoreTestResult> _run001MinusSFlagTest({
  required CoreTestsContext context,
  required CoreTestLogger coreTestLogger,
  required NoPortsVersion daemonVersion,
  required NoPortsVersion clientVersion,
}) async {
  final String extra = generateExtraString(
    clientVersion,
    daemonVersion,
    useShortLanguageName: true,
  );
  printTestStart(testName: testName, extra: extra);
  final ClientBinary currentSshnpClientBinary = context.clientBinaries
      .firstWhere(
        (cb) =>
            cb.binaryType == ClientBinaryType.sshnp &&
            cb.noPortsVersion == clientVersion,
      );

  // Step 1: Run sshnp against a dameon without the `-s` flag, verify it fails
  final String deviceNameNoFlags = getDeviceNameNoFlags(
    testRunId: context.testRunId,
    noPortsVersion: daemonVersion,
  );
  final DockerInstance dockerInstance1 = context.dockerInstances
      .firstWhere((di) => di.$1 == deviceNameNoFlags)
      .$2;
  final LogFragment logFragment1 = await dockerInstance1.createLogFragment(
    stdoutFile: coreTestLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceNameNoFlags,
      testMetadata: _metadataNoFlags,
    ),
    stderrFile: coreTestLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceNameNoFlags,
      testMetadata: _metadataNoFlags,
    ),
  );
  logFragment1.start();
  final List<String> sshnpArgs1 = _buildSshnpArgs(
    context: context,
    deviceName: deviceNameNoFlags,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
  );
  final ProcessOutputCapture capture1 = await startCommandWithCapture(
    currentSshnpClientBinary.file.path,
    sshnpArgs1,
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataNoFlags,
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataNoFlags,
    ),
  );
  final int exitCode1 = await capture1.exitCode;
  logFragment1.stop();
  if (exitCode1 == 0) {
    // it succeeded, not expected.
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode1,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: capture1, daemonLogFragment: logFragment1);
    return coreTestResult;
  }

  // Step 2: Run sshnp against dameon with `-s -u`
  final String deviceNameWithFlags = '${deviceNameNoFlags}_f';
  final DockerInstance dockerInstance2 = context.dockerInstances
      .firstWhere((di) => di.$1 == deviceNameWithFlags)
      .$2;
  final LogFragment logFragment2 = await dockerInstance2.createLogFragment(
    stdoutFile: coreTestLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceNameWithFlags,
      testMetadata: _metadataWithFlags,
    ),
    stderrFile: coreTestLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceNameWithFlags,
      testMetadata: _metadataWithFlags,
    ),
  );
  final List<String> sshnpArgs2 = _buildSshnpArgs(
    context: context,
    deviceName: deviceNameWithFlags,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
  );
  logFragment2.start();
  final ProcessOutputCapture capture2 = await startCommandWithCapture(
    currentSshnpClientBinary.file.path,
    sshnpArgs2,
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataWithFlags,
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataWithFlags,
    ),
  );
  final int exitCode2 = await capture2.exitCode;
  logFragment2.stop();
  if (exitCode2 != 0) {
    // it failed, not expected.
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode2,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: capture2, daemonLogFragment: logFragment2);
    return coreTestResult;
  }

  // 3. Use the stdout from step 2 then execute ssh command
  final LogFragment logFragment3 = await dockerInstance2.createLogFragment(
    stdoutFile: coreTestLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceNameWithFlags,
      testMetadata: _metadataSshTest,
    ),
    stderrFile: coreTestLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceNameWithFlags,
      testMetadata: _metadataSshTest,
    ),
  );
  logFragment3.start();
  // TODO: make helper function to form ssh command
  String sshCommand = capture2.stdout.trim();
  if (sshCommand.startsWith('ssh ')) {
    sshCommand = sshCommand.substring(4);
  }
  final List<String> sshCommandArgs = sshCommand.split(' ');
  const String sshExecutable = 'ssh';
  sshCommandArgs.addAll([
    'echo',
    '`whoami`'
        '`date`',
    '`hostname`',
    'TEST PASSED',
  ]);
  final ProcessOutputCapture capture3 = await startCommandWithCapture(
    sshExecutable,
    sshCommandArgs,
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataSshTest,
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataSshTest,
    ),
  );
  final int exitCode3 = await capture3.exitCode;
  logFragment3.stop();
  final CoreTestResult coreTestResult = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: exitCode3 == 0 ? TestStatus.passed : TestStatus.failed,
    exitCode: exitCode3,
  );
  printTestResult(testResult: coreTestResult, extra: extra);
  if (exitCode3 != 0) {
    // it failed, not expected.
    printAllLogs(clientCapture: capture3, daemonLogFragment: logFragment3);
  }
  return coreTestResult;
}

List<String> _buildSshnpArgs({
  required CoreTestsContext context,
  required String deviceName,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) {
  final List<String> args = [
    '-f',
    context.clientAtsign,
    '-t',
    context.daemonAtsign,
    '-i',
    context.identityFilePath,
    '-d',
    deviceName,
    '-h',
    context.relayAtsign,
    '-u',
    context.remoteUsername,
    '--root-domain',
    context.rootDomain,
    '-s',
  ];

  if (daemonVersion.language == Language.c) {
    args.add('-x');
  } else if (versionIsAtLeast(
    clientVersion,
    NoPortsVersion(language: Language.dart, version: 'v5.0.0'),
  )) {
    args.add('-x');
    args.add('--no-ad');
    args.add('--no-et');
  }

  if (versionIsAtLeast(
    clientVersion,
    NoPortsVersion(language: Language.dart, version: 'v5.3.0'),
  )) {
    args.add('-k');
    args.add(context.apkamKeys[context.clientAtsign]!.path);
  }

  return args;
}
