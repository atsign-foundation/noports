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

const String _metadataNoFlags = 'noFlags';
const String _metadataWithFlags = 'withFlags';
const String _metadataSshTest = 'sshTest';
const String testName = '001_minus_s_flag';

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
Future<List<CoreTestResult>> run001MinusSFlagTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> daemonVersions,
}) async {
  final List<CoreTestResult> testResults = [];
  final CoreTestLogger testLogger = CoreTestLogger(logsDirectory: context.logsDirectory, testName: testName);

  final ClientBinary currentSshnpClientBinary = context.clientBinaries.firstWhere((cb) =>
    cb.binaryType == ClientBinaryType.sshnp &&
    cb.noPortsVersion.version == 'current');
  final String clientVersionStr = currentSshnpClientBinary.noPortsVersion.version;

  for(final NoPortsVersion daemonVersion in daemonVersions) {
    final Language daemonLanguage = daemonVersion.language;
    final String daemonVersionStr = daemonVersion.version;
    final String extra = '(client: ${currentSshnpClientBinary.noPortsVersion.language.name[0]}:${clientVersionStr}, daemon: ${daemonLanguage.name[0]}:$daemonVersionStr)';
    final String daemonInfo = '${daemonLanguage.name}_${daemonVersionStr}';

    final String deviceNameNoFlags = getDeviceNameNoFlags(
      testRunId: context.testRunId,
      language: daemonLanguage,
      version: daemonVersionStr);

    testResults.add(await _runTestWithoutFlags(
      context: context,
      testLogger: testLogger,
      clientBinary: currentSshnpClientBinary,
      daemonVersion: daemonVersion,
      deviceName: deviceNameNoFlags,
      daemonInfo: daemonInfo,
      extra: extra,
    ));

    final String deviceNameWithFlags = '${deviceNameNoFlags}_f';
    testResults.addAll(await _runTestWithFlags(
      context: context,
      testLogger: testLogger,
      clientBinary: currentSshnpClientBinary,
      daemonVersion: daemonVersion,
      deviceName: deviceNameWithFlags,
      daemonInfo: daemonInfo,
      identityFilePath: context.identityFilePath,
      extra: extra,
    ));
  }

  return testResults;
}

List<String> _buildSshnpArgs({
  required CoreTestsContext context,
  required ClientBinary clientBinary,
  required String deviceName,
  required Language daemonLanguage,
}) {
  final List<String> args = [
    '-f', context.clientAtsign,
    '-t', context.daemonAtsign,
    '-i', context.identityFilePath,
    '-d', deviceName,
    '-h', context.relayAtsign,
    '-u', context.remoteUsername,
    '--root-domain', context.rootDomain,
    '-s',
  ];

  if(daemonLanguage == Language.c) {
    args.add('-x');
  } else if(versionIsAtLeast(clientBinary.noPortsVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
    args.add('-x');
    args.add('--no-ad');
    args.add('--no-et');
  }

  if(versionIsAtLeast(clientBinary.noPortsVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
    args.add('-k');
    args.add(context.apkamKeys[context.clientAtsign]!.path);
  }

  return args;
}

Future<CoreTestResult> _runTestWithoutFlags({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required ClientBinary clientBinary,
  required NoPortsVersion daemonVersion,
  required String deviceName,
  required String daemonInfo,
  required String extra,
}) async {
  final Language daemonLanguage = daemonVersion.language;
  final String daemonVersionStr = daemonVersion.version;
  final String clientVersionStr = clientBinary.noPortsVersion.version;

  final List<String> args = _buildSshnpArgs(
    context: context,
    clientBinary: clientBinary,
    deviceName: deviceName,
    daemonLanguage: daemonLanguage,
  );

  printTestStart(testName: testName, extra: extra);
  final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
  final DaemonLogCapture daemonLogCapture = DaemonLogCapture(
    dockerInstance: daemonDockerInstance,
    stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
      language: daemonLanguage,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataNoFlags,
    ),
    stderrFragmentFile: testLogger.getDaemonStderrLogFile(
      language: daemonLanguage,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataNoFlags,
    ),
  );
  await daemonLogCapture.start();

  final ProcessOutputCapture capture = await startCommandWithCapture(
    clientBinary.file.path,
    args,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      language: clientBinary.noPortsVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataNoFlags,
      daemonInfo: daemonInfo,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      language: clientBinary.noPortsVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataNoFlags,
      daemonInfo: daemonInfo,
    ),
  );

  final int exitCode = await capture.exitCode;
  await daemonLogCapture.stop();

  if(exitCode == 0) {
    print('Daemon version: $daemonVersionStr | Client version: $clientVersionStr | Device Name: $deviceName Test Failed | exitCode=$exitCode');
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.failed,
      exitCode: exitCode,
      stdout: StringBuffer(capture.stdout),
      stderr: StringBuffer(capture.stderr),
    );
    printTestResult(testResult: result, extra: extra);
    printAllLogs(clientCapture: capture, daemonLogCapture: daemonLogCapture);
    return result;
  } else {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.passed,
      exitCode: exitCode,
    );
    printTestResult(testResult: result, extra: extra);
    if(context.alwaysOutputLogs) {
      printAllLogs(clientCapture: capture, daemonLogCapture: daemonLogCapture);
    }
    return result;
  }
}

