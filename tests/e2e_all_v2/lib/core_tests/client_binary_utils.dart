import 'dart:io';

import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/noports_version.dart';
import 'package:e2e_all_v2/os_utils.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/utils.dart';
import 'package:path/path.dart' as path;

Future<List<ClientBinary>> fetchClientBinaries({
  required final Directory binariesDirectory,
  required final List<(Language, String, ClientBinaryType)> clientBinaryTuples}) async {
  // 1. ensure binariesDirectory exists
  final bool dirExists = await ensureDirectoryExists(binariesDirectory);
  if(!dirExists) {
    throw Exception('Failed to create binaries directory: ${binariesDirectory.path}');
  }

  // 2. sort by language and version
  // e.g. 
  // 'dart': {
  //   'v5.9.4': [ClientBinaryType.sshnp, ClientBinaryType.npt, ...]
  //   'current': [ClientBinaryType.at_activate,...]
  // }
  final Map<Language, Map<String, List<ClientBinaryType>>> map = {};
  for(final (Language, String, ClientBinaryType) e in clientBinaryTuples) {
    final Language language = e.$1;
    if(language != Language.dart) {
      throw Exception('Currently only dart client binaries are supported. Found language: ${language.name}');
    }
    final String version = e.$2;
    final ClientBinaryType binaryType = e.$3;
    map.putIfAbsent(language, () => {});
    map[language]!.putIfAbsent(version, () => []);
    map[language]![version]!.add(binaryType);
  }


  // 3. fetch binaries sorted by version and language
  final List<ClientBinary> allClientBinaries = [];
  for(final Language language in map.keys) {
    final Map<String, List<ClientBinaryType>> versionMap = map[language]!;
    for(final String version in versionMap.keys) {
      final Directory dir = Directory(path.join(binariesDirectory.path, language.name, version));
      ensureDirectoryExists(dir);
      final List<ClientBinaryType> clientBinaryTypes = versionMap[version]!;
      if(version == 'current') {
        allClientBinaries.addAll(await _compileCurrent(language: language, clientBinaryTypes: clientBinaryTypes, directory: dir));
      } else if(version.startsWith('v')) {
        allClientBinaries.addAll(await _downloadRelease(language: language, version: version, clientBinaryTypes: clientBinaryTypes, directory: dir));
      } else {
        allClientBinaries.addAll(await _compileBranch(language: language, branch: version, clientBinaryTypes: clientBinaryTypes, directory: dir));
      }
    }
  }
  return allClientBinaries;
}

Future<List<ClientBinary>> _compileCurrent({
  required final Language language,
  required final List<ClientBinaryType> clientBinaryTypes,
  required final Directory directory,
}) async {
  // 1. validate funciton arguments
  // 1a. language
  if(language != Language.dart) {
    throw Exception('Currently only dart client binaries are supported. Found language: ${language.name}');
  }

  // 1b. directory
  final bool dirExists = await ensureDirectoryExists(directory);
  if(!dirExists) {
    throw Exception('Failed to create directory for compiling current binaries: ${directory.path}');
  }

  // 2. compile binaries using dart compile exe
  final List<(Process, ClientBinaryType, String)> compileProcesses = [];
  final List<ClientBinary> clientBinaries = [];
  for(final ClientBinaryType binaryType in clientBinaryTypes) {
    final String dartSourcePath = getDartSourcePath(binaryType);
    final String outputPath = path.join(directory.path, binaryType.name); // e.g. /path/to/binaries/dart/current/sshnp
    final Process compileProcess = await startCommand(
      'dart', 
      ['compile', 'exe', dartSourcePath, '-o', outputPath]);
    compileProcesses.add((compileProcess, binaryType, outputPath));
  }

  // 3. wait for processes to finish and check exit codes
  for(final (Process, ClientBinaryType, String) element in compileProcesses) {
    final Process compileProcess = element.$1;
    final ClientBinaryType binaryType = element.$2;
    final String outputPath = element.$3;
    final int exitCode = await compileProcess.exitCode;
    if(exitCode != 0) {
      print('Failed to compile ${element.$2.name}. Exit code: $exitCode');
      compileProcess.stderr.transform(SystemEncoding().decoder).listen((data) {
        print('Compile stderr: $data');
      });
      throw Exception('Failed to compile ${element.$2.name}. Exit code: $exitCode');
    }

    final File outputFile = File(outputPath);
    if(!(await outputFile.exists())) {
      throw Exception('Expected output binary not found after compilation: ${outputFile.path}');
    }
    
    clientBinaries.add(ClientBinary(
      binaryType: binaryType,
      language: Language.dart, 
      version: 'current',
      file: outputFile,
    ));
  }

  return clientBinaries;
}

