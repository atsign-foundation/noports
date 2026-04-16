import 'dart:convert';
import 'dart:io';

import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/core_tests_test_result.dart';
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/print_test_utils.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/test_result.dart';
import 'package:path/path.dart' as path;
import 'package:at_cli_commons/at_cli_commons.dart';

// Test: 001_minus_s_flag
// 1. Generate a new SSH key
// 2.
//     a. Run sshnp against a dameon without the `-s` flag with that new key
//     b. Verify it fails
// 3.
//     a. Run against a daemon with the `-s` flag
//     b. Verify it succeeds
// - Client: Dart (current) | Daemon: Dart (current)
// - Client: Dart (current) | Daemon: C (current)
// - Client: Dart (current) | Daemon: Dart v5.9.4
// - Client: Dart (current) | Daemon: Dart v5.11.2
// - Client: Dart (current) | Daemon: Dart v5.13.0
Future<List<CoreTestResult>> run001MinusSFlagTests({
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String relayAtsign,
  required final String rootDomain,
  required final String remoteUsername,
  required final List<NoPortsVersion> daemonVersions,
  required final String testRunId,
  required final List<ClientBinary> allClientBinaries,
  required final List<(String, DockerInstance)> dockerInstances,
  required final Map<String, File> apkamKeys,
}) async {
  const String testName = '001_minus_s_flag';
  final List<CoreTestResult> testResults = [];

  // 1. generate new ssh key
  final (File, File) sshKeys = await _generateNewSshKey(testRunId: testRunId);
  final File identityFile = sshKeys.$2;
  print('Generated ${sshKeys.$1.path} and ${sshKeys.$2.path}');

  final ClientBinary currentSshnpClientBinary = allClientBinaries.firstWhere((cb) =>
    cb.binaryType == ClientBinaryType.sshnp &&
    cb.noPortsVersion.version == 'current');
  final String clientVersionStr = currentSshnpClientBinary.noPortsVersion.version;

  for(final NoPortsVersion daemonVersion in daemonVersions) {
    final Language daemonLanguage = daemonVersion.language;
    final String daemonVersionStr = daemonVersion.version;
    final String extra = '(client: ${clientVersionStr}, daemon : $daemonVersionStr)';

    // 2. Run sshnp against daemon without flags, expect failure
    final String deviceNameNoFlags = getDeviceNameNoFlags(
      testRunId: testRunId,
      language: daemonLanguage,
      version: daemonVersionStr);

    List<String> args = [
        '-f', clientAtsign, '-t', daemonAtsign,
        '-i', identityFile.path, '-d', deviceNameNoFlags,
        '-h', relayAtsign, '-u', remoteUsername,
        '--root-domain', rootDomain,
        '-s',
    ];
    if(daemonLanguage == Language.c) {
      // if we're running against the C daemon,
      // only add -x
      args.add('-x');
    } else if(versionIsAtLeast(currentSshnpClientBinary.noPortsVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
      // if the client we're running as is at least v5.0.0
      // and we're connecting to another Dart daemon,
      // add -x, --no-ad, and --no-et
      args.add('-x');
      args.add('--no-ad');
      args.add('--no-et');
    }

    if(versionIsAtLeast(currentSshnpClientBinary.noPortsVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
      // if the cleint we're running as it at least v5.3.0
      // add -k $clientApkamKeyFilePath
      if(!(await apkamKeys[clientAtsign]!.exists())) {
        throw Exception('Expected apkam key file for client at ${apkamKeys[clientAtsign]!.path} does not exist.');
      }
      args.add('-k');
      args.add(apkamKeys[clientAtsign]!.path);
    }

    // 3. Run sshnp against daemon without flags, expect failure
    printTestStart(testName: testName, extra: extra);
    final Process process1 = await startCommand(
      currentSshnpClientBinary.file.path,
      args,
    );
    final int exitCode = await process1.exitCode;
    if(exitCode == 0) {
      final StringBuffer stdoutBuffer = StringBuffer();
      final StringBuffer stderrBuffer = StringBuffer();
      process1.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
        stdoutBuffer.writeln(line);
      });
      process1.stderr.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
        stderrBuffer.writeln(line);
      });
      print('Daemon version: $daemonVersionStr | Client version: ${currentSshnpClientBinary.noPortsVersion.version} | Device Name: ${deviceNameNoFlags} Test Failed | exitCode=$exitCode');
      CoreTestResult tr = CoreTestResult(
        testName: testName,
        clientVersion: currentSshnpClientBinary.noPortsVersion.version,
        daemonVersion: daemonVersionStr,
        status: TestStatus.failed,
        exitCode: exitCode,
        stdout: stdoutBuffer,
        stderr: stderrBuffer,
      );
      printTestResult(testResult: tr, extra: extra);
      print(stderrBuffer.toString());
      testResults.add(tr);
    } else {
      CoreTestResult tr = CoreTestResult(
        testName: testName,
        clientVersion: currentSshnpClientBinary.noPortsVersion.version,
        daemonVersion: daemonVersionStr,
        status: TestStatus.passed,
        exitCode: exitCode,
      );
      printTestResult(testResult: tr, extra: extra);
      testResults.add(tr);
    }

    // 4. Run sshnp against daemon with flags, expect success
    final String deviceNameWithFlags = '${deviceNameNoFlags}_f';

    // TODO: Make this args thing a helper function
    args = [
        '-f', clientAtsign, '-t', daemonAtsign,
        '-i', identityFile.path, '-d', deviceNameWithFlags,
        '-h', relayAtsign, '-u', remoteUsername,
        '--root-domain', rootDomain,
        '-s',
    ];
    if(daemonLanguage == Language.c) {
      // if we're running against the C daemon,
      // only add -x
      args.add('-x');
    } else if(versionIsAtLeast(currentSshnpClientBinary.noPortsVersion, NoPortsVersion(language: Language.dart, version: 'v5.0.0'))) {
      // if the client we're running as is at least v5.0.0
      // and we're connecting to another Dart daemon,
      // add -x, --no-ad, and --no-et
      args.add('-x');
      args.add('--no-ad');
      args.add('--no-et');
    }

    if(versionIsAtLeast(currentSshnpClientBinary.noPortsVersion, NoPortsVersion(language: Language.dart, version: 'v5.3.0'))) {
      // if the cleint we're running as it at least v5.3.0
      // add -k $clientApkamKeyFilePath
      if(!(await apkamKeys[clientAtsign]!.exists())) {
        throw Exception('Expected apkam key file for client at ${apkamKeys[clientAtsign]!.path} does not exist.');
      }
      args.add('-k');
      args.add(apkamKeys[clientAtsign]!.path);
    }

    printTestStart(testName: testName, extra: extra);
    final Process process2 = await startCommand(
      currentSshnpClientBinary.file.path,
      args,
    );

    final StringBuffer stdoutBuffer = StringBuffer();
    final StringBuffer stderrBuffer = StringBuffer(); 
    // put sshnp -x output into stdout buffer
    process2.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      stdoutBuffer.writeln(line);
    });
    process2.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      stderrBuffer.writeln(line);
    });
    final int exitCode2 = await process2.exitCode;
    if(exitCode2 == 0) {
    } else {
      print('Daemon version: $daemonVersionStr | Client version: ${clientVersionStr} | Device Name: ${deviceNameWithFlags} Test Failed | exitCode=$exitCode2');
      final CoreTestResult tr = CoreTestResult(
        testName: testName,
        clientVersion: clientVersionStr,
        daemonVersion: daemonVersionStr,
        status: TestStatus.failed,
        exitCode: exitCode2,
        stdout: stdoutBuffer,
      );
      printTestResult(testResult: tr, extra: extra);
      print(stderrBuffer.toString());
      testResults.add(tr);
    }

    String sshCommand = stdoutBuffer.toString().trim();
    // remove ssh part
    if(sshCommand.startsWith('ssh ')) {
      sshCommand = sshCommand.substring(4);
    } else {
      throw Exception('Expected stdout from sshnp to start with "ssh ". Actual output: "$sshCommand"');
    }
    List<String> sshCommandArgs = sshCommand.split(' ');
    sshCommandArgs.add('echo');
    sshCommandArgs.add('`date`');
    sshCommandArgs.add('`whoami`');
    sshCommandArgs.add('`hostname`');
    sshCommandArgs.add('TEST PASSED');

    final Process sshProcess = await startCommand(
      'ssh',
      sshCommandArgs,
    );
    final int sshExitCode = await sshProcess.exitCode;
    if(sshExitCode == 0) {
      // TODO read stdout for 'TEST PASSED'
      final String clientVersion = currentSshnpClientBinary.noPortsVersion.version;
      final CoreTestResult tr = CoreTestResult(
        testName: testName,
        clientVersion: clientVersion,
        daemonVersion: daemonVersionStr,
        status: TestStatus.passed,
        exitCode: sshExitCode,
      );
      printTestResult(testResult: tr, extra: extra);
      testResults.add(tr);
    } else {
      final StringBuffer sshStdoutBuffer = StringBuffer();
      sshProcess.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
        sshStdoutBuffer.writeln(line);
      });
      final StringBuffer sshStderrBuffer = StringBuffer();
      sshProcess.stderr.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
        sshStderrBuffer.writeln(line);
      });
      final CoreTestResult tr = CoreTestResult(
        testName: testName,
        clientVersion: currentSshnpClientBinary.noPortsVersion.version,
        daemonVersion: daemonVersionStr,
        status: TestStatus.failed,
        exitCode: sshExitCode,
        stdout: sshStdoutBuffer,
        stderr: sshStderrBuffer,
      );
      printTestResult(testResult: tr, extra: extra);
      testResults.add(tr);
    }
  }

  return testResults;
}

