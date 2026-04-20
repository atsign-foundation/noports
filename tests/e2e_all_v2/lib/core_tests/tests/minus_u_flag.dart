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

// 1. Run sshnp without `-u <username>` talking to device daemon which does not have `-u` flag enabled (expect to fail)
// 2. Run sshnp without `-u <username>` talking to device daemon which does have `-u` flag enabled (expect to pass)
// - Client: Dart (current) | Daemon: Dart (current)
Future<List<CoreTestResult>> runMinusUFlagTests({
  required final CoreTestsContext context,
}) async {
  const String testName = 'minus_u_flag';
  final CoreTestLogger coreTestLogger = CoreTestLogger(testName: testName, logsDirectory: context.logsDirectory);
  final List<CoreTestResult> testResults = [];
  final NoPortsVersion clientVersion = NoPortsVersion(language: Language.dart, version: 'current');
  final NoPortsVersion daemonVersion = NoPortsVersion(language: Language.dart, version: 'current');
  final String extra = '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version})';
  final List<ClientBinary> clientBinaries = context.clientBinaries;
  final String testRunId = context.testRunId;
  final Map<String, File> apkamKeys = context.apkamKeys;
  final String clientAtsign = context.clientAtsign;
  final String daemonAtsign = context.daemonAtsign;
  final String identityFilePath = context.identityFilePath;
  final String rootDomain = context.rootDomain;
  final String relayAtsign = context.relayAtsign;
  printTestStart(testName: testName, extra: extra);
  final ClientBinary sshnpClientBinary = clientBinaries.firstWhere((cb) => cb.noPortsVersion == clientVersion);
  final String deviceNameNoFlags = getDeviceNameNoFlags(testRunId: testRunId, language: daemonVersion.language, version: daemonVersion.version);
  final String deviceNameWithFlags = '${deviceNameNoFlags}_f';
  final List<String> baseArgs = _generateBaseSshnpArgs(
    clientVersion: clientVersion,
    testRunId: testRunId, 
    clientAtsign: clientAtsign,
    daemonAtsign: daemonAtsign,
    localClientAtsignAtKeysFilePath: apkamKeys[clientAtsign]!.path,
    relayAtsign: relayAtsign,
    identityFilePath: identityFilePath,
    rootDomain: rootDomain,
    deviceName: deviceNameNoFlags,
  );

  // 1. Test that `sshnp` (no -u $remoteUsername) to a daemon with `sshnpd` (no -u)
  final String daemonInfo1 = '${daemonVersion.language.name}_${daemonVersion.version}';
  final DockerInstance daemonDockerInstance1 = context.dockerInstances.firstWhere((di) => di.$1 == deviceNameNoFlags).$2;
  final DaemonLogCapture daemonLogCapture1 = DaemonLogCapture(
    dockerInstance: daemonDockerInstance1,
    stdoutFragmentFile: coreTestLogger.getDaemonStdoutLogFile(
      language: daemonVersion.language,
      version: daemonVersion.version,
      deviceName: deviceNameNoFlags,
      testMetadata: 'without_u_flag',
    ),
    stderrFragmentFile: coreTestLogger.getDaemonStderrLogFile(
      language: daemonVersion.language,
      version: daemonVersion.version,
      deviceName: deviceNameNoFlags,
      testMetadata: 'without_u_flag',
    ),
  );
  await daemonLogCapture1.start();
  printTestStart(testName: testName, extra: extra);
  final String _metadataWithoutUFlag = 'without_u_flag';
  final List<String> argsWithoutUFlag = List.from(baseArgs);
  final ProcessOutputCapture resultWithoutUFlag = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    argsWithoutUFlag,  
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      language: sshnpClientBinary.noPortsVersion.language,
      version: sshnpClientBinary.noPortsVersion.version,
      testMetadata: _metadataWithoutUFlag,
      daemonInfo: daemonInfo1,
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile(
      language: sshnpClientBinary.noPortsVersion.language,
      version: sshnpClientBinary.noPortsVersion.version,
      testMetadata: _metadataWithoutUFlag,
      daemonInfo: daemonInfo1,
    ),
  );
  int exitCode = await resultWithoutUFlag.exitCode;
  await daemonLogCapture1.stop();

  if(exitCode == 0) {
    print('Expected failure when connecting without -u flag.');
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion.version,
      daemonVersion: daemonVersion.version,
      status: TestStatus.failed,
      exitCode: exitCode,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: resultWithoutUFlag, daemonLogCapture: daemonLogCapture1);
    testResults.add(coreTestResult);
  } else {
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion.version,
      daemonVersion: daemonVersion.version,
      status: TestStatus.passed,
      exitCode: exitCode,
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    testResults.add(coreTestResult);
  }


  // 2. Run sshnp without the `-u <username> option talking
  // to a device daemon WHICH DOES have the `-u` flag enabled
  // Expect succeeds
  // Verify with subsequent ssh command that it succeeds
  final String daemonInfo2 = '${daemonVersion.language.name}_${daemonVersion.version}';
  final DockerInstance daemonDockerInstance2 = context.dockerInstances.firstWhere((di) => di.$1 == deviceNameWithFlags).$2;
  final DaemonLogCapture daemonLogCapture2 = DaemonLogCapture(
    dockerInstance: daemonDockerInstance2,
    stdoutFragmentFile: coreTestLogger.getDaemonStdoutLogFile(
      language: daemonVersion.language,
      version: daemonVersion.version,
      deviceName: deviceNameWithFlags,
      testMetadata: 'with_u_flag',
    ),
    stderrFragmentFile: coreTestLogger.getDaemonStderrLogFile(
      language: daemonVersion.language,
      version: daemonVersion.version,
      deviceName: deviceNameWithFlags,
      testMetadata: 'with_u_flag',
    ),
  );
  await daemonLogCapture2.start();
  printTestStart(testName: testName, extra: extra);
  final String _metadataWithUFlag = 'with_u_flag';
  final List<String> argsWithUFlag = List.from(baseArgs);
  final ProcessOutputCapture resultWithUFlag = await startCommandWithCapture(
    sshnpClientBinary.file.path,
    argsWithUFlag,  
    stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
      language: sshnpClientBinary.noPortsVersion.language,
      version: sshnpClientBinary.noPortsVersion.version,
      testMetadata: _metadataWithUFlag,
      daemonInfo: daemonInfo2,
    ),
    stderrLogFile: coreTestLogger.getClientStderrLogFile( 
      language: sshnpClientBinary.noPortsVersion.language,
      version: sshnpClientBinary.noPortsVersion.version,
      testMetadata: _metadataWithUFlag,
      daemonInfo: daemonInfo2,
    ),
  );
  exitCode = await resultWithUFlag.exitCode;
  await daemonLogCapture2.stop();

  if(exitCode != 0) {
    print('Expected success when connecting without -u flag to a daemon with -u flag enabled.');
    final CoreTestResult coreTestResult = CoreTestResult(
      testName: testName,
      clientVersion: clientVersion.version,
      daemonVersion: daemonVersion.version,
      status: TestStatus.failed,
      exitCode: exitCode,
      stdout: StringBuffer(resultWithUFlag.stdout),
      stderr: StringBuffer(resultWithUFlag.stderr),
    );
    printTestResult(testResult: coreTestResult, extra: extra);
    printAllLogs(clientCapture: resultWithUFlag, daemonLogCapture: daemonLogCapture2);
    testResults.add(coreTestResult);
  } else {
    String sshCommand = resultWithUFlag.stdout.trim();
    if(sshCommand.startsWith('ssh ')) {
      sshCommand = sshCommand.substring(4);
    } else {
      print('Expected ssh command in stdout, got: ${resultWithUFlag.stdout}');
      final CoreTestResult coreTestResult = CoreTestResult(
        testName: testName,
        clientVersion: clientVersion.version,
        daemonVersion: daemonVersion.version,
        status: TestStatus.failed,
        exitCode: exitCode,
        stdout: StringBuffer(resultWithUFlag.stdout),
        stderr: StringBuffer(resultWithUFlag.stderr),
      );
      printTestResult(testResult: coreTestResult, extra: extra);
      printAllLogs(clientCapture: resultWithUFlag, daemonLogCapture: daemonLogCapture2);
      testResults.add(coreTestResult);
      return testResults;
    }
    List<String> sshCommandArgs = sshCommand.split(' ');
    sshCommandArgs.add('echo');
    sshCommandArgs.add('`date`');
    sshCommandArgs.add('`whoami`');
    sshCommandArgs.add('`hostname`');
    sshCommandArgs.add('TEST PASSED');

    final DaemonLogCapture sshDameonLogCapture = DaemonLogCapture(
      dockerInstance: daemonDockerInstance2,
      stdoutFragmentFile: coreTestLogger.getDaemonStdoutLogFile(
        language: daemonVersion.language,
        version: daemonVersion.version,
        deviceName: deviceNameWithFlags,
        testMetadata: 'ssh_after_with_u_flag',
      ),
      stderrFragmentFile: coreTestLogger.getDaemonStderrLogFile(
        language: daemonVersion.language,
        version: daemonVersion.version,
        deviceName: deviceNameWithFlags,
        testMetadata: 'ssh_after_with_u_flag',
      ),
    );
    await sshDameonLogCapture.start();
    final ProcessOutputCapture sshResult = await startCommandWithCapture(
      'ssh',
      sshCommandArgs,
      stdoutLogFile: coreTestLogger.getClientStdoutLogFile(
        language: clientVersion.language,
        version: clientVersion.version,
        testMetadata: 'ssh_after_with_u_flag',
        daemonInfo: daemonInfo2,
      ),
      stderrLogFile: coreTestLogger.getClientStderrLogFile(
        language: clientVersion.language,
        version: clientVersion.version,
        testMetadata: 'ssh_after_with_u_flag',
        daemonInfo: daemonInfo2,
      ),
    );
    final int sshExitCode = await sshResult.exitCode;
    await sshDameonLogCapture.stop();
    if(sshExitCode == 0) {
      final CoreTestResult coreTestResult = CoreTestResult(
        testName: testName,
        clientVersion: clientVersion.version,
        daemonVersion: daemonVersion.version,
        status: TestStatus.passed,
        exitCode: sshExitCode,
      );
      printTestResult(testResult: coreTestResult, extra: extra);
      if(context.alwaysOutputLogs) {
        printAllLogs(clientCapture: resultWithUFlag, daemonLogCapture: daemonLogCapture2, clientLabel: 'Client (sshnp with -u flag enabled daemon)', daemonLabel: 'Daemon (sshnp with -u flag enabled)');
        printAllLogs(clientCapture: sshResult, daemonLogCapture: sshDameonLogCapture, clientLabel: 'Client (ssh after sshnp with -u flag enabled)', daemonLabel: 'Daemon (ssh after sshnp with -u flag enabled)');
      }
      testResults.add(coreTestResult);
    } else {
      final CoreTestResult coreTestResult = CoreTestResult(
        testName: testName,
        clientVersion: clientVersion.version,
        daemonVersion: daemonVersion.version,
        status: TestStatus.failed,
        exitCode: sshExitCode,
        stdout: StringBuffer(sshResult.stdout),
        stderr: StringBuffer(sshResult.stderr),
      );
      printTestResult(testResult: coreTestResult, extra: extra);
      printAllLogs(clientCapture: resultWithUFlag, daemonLogCapture: daemonLogCapture2, clientLabel: 'Client (sshnp with -u flag enabled daemon)', daemonLabel: 'Daemon (sshnp with -u flag enabled)');
      printAllLogs(clientCapture: sshResult, daemonLogCapture: sshDameonLogCapture, clientLabel: 'Client (ssh after sshnp with -u flag enabled)', daemonLabel: 'Daemon (ssh after sshnp with -u flag enabled)');
      testResults.add(coreTestResult);
    }
  }


  return testResults;
}

List<String> _generateBaseSshnpArgs({
  required final NoPortsVersion clientVersion,
  required final String testRunId,
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String localClientAtsignAtKeysFilePath,
  required final String relayAtsign,
  required final String identityFilePath,
  required final String rootDomain,
  required final String deviceName,
}) {
  final List<String> args = [];
  // v4 feature set, default client flags
  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
    args.add('-x');
    args.add('--no-ad');
    args.add('--no-et');
  }
  if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
    args.add('-k');
    args.add(localClientAtsignAtKeysFilePath);
  }
  args.addAll([
    '-f', clientAtsign,
    '-t', daemonAtsign,
    '-h', relayAtsign,
    '--root-domain', rootDomain,
    '-d', deviceName,
  ]);
  return args;
}