Future<List<ClientBinary>> _downloadRelease({
  required final Language language,
  required final String version,
  required final List<ClientBinaryType> clientBinaryTypes,
  required final Directory directory,
}) async {
  if(language != Language.dart) {
    throw Exception('Currently only dart client binaries are supported. Found language: ${language.name}');
  }
  // 1. construct $archiveName and $downloadUrl
  final String osStr = getOsString();   
  final String archStr = getArchString();
  String archiveExt;
  switch(Platform.operatingSystem) {
    case 'windows':
    case 'macos':
      archiveExt = 'zip';
      break;
    case 'linux':
      archiveExt = 'tgz';
      break;
    default:
      throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }
  final String archiveName = 'sshnp-$osStr-$archStr.$archiveExt';
  final String downloadUrl = 'https://github.com/atsign-foundation/noports/releases/download/$version/$archiveName';

  // 2. get tgz/zip
  final ProcessResult curlProcessResult = await runCommand(
    'curl', 
    ['-L', '-o', path.join(directory.path, archiveName), downloadUrl]);
  if(curlProcessResult.exitCode != 0) {
    throw Exception('Failed to download archive from $downloadUrl: ${curlProcessResult.stderr}');
  }

  // 3. create temporary extraction directory: $directory/temp_extract/
  final Directory tempExtractDir = Directory(path.join(directory.path, 'temp_extract'));
  ensureDirectoryExists(tempExtractDir);

  // 4. extract archive to temporary directory
  ProcessResult extractResult;
  switch(Platform.operatingSystem) {
    case 'linux':
      extractResult = await runCommand(
        'tar',
        ['-xzf', path.join(directory.path, archiveName), '-C', tempExtractDir.path],
      );
      break;
    case 'windows':
      extractResult = await runCommand(
        'powershell',
        ['-Command', 'Expand-Archive', '-Path', path.join(directory.path, archiveName), '-DestinationPath', tempExtractDir.path],
      );
      break;
    case 'macos':
      extractResult = await runCommand(
        'unzip',
        ['-q', path.join(directory.path, archiveName), '-d', tempExtractDir.path],
      );
      break;
    default:
      throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }

  if(extractResult.exitCode != 0) {
    throw Exception('Failed to extract archive: ${extractResult.stderr}');
  }

  final List<ClientBinary> clientBinaries = [];

  // 5. move binaries from temporary extraction directory to final location: $directory/{binaryType}/
  for(final ClientBinaryType binaryType in clientBinaryTypes) {
    final String binaryName = binaryType.name;
    final File extractedBinary = File(path.join(tempExtractDir.path, 'sshnp', binaryName));
    if(!(await extractedBinary.exists())) {
      throw Exception('Expected binary not found in extracted archive: ${extractedBinary.path}');
    }
    final String finalBinaryPath = path.join(directory.path, binaryName);
    final File binary = await extractedBinary.copy(finalBinaryPath);
    if(!(await binary.exists())) {
      throw Exception('Failed to move binary to final location: ${binary.path}');
    } 
    clientBinaries.add(ClientBinary(
        binaryType: binaryType,
        language: language,
        version: version,
        file: binary,
    ));
  }

  // 6. clean up temporary extraction directory and archive
  try {
    await tempExtractDir.delete(recursive: true);
    await File(path.join(directory.path, archiveName)).delete();
  } catch (e) {
    print('Warning: Failed to clean up temporary files: $e');
  }
  return clientBinaries;
}

