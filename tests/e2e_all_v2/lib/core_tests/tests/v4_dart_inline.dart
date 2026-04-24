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

const String testName = 'v4_dart_inline';
const String _metadata = 'v4DartInline';

// Test: v4_dart_inline
// Tests v4 daemon features with Dart SSH client running inline
// - Uses --ssh-client dart flag
// - Dart client manages SSH session internally
// - Expects successful inline SSH execution
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart v5.9.4 | Daemon: Dart (current)
// - Client: Dart v5.11.2 | Daemon: Dart (current)
// - Client: Dart v5.13.0 | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0
List<Future<CoreTestResult> Function()> runV4DartInlineTests({
  required final CoreTestsContext context,
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  final List<Future<CoreTestResult> Function()> testFunctions = [];
  final CoreTestLogger testLogger = CoreTestLogger(logsDirectory: context.logsDirectory, testName: testName);

  final List<(NoPortsVersion, NoPortsVersion)> versionCombinations =
    _generateVersionCombinations(
      clientVersions: clientVersions,
      daemonVersions: daemonVersions,
    );

  for(final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion) in versionCombinations) {
    testFunctions.add(() => _runV4DartInlineTest(
      context: context,
      testLogger: testLogger,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
    ));
  }

  return testFunctions;
}

Future<CoreTestResult> _runV4DartInlineTest({
  required final CoreTestsContext context,
  required final CoreTestLogger testLogger,
  required final NoPortsVersion clientVersion,
  required final NoPortsVersion daemonVersion,
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
  final LogFragment daemonLogFragment = daemonDockerInstance.createLogFragment(
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
  daemonLogFragment.start();

  // Execute sshnp with dart client inline mode
  // Pass the test command directly - it will execute and exit
  final ProcessOutputCapture capture = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    sshnpArgs,
    stdoutLogFile: testLogger.getClientStdoutLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadata,
    ),
    stderrLogFile: testLogger.getClientStderrLogFile(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      testMetadata: _metadata,
    ),
  );

  final int exitCode = await capture.exitCode;
  daemonLogFragment.stop();

  // Check if test passed - command should have output our test string
  final String stdout = capture.stdout;
  final bool sshSucceeded = exitCode == 0 && stdout.contains('SCOOBY DOO');

  final CoreTestResult result = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: sshSucceeded ? TestStatus.passed : TestStatus.failed,
    exitCode: sshSucceeded ? exitCode : (exitCode == 0 ? 1 : exitCode),
  );
  printTestResult(testResult: result, extra: extra);
  if(!sshSucceeded) {
    print('Client stdout (last 500 chars): ${stdout.length > 500 ? stdout.substring(stdout.length - 500) : stdout}');
    print('Client stderr: ${capture.stderr}');
    print('Daemon logs available at: ${daemonLogFragment.stdoutFile.path} and ${daemonLogFragment.stderrFile.path}');
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
    '--root-domain', context.rootDomain,
    '-i', context.identityFilePath,
    '-s',
    '--ssh-client', 'dart',
  ];

  // v5+ clients need backward compatibility flags for v4 daemons
  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
    args.add('--no-ad');
    args.add('--no-et');
  }

  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
    args.add('-k');
    args.add(context.apkamKeys[context.clientAtsign]!.path);
  }

  // Add test command to execute and exit
  args.addAll(['echo', '`date`', '`whoami`', '`hostname`', 'SCOOBY', 'DOO']);

  return args;
}

// Generate version combinations:
// - Released client with current daemon
// - Current client with released daemon
// Skip: released client with released daemon (already tested)
// Skip: C daemon (incompatible)
List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> combinations = [];
  for(final clientVersion in clientVersions) {
    for(final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';

      // Skip if both are not current
      if(!isClientCurrent && !isDaemonCurrent) {
        continue;
      }

      // Skip C daemon (not applicable for this test)
      if(daemonVersion.language == Language.c) {
        continue;
      }

      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
