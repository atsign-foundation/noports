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

const String _metadataDashDashHost = 'dashDashHost';
const String _metadataInvalidHostValidR = 'invalidHostValidR';
const String _metadataValidHostInvalidR = 'validHostInvalidR';
const String testName = 'minus_r_flag';

// The --host and -r flag are the same thing. This is a test to ensure backwards compatibility
// 1. Run sshnp with `--host` (expect to pass)
// 2. Run sshnp with `-h` invalid and `-r` valid (expect to pass)
// 3. Run sshnp with `-h` valid and `-r` invalid (expect to fail)
//
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0
List<Future<CoreTestResult> Function()> runMinusRFlagTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final CoreTestLogger coreTestLogger = CoreTestLogger(
    logsDirectory: context.logsDirectory,
    testName: testName,
  );
  final Set<(NoPortsVersion, NoPortsVersion)> versionCombinations =
      _generateVersionCombinations(
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
      );

  final List<Future<CoreTestResult> Function()> testFactories = [];
  for (final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion)
      in versionCombinations) {
    final String deviceName =
        '${getDeviceNameNoFlags(testRunId: context.testRunId, noPortsVersion: daemonVersion)}_f';
    testFactories.add(
      () => _runMinusRFlagTest(
        context: context,
        coreTestLogger: coreTestLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
        deviceName: deviceName,
      ),
    );
  }
  return testFactories;
}

Future<CoreTestResult> _runMinusRFlagTest({
  required final CoreTestLogger coreTestLogger,
  required final CoreTestsContext context,
  required final NoPortsVersion clientVersion,
  required final NoPortsVersion daemonVersion,
  required final String deviceName,
}) async {
  final String extra = generateExtraString(clientVersion, daemonVersion);
  printTestStart(testName: testName, extra: extra);
  final String relayAtsign = context.relayAtsign;

  final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere(
    (cb) =>
        cb.binaryType == ClientBinaryType.sshnp &&
        cb.noPortsVersion == clientVersion,
  );
  final DockerInstance dockerInstance = context.dockerInstances
      .firstWhere(
        (di) =>
            di.$1 ==
            getDeviceNameNoFlags(
              testRunId: context.testRunId,
              noPortsVersion: daemonVersion,
            ),
      )
      .$2;

  // 1. Run sshnp with `--host` (expect to pass)
  final List<String> args1 = _buildBaseSshnpArgs(
    context: context,
    clientBinary: sshnpClientBinary,
    deviceName: deviceName,
  );
  final LogFragment logFragment1 = await dockerInstance.createLogFragment(
    stdoutFile: coreTestLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataDashDashHost,
    ),
    stderrFile: coreTestLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataDashDashHost,
    ),
  );
  logFragment1.start();
  final ProcessOutputCapture capture1 = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    [...args1, '--host', relayAtsign],
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataDashDashHost,
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataDashDashHost,
    ),
  );
  final int exitCode1 = await capture1.exitCode;
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
    printAllLogs(clientCapture: capture1, daemonLogFragment: logFragment1);
    return coreTestResult;
  }

  // 2. Run sshnp with invalid `-h` and valid `-r` (expect to pass)
  final List<String> args2 = _buildBaseSshnpArgs(
    context: context,
    clientBinary: sshnpClientBinary,
    deviceName: deviceName,
  );
  final LogFragment logFragment2 = await dockerInstance.createLogFragment(
    stdoutFile: coreTestLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataInvalidHostValidR,
    ),
    stderrFile: coreTestLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataInvalidHostValidR,
    ),
  );
  logFragment2.start();
  final ProcessOutputCapture capture2 = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    [
      ...args2,
      '-h',
      '@do_not_activate',
      '-r',
      relayAtsign,
    ], // TODO make @do_not_activate a constant somewhere
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataInvalidHostValidR,
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataInvalidHostValidR,
    ),
  );
  final int exitCode2 = await capture2.exitCode;
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

  // 3. Run sshnp with valid `-h` and invalid `-r` (expect to fail)
  final List<String> args3 = _buildBaseSshnpArgs(
    context: context,
    clientBinary: sshnpClientBinary,
    deviceName: deviceName,
  );
  final LogFragment logFragment3 = await dockerInstance.createLogFragment(
    stdoutFile: coreTestLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataValidHostInvalidR,
    ),
    stderrFile: coreTestLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataValidHostInvalidR,
    ),
  );
  logFragment3.start();
  final ProcessOutputCapture capture3 = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    [
      ...args3,
      '-h',
      relayAtsign,
      '-r',
      '@do_not_activate',
    ], // TODO make @do_not_activate a constant somewhere
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataValidHostInvalidR,
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataValidHostInvalidR,
    ),
  );
  final int exitCode3 = await capture3.exitCode;
  logFragment3.stop();
  if (exitCode3 == 0) {
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode3,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: capture3, daemonLogFragment: logFragment3);
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

List<String> _buildBaseSshnpArgs({
  required CoreTestsContext context,
  required ClientBinary clientBinary,
  required String deviceName,
}) {
  final List<String> args = [];
  if (versionIsAtLeast(
    clientBinary.noPortsVersion,
    NoPortsVersion(language: Language.dart, version: 'v5.0.0'),
  )) {
    args.add('-x');
    args.add('--no-ad');
    args.add('--no-et');
  }
  if (versionIsAtLeast(
    clientBinary.noPortsVersion,
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
    '-i',
    context.identityFilePath,
    '-u',
    context.remoteUsername,
    '--root-domain',
    context.rootDomain,
    '-d',
    deviceName,
    '-s',
  ]);
  return args;
}

// we only want to check:
//   a. non-current client with current daemon
//   b. current cleint with non-current daemon
Set<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  Set<(NoPortsVersion, NoPortsVersion)> combinations = {};
  for (final clientVersion in clientVersions) {
    for (final daemonVersion in daemonVersions) {
      if (combinations.contains((clientVersion, daemonVersion))) {
        // if permutation already exists, skip
        continue;
      }
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      // skip if both client and daemon are not current
      if (!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      if (daemonVersion.language == Language.c) {
        // C daemon doesn't need to test a client side only feature
        continue;
      }
      if (clientVersion.language == Language.dart &&
          versionIsLessThan(
            clientVersion,
            NoPortsVersion(language: Language.dart, version: 'v5.2.0'),
          )) {
        // -r was added in v5.2.0
        continue;
      }
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
