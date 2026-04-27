import 'dart:convert';
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
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/test_result.dart';

enum SshnpProtocol { v4, v5 }

enum SshnpClient { dart, openssh }

const String remoteCommandObservedMarker =
    'EXPECT: observed remote SCOOBY DOO marker';
const String remotePrintCommandMarker = 'TEST PASSED';

List<(NoPortsVersion, NoPortsVersion)> generateV4VersionCombinations({
  required List<NoPortsVersion> clientVersions,
  required List<NoPortsVersion> daemonVersions,
}) {
  return _generateVersionCombinations(
    clientVersions: clientVersions,
    daemonVersions: daemonVersions,
    allowCDaemon: false,
    minimumClientVersion: 'v5.1.0',
    minimumDaemonVersion: null,
  );
}

List<(NoPortsVersion, NoPortsVersion)> generateV5VersionCombinations({
  required List<NoPortsVersion> clientVersions,
  required List<NoPortsVersion> daemonVersions,
}) {
  return _generateVersionCombinations(
    clientVersions: clientVersions,
    daemonVersions: daemonVersions,
    allowCDaemon: true,
    minimumClientVersion: 'v5.0.0',
    minimumDaemonVersion: 'v5.0.0',
  );
}

bool isUnsupportedPrintClient(NoPortsVersion clientVersion) {
  return versionIsAtLeast(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.0.0'),
      ) &&
      versionIsLessThan(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.1.0'),
      );
}

