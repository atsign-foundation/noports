import 'dart:async';
import 'dart:io';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:e2e_all_v2/core_test_cases.dart';
import 'package:e2e_all_v2/docker_manager.dart';
import 'package:e2e_all_v2/params.dart';


Future<void> main(List<String> args) async {
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
  _logLoadedParameters(e2eAllV2Params);

  // Get git commit ID (shortened) as testRunId
  final ProcessResult gitResult = await Process.run('git', ['rev-parse', '--short', 'HEAD']);
  if (gitResult.exitCode != 0) {
    print('Error: Failed to get git commit ID');
    print('stderr: ${gitResult.stderr}');
    exit(1);
  }
  final String testRunId = gitResult.stdout.toString().trim();
  print('Test run ID (git commit): $testRunId');

  // Copy APKAM keys from e2e_all to ~/.atsign/keys/
  print('');
  print('========== Copying APKAM keys from e2e_all ==========');
  final String e2eAllApkamKeysDir = 'e2e_all/$testRunId/apkamKeys';
  final Directory e2eAllApkamKeysDirectory = Directory(e2eAllApkamKeysDir);
  final Directory atSignKeysDirectory = Directory('${getHomeDirectory()}/.atsign/keys/');

  if (e2eAllApkamKeysDirectory.existsSync()) {
    print('Found e2e_all APKAM keys at: ${e2eAllApkamKeysDirectory.path}');
    print('Copying to: ${atSignKeysDirectory.path}');

    final List<FileSystemEntity> apkamKeyFiles = e2eAllApkamKeysDirectory.listSync();
    int copiedCount = 0;
    for (final FileSystemEntity file in apkamKeyFiles) {
      if (file is File) {
        final String fileName = file.path.split('/').last;
        final String destinationPath = '${atSignKeysDirectory.path}/$fileName';
        print('  Copying: $fileName');
        await file.copy(destinationPath);
        copiedCount++;
      }
    }
    print('Successfully copied $copiedCount APKAM key files');
    print('');
    print('Contents of ~/.atsign/keys/:');
    final List<FileSystemEntity> keysFiles = atSignKeysDirectory.listSync();
    for (final FileSystemEntity file in keysFiles) {
      if (file is File) {
        final String fileName = file.path.split('/').last;
        print('  - $fileName');
      }
    }
  } else {
    print('Warning: e2e_all APKAM keys directory not found at: ${e2eAllApkamKeysDirectory.path}');
    print('This might be expected if e2e_all hasn\'t run yet or failed');
  }
  print('========== End Copying APKAM keys ==========');
  print('');

  // Create directory structure: e2e_all/$testRunId/{binaries,logs,apkamKeys}
  final String baseDirectory = 'e2e_all_v2/$testRunId';
  final String logDirectory = '$baseDirectory/logs';

  final int exitCode = await runCoreTestCases(
    testRunId: testRunId,
    logDirectory: logDirectory,
    clientAtsign: e2eAllV2Params.clientAtsign,
    daemonAtsign: e2eAllV2Params.daemonAtsign,
    relayAtsign: e2eAllV2Params.relayAtsign,
    atKeysVolumeMapping: VolumeMapping(
      localDirectory: Directory('${getHomeDirectory()}/.atsign/keys/'),
      containerDirectory: Directory('/atsign/.atsign/keys/'),
    ),
    atDirectoryHost: e2eAllV2Params.rootDomain,
  );

  exit(exitCode);
}

void test_minus_r_flag() {
}

void test_minus_u_flag() {
}

void npt_to_port_22() {
}

void npt_to_port_22_no_encrypt_traffic() {
}

