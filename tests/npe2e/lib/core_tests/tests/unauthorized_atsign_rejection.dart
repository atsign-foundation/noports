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
const String testName = 'unauthorized_atsign_rejection';

/// Verifies that the C sshnpd daemon rejects requests from atSigns not in its
/// manager list. Uses the relay atSign as an unauthorized client — the daemon
/// is started with `-m $clientAtsign`, so the relay atSign should be rejected.
///
/// Only runs against c:current daemons with d:current client.
List<Future<CoreTestResult> Function()> runUnauthorizedAtsignRejectionTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final List<Future<CoreTestResult> Function()> testFactories = [];
  final CoreTestLogger testLogger = CoreTestLogger(
    logsDirectory: context.logsDirectory,
    testName: testName,
  );

  final NoPortsVersion currentDartClient = NoPortsVersion(
    language: Language.dart,
    version: 'current',
  );

  for (final NoPortsVersion daemonVersion in daemonVersions) {
    if (daemonVersion.language != Language.c) {
      continue;
    }
    if (daemonVersion.version != 'current') {
      continue;
    }

    testFactories.add(
      () => _runUnauthorizedAtsignRejectionTest(
        context: context,
        testLogger: testLogger,
        clientVersion: currentDartClient,
        daemonVersion: daemonVersion,
      ),
    );
  }

  return testFactories;
}

Future<CoreTestResult> _runUnauthorizedAtsignRejectionTest({
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
    (ClientBinary cb) =>
        cb.binaryType == ClientBinaryType.npt &&
        cb.noPortsVersion == clientVersion,
  );

  final DockerInstance dockerInstance = context.dockerInstances
      .firstWhere(((String, DockerInstance) di) => di.$1 == deviceName)
      .$2;

  final LogFragment logFragment = await dockerInstance.createLogFragment(
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

  // Run npt as the relay atSign (unauthorized) targeting the daemon.
  // The daemon's manager list only includes clientAtsign, so relayAtsign
  // should be rejected.
  final List<String> nptArgs = [
    '-f', context.relayAtsign,
    '-t', context.daemonAtsign,
    '-d', deviceName,
    '-r', context.relayAtsign,
    '--root-domain', context.rootDomain,
    '--remote-port', '22',
    '--exit-when-connected',
    '--verbose',
  ];

  if (context.apkamKeys.containsKey(context.relayAtsign)) {
    nptArgs.addAll(['-k', context.apkamKeys[context.relayAtsign]!.path]);
  }

  logFragment.start();
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

  final int exitCode = await nptOutput.exitCode;

  // Give the daemon a moment to log the rejection
  await Future<void>.delayed(const Duration(seconds: 2));
  logFragment.stop();

  // The npt command should have failed (daemon rejects unauthorized atSign)
  if (exitCode == 0) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode,
    );
    print('FAIL: npt succeeded as unauthorized atSign ${context.relayAtsign} '
        '— daemon should have rejected it');
    printAllLogs(clientCapture: nptOutput, daemonLogFragment: logFragment);
    return result;
  }

  // Verify the daemon log contains the rejection message
  final String daemonStdout = logFragment.stdoutFile.existsSync()
      ? logFragment.stdoutFile.readAsStringSync()
      : '';
  final String daemonStderr = logFragment.stderrFile.existsSync()
      ? logFragment.stderrFile.readAsStringSync()
      : '';
  final String combinedDaemonLog = '$daemonStdout\n$daemonStderr';

  if (!combinedDaemonLog.contains('Rejecting request from unauthorized atSign')) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode,
    );
    print('FAIL: daemon log does not contain rejection message '
        '— the authorization check may not be working');
    printAllLogs(clientCapture: nptOutput, daemonLogFragment: logFragment);
    return result;
  }

  final CoreTestResult result = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: TestStatus.passed,
    exitCode: exitCode,
  );
  printTestResult(testResult: result, extra: extra);
  return result;
}
