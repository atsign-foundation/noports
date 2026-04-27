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

const String testName = 'v4_openssh_print';
const String _metadataSshnpExecution = 'sshnpExecution';
const String _metadataSshExecution = 'sshExecution';

List<Future<CoreTestResult> Function()> runV4OpensshPrintTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final List<Future<CoreTestResult> Function()> testFactories = [];
  final CoreTestLogger testLogger = CoreTestLogger(logsDirectory: context.logsDirectory, testName: testName);

  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations = _generateVersionCombinations(
    clientVersions: clientVersions,
    daemonVersions: daemonVersions,
  );

  for(final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion) in versionCombinations) {
    if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0')) &&
       versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.1.0'))) {
      continue;
    }

    testFactories.add(() => _runV4OpensshPrintTest(
      context: context,
      testLogger: testLogger,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
    ));
  }

  return testFactories;
}

Future<CoreTestResult> _runV4OpensshPrintTest({
  required CoreTestsContext context,
  required CoreTestLogger testLogger,
  required NoPortsVersion clientVersion,
  required NoPortsVersion daemonVersion,
}) async {
  final String extra = generateExtraString(clientVersion, daemonVersion, useShortLanguageName: true);
  printTestStart(testName: testName, extra: extra);

  final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere((cb) =>
    cb.binaryType == ClientBinaryType.sshnp &&
    cb.noPortsVersion == clientVersion);

  final String deviceName = '${getDeviceNameNoFlags(
    testRunId: context.testRunId,
    noPortsVersion: daemonVersion)}_f';

  final List<String> sshnpArgs = _buildSshnpArgs(
    context: context,
    clientVersion: clientVersion,
    deviceName: deviceName,
  );

  final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
  final LogFragment daemonLogCapture = await daemonDockerInstance.createLogFragment(
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
  daemonLogCapture.start();

  final ProcessOutputCapture sshnpCapture = await startCommandWithCapture(
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

  final int sshnpExitCode = await sshnpCapture.exitCode;
  daemonLogCapture.stop();

  if(sshnpExitCode != 0) {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: sshnpExitCode,
    );
    printTestResult(testResult: result, extra: extra);
    printAllLogs(clientCapture: sshnpCapture, daemonLogFragment: daemonLogCapture);
    return result;
  }

  String sshCommand = sshnpCapture.stdout.trim();
  if(sshCommand.startsWith('ssh ')) {
    sshCommand = sshCommand.substring(4);
  } else {
    final CoreTestResult result = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      status: TestStatus.failed,
      exitCode: 1,
    );
    printTestResult(testResult: result, extra: extra);
    printAllLogs(clientCapture: sshnpCapture, daemonLogFragment: daemonLogCapture);
    return result;
  }

  List<String> sshCommandArgs = sshCommand.split(' ');
  sshCommandArgs.addAll(['echo', '`date`', '`whoami`', '`hostname`', 'TEST', 'PASSED']);

  final LogFragment daemonLogCapture2 = await daemonDockerInstance.createLogFragment(
    stdoutFile: testLogger.getDaemonStdoutLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataSshExecution,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadataSshExecution,
    ),
  );
  daemonLogCapture2.start();

  final ProcessOutputCapture sshCapture = await startCommandWithCapture(
    'ssh',
    sshCommandArgs,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataSshExecution,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadataSshExecution,
    ),
  );
  final int sshExitCode = await sshCapture.exitCode;
  daemonLogCapture2.stop();

  final CoreTestResult result = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: sshExitCode == 0 ? TestStatus.passed : TestStatus.failed,
    exitCode: sshExitCode,
  );
  printTestResult(testResult: result, extra: extra);

  if(sshExitCode != 0) {
    printAllLogs(clientCapture: sshCapture, daemonLogFragment: daemonLogCapture2);
  }

  return result;
}

List<String> _buildSshnpArgs({
  required CoreTestsContext context,
  required NoPortsVersion clientVersion,
  required String deviceName,
}) {
  final List<String> args = [
    '-f', context.clientAtsign,
    '-t', context.daemonAtsign,
    '-d', deviceName,
    '-h', context.relayAtsign,
    '-u', context.remoteUsername,
    '-i', context.identityFilePath,
    '--root-domain', context.rootDomain,
    '-s',
  ];

  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
    args.add('--no-ad');
    args.add('--no-et');
    args.add('-x');
  }

  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
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
  for(final clientVersion in clientVersions) {
    for(final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';

      if(!isClientCurrent && !isDaemonCurrent) {
        continue;
      }

      if(daemonVersion.language == Language.c) {
        continue;
      }

      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
