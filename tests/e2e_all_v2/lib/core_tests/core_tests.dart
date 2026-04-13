// 1. Generate a new ssh key
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
import 'dart:io';

import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_tests/core_test_result.dart';
import 'package:e2e_all_v2/core_tests/core_tests_utils.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';

Future<List<CoreTestResult>> _001_minus_s_flag({
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String relayAtsign,
  required final String rootDomain,
  required final String remoteUsername,
  required final List<String> daemonVersions,
  required final String testRunId,
  required final List<ClientBinary> allClientBinaries,
  required final List<(String, DockerInstance)> dockerInstances,
  required final Map<String, File> apkamKeys,
}) async {
  const String testName = '001_minus_s_flag';
  List<CoreTestResult> testResults = [];
  // 1. generate new ssh key
  final (File, File) sshKeys = await _generateNewSshKey(testRunId: testRunId);
  final File identityFile = sshKeys.$2;
  print('Generated ${sshKeys.$1.path} and ${sshKeys.$2.path}');

  final ClientBinary currentSshnpClientBinary = allClientBinaries.firstWhere((cb) => 
    cb.binaryType == ClientBinaryType.sshnp &&
    cb.version == 'current');

  for(final String daemonVersion in daemonVersions) {
    final NoPortsVersion noPortsVersion = NoPortsVersion.fromLanguageVersionString(daemonVersion);
    final Language language = noPortsVersion.language;
    final String version = noPortsVersion.version;
    
    // 2. Run sshnp against daemon without flags, expect failure
    final String deviceNameNoFlags = getDeviceNameNoFlags( 
      testRunId: testRunId,
      language: language,
      version: version);

    List<String> args = [
        '-f', clientAtsign, '-t', daemonAtsign,
        '-i', identityFile.path, '-d', deviceNameNoFlags,
        '-h', relayAtsign, '-u', remoteUsername,
        '--root-domain', rootDomain,
        '-s',
    ];
    if(language == Language.c) {
      // if we're running against the C daemon,
      // only add -x
      args.add('-x');
    } else if(versionIsAtLeast(currentSshnpClientBinary.version, 'v5.0.0')) {
      // if the client we're running as is at least v5.0.0
      // and we're connecting to another Dart daemon,
      // add -x, --no-ad, and --no-et
      args.add('-x');
      args.add('--no-ad');
      args.add('--no-et');
    }

    if(versionIsAtLeast(currentSshnpClientBinary.version, 'v5.3.0')) {
      // if the cleint we're running as it at least v5.3.0
      // add -k $clientApkamKeyFilePath
      if(!(await apkamKeys[clientAtsign]!.exists())) {
        throw Exception('Expected apkam key file for client at ${apkamKeys[clientAtsign]!.path} does not exist.');
      }
      args.add('-k');
      args.add(apkamKeys[clientAtsign]!.path);
    }

    // 3. Run sshnp against daemon without flags, expect failure
    final Process process1 = await startCommand(
      currentSshnpClientBinary.file.path,
      args,
    );

    final int exitCode = await process1.exitCode;
    if(exitCode == 0) {
      StringBuffer stdoutBuffer = StringBuffer();
      process1.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
        stdoutBuffer.writeln(line);
      });
      StringBuffer stderrBuffer = StringBuffer();
      process1.stderr.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
        stderrBuffer.writeln(line);
      });
      print('Daemon version: $daemonVersion | Client version: ${currentSshnpClientBinary.version} | Device Name: ${deviceNameNoFlags} Test Failed | exitCode=$exitCode');
      CoreTestResult tr = CoreTestResult(
        testName: '001_minus_s_flag_no_flags',
        clientVersion: currentSshnpClientBinary.version,
        daemonVersion: daemonVersion,
        status: TestStatus.failed,
        exitCode: exitCode,
        stdout: stdoutBuffer,
        stderr: stderrBuffer,
      );
      tr.printResult(printStdout: true, printStderr: false);
      testResults.add(tr);
    } else {
      CoreTestResult tr = CoreTestResult(
        testName: '001_minus_s_flag_no_flags',
        clientVersion: currentSshnpClientBinary.version,
        daemonVersion: daemonVersion,
        status: TestStatus.passed,
        exitCode: exitCode,
      );
      tr.printResult(printStdout: false, printStderr: false);
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
    if(language == Language.c) {
      // if we're running against the C daemon,
      // only add -x
      args.add('-x');
    } else if(versionIsAtLeast(currentSshnpClientBinary.version, 'v5.0.0')) {
      // if the client we're running as is at least v5.0.0
      // and we're connecting to another Dart daemon,
      // add -x, --no-ad, and --no-et
      args.add('-x');
      args.add('--no-ad');
      args.add('--no-et');
    }

    if(versionIsAtLeast(currentSshnpClientBinary.version, 'v5.3.0')) {
      // if the cleint we're running as it at least v5.3.0
      // add -k $clientApkamKeyFilePath
      if(!(await apkamKeys[clientAtsign]!.exists())) {
        throw Exception('Expected apkam key file for client at ${apkamKeys[clientAtsign]!.path} does not exist.');
      }
      args.add('-k');
      args.add(apkamKeys[clientAtsign]!.path);
    }

    final Process process2 = await startCommand(
      currentSshnpClientBinary.file.path,
      args,
    );

    final StringBuffer stdoutBuffer = StringBuffer();
    // put sshnp -x output into stdout buffer
    process2.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      stdoutBuffer.writeln(line);
    });
    final int exitCode2 = await process2.exitCode;
    if(exitCode2 == 0) {
    } else {
      print('Daemon version: $daemonVersion | Client version: ${currentSshnpClientBinary.version} | Device Name: ${deviceNameWithFlags} Test Failed | exitCode=$exitCode2');
      CoreTestResult tr = CoreTestResult(
        testName: '001_minus_s_flag',
        clientVersion: currentSshnpClientBinary.version,
        daemonVersion: daemonVersion,
        status: TestStatus.failed,
        exitCode: exitCode2,
        stdout: stdoutBuffer,
      );
      tr.printResult();
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
      CoreTestResult tr = CoreTestResult(
        testName: testName,
        clientVersion: currentSshnpClientBinary.version,
        daemonVersion: daemonVersion,
        status: TestStatus.passed,
        exitCode: sshExitCode,
      );
      tr.printResult(printStdout: false, printStderr: false);
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
      CoreTestResult tr = CoreTestResult(
        testName: testName,
        clientVersion: currentSshnpClientBinary.version,
        daemonVersion: daemonVersion,
        status: TestStatus.failed,
        exitCode: sshExitCode,
        stdout: sshStdoutBuffer,
        stderr: sshStderrBuffer,
      );
      tr.printResult(printStdout: true, printStderr: true);
      testResults.add(tr);
    }
  }

  //     b. Verify it fails
  return testResults;
}

Future<(File, File)> _generateNewSshKey({required final String testRunId}) async {
  final String? homeDirectoryPath = getHomeDirectory(throwIfNull: false);
  if(homeDirectoryPath == null) {
    throw Exception('Unable to determine home directory path for current user.');
  }
  final Directory sshDirectory = Directory(path.join(homeDirectoryPath, '.ssh'));

  // mkdir -p $HOME/.ssh
  await ensureDirectoryExists(sshDirectory);

  // chmod go-rwx $HOME/.ssh
  await runCommand(
    'chmod',
    ['go-rwx', sshDirectory.path],
  );

  // touch $authKeysFile
  await runCommand(
    'touch',
    [path.join(sshDirectory.path, 'authorized_keys')],
  );

  // chmod go-rwx $authKeysFile
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

String _getIdentitfyFilePath({required final String testRunId}) {
  final String? homeDirectoryPath = getHomeDirectory(throwIfNull: false);
  if(homeDirectoryPath == null) {
    throw Exception('Unable to determine home directory path for current user.');
  }
  return path.join(homeDirectoryPath, '.ssh', 'e2e_all_v2.${testRunId}');
}
