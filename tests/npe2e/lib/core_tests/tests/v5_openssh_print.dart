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

const String _remotePrintCommandMarker = 'TEST PASSED';

const String testName = 'v5_openssh_print';
const String _metadataSshnpExecution = 'sshnpExecution';
const String _metadataSshExecution = 'sshExecution';

List<Future<CoreTestResult> Function()> runV5OpensshPrintTests({
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
    if (_isUnsupportedPrintClient(clientVersion)) {
      continue;
    }
    testFactories.add(
      () => _runPrintSshnpTest(
        testName: testName,
        sshnpMetadata: _metadataSshnpExecution,
        sshMetadata: _metadataSshExecution,
        context: context,
        testLogger: testLogger,
        clientVersion: clientVersion,
        daemonVersion: daemonVersion,
      ),
    );
  }

  return testFactories;
}

Future<CoreTestResult> _runPrintSshnpTest({
  required String testName,
  required String sshnpMetadata,
  required String sshMetadata,
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

  final List<String> sshCommandArgs = _splitShellWords(
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
      sshExitCode == 0 && sshCapture.stdout.contains(_remotePrintCommandMarker);
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

bool _isUnsupportedPrintClient(NoPortsVersion clientVersion) {
  return versionIsAtLeast(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.0.0'),
      ) &&
      versionIsLessThan(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.1.0'),
      );
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

  args.add('-x');

  if (versionIsAtLeast(
    clientVersion,
    NoPortsVersion(language: Language.dart, version: 'v5.3.0'),
  )) {
    args.add('-k');
    args.add(context.apkamKeys[context.clientAtsign]!.path);
  }

  return args;
}

List<String> _splitShellWords(String command) {
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