Future<List<CoreTestResult>> _runTestWithFlags({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required ClientBinary clientBinary,
  required NoPortsVersion daemonVersion,
  required String deviceName,
  required String daemonInfo,
  required String identityFilePath,
  required String extra,
}) async {
  final Language daemonLanguage = daemonVersion.language;
  final String daemonVersionStr = daemonVersion.version;
  final String clientVersionStr = clientBinary.noPortsVersion.version;
  final List<CoreTestResult> results = [];

  final List<String> args = _buildSshnpArgs(
    context: context,
    clientBinary: clientBinary,
    deviceName: deviceName,
    daemonLanguage: daemonLanguage,
  );

  printTestStart(testName: testName, extra: extra);

  final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
  final DaemonLogCapture daemonLogCapture = DaemonLogCapture(
    dockerInstance: daemonDockerInstance,
    stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
      language: daemonLanguage,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataWithFlags,
    ),
    stderrFragmentFile: testLogger.getDaemonStderrLogFile(
      language: daemonLanguage,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataWithFlags,
    ),
  );
  await daemonLogCapture.start();

  final ProcessOutputCapture capture = await startCommandWithCapture(
    clientBinary.file.path,
    args,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      language: clientBinary.noPortsVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataWithFlags,
      daemonInfo: daemonInfo,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      language: clientBinary.noPortsVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataWithFlags,
      daemonInfo: daemonInfo,
    ),
  );

  final int exitCode = await capture.exitCode;
  await daemonLogCapture.stop();

  if(exitCode != 0) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.failed,
      exitCode: exitCode,
      stdout: StringBuffer(capture.stdout),
    );
    printTestResult(testResult: result, extra: extra);
    printAllLogs(clientCapture: capture, daemonLogCapture: daemonLogCapture);
    results.add(result);
    return results;
  }

  String sshCommand = capture.stdout.trim();
  if(sshCommand.startsWith('ssh ')) {
    sshCommand = sshCommand.substring(4);
  } else {
    throw Exception('Expected stdout from sshnp to start with "ssh ". Actual output: "$sshCommand"');
  }

  List<String> sshCommandArgs = sshCommand.split(' ');
  sshCommandArgs.add('echo');
  sshCommandArgs.add('`date`');
  sshCommandArgs.add('`whoami`');
  sshCommandArgs.add('`hostname`');
  sshCommandArgs.add('TEST PASSED');

  final DaemonLogCapture daemonLogCapture2 = DaemonLogCapture(
    dockerInstance: daemonDockerInstance,
    stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
      language: daemonLanguage,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataSshTest,
    ),
    stderrFragmentFile: testLogger.getDaemonStderrLogFile(
      language: daemonLanguage,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataSshTest,
    ),
  );
  await daemonLogCapture2.start();

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
        clientCapture: capture,
        daemonLogCapture: daemonLogCapture,
        clientLabel: 'Client (sshnp with flags)',
        daemonLabel: 'Daemon (withFlags)',
      );
      printDaemonLogFragments(daemonLogCapture2, label: 'Daemon (sshTest)');
    }
    results.add(result);
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
      clientCapture: sshCapture,
      daemonLogCapture: daemonLogCapture2,
      clientLabel: 'SSH command',
    );
    results.add(result);
  }

  return results;
}