Future<int> v4_dart_inline() async {
  // Generate unique test run ID
  final String testRunId = DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(0, 6);
  print('Test run ID: $testRunId');

  // Set up log directory
  final Directory logDirectory = Directory('logs');
  if (!logDirectory.existsSync()) {
    logDirectory.createSync(recursive: true);
    print('Created log directory: ${logDirectory.path}');
  }

  const List<String> clientVersions = [
    'd:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];
  const List<String> daemonVersions = [
    'd:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];
  List<(String, String)> testCases = [];
  for(final String clientVersion in clientVersions) {
    for(final String daemonVersion in daemonVersions) {
      if(!clientVersion.contains('d:current') && !daemonVersion.contains('d:current')) {
        continue;
      }
      testCases.add((clientVersion, daemonVersion));
    }
  }
  print(testCases);

  List<DockerImage> builtDockerImages = [];
  List<DockerImage> failedDockerImages = [];

  for(final (String, String) testCase in testCases) {
    final String clientVersion = testCase.$1;
    final String daemonVersion = testCase.$2;

    Language language;
    final List<String> daemonVersionSplit = daemonVersion.split(':');
    if(daemonVersionSplit.length != 2) {
      print('daemonVersionSplit was expected to be length == 2');
      return 1;
    }
    switch(daemonVersionSplit[0]) {
      case('d'): {
        language = Language.dart;
        break;
      }
      case('c'): {
        language = Language.c;
        break;
      }
      default: {
        print('Could not parse language: ${daemonVersionSplit[0]}');
        return 1;
      }
    }

    final String value = daemonVersionSplit[1];

    DockerImage dockerImage;
    if(value.startsWith('v')) {
      dockerImage = DockerImage.release(language: language, version: value);
    } else if (value == 'current') {
      dockerImage = DockerImage.current(language: language);
    } else {
      dockerImage = DockerImage.branch(language: language, branch: value);
    }
    final bool existsOnMachine = await dockerImage.existsOnMachine();
    if(!existsOnMachine) {
      final Process tryPullProcess = await dockerImage.pull(logDirectory: logDirectory.path);
      final int tryPullProcessExitCode = await tryPullProcess.exitCode;
      if(tryPullProcessExitCode != 0) {
        // we need to build it
        print('Attempted to pull ${dockerImage.fullImageName} but was not found. Building it locally...');
        final Process buildProcess = await dockerImage.build(
          forceOverwriteCache: false,
          quiet: false,
          logDirectory: logDirectory.path);
        final int buildExitCode = await buildProcess.exitCode;
        print('Built ${dockerImage.fullImageName}: $buildExitCode');
        if (buildExitCode == 0) {
          builtDockerImages.add(dockerImage);
        } else {
          failedDockerImages.add(dockerImage);
        }
      } else {
        print('Pulled ${dockerImage.fullImageName} successfully');
        builtDockerImages.add(dockerImage);
      }
    } else {
      print('${dockerImage.fullImageName} was already found on the machine, skipping pull/build');
      builtDockerImages.add(dockerImage);
    }
  }

  print('Built DockerImages: ${builtDockerImages.length}');
  print('Failed Docker Images: ${failedDockerImages.length}');

  List<DockerInstance> dockerInstances = [];

  for(final DockerImage dockerImage in builtDockerImages) {
    final DockerInstance dockerInstance = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
    );
    await dockerInstance.run(
      quiet: false,
      removeWhenStopped: true,
      logDirectory: logDirectory.path,
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && sshnpd -a @device_jttest -m @client_jttest -s -v'
        ],
      volumeMappings: [VolumeMapping(
        localDirectory: Directory('${getHomeDirectory()}/.atsign/keys/'),
        containerDirectory: Directory('/atsign/.atsign/keys/'),
      )],
    );
    dockerInstances.add(dockerInstance);
  }

  for(final DockerInstance dockerInstance in dockerInstances) {
    await dockerInstance.process!.exitCode;
  }

  return 0;
}

void _logLoadedParameters(E2EAllV2Params e2eAllV2Params) {
  print('e2e_all_v2 Loaded Parameters:');
  print('  help: ${e2eAllV2Params.help}');
  print('  client-atsign: ${e2eAllV2Params.clientAtsign}');
  print('  daemon-atsign: ${e2eAllV2Params.daemonAtsign}');
  print('  relay-atsign: ${e2eAllV2Params.relayAtsign}');
  print('  policy-atsign: ${e2eAllV2Params.policyAtsign}');
  print('  events-atsign: ${e2eAllV2Params.eventsAtsign}');
  print('  root-domain: ${e2eAllV2Params.rootDomain}');
  print('  verbose: ${e2eAllV2Params.verbose}');
}
