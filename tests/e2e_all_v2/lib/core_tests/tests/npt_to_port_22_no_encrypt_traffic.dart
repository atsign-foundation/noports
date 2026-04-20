// import 'package:e2e_all_v2/client_binary.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_logging.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_print_utils.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
// import 'package:e2e_all_v2/docker_instance.dart';
// import 'package:e2e_all_v2/language.dart';
// import 'package:e2e_all_v2/print_test_utils.dart';
// import 'package:e2e_all_v2/process_utils.dart';
// import 'package:e2e_all_v2/test_result.dart';
//
// const String _metadataNptExecution = 'nptExecution';
// const String _metadataSshExecution = 'sshExecution';
// const String testName = 'npt_to_port_22_no_encrypt_traffic';
//
// // Test: npt_to_port_22_no_encrypt_traffic
// // 1. Execute npt command with --no-encrypt-rvd-traffic flag to create an unencrypted tunnel to remote port 22
// // 2. Capture the local port returned by npt
// // 3. Execute SSH connection to localhost on that port
// // 4. Verify the SSH connection succeeds
// // Requirements:
// // - Feature only available in v5.6.2+ (current versions only)
// // - Only runs with BOTH client and daemon as d:current
// Future<List<CoreTestResult>> runNptToPort22NoEncryptTrafficTests({
//   required final CoreTestsContext context,
// }) async {
//   final List<CoreTestResult> testResults = [];
//   final CoreTestLogger testLogger = CoreTestLogger(logsDirectory: context.logsDirectory, testName: testName);
//
//   // This test only runs with current client and current daemon (v5.6.2+ feature)
//   final ClientBinary currentNptClientBinary = context.clientBinaries.firstWhere((cb) =>
//     cb.binaryType == ClientBinaryType.npt &&
//     cb.noPortsVersion.version == 'current' &&
//     cb.noPortsVersion.language == Language.dart);
//
//   final String extra = '(client: d:current, daemon: d:current)';
//   final String clientVersionStr = 'current';
//   final String daemonVersionStr = 'current';
//
//   final String deviceName = '${getDeviceNameNoFlags(
//     testRunId: context.testRunId,
//     language: Language.dart,
//     version: daemonVersionStr)}_f';
//   final String daemonInfo = 'dart_current';
//
//   final List<String> nptArgs = _buildNptArgs(
//     context: context,
//     deviceName: deviceName,
//   );
//
//   printTestStart(testName: testName, extra: extra);
//
//   final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
//   final DaemonLogCapture daemonLogCapture = DaemonLogCapture(
//     dockerInstance: daemonDockerInstance,
//     stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
//       language: Language.dart,
//       version: daemonVersionStr,
//       deviceName: deviceName,
//       testMetadata: _metadataNptExecution,
//     ),
//     stderrFragmentFile: testLogger.getDaemonStderrLogFile(
//       language: Language.dart,
//       version: daemonVersionStr,
//       deviceName: deviceName,
//       testMetadata: _metadataNptExecution,
//     ),
//   );
//   await daemonLogCapture.start();
//
//   // 1. Execute npt command with --no-encrypt-rvd-traffic
//   final ProcessOutputCapture nptCapture = await startCommandWithCapture(
//     currentNptClientBinary.file.path,
//     nptArgs,
//     stdoutLogFile: testLogger.getClientStdoutLogFile(
//       language: Language.dart,
//       version: clientVersionStr,
//       testMetadata: _metadataNptExecution,
//       daemonInfo: daemonInfo,
//     ),
//     stderrLogFile: testLogger.getClientStderrLogFile(
//       language: Language.dart,
//       version: clientVersionStr,
//       testMetadata: _metadataNptExecution,
//       daemonInfo: daemonInfo,
//     ),
//   );
//
//   final int nptExitCode = await nptCapture.exitCode;
//   await daemonLogCapture.stop();
//
//   if(nptExitCode != 0) {
//     final CoreTestResult result = CoreTestResult(
//       testName: testName,
//       clientVersion: clientVersionStr,
//       daemonVersion: daemonVersionStr,
//       status: TestStatus.failed,
//       exitCode: nptExitCode,
//       stdout: StringBuffer(nptCapture.stdout),
//       stderr: StringBuffer(nptCapture.stderr),
//     );
//     printTestResult(testResult: result, extra: extra);
//     printAllLogs(clientCapture: nptCapture, daemonLogCapture: daemonLogCapture);
//     testResults.add(result);
//     return testResults;
//   }
//
//   // 2. Parse the local port from npt output
//   final String nptOutput = nptCapture.stdout.trim();
//   final int? localPort = int.tryParse(nptOutput);
//
//   if(localPort == null) {
//     final CoreTestResult result = CoreTestResult(
//       testName: testName,
//       clientVersion: clientVersionStr,
//       daemonVersion: daemonVersionStr,
//       status: TestStatus.failed,
//       exitCode: 1,
//       stdout: StringBuffer('Failed to parse local port from npt output: "$nptOutput"'),
//     );
//     printTestResult(testResult: result, extra: extra);
//     printAllLogs(clientCapture: nptCapture, daemonLogCapture: daemonLogCapture);
//     testResults.add(result);
//     return testResults;
//   }
//
//   // 3. Execute SSH connection
//   final List<String> sshArgs = [
//     '-p', localPort.toString(),
//     '-o', 'StrictHostKeyChecking=accept-new',
//     '-o', 'IdentitiesOnly=yes',
//     '-i', context.identityFilePath,
//     '${context.remoteUsername}@localhost',
//     'echo', '`date`', '`whoami`', '`hostname`', 'TEST', 'PASSED',
//   ];
//
//   final DaemonLogCapture daemonLogCapture2 = DaemonLogCapture(
//     dockerInstance: daemonDockerInstance,
//     stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
//       language: Language.dart,
//       version: daemonVersionStr,
//       deviceName: deviceName,
//       testMetadata: _metadataSshExecution,
//     ),
//     stderrFragmentFile: testLogger.getDaemonStderrLogFile(
//       language: Language.dart,
//       version: daemonVersionStr,
//       deviceName: deviceName,
//       testMetadata: _metadataSshExecution,
//     ),
//   );
//   await daemonLogCapture2.start();
//
//   final ProcessOutputCapture sshCapture = await startCommandWithCapture('ssh', sshArgs);
//   final int sshExitCode = await sshCapture.exitCode;
//   await daemonLogCapture2.stop();
//
//   if(sshExitCode == 0) {
//     final CoreTestResult result = CoreTestResult(
//       testName: testName,
//       clientVersion: clientVersionStr,
//       daemonVersion: daemonVersionStr,
//       status: TestStatus.passed,
//       exitCode: sshExitCode,
//     );
//     printTestResult(testResult: result, extra: extra);
//     if(context.alwaysOutputLogs) {
//       printAllLogs(
//         clientCapture: nptCapture,
//         daemonLogCapture: daemonLogCapture,
//         clientLabel: 'Client (npt with --no-encrypt-rvd-traffic)',
//         daemonLabel: 'Daemon (npt execution)',
//       );
//       printAllLogs(
//         clientCapture: sshCapture,
//         daemonLogCapture: daemonLogCapture2,
//         clientLabel: 'Client (ssh)',
//         daemonLabel: 'Daemon (ssh execution)',
//       );
//     }
//     testResults.add(result);
//   } else {
//     final CoreTestResult result = CoreTestResult(
//       testName: testName,
//       clientVersion: clientVersionStr,
//       daemonVersion: daemonVersionStr,
//       status: TestStatus.failed,
//       exitCode: sshExitCode,
//       stdout: StringBuffer(sshCapture.stdout),
//       stderr: StringBuffer(sshCapture.stderr),
//     );
//     printTestResult(testResult: result, extra: extra);
//     printAllLogs(
//       clientCapture: nptCapture,
//       daemonLogCapture: daemonLogCapture,
//       clientLabel: 'Client (npt with --no-encrypt-rvd-traffic)',
//       daemonLabel: 'Daemon (npt execution)',
//     );
//     printAllLogs(
//       clientCapture: sshCapture,
//       daemonLogCapture: daemonLogCapture2,
//       clientLabel: 'Client (ssh)',
//       daemonLabel: 'Daemon (ssh execution)',
//     );
//     testResults.add(result);
//   }
//
//   return testResults;
// }
//
// List<String> _buildNptArgs({
//   required CoreTestsContext context,
//   required String deviceName,
// }) {
//   final List<String> args = [
//     '-f', context.clientAtsign,
//     '-t', context.daemonAtsign,
//     '-d', deviceName,
//     '-r', context.relayAtsign,
//     '--root-domain', context.rootDomain,
//     '--remote-port', '22',
//     '--exit-when-connected',
//     '--no-encrypt-rvd-traffic',
//     '--verbose',
//     '-k', context.apkamKeys[context.clientAtsign]!.path,
//   ];
//
//   return args;
// }
