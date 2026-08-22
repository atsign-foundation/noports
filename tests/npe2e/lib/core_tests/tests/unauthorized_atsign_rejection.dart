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

const String _metadataSshnpExecution = 'sshnpExecution';
const String testName = 'unauthorized_atsign_rejection';

// An atSign the runner holds atKeys for, but which is never in a core_tests
// daemon's manager list — those run with `-m $clientAtsign`.
const String _unauthorizedAtsign = '@npe2e_org_client02_jttest';

/// Verifies that the C sshnpd daemon silently rejects ssh_request notifications
/// from atSigns not in its manager list.
///
/// The daemon is started with `-m $clientAtsign`, so sshnp runs as
/// [_unauthorizedAtsign]. It must be an atSign we hold atKeys for: sshnp has to
/// authenticate before it can send anything for the daemon to reject. That rules
/// out the relay atSign (in CI, @rv_am — no atKeys on the runner).
///
/// Asserts sshnp failed and that the daemon logged the rejection naming that
/// atSign; the log check is what proves sshnp reached the daemon at all.
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

  final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere(
    (ClientBinary cb) =>
        cb.binaryType == ClientBinaryType.sshnp &&
        cb.noPortsVersion == clientVersion,
  );

  final DockerInstance dockerInstance = context.dockerInstances
      .firstWhere(((String, DockerInstance) di) => di.$1 == deviceName)
      .$2;

  final LogFragment logFragment = await dockerInstance.createLogFragment(
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

  // Run sshnp as the unauthorized atSign: not in the daemon's manager list, so
  // the request should be silently rejected — no response sent back. No APKAM
  // keys are enrolled for it, so sshnp falls back to its default
  // ~/.atsign/keys/<atsign>_key.atKeys lookup.
  final List<String> sshnpArgs = [
    '-f',
    _unauthorizedAtsign,
    '-t',
    context.daemonAtsign,
    '-d',
    deviceName,
    '-h',
    context.relayAtsign,
    '-u',
    context.remoteUsername,
    '-i',
    context.identityFilePath,
    '--root-domain',
    context.rootDomain,
    '--ssh-client',
    'openssh',
    '-s',
    '-x',
  ];

  logFragment.start();
  final ProcessOutputCapture sshnpOutput = await startCommandWithCapture(
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

  final int exitCode = await sshnpOutput.exitCode;

  // Give the daemon a moment to flush its log
  await Future<void>.delayed(const Duration(seconds: 2));
  logFragment.stop();

  final String daemonStdout = logFragment.stdoutFile.existsSync()
      ? logFragment.stdoutFile.readAsStringSync()
      : '';
  final String daemonStderr = logFragment.stderrFile.existsSync()
      ? logFragment.stderrFile.readAsStringSync()
      : '';
  final String combinedDaemonLog = '$daemonStdout\n$daemonStderr';

  // 1. sshnp must have failed (daemon never responds to unauthorized requests)
  if (exitCode == 0) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode,
    );
    print(
      'FAIL: sshnp succeeded as unauthorized atSign $_unauthorizedAtsign '
      '— daemon should have rejected it',
    );
    printAllLogs(clientCapture: sshnpOutput, daemonLogFragment: logFragment);
    return result;
  }

  // 2. Daemon log must contain the rejection message naming the unauthorized
  //    atSign. Matching on the atSign as well as the message proves the daemon
  //    rejected *this* request, not some other test's, and proves sshnp got far
  //    enough to actually notify the daemon.
  final String expectedRejection =
      'Rejecting request from unauthorized atSign: $_unauthorizedAtsign';
  if (!combinedDaemonLog.toLowerCase().contains(
    expectedRejection.toLowerCase(),
  )) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: exitCode,
    );
    print('FAIL: daemon log does not contain "$expectedRejection"');
    printAllLogs(clientCapture: sshnpOutput, daemonLogFragment: logFragment);
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