Future<CoreTestResult> runInlineSshnpTest({
  required String testName,
  required String metadata,
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required SshnpProtocol protocol,
  required SshnpClient sshClient,
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
  final String deviceName = _deviceName(
    context: context,
    daemonVersion: daemonVersion,
  );
  final DockerInstance daemonDockerInstance = _getDockerInstance(
    context: context,
    deviceName: deviceName,
  );
  final List<String> sshnpArgs = buildSshnpArgs(
    context: context,
    clientVersion: clientVersion,
    deviceName: deviceName,
    protocol: protocol,
    sshClient: sshClient,
    printSshCommand: false,
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
      clientStdoutBuffer.toString().contains(remoteCommandObservedMarker) &&
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

Future<CoreTestResult> runPrintSshnpTest({
  required String testName,
  required String sshnpMetadata,
  required String sshMetadata,
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required SshnpProtocol protocol,
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
  final String deviceName = _deviceName(
    context: context,
    daemonVersion: daemonVersion,
  );
  final DockerInstance daemonDockerInstance = _getDockerInstance(
    context: context,
    deviceName: deviceName,
  );
  final List<String> sshnpArgs = buildSshnpArgs(
    context: context,
    clientVersion: clientVersion,
    deviceName: deviceName,
    protocol: protocol,
    sshClient: SshnpClient.openssh,
    printSshCommand: true,
  );

  final LogFragment sshnpDaemonLogCapture = await daemonDockerInstance
      .createLogFragment(
        stdoutFile: testLogger.getDaemonStdoutLogFile(
          daemonVersion: daemonVersion,
          deviceName: deviceName,
          testMetadata: sshnpMetadata,
        ),
        stderrFile: testLogger.getDaemonStderrLogFile(
          daemonVersion: daemonVersion,
          deviceName: deviceName,
          testMetadata: sshnpMetadata,
        ),
      );
  sshnpDaemonLogCapture.start();
  final ProcessOutputCapture sshnpCapture = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    sshnpArgs,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: sshnpMetadata,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: sshnpMetadata,
    ),
  );
  final int sshnpExitCode = await sshnpCapture.exitCode;
  sshnpDaemonLogCapture.stop();

  final String printedSshCommand = sshnpCapture.stdout.trim();
  if (sshnpExitCode != 0 || !printedSshCommand.startsWith('ssh ')) {
    final CoreTestResult result = _result(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      exitCode: sshnpExitCode == 0 ? 1 : sshnpExitCode,
      passed: false,
    );
    printTestResult(testResult: result, extra: extra);
    printAllLogs(
      clientCapture: sshnpCapture,
      daemonLogFragment: sshnpDaemonLogCapture,
      clientLabel: 'sshnp client',
      daemonLabel: 'sshnp daemon',
    );
    return result;
  }

  final List<String> sshCommandArgs = splitShellWords(
    printedSshCommand.substring(4),
  );
  sshCommandArgs.addAll([
    'echo',
    r'$(date)',
    r'$(whoami)',
    r'$(hostname)',
    'TEST',
    'PASSED',
  ]);

  final LogFragment sshDaemonLogCapture = await daemonDockerInstance
      .createLogFragment(
        stdoutFile: testLogger.getDaemonStdoutLogFile(
          daemonVersion: daemonVersion,
          deviceName: deviceName,
          testMetadata: sshMetadata,
        ),
        stderrFile: testLogger.getDaemonStderrLogFile(
          daemonVersion: daemonVersion,
          deviceName: deviceName,
          testMetadata: sshMetadata,
        ),
      );
  sshDaemonLogCapture.start();
  final ProcessOutputCapture sshCapture = await startCommandWithCapture(
    'ssh',
    sshCommandArgs,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: sshMetadata,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: sshMetadata,
    ),
  );
  final int sshExitCode = await sshCapture.exitCode;
  sshDaemonLogCapture.stop();

  final bool sshSucceeded =
      sshExitCode == 0 && sshCapture.stdout.contains(remotePrintCommandMarker);
  final CoreTestResult result = _result(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    exitCode: sshExitCode,
    passed: sshSucceeded,
  );
  printTestResult(testResult: result, extra: extra);

  if (!sshSucceeded) {
    printAllLogs(
      clientCapture: sshnpCapture,
      daemonLogFragment: sshnpDaemonLogCapture,
      clientLabel: 'sshnp client',
      daemonLabel: 'sshnp daemon',
    );
    printAllLogs(
      clientCapture: sshCapture,
      daemonLogFragment: sshDaemonLogCapture,
      clientLabel: 'ssh client',
      daemonLabel: 'ssh daemon',
    );
  }

  return result;
}

List<String> buildSshnpArgs({
  required CoreTestsContext context,
  required NoPortsVersion clientVersion,
  required String deviceName,
  required SshnpProtocol protocol,
  required SshnpClient sshClient,
  required bool printSshCommand,
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
    sshClient.name,
    '-s',
  ];

  if (protocol == SshnpProtocol.v4 &&
      versionIsAtLeast(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.0.0'),
      )) {
    args.add('--no-ad');
    args.add('--no-et');
  }

  if (printSshCommand) {
    args.add('-x');
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

List<String> splitShellWords(String command) {
  final List<String> words = [];
  final StringBuffer current = StringBuffer();
  var quote = '';
  var escaping = false;

  for (final int rune in command.runes) {
    final String char = String.fromCharCode(rune);
    if (escaping) {
      current.write(char);
      escaping = false;
      continue;
    }
    if (char == r'\') {
      escaping = true;
      continue;
    }
    if (quote.isNotEmpty) {
      if (char == quote) {
        quote = '';
      } else {
        current.write(char);
      }
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char.trim().isEmpty) {
      if (current.isNotEmpty) {
        words.add(current.toString());
        current.clear();
      }
      continue;
    }
    current.write(char);
  }

  if (escaping) {
    current.write(r'\');
  }
  if (quote.isNotEmpty) {
    throw FormatException('Unterminated quote in ssh command: $command');
  }
  if (current.isNotEmpty) {
    words.add(current.toString());
  }
  return words;
}

List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required List<NoPortsVersion> clientVersions,
  required List<NoPortsVersion> daemonVersions,
  required bool allowCDaemon,
  required String? minimumClientVersion,
  required String? minimumDaemonVersion,
}) {
  final List<(NoPortsVersion, NoPortsVersion)> combinations = [];
  for (final clientVersion in clientVersions) {
    for (final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      if (!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      if (!allowCDaemon && daemonVersion.language == Language.c) {
        continue;
      }
      if (minimumClientVersion != null &&
          versionIsLessThan(
            clientVersion,
            NoPortsVersion(
              language: Language.dart,
              version: minimumClientVersion,
            ),
          )) {
        continue;
      }
      if (minimumDaemonVersion != null &&
          versionIsLessThan(
            daemonVersion,
            NoPortsVersion(
              language: daemonVersion.language,
              version: minimumDaemonVersion,
            ),
          )) {
        continue;
      }
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
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

String _deviceName({
  required CoreTestsContext context,
  required NoPortsVersion daemonVersion,
}) {
  return '${getDeviceNameNoFlags(testRunId: context.testRunId, noPortsVersion: daemonVersion)}_f';
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

CoreTestResult _result({
  required String testName,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
  required int exitCode,
  required bool passed,
}) {
  return CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: passed ? TestStatus.passed : TestStatus.failed,
    exitCode: exitCode,
  );
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
      'REMOTE_COMMAND_OBSERVED_MARKER': remoteCommandObservedMarker,
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
