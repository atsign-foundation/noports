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

const String testName = 'minus_u_flag';
const String _metadataNoFlags = 'noFlags';

// 1. Run sshnp without `-u <username>` talking to device daemon which does not have `-u` flag enabled (expect to fail)
// 2. Run sshnp without `-u <username>` talking to device daemon which does have `-u` flag enabled (expect to pass)
// - Client: Dart (current) | Daemon: Dart (current)
List<Future<CoreTestResult> Function()> runMinusUFlagTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final List<Future<CoreTestResult> Function()> testFactories = [];
  final CoreTestLogger coreTestLogger = CoreTestLogger(
    logsDirectory: context.logsDirectory,
    testName: testName,
  );

  for (final NoPortsVersion clientVersion in clientVersions) {
    for (final NoPortsVersion daemonVersion in daemonVersions) {
      // Only run this test with the Dart current client against the Dart
      // current daemon (matches e2e_all, which required `daemonVersion ==
      // d:current`). Note c:current also has version=='current', so we must
      // also check the language to avoid generating a mislabeled duplicate that
      // still targets the Dart current daemon.
      if (clientVersion.language != Language.dart ||
          clientVersion.version != 'current' ||
          daemonVersion.language != Language.dart ||
          daemonVersion.version != 'current') {
        continue;
      }
      testFactories.add(
        () => _runMinusUFlagTest(
          context: context,
          coreTestLogger: coreTestLogger,
          clientVersion: clientVersion,
          daemonVersion: daemonVersion,
        ),
      );
    }
  }

  return testFactories;
}

Future<CoreTestResult> _runMinusUFlagTest({
  required CoreTestsContext context,
  required CoreTestLogger coreTestLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) async {
  final String extra = generateExtraString(clientVersion, daemonVersion);
  printTestStart(testName: testName, extra: extra);

  final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere(
    (cb) =>
        cb.binaryType == ClientBinaryType.sshnp &&
        cb.noPortsVersion == clientVersion,
  );

  // 1. Run `sshnp` (no -u $remoteUsername) talking to sshnpd (no `-u`)
  // verify fail
  final String deviceNameNoFlags = getDeviceNameNoFlags(
    testRunId: context.testRunId,
    noPortsVersion: NoPortsVersion(language: Language.dart, version: 'current'),
  );
  final DockerInstance dockerInstanceWithoutFlags = context.dockerInstances
      .firstWhere((di) => di.$1 == deviceNameNoFlags)
      .$2;
  final List<String> sshnpArgs1 = _generateBaseSshnpArgs(
    context: context,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    deviceName: deviceNameNoFlags,
  );
  final LogFragment logFragment1 = await dockerInstanceWithoutFlags
      .createLogFragment(
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
  final ProcessOutputCapture capture1 = await startCommandWithCapture(
    sshnpClientBinary.file.path,
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
  final int exitCode1 = await capture1.process.exitCode;
  logFragment1.stop();
  if (exitCode1 == 0) {
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

  // 2. Run sshnp without `-u` to sshnpd with `-u`:w
  // Verify succeeds
  final String deviceNameWithFlags = '${deviceNameNoFlags}_f';
  final DockerInstance dockerInstanceWithFlags = context.dockerInstances
      .firstWhere((di) => di.$1 == deviceNameWithFlags)
      .$2;
  final List<String> sshnpArgs2 = _generateBaseSshnpArgs(
    context: context,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    deviceName: deviceNameWithFlags,
  );
  final LogFragment logFragment2 = await dockerInstanceWithFlags
      .createLogFragment(
        stdoutFile: coreTestLogger.getDaemonStdoutLogFile(
          daemonVersion: daemonVersion,
          deviceName: deviceNameWithFlags,
          testMetadata: _metadataNoFlags,
        ),
        stderrFile: coreTestLogger.getDaemonStderrLogFile(
          daemonVersion: daemonVersion,
          deviceName: deviceNameWithFlags,
          testMetadata: _metadataNoFlags,
        ),
      );
  logFragment2.start();
  final ProcessOutputCapture capture2 = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    sshnpArgs2,
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
  final int exitCode2 = await capture2.process.exitCode;
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
    printAllLogs(clientCapture: capture2, daemonLogFragment: logFragment2);
    return coreTestResult;
  }

  // 2b. Run ssh command from sshnp output
  String sshCommand = capture2.stdout.trim();
  if (sshCommand.startsWith('ssh ')) {
    sshCommand = sshCommand.substring(4);
  }
  final List<String> sshCommandParts = sshCommand.split(' ');
  sshCommandParts.addAll([
    'echo',
    '`whoami`'
        '`date`',
    '`hostname`',
    'TEST PASSED',
  ]); // TODO helper function
  final ProcessOutputCapture capture3 = await startCommandWithCapture(
    'ssh',
    sshCommandParts,
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: '${_metadataNoFlags}_sshCommand',
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: '${_metadataNoFlags}_sshCommand',
    ),
  );
  final int exitCode3 = await capture3.process.exitCode;
  // Match e2e_all's pass criterion: the ssh must exit 0 AND the remote command
  // must actually have run (its output contains the 'TEST PASSED' marker).
  if (exitCode3 != 0 || !capture3.stdout.contains('TEST PASSED')) {
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode3,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: capture3, daemonLogFragment: logFragment2);
    return coreTestResult;
  }

  final CoreTestResult coreTestResult = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: TestStatus.passed,
    exitCode: exitCode3,
  );
  printTestResult(testResult: coreTestResult, extra: extra);
  return coreTestResult;
}

List<String> _generateBaseSshnpArgs({
  required final CoreTestsContext context,
  required final NoPortsVersion clientVersion,
  required final NoPortsVersion daemonVersion,
  required final String deviceName,
}) {
  final List<String> args = [];
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
  args.addAll([
    '-f',
    context.clientAtsign,
    '-t',
    context.daemonAtsign,
    '-d',
    deviceName,
    '-h',
    context.relayAtsign,
    '--root-domain',
    context.rootDomain,
    '-i',
    context.identityFilePath,
    '-s',
  ]);
  return args;
}