Future<List<ClientBinary>> _compileBranch({
  required final Language language,
  required final String branch,
  required final List<ClientBinaryType> clientBinaryTypes,
  required final Directory directory,
}) async {
  throw Exception('Compiling from branch is not yet implemented. Found branch: $branch');
}

bool isCommandAvailable(String command) {
  try {
    final ProcessResult result = Process.runSync(
      Platform.isWindows ? 'where' : 'which',
      [command],
    );
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

Future<List<(String, DockerInstance)>> startDockerDaemons({
  required final List<String> daemonVersions,
  required final String clientAtsign,
  required final String daemonAtsign,
  required final String daemonAtsignKeyFilePath,
  required final String rootDomain,
  required final String testRunId,
  required final Directory apkamKeysDirectory,
}) async {
  final List<DockerImage> dockerImages = [];
  for(final String daemonVersion in daemonVersions) {
    final NoPortsVersion noPortsVersion = NoPortsVersion.fromLanguageVersionString(daemonVersion);
    final Language language = noPortsVersion.language;
    final String version = noPortsVersion.version;
    
    DockerImage dockerImage;
    if(version == 'current') {
      dockerImage = DockerImage.current(language: language); 
    } else if(version.startsWith('v')) {
      dockerImage = DockerImage.release(language: language, version: version);
    } else {
      dockerImage = DockerImage.branch(language: language, branch: version);
    }
    dockerImages.add(dockerImage);
  }

  // ensure all docker images exist on machine
  for(final DockerImage dockerImage in dockerImages) {
    if(!(await dockerImage.existsOnMachine())) {
      print('Docker image not found on machine: ${dockerImage.fullImageName}. Pulling from registry...');
      final Process pullProcess = await dockerImage.pull(quiet: true);
      if((await pullProcess.exitCode) != 0) {
        print('Failed to pull docker image ${dockerImage.fullImageName}. Exit code: ${await pullProcess.exitCode}');
        print('Building instead...');
        final Process buildProcess = await dockerImage.build(quiet: true);
        if((await buildProcess.exitCode) != 0) {
          throw Exception('Failed to build docker image ${dockerImage.fullImageName}. Exit code: ${await buildProcess.exitCode}');
        }
      }
    } else {
      print('Docker image already exists on machine: ${dockerImage.fullImageName}');
    }
  }

  final List<(String, DockerInstance)> dockerInstances = [];
  for(final DockerImage dockerImage in dockerImages) {
    final DockerInstance dockerInstance1 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
    );
    final String deviceName1 = getDeviceNameNoFlags(testRunId: testRunId,
      language: dockerInstance1.dockerImage.language,
      version: dockerInstance1.dockerImage.tag);
    await dockerInstance1.run(
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && '
        '/usr/local/bin/sshnpd '
        '-a ${daemonAtsign} '
        '-m ${clientAtsign} '
        '-k ${daemonAtsignKeyFilePath} '
        '--root-domain ${rootDomain} '
        '-d ${deviceName1} '
        '-v '
      ],
      quiet: false,
      removeWhenStopped: true,
      volumeMappings: [
        VolumeMapping(
          localDirectory: apkamKeysDirectory,
          containerDirectory: '/atsign/.atsign/keys',
        ),
      ],
    );
    dockerInstances.add((deviceName1, dockerInstance1));
    final DockerInstance dockerInstance2 = DockerInstance(
      dockerImage: dockerImage,
      testRunId: testRunId,
      uniqueIdentifier: '_f',
    );
    final String deviceName2 = '${deviceName1}_f';
    await dockerInstance2.run(
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && '
        '/usr/local/bin/sshnpd '
        '-a ${daemonAtsign} '
        '-m ${clientAtsign} '
        '-k ${daemonAtsignKeyFilePath} '
        '--root-domain ${rootDomain} '
        '-d ${deviceName2} '
        '-v -s -u'
      ],
      quiet: false,
      removeWhenStopped: true,
      volumeMappings: [
        VolumeMapping(
          localDirectory: apkamKeysDirectory,
          containerDirectory: '/atsign/.atsign/keys',
        ),
      ],
    ); 
    dockerInstances.add((deviceName2, dockerInstance2));
  }
  return dockerInstances;
}
