import 'dart:async';
import 'dart:io';

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
import 'package:e2e_all_v2/test_result.dart';

const String testName = 'v4_dart_inline';
const String _metadata = 'v4DartInline';

List<Future<CoreTestResult> Function()> getV4DartInLineFactories({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final List<Future<CoreTestResult> Function()> testFactories = [];
  final CoreTestLogger testLogger = CoreTestLogger(
    logsDirectory: context.logsDirectory,
    testName: testName,
  );

  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations =
      _generateVersionCombinations(
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
      );

  for (final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion)
      in versionCombinations) {
    testFactories.add(
      () => _runV4DartInlineTest(
        context: context,
        testLogger: testLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
      ),
    );
  }

  return testFactories;
}

Future<CoreTestResult> _runV4DartInlineTest({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) async {
  final String extra = generateExtraString(
    clientVersion,
    daemonVersion,
    useShortLanguageName: true,
  );
  printTestStart(testName: testName, extra: extra);
  final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere(
    (cb) =>
        cb.binaryType == ClientBinaryType.sshnp &&
        cb.noPortsVersion == clientVersion,
  );
  final String deviceName =
      '${getDeviceNameNoFlags(testRunId: context.testRunId, noPortsVersion: daemonVersion)}_f';

  final List<String> sshnpArgs = _buildSshnpArgs(
    context: context,
    clientVersion: clientVersion,
    deviceName: deviceName,
  );
  final DockerInstance dockerInstance = context.dockerInstances
      .firstWhere((di) => di.$1 == deviceName)
      .$2;
  final LogFragment logFragment1 = await dockerInstance.createLogFragment(
    stdoutFile: testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadata,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadata,
    ),
  );
  final File clientStdoutLogFile = testLogger.getClientStdoutLogFile(
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    testMetadata: _metadata,
  );
  final File clientStderrLogFile = testLogger.getClientStderrLogFile(
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    testMetadata: _metadata,
  );

  logFragment1.start();
  late final ProcessResult expectResult;
  try {
    expectResult = await _runSshnpExpect(
      sshnpExecutablePath: sshnpClientBinary.file.path,
      sshnpArgs: sshnpArgs,
      remoteUsername: context.remoteUsername,
    );
  } finally {
    logFragment1.stop();
  }

  final StringBuffer clientStdoutBuffer = StringBuffer(expectResult.stdout);
  final StringBuffer clientStderrBuffer = StringBuffer(expectResult.stderr);
  final StringBuffer daemonStdoutBuffer = StringBuffer(
    logFragment1.stdoutFile.existsSync()
        ? logFragment1.stdoutFile.readAsStringSync()
        : '',
  );
  final StringBuffer daemonStderrBuffer = StringBuffer(
    logFragment1.stderrFile.existsSync()
        ? logFragment1.stderrFile.readAsStringSync()
        : '',
  );

  await clientStdoutLogFile.writeAsString(clientStdoutBuffer.toString());
  await clientStderrLogFile.writeAsString(clientStderrBuffer.toString());
  final int exitCode = expectResult.exitCode;
  final bool expectSucceeded =
      exitCode == 0 &&
      clientStdoutBuffer.toString().contains(_lastLoginObservedMarker) &&
      clientStdoutBuffer.toString().contains(_remoteCommandObservedMarker) &&
      clientStderrBuffer.toString().trim().isEmpty;

  final CoreTestResult result = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: expectSucceeded ? TestStatus.passed : TestStatus.failed,
    exitCode: exitCode,
  );
  printTestResult(testResult: result, extra: extra);

  if (!expectSucceeded) {
    printAllLogsFromStringBuffers(
      clientStdoutBuffer: clientStdoutBuffer,
      clientStderrBuffer: clientStderrBuffer,
      daemonStdoutBuffer: daemonStdoutBuffer,
      daemonStderrBuffer: daemonStderrBuffer,
    );
  }

  return result;
}

const String _lastLoginObservedMarker = 'EXPECT: observed Last login prompt';
const String _remoteCommandObservedMarker =
    'EXPECT: observed remote SCOOBY DOO marker';

Future<ProcessResult> _runSshnpExpect({
  required String sshnpExecutablePath,
  required List<String> sshnpArgs,
  required String remoteUsername,
}) {
  final String sshnpCommand = [
    sshnpExecutablePath,
    ...sshnpArgs,
  ].map(_tclListElement).join(' ');

  return Process.run(
    'expect',
    ['-c', _sshnpExpectScript],
    environment: {
      'SSHNP_COMMAND': sshnpCommand,
      'SSHNP_TIMEOUT': '60',
      'REMOTE_USERNAME': remoteUsername,
      'LAST_LOGIN_OBSERVED_MARKER': _lastLoginObservedMarker,
      'REMOTE_COMMAND_OBSERVED_MARKER': _remoteCommandObservedMarker,
    },
  );
}

const String _sshnpExpectScript = r'''
proc timed_out { } { send_user "\nTimeout!\n" ; exit 1 }
set timeout $env(SSHNP_TIMEOUT)
expect_before timeout timed_out

eval spawn $env(SSHNP_COMMAND)

expect {
    eof             { exit 1 }
    "Last login:"  { puts "$env(LAST_LOGIN_OBSERVED_MARKER)" }
}

send "echo \$(date) \$(whoami) \$(hostname) SCOOBY DOO\n"
set expected "${env(REMOTE_USERNAME)}.*SCOOBY DOO"
expect {
    eof             { exit 1 }
    -re $expected   { puts "$env(REMOTE_COMMAND_OBSERVED_MARKER)" }
}

exit 0
''';

String _tclListElement(String value) {
  if (value.isEmpty) {
    return '{}';
  }
  return '{${value.replaceAll(r'\', r'\\').replaceAll('{', r'\{').replaceAll('}', r'\}')}}';
}

List<String> _buildSshnpArgs({
  required CoreTestsContext context,
  required NoPortsVersion clientVersion,
  required String deviceName,
}) {
  final List<String> args = [
    '-f',
    context.clientAtsign,
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
    'dart',
    '-s',
  ];

  if (versionIsAtLeast(
    clientVersion,
    NoPortsVersion(language: Language.dart, version: 'v5.0.0'),
  )) {
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

List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> combinations = [];
  for (final clientVersion in clientVersions) {
    for (final daemonVersion in daemonVersions) {
      // only test against current
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      if (!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      // do not test against C daemon
      if (daemonVersion.language == Language.c) {
        continue;
      }
      // ensure client version is >= v5.1.0 to support client features
      if (versionIsLessThan(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.1.0'),
      )) {
        continue;
      }
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