String _getIdentitfyFilePath({required final String testRunId}) {
  final String? homeDirectoryPath = getHomeDirectory(throwIfNull: false);
  if(homeDirectoryPath == null) {
    throw Exception('Unable to determine home directory path for current user.');
  }
  return path.join(homeDirectoryPath, '.ssh', 'e2e_all_v2.${testRunId}');
}

Future<(File, File)> _generateNewSshKey({required final String testRunId}) async {
  final String? homeDirectoryPath = getHomeDirectory(throwIfNull: false);
  if(homeDirectoryPath == null) {
    throw Exception('Unable to determine home directory path for current user.');
  }

  final Directory sshDirectory = Directory(path.join(homeDirectoryPath, '.ssh'));
  if(!(await sshDirectory.exists())) {
    throw Exception('SSH directory does not exist: ${sshDirectory.path}');
  }

  // Change the permissions of the authorized_keys file so that we can add public keys to it
  await runCommand(
    'chmod',
    ['go-rwx', path.join(sshDirectory.path, 'authorized_keys')],
  );

  // ssh-keygen -t ed25519 -q -N '' -f $identityFileName -C $testRunId <<<y >/dev/null 2>&1
  final String identityFilePath = _getIdentitfyFilePath(testRunId: testRunId);
  await runCommand(
    'ssh-keygen',
    [
      '-t', 'ed25519',
      '-q',
      '-N', '',
      '-f', identityFilePath,
      '-C', testRunId,
    ],
  );

  final File identityFile = File(identityFilePath);
  final File publicIdentityFile = File('$identityFilePath.pub');
  if(!(await identityFile.exists()) || !(await publicIdentityFile.exists())) {
    throw Exception('Failed to generate ssh key pair. Expected files not found: $identityFilePath and ${publicIdentityFile.path}');
  }
  return (publicIdentityFile, identityFile);
}
