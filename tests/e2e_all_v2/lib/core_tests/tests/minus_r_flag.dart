import 'dart:io';

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
Future<List<CoreTestResult>> runMinusRFlagTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) async {
  final CoreTestLogger testLogger = CoreTestLogger(logsDirectory: context.logsDirectory, testName: testName);
  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations =
    _generateVersionCombinations(
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    );

  final List<CoreTestResult> testResults = [];
  for(final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion) in versionCombinations) {
    if(versionIsLessThan(daemonVersion, NoPortsVersion(language: Language.dart, version: 'v5.2.0'))) {
      continue;
    }
    if(versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.2.0'))) {
      continue;
    }
    final String extra = '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version})';
    final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere((cb) => cb.noPortsVersion == clientVersion);
    final String deviceName = '${getDeviceNameNoFlags(testRunId: context.testRunId, language: daemonVersion.language, version: daemonVersion.version)}_f';
    final String daemonInfo = '${daemonVersion.language.name}_${daemonVersion.version}';

    testResults.add(await _runTestWithDashDashHost(
      context: context,
      testLogger: testLogger,
      clientBinary: sshnpClientBinary,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      daemonInfo: daemonInfo,
      extra: extra,
    ));

    testResults.add(await _runTestWithInvalidHostValidR(
      context: context,
      testLogger: testLogger,
      clientBinary: sshnpClientBinary,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      daemonInfo: daemonInfo,
      extra: extra,
    ));

    testResults.add(await _runTestWithValidHostInvalidR(
      context: context,
      testLogger: testLogger,
      clientBinary: sshnpClientBinary,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      daemonInfo: daemonInfo,
      extra: extra,
    ));
  }
  return testResults;
}

List<String> _buildBaseSshnpArgs({
  required CoreTestsContext context,
  required ClientBinary clientBinary,
  required String deviceName,
}) {
  final List<String> args = [];
  if(versionIsAtLeast(clientBinary.noPortsVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
    args.add('-x');
    args.add('--no-ad');
    args.add('--no-et');
  }
  if(versionIsAtLeast(clientBinary.noPortsVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
    args.add('-k');
    args.add(context.apkamKeys[context.clientAtsign]!.path);
  }
  args.addAll([
    '-f', context.clientAtsign,
    '-t', context.daemonAtsign,
    '-i', context.identityFilePath,
    '-u', context.remoteUsername,
    '--root-domain', context.rootDomain,
    '-d', deviceName,
    '-s',
  ]);
  return args;
}

Future<CoreTestResult> _runTestWithDashDashHost({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required ClientBinary clientBinary,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required String deviceName,
  required String daemonInfo,
  required String extra,
}) async {
  final String clientVersionStr = clientVersion.version;
  final String daemonVersionStr = daemonVersion.version;

  final List<String> baseArgs = _buildBaseSshnpArgs(
    context: context,
    clientBinary: clientBinary,
    deviceName: deviceName,
  );
  final List<String> args = List.from(baseArgs)..addAll(['--host', context.relayAtsign]);

  printTestStart(testName: testName, extra: extra);

  final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
  final DaemonLogCapture daemonLogCapture = DaemonLogCapture(
    dockerInstance: daemonDockerInstance,
    stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
      language: daemonVersion.language,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataDashDashHost,
    ),
    stderrFragmentFile: testLogger.getDaemonStderrLogFile(
      language: daemonVersion.language,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataDashDashHost,
    ),
  );
  await daemonLogCapture.start();

  final ProcessResult processResult = await runCommand(
    clientBinary.file.path,
    args,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      language: clientVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataDashDashHost,
      daemonInfo: daemonInfo,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      language: clientVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataDashDashHost,
      daemonInfo: daemonInfo,
    ),
  );
  await daemonLogCapture.stop();

  final StringBuffer stdoutBuffer = StringBuffer();
  final StringBuffer stderrBuffer = StringBuffer();
  stdoutBuffer.writeln(processResult.stdout.toString());
  stderrBuffer.writeln(processResult.stderr.toString());

  if(processResult.exitCode != 0) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.failed,
      exitCode: processResult.exitCode,
    );
    printTestResult(testResult: result, extra: extra);
    printClientStderr(stderrBuffer.toString());
    printDaemonLogFragments(daemonLogCapture);
    return result;
  } else {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.passed,
      exitCode: processResult.exitCode,
      stdout: stdoutBuffer,
      stderr: stderrBuffer,
    );
    printTestResult(testResult: result, extra: extra);
    if(context.alwaysOutputLogs) {
      final File clientStdoutFile = testLogger.getClientStdoutLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataDashDashHost,
        daemonInfo: daemonInfo,
      );
      final File clientStderrFile = testLogger.getClientStderrLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataDashDashHost,
        daemonInfo: daemonInfo,
      );
      printAllLogsFromFiles(
        clientStdoutFile: clientStdoutFile,
        clientStderrFile: clientStderrFile,
        daemonLogCapture: daemonLogCapture,
      );
    }
    return result;
  }
}

