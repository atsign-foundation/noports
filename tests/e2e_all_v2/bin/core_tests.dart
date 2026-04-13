import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:e2e_all_v2/core_tests/client_binary_utils.dart';
import 'package:e2e_all_v2/core_tests/core_test_result.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/test_result.dart';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/core_tests/core_tests_params.dart';
import 'package:e2e_all_v2/core_tests/apkam_setup.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/utils.dart';

Future<void> main(List<String> args) async {
  // 1. declare const variables
  const List<String> clientVersions = [
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
    'd:current',
  ];

  const List<String> daemonVersions = [
    'd:current',
    'c:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];

  // 2. parse args
  CoreTestsParams e2eAllV2Params;
  try {
    e2eAllV2Params = CoreTestsParams.parse(args);
    if(e2eAllV2Params.help) {
      CoreTestsParams.printUsage();
      exit(1);
    }
  } catch(e) {
    CoreTestsParams.printUsage();
    exit(1);
  }
  print('');
  _printLoadedParameters(e2eAllV2Params);
  print('');

  try {
    // 3. $testRunId = git rev-parse --short HEAD (shortened git commit hash)
    final String testRunId = await _getShortenedGitCommitHash();
    print('\ntestRunId: $testRunId\n');

    // 4. create directory structure: 
    //  ./e2e_all_v2/$testRunId/
    //    ├── apkamKeys/
    //    ├── logs/
    //    └── binaries/
    //            v5.9.4/
    //            v5.11.2/
    //            v5.13.0/
    //            current/
    final Directory baseDirectory = Directory('${e2eAllV2Params.baseDirectory}/$testRunId');
    ensureDirectoryExists(baseDirectory);

    final Directory apkamKeysDirectory = Directory('${baseDirectory.path}/apkamKeys');
    final Directory logsDirectory = Directory('${baseDirectory.path}/logs');
    final Directory binariesDirectory = Directory('${baseDirectory.path}/binaries');
    ensureDirectoryExists(apkamKeysDirectory);
    ensureDirectoryExists(logsDirectory);
    ensureDirectoryExists(binariesDirectory);

    // 5. download client binaries
    List<(Language, String, ClientBinaryType)> clientBinaryTuples = [];
    clientVersions.forEach((languageVersionStr) {
      final Language language = getLanguage(languageVersionStr);
      final String version = getVersionStr(languageVersionStr);
      clientBinaryTuples.add((language, version, ClientBinaryType.sshnp));
      clientBinaryTuples.add((language, version, ClientBinaryType.srv));
      clientBinaryTuples.add((language, version, ClientBinaryType.npt));
    });
    clientBinaryTuples.add((Language.dart, 'current', ClientBinaryType.at_activate));

    print('Fetching ${clientBinaryTuples.length} client binaries...');
    List<ClientBinary> clientBinaries = await fetchClientBinaries(
      clientBinaryTuples: clientBinaryTuples, 
      binariesDirectory: binariesDirectory);

    print('');
    print('Fetched client binaries (${clientBinaries.length}):');
    for(final ClientBinary clientBinary in clientBinaries) {
      print('    ${clientBinary.binaryType.name} | ${clientBinary.language.name} | ${clientBinary.version} | ${clientBinary.file.path}');
    }
    print('');

    // 6. set up client and daemon apkam keys
    final ClientBinary atActivateClientBinary = clientBinaries.firstWhere((cb) => cb.binaryType == ClientBinaryType.at_activate && cb.version == 'current');
    Map<String, File> apkamKeys = await setUpApkamKeys(
      atActivateClientBinary: atActivateClientBinary,
      clientAtsign: e2eAllV2Params.clientAtsign,
      daemonAtsign: e2eAllV2Params.daemonAtsign,
      rootDomain: e2eAllV2Params.rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId
    );

    // 7. set up docker daemons
    final List<(String, DockerInstance)> dockerInstances = await startDockerDaemons(
      clientAtsign: e2eAllV2Params.clientAtsign,
      daemonVersions: daemonVersions,
      daemonAtsign: e2eAllV2Params.daemonAtsign,
      rootDomain: e2eAllV2Params.rootDomain,
      testRunId: testRunId,
      apkamKeysDirectory: apkamKeysDirectory,
      daemonAtsignKeyFilePath: '/atsign/.atsign/keys/${apkamKeys[e2eAllV2Params.daemonAtsign]!.path.split('/').last}');
    print('');
    print('Started ${dockerInstances.length} docker daemon instances');
    for(final (String, DockerInstance) dockerInstance in dockerInstances) {
      print('    Daemon (-d ${dockerInstance.$1}): ${dockerInstance.$2.containerName}');
    }
    print('');

    // 8. Run tests

    List<CoreTestResult> allTestResults = [];

    // a. 001_minus_s_flag
    // generate new ssh key
    
    allTestResults.addAll(
      (await _001_minus_s_flag(
        clientAtsign: e2eAllV2Params.clientAtsign,
        daemonAtsign: e2eAllV2Params.daemonAtsign,
        relayAtsign: e2eAllV2Params.relayAtsign,
        rootDomain: e2eAllV2Params.rootDomain,
        daemonVersions: daemonVersions,
        testRunId: testRunId, 
        allClientBinaries: clientBinaries,
        dockerInstances: dockerInstances,
        apkamKeys: apkamKeys,
        remoteUsername: 'atsign',
      )));


    final int totalTests = allTestResults.length;
    final int passedTests = allTestResults.where((tr) => tr.status == TestStatus.passed).length;
    final int failedTests = allTestResults.where((tr) => tr.status == TestStatus.failed).length;

    print('');
    print('Test Results Summary:');
    print('    Total tests: $totalTests');
    print('    Passed: $passedTests');
    print('    Failed: $failedTests');
    print('');

    exit(0);
  } catch (e) {
    print(e);
    exit(1);
  }
}

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
    final Language language = getLanguage(daemonVersion);
    final String version = getVersionStr(daemonVersion);
    
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

void _printLoadedParameters(CoreTestsParams e2eAllV2Params) {
  print('e2e_all_v2 Loaded Parameters:');
  print('    help: ${e2eAllV2Params.help}');
  print('    client-atsign: ${e2eAllV2Params.clientAtsign}');
  print('    daemon-atsign: ${e2eAllV2Params.daemonAtsign}');
  print('    relay-atsign: ${e2eAllV2Params.relayAtsign}');
  print('    policy-atsign: ${e2eAllV2Params.policyAtsign}');
  print('    events-atsign: ${e2eAllV2Params.eventsAtsign}');
  print('    root-domain: ${e2eAllV2Params.rootDomain}');
  print('    verbose: ${e2eAllV2Params.verbose}');
  print('    base-directory: ${e2eAllV2Params.baseDirectory}');
}

Future<String> _getShortenedGitCommitHash() async {
  final ProcessResult gitResult = await runCommand(
    'git',
    ['rev-parse', '--short', 'HEAD']);
  if (gitResult.exitCode != 0) {
    print('stderr: ${gitResult.stderr}');
    exit(1);
  }
  return gitResult.stdout.toString().trim();
}

