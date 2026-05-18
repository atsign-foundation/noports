import 'dart:convert';
import 'dart:io';

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

const String _remoteCommandObservedMarker =
    'EXPECT: observed remote SCOOBY DOO marker';

const String testName = 'v5_openssh_inline';
const String _metadata = 'v5OpensshInline';

List<Future<CoreTestResult> Function()> runV5OpensshInlineTests({
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
      _generateVersionPermutations(
        clientVersions: clientVersions,
        daemonVersions: daemonVersions,
      );

  for (final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion)
      in versionCombinations) {
    testFactories.add(
      () => _runInlineSshnpTest(
        testName: testName,
        metadata: _metadata,
        context: context,
        testLogger: testLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
      ),
    );
  }

  return testFactories;
}

Future<CoreTestResult> _runInlineSshnpTest({
  required String testName,
  required String metadata,
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

  final ClientBinary sshnpClientBinary = _getSshnpClientBinary(
    context: context,
    clientVersion: clientVersion,
  );
  final String deviceName =
      '${getDeviceNameNoFlags(testRunId: context.testRunId, noPortsVersion: daemonVersion)}_f';
  final DockerInstance daemonDockerInstance = _getDockerInstance(
    context: context,
    deviceName: deviceName,
  );
  final List<String> sshnpArgs = _buildSshnpArgs(
    context: context,
    clientVersion: clientVersion,
    deviceName: deviceName,
  );

  final LogFragment daemonLogCapture = await daemonDockerInstance
      .createLogFragment(
        stdoutFile: testLogger.getDaemonStdoutLogFile(
          daemonVersion: daemonVersion,
          deviceName: deviceName,
          testMetadata: metadata,
        ),
        stderrFile: testLogger.getDaemonStderrLogFile(
          daemonVersion: daemonVersion,
          deviceName: deviceName,
          testMetadata: metadata,
        ),
      );
  final File clientStdoutLogFile = testLogger.getClientStdoutLogFile(
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    testMetadata: metadata,
  );
  final File clientStderrLogFile = testLogger.getClientStderrLogFile(
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    testMetadata: metadata,
  );
  final File expectTranscriptLogFile = File(
    '${clientStdoutLogFile.path}.expect_transcript',
  );
  if (expectTranscriptLogFile.existsSync()) {
    expectTranscriptLogFile.deleteSync();
  }

  daemonLogCapture.start();
  late final ProcessResult expectResult;
  try {
    expectResult = await _runSshnpExpect(
      sshnpExecutablePath: sshnpClientBinary.file.path,
      sshnpArgs: sshnpArgs,
      remoteUsername: context.remoteUsername,
      transcriptLogPath: expectTranscriptLogFile.path,
    );
  } finally {
    daemonLogCapture.stop();
  }

  final StringBuffer clientStdoutBuffer = StringBuffer(expectResult.stdout);
  if (expectTranscriptLogFile.existsSync()) {
    clientStdoutBuffer.write(expectTranscriptLogFile.readAsStringSync());
    expectTranscriptLogFile.deleteSync();
  }
  final StringBuffer clientStderrBuffer = StringBuffer(expectResult.stderr);
  final StringBuffer daemonStdoutBuffer = _readBuffer(
    daemonLogCapture.stdoutFile,
  );
  final StringBuffer daemonStderrBuffer = _readBuffer(
    daemonLogCapture.stderrFile,
  );

  await clientStdoutLogFile.writeAsString(clientStdoutBuffer.toString());
  await clientStderrLogFile.writeAsString(clientStderrBuffer.toString());

  final int exitCode = expectResult.exitCode;
  final bool expectSucceeded =
      exitCode == 0 &&
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

List<(NoPortsVersion, NoPortsVersion)> _generateVersionPermutations({
  required List<NoPortsVersion> clientVersions,
  required List<NoPortsVersion> daemonVersions,
}) {
  final List<(NoPortsVersion, NoPortsVersion)> permutations = [];
  for (final clientVersion in clientVersions) {
    for (final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      if (!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      if (versionIsLessThan(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.0.0'),
      )) {
        continue;
      }
      if (versionIsLessThan(
        daemonVersion,
        NoPortsVersion(language: daemonVersion.language, version: 'v5.0.0'),
      )) {
        continue;
      }
      permutations.add((clientVersion, daemonVersion));
    }
  }
  return permutations;
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
    'openssh',
    '-s',
  ];

  if (versionIsAtLeast(
    clientVersion,
    NoPortsVersion(language: Language.dart, version: 'v5.3.0'),
  )) {
    args.add('-k');
    args.add(context.apkamKeys[context.clientAtsign]!.path);
  }

  return args;
}

ClientBinary _getSshnpClientBinary({
  required CoreTestsContext context,
  required NoPortsVersion clientVersion,
}) {
  return context.clientBinaries.firstWhere(
    (cb) =>
        cb.binaryType == ClientBinaryType.sshnp &&
        cb.noPortsVersion == clientVersion,
  );
}

DockerInstance _getDockerInstance({
  required CoreTestsContext context,
  required String deviceName,
}) {
  return context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
}

StringBuffer _readBuffer(File file) {
  return StringBuffer(file.existsSync() ? file.readAsStringSync() : '');
}

Future<ProcessResult> _runSshnpExpect({
  required String sshnpExecutablePath,
  required List<String> sshnpArgs,
  required String remoteUsername,
  required String transcriptLogPath,
}) async {
  final String sshnpCommand = [
    sshnpExecutablePath,
    ...sshnpArgs,
  ].map(_tclListElement).join(' ');

  final Process process = await startCommand(
    'expect',
    ['-c', _sshnpExpectScript],
    environment: {
      'SSHNP_COMMAND': sshnpCommand,
      'SSHNP_TIMEOUT': '60',
      'REMOTE_USERNAME': remoteUsername,
      'EXPECT_TRANSCRIPT_LOG': transcriptLogPath,
      'REMOTE_COMMAND_OBSERVED_MARKER': _remoteCommandObservedMarker,
    },
  );
  final Future<String> stdoutFuture = process.stdout
      .transform(utf8.decoder)
      .join();
  final Future<String> stderrFuture = process.stderr
      .transform(utf8.decoder)
      .join();
  final int exitCode = await process.exitCode;

  return ProcessResult(
    process.pid,
    exitCode,
    await stdoutFuture,
    await stderrFuture,
  );
}

const String _sshnpExpectScript = r'''
proc timed_out { } { send_user "\nTimeout!\n" ; exit 1 }
set timeout $env(SSHNP_TIMEOUT)
expect_before timeout timed_out
log_file -a $env(EXPECT_TRANSCRIPT_LOG)

eval spawn $env(SSHNP_COMMAND)

expect {
    eof             { exit 1 }
    "Last login:"   { }
    -re {[^ \r\n]*@[^:\r\n]+:[^\r\n]*[$#] $} { }
}

send "echo \$(date) \$(whoami) \$(hostname) SCOOBY DOO\n"
set expected "${env(REMOTE_USERNAME)}.*SCOOBY DOO"
expect {
    eof             { exit 1 }
    -re $expected   { send_log "\n$env(REMOTE_COMMAND_OBSERVED_MARKER)\n" }
}

exit 0
''';

String _tclListElement(String value) {
  if (value.isEmpty) {
    return '{}';
  }
  return '{${value.replaceAll(r'\', r'\\').replaceAll('{', r'\{').replaceAll('}', r'\}')}}';
}