Future<CoreTestResult> _runTestWithInvalidHostValidR({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required ClientBinary clientBinary,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required String deviceName,
  required String daemonInfo,
  required String extra,
}) async {
  final String clientVersionStr = clientVersion.version;
  final String daemonVersionStr = daemonVersion.version;

  final List<String> baseArgs = _buildBaseSshnpArgs(
    context: context,
    clientBinary: clientBinary,
    deviceName: deviceName,
  );
  final List<String> args = List.from(baseArgs)..addAll(['-h', '@do_not_activate', '-r', context.relayAtsign]);

  printTestStart(testName: testName, extra: extra);

  final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
  final DaemonLogCapture daemonLogCapture = DaemonLogCapture(
    dockerInstance: daemonDockerInstance,
    stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
      language: daemonVersion.language,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataInvalidHostValidR,
    ),
    stderrFragmentFile: testLogger.getDaemonStderrLogFile(
      language: daemonVersion.language,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataInvalidHostValidR,
    ),
  );
  await daemonLogCapture.start();

  final ProcessResult processResult = await runCommand(
    clientBinary.file.path,
    args,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      language: clientVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataInvalidHostValidR,
      daemonInfo: daemonInfo,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      language: clientVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataInvalidHostValidR,
      daemonInfo: daemonInfo,
    ),
  );
  await daemonLogCapture.stop();

  final StringBuffer stdoutBuffer = StringBuffer();
  final StringBuffer stderrBuffer = StringBuffer();
  stdoutBuffer.writeln(processResult.stdout.toString());
  stderrBuffer.writeln(processResult.stderr.toString());

  if(processResult.exitCode != 0) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.failed,
      exitCode: processResult.exitCode,
    );
    printTestResult(testResult: result, extra: extra);
    printClientStderr(stderrBuffer.toString());
    printDaemonLogFragments(daemonLogCapture);
    return result;
  } else {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.passed,
      exitCode: processResult.exitCode,
      stdout: stdoutBuffer,
      stderr: stderrBuffer,
    );
    printTestResult(testResult: result, extra: extra);
    if(context.alwaysOutputLogs) {
      final File clientStdoutFile = testLogger.getClientStdoutLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataInvalidHostValidR,
        daemonInfo: daemonInfo,
      );
      final File clientStderrFile = testLogger.getClientStderrLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataInvalidHostValidR,
        daemonInfo: daemonInfo,
      );
      printAllLogsFromFiles(
        clientStdoutFile: clientStdoutFile,
        clientStderrFile: clientStderrFile,
        daemonLogCapture: daemonLogCapture,
      );
    }
    return result;
  }
}

Future<CoreTestResult> _runTestWithValidHostInvalidR({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required ClientBinary clientBinary,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required String deviceName,
  required String daemonInfo,
  required String extra,
}) async {
  final String clientVersionStr = clientVersion.version;
  final String daemonVersionStr = daemonVersion.version;

  final List<String> baseArgs = _buildBaseSshnpArgs(
    context: context,
    clientBinary: clientBinary,
    deviceName: deviceName,
  );
  final List<String> args = List.from(baseArgs)..addAll(['-h', context.relayAtsign, '-r', '@do_not_activate']);

  printTestStart(testName: testName, extra: extra);

  final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
  final DaemonLogCapture daemonLogCapture = DaemonLogCapture(
    dockerInstance: daemonDockerInstance,
    stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
      language: daemonVersion.language,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataValidHostInvalidR,
    ),
    stderrFragmentFile: testLogger.getDaemonStderrLogFile(
      language: daemonVersion.language,
      version: daemonVersionStr,
      deviceName: deviceName,
      testMetadata: _metadataValidHostInvalidR,
    ),
  );
  await daemonLogCapture.start();

  final ProcessResult processResult = await runCommand(
    clientBinary.file.path,
    args,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      language: clientVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataValidHostInvalidR,
      daemonInfo: daemonInfo,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      language: clientVersion.language,
      version: clientVersionStr,
      testMetadata: _metadataValidHostInvalidR,
      daemonInfo: daemonInfo,
    ),
  );
  await daemonLogCapture.stop();

  final StringBuffer stdoutBuffer = StringBuffer();
  final StringBuffer stderrBuffer = StringBuffer();
  stdoutBuffer.writeln(processResult.stdout.toString());
  stderrBuffer.writeln(processResult.stderr.toString());

  if(processResult.exitCode == 0) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.failed,
      exitCode: processResult.exitCode,
      stdout: stdoutBuffer,
      stderr: stderrBuffer,
    );
    printTestResult(testResult: result, extra: extra);
    printClientStdout(stdoutBuffer.toString());
    printClientStderr(stderrBuffer.toString());
    printDaemonLogFragments(daemonLogCapture);
    return result;
  } else {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersionStr,
      daemonVersion: daemonVersionStr,
      status: TestStatus.passed,
      exitCode: processResult.exitCode,
    );
    printTestResult(testResult: result, extra: extra);
    if(context.alwaysOutputLogs) {
      final File clientStdoutFile = testLogger.getClientStdoutLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataValidHostInvalidR,
        daemonInfo: daemonInfo,
      );
      final File clientStderrFile = testLogger.getClientStderrLogFile(
        language: clientVersion.language,
        version: clientVersionStr,
        testMetadata: _metadataValidHostInvalidR,
        daemonInfo: daemonInfo,
      );
      printAllLogsFromFiles(
        clientStdoutFile: clientStdoutFile,
        clientStderrFile: clientStderrFile,
        daemonLogCapture: daemonLogCapture,
      );
    }
    return result;
  }
}


// we only want to check:
//   a. non-current client with current daemon
//   b. current cleint with non-current daemon
List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> combinations = [];
  for(final clientVersion in clientVersions) {
    for(final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      // skip if both client and daemon are not current
      if(!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      if(daemonVersion.language == Language.c) {
        // C daemon doesn't need to test a client side only feature
        continue;
      }
      if(clientVersion.language == Language.dart && versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.2.0'))) {
        // -r was added in v5.2.0
        continue; 
      }
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
