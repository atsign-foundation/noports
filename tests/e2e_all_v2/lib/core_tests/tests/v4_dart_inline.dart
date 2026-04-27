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

List<Future<CoreTestResult> Function()> runV4DartInlineTests({
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

    testFactories.add(() => _runV4DartInlineTest(
      context: context,
      testLogger: testLogger,
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
    ));
  }

  return testFactories;
}

Future<CoreTestResult> _runV4DartInlineTest({
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
      testMetadata: _metadata,
    ),
    stderrFile: testLogger.getDaemonStderrLogFile(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: _metadata,
    ),
  );
  daemonLogCapture.start();

  final Process process = await Process.start(
    sshnpClientBinary.file.path,
    sshnpArgs,
  );

  final StringBuffer stdoutBuffer = StringBuffer();
  final StringBuffer stderrBuffer = StringBuffer();

  bool commandSent = false;
  final completer = Completer<int>();

  process.stdout.listen((data) {
    final str = String.fromCharCodes(data);
    stdoutBuffer.write(str);
    if(!commandSent && str.contains('Last login:')) {
      commandSent = true;
      process.stdin.writeln('echo `date` `whoami` `hostname` SCOOBY DOO');
      Future.delayed(Duration(seconds: 2), () {
        process.stdin.writeln('exit');
      });
    }
  });

  process.stderr.listen((data) {
    final str = String.fromCharCodes(data);
    stderrBuffer.write(str);
  });

  process.exitCode.then((code) {
    if(!completer.isCompleted) {
      completer.complete(code);
    }
  });

  Timer(Duration(seconds: 30), () {
    if(!completer.isCompleted) {
      process.kill();
      completer.complete(1);
    }
  });

  final int exitCode = await completer.future;
  daemonLogCapture.stop();

  final String stdout = stdoutBuffer.toString();
  final String stderr = stderrBuffer.toString();
  final bool sshSucceeded = exitCode == 0 && commandSent && stdout.contains('SCOOBY DOO');

  final CoreTestResult result = CoreTestResult(
    testName: testName,
    clientVersion: clientVersion,
    daemonVersion: daemonVersion,
    status: sshSucceeded ? TestStatus.passed : TestStatus.failed,
    exitCode: exitCode,
  );
  printTestResult(testResult: result, extra: extra);

  if(!sshSucceeded) {
    print('Client stdout: $stdout');
    print('Client stderr: $stderr');
    print('Daemon logs available at: ${daemonLogCapture.stdoutFile.path}');
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
    '--ssh-client', 'dart',
  ];

  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
    args.add('--no-ad');
    args.add('--no-et');
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
