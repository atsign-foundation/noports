import 'dart:io';
import 'dart:async';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:e2e_all_v2/test_result.dart';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/e2e_all_v2_params.dart';
import 'package:e2e_all_v2/apkam_setup.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/utils.dart';

Future<void> main(List<String> args) async {

  // 1. parse args
  E2EAllV2Params e2eAllV2Params;
  try {
    e2eAllV2Params = E2EAllV2Params.parse(args);
    if(e2eAllV2Params.help) {
      E2EAllV2Params.printUsage();
      exit(1);
    }
  } catch(e) {
    E2EAllV2Params.printUsage();
    exit(1);
  }
  print('');
  _printLoadedParameters(e2eAllV2Params);
  print('');

  // 2. declare const variables
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

  try {
    // 3. $testRunId = git rev-parse --short HEAD (shortened git commit hash)
    final String testRunId = await getShortenedGitCommitHash();
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

    List<TestResult> allTestResults = [];

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
      )));
    

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
Future<List<TestResult>> _001_minus_s_flag({
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String relayAtsign,
  required final String rootDomain,
  required final String remoteUsername,
  required final List<String> daemonVersions,
  required final String testRunId,
  required final List<ClientBinary> allClientBinaries,
  required final List<(String, DockerInstance)> dockerInstances,
}) async {
  List<TestResult> testResults = [];
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

    // Construct args
    List<String> args = [
        '-f', clientAtsign, '-t', daemonAtsign,
        '-i', identityFile.path, '-d', deviceNameNoFlags,
        '-h', relayAtsign, '-u', remoteUsername,
        '--root-domain', rootDomain,
    ];
    if(language == Language.c) {
      // if we're running against the C daemon,
      // only add -x
      args.add('-x');
    } else if(versionIsAtLeast(version, 'v5.0.0') {
      // if the client we're running as is at least v5.0.0
      // and we're connecting to another Dart daemon,
      // add -x, --no-ad, and --no-et
      args.add('-x');
      args.add('--no-ad');
      args.add('--no-et');
    }

    currentSshnpClientBinary.execute(
      args: args,
    );
  
    // 3. Run sshnp against daemon with flags, expect pass
    final String deviceNameWithFlags = '${deviceNameNoFlags}_f';
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

void _printLoadedParameters(E2EAllV2Params e2eAllV2Params) {
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
