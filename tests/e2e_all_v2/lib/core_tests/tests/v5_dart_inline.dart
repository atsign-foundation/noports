// import 'dart:async';
// import 'dart:io';
//
// import 'package:e2e_all_v2/client_binary.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_context.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_logging.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_print_utils.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
// import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
// import 'package:e2e_all_v2/docker_instance.dart';
// import 'package:e2e_all_v2/language.dart';
// import 'package:e2e_all_v2/noports_version.dart';
// import 'package:e2e_all_v2/print_test_utils.dart';
// import 'package:e2e_all_v2/test_result.dart';
//
// const String testName = 'v5_dart_inline';
// const String _metadata = 'v5DartInline';
//
// // Test: v5_dart_inline
// // Tests v5 daemon features with Dart SSH client running inline
// // - Uses --ssh-client dart flag
// // - Dart client manages SSH session internally
// // - Expects successful inline SSH execution
// // - Tests v5 features (asset discovery, encrypted traffic, etc.)
// // Requirements:
// // - Requires v5+ client to test v5 features
// // - Requires v5+ daemon to test v5 features
// // - Dart SSH client always runs inline (doesn't support print mode)
// // - C daemon requires v5.3.0+ client for compatibility
// // Test matrix:
// // - Released client with current daemon
// // - Current client with released daemon
// Future<List<CoreTestResult>> runV5DartInlineTests({
//   required final CoreTestsContext context,
//   required final List<NoPortsVersion> clientVersions,
//   required final List<NoPortsVersion> daemonVersions,
// }) async {
//   final List<CoreTestResult> testResults = [];
//   final CoreTestLogger testLogger = CoreTestLogger(logsDirectory: context.logsDirectory, testName: testName);
//
//   final List<(NoPortsVersion, NoPortsVersion)> versionCombinations =
//     _generateVersionCombinations(
//       clientVersions: clientVersions,
//       daemonVersions: daemonVersions,
//     );
//
//   for(final (NoPortsVersion clientVersion, NoPortsVersion daemonVersion) in versionCombinations) {
//     // Require v5+ client for v5 features
//     if(versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
//       continue;
//     }
//
//     // Require v5+ daemon for v5 features
//     if(versionIsLessThan(daemonVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
//       continue;
//     }
//
//     // C daemon requires v5.3.0+ client
//     if(daemonVersion.language == Language.c &&
//        versionIsLessThan(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
//       continue;
//     }
//
//     final String extra = '(client: ${clientVersion.language.name[0]}:${clientVersion.version}, daemon: ${daemonVersion.language.name[0]}:${daemonVersion.version})';
//     final String clientVersionStr = clientVersion.version;
//     final String daemonVersionStr = daemonVersion.version;
//
//     final ClientBinary sshnpClientBinary = context.clientBinaries.firstWhere((cb) =>
//       cb.binaryType == ClientBinaryType.sshnp &&
//       cb.noPortsVersion == clientVersion);
//
//     final String deviceName = '${getDeviceNameNoFlags(
//       testRunId: context.testRunId,
//       language: daemonVersion.language,
//       version: daemonVersionStr)}_f';
//     final String daemonInfo = '${daemonVersion.language.name}_${daemonVersionStr}';
//
//     final List<String> sshnpArgs = _buildSshnpArgs(
//       context: context,
//       clientVersion: clientVersion,
//       daemonLanguage: daemonVersion.language,
//       deviceName: deviceName,
//     );
//
//     printTestStart(testName: testName, extra: extra);
//
//     final DockerInstance daemonDockerInstance = context.dockerInstances.firstWhere((di) => di.$1 == deviceName).$2;
//     final DaemonLogCapture daemonLogCapture = DaemonLogCapture(
//       dockerInstance: daemonDockerInstance,
//       stdoutFragmentFile: testLogger.getDaemonStdoutLogFile(
//         language: daemonVersion.language,
//         version: daemonVersionStr,
//         deviceName: deviceName,
//         testMetadata: _metadata,
//       ),
//       stderrFragmentFile: testLogger.getDaemonStderrLogFile(
//         language: daemonVersion.language,
//         version: daemonVersionStr,
//         deviceName: deviceName,
//         testMetadata: _metadata,
//       ),
//     );
//     await daemonLogCapture.start();
//
//     // Execute sshnp with dart client inline mode
//     // The Dart SSH client will handle the SSH session internally
//     final Process process = await Process.start(
//       sshnpClientBinary.file.path,
//       sshnpArgs,
//     );
//
//     final File stdoutLogFile = testLogger.getClientStdoutLogFile(
//       language: clientVersion.language,
//       version: clientVersionStr,
//       testMetadata: _metadata,
//       daemonInfo: daemonInfo,
//     );
//     final File stderrLogFile = testLogger.getClientStderrLogFile(
//       language: clientVersion.language,
//       version: clientVersionStr,
//       testMetadata: _metadata,
//       daemonInfo: daemonInfo,
//     );
//
//     // Ensure files exist before opening
//     if (!stdoutLogFile.existsSync()) {
//       stdoutLogFile.createSync(recursive: true);
//     }
//     if (!stderrLogFile.existsSync()) {
//       stderrLogFile.createSync(recursive: true);
//     }
//
//     final IOSink stdoutSink = stdoutLogFile.openWrite();
//     final IOSink stderrSink = stderrLogFile.openWrite();
//     final StringBuffer stdoutBuffer = StringBuffer();
//     final StringBuffer stderrBuffer = StringBuffer();
//
//     // Capture both to buffers and log files
//     final StreamSubscription stdoutSub = process.stdout.listen((data) {
//       final str = String.fromCharCodes(data);
//       stdoutBuffer.write(str);
//       stdoutSink.add(data);
//     });
//     final StreamSubscription stderrSub = process.stderr.listen((data) {
//       final str = String.fromCharCodes(data);
//       stderrBuffer.write(str);
//       stderrSink.add(data);
//     });
//
//     // Wait for "Last login:" prompt indicating SSH session is ready
//     bool loginPromptSeen = false;
//     final completer = Completer<void>();
//     Timer? timeoutTimer;
//
//     final stdoutLineController = StreamController<String>();
//     String currentLine = '';
//
//     final stdoutLineSub = stdoutLineController.stream.listen((line) {
//       if(line.contains('Last login:')) {
//         loginPromptSeen = true;
//         // Send test command
//         process.stdin.writeln('echo `date` `whoami` `hostname` SCOOBY DOO');
//         // Give it a moment then exit the session
//         Future.delayed(Duration(seconds: 2), () {
//           process.stdin.writeln('exit');
//           completer.complete();
//         });
//       }
//     });
//
//     // Parse stdout into lines
//     stdoutSub.onData((data) {
//       final str = String.fromCharCodes(data);
//       for(int i = 0; i < str.length; i++) {
//         if(str[i] == '\n') {
//           stdoutLineController.add(currentLine);
//           currentLine = '';
//         } else {
//           currentLine += str[i];
//         }
//       }
//     });
//
//     // Set timeout
//     timeoutTimer = Timer(Duration(seconds: 30), () {
//       if(!completer.isCompleted) {
//         completer.completeError('Timeout waiting for SSH session');
//       }
//     });
//
//     try {
//       await completer.future;
//     } catch(e) {
//       // Timeout or error
//       process.kill();
//     }
//
//     timeoutTimer.cancel();
//     await stdoutLineSub.cancel();
//     await stdoutLineController.close();
//
//     final int exitCode = await process.exitCode;
//     await stdoutSub.cancel();
//     await stderrSub.cancel();
//     await stdoutSink.close();
//     await stderrSink.close();
//     await daemonLogCapture.stop();
//
//     // Check if test passed
//     final String stdout = stdoutBuffer.toString();
//     final String stderr = stderrBuffer.toString();
//     final bool sshSucceeded = exitCode == 0 && loginPromptSeen && stdout.contains('SCOOBY DOO');
//
//     if(sshSucceeded) {
//       final CoreTestResult result = CoreTestResult(
//         testName: testName,
//         clientVersion: clientVersionStr,
//         daemonVersion: daemonVersionStr,
//         status: TestStatus.passed,
//         exitCode: exitCode,
//       );
//       printTestResult(testResult: result, extra: extra);
//       if(context.alwaysOutputLogs) {
//         printAllLogsFromFiles(
//           clientStdoutFile: stdoutLogFile,
//           clientStderrFile: stderrLogFile,
//           daemonLogCapture: daemonLogCapture,
//         );
//       }
//       testResults.add(result);
//     } else {
//       final CoreTestResult result = CoreTestResult(
//         testName: testName,
//         clientVersion: clientVersionStr,
//         daemonVersion: daemonVersionStr,
//         status: TestStatus.failed,
//         exitCode: exitCode == 0 ? 1 : exitCode,
//         stdout: StringBuffer(stdout),
//         stderr: StringBuffer(stderr),
//       );
//       printTestResult(testResult: result, extra: extra);
//       printAllLogsFromFiles(
//         clientStdoutFile: stdoutLogFile,
//         clientStderrFile: stderrLogFile,
//         daemonLogCapture: daemonLogCapture,
//       );
//       testResults.add(result);
//     }
//   }
//
//   return testResults;
// }
//
// List<String> _buildSshnpArgs({
//   required CoreTestsContext context,
//   required NoPortsVersion clientVersion,
//   required Language daemonLanguage,
//   required String deviceName,
// }) {
//   final List<String> args = [
//     '-f', context.clientAtsign,
//     '-t', context.daemonAtsign,
//     '-d', deviceName,
//     '-h', context.relayAtsign,
//     '-u', context.remoteUsername,
//     '--root-domain', context.rootDomain,
//     '-s',
//     '--ssh-client', 'dart',
//   ];
//
//   // C daemon requires -x flag
//   if(daemonLanguage == Language.c) {
//     args.add('-x');
//   }
//
//   if(versionIsAtLeast(clientVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
//     args.add('-k');
//     args.add(context.apkamKeys[context.clientAtsign]!.path);
//   }
//
//   return args;
// }
//
// // Generate version combinations:
// // - Released client with current daemon
// // - Current client with released daemon
// // Skip: released client with released daemon (already tested)
// List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
//   required final List<NoPortsVersion> clientVersions,
//   required final List<NoPortsVersion> daemonVersions,
// }) {
//   List<(NoPortsVersion, NoPortsVersion)> combinations = [];
//   for(final clientVersion in clientVersions) {
//     for(final daemonVersion in daemonVersions) {
//       final bool isClientCurrent = clientVersion.version == 'current';
//       final bool isDaemonCurrent = daemonVersion.version == 'current';
//
//       // Skip if both are not current
//       if(!isClientCurrent && !isDaemonCurrent) {
//         continue;
//       }
//
//       combinations.add((clientVersion, daemonVersion));
//     }
//   }
//   return combinations;
// }
