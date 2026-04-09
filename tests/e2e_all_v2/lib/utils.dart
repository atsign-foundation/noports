import 'dart:io';
import 'package:e2e_all_v2/apkam_setup.dart';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

Future<ProcessResult> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  printCommand = false,
  dynamic stdinData,
}) async {
  print('> $executable ${arguments.join(' ')}');
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printCommand) {
    print('stdout:\n\t${result.stdout}');
    print('stderr:\n\t${result.stderr}');
  }
  return result;
}

Future<Process> startCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool printCommand = false,
}) async {
  print('> $executable ${arguments.join(' ')}');
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printCommand) {
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      print('$data');
    });
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      print('$data');
    });
  }
  return process;
}

String versionForDeviceName(final String version) {
  if(version == 'current') {
    return 'c';
  }
  // v5.9.4 -> 594
  // c0.0.1 --> 001
  return version.replaceAll('.', '').replaceAll('v', '').replaceAll('c', '');
}

String getDeviceNameNoFlags({
  required final String testRunId,
  required final Language language,
  required final String version}) {
  return '${testRunId}${language.name.substring(0, 1)}${versionForDeviceName(version)}';
}

String getOsString() {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  if (Platform.isWindows) return 'windows';
  throw Exception('Unsupported platform: ${Platform.operatingSystem}');
}

String getArchString() {
  final String arch = Platform.version.contains('x64') ? 'x64' : 'arm64';
  return arch;
}

Directory joinPath(
  final String part1, {
  final String? part2,
  final String? part3,
  final String? part4,
  final String? part5,
  final String? part6,
  final String? part7,
  final String? part8,
  final String? part9,
  final String? part10,
  final String? part11,
}) {
  final List<String> parts = [part1];
  if (part2 != null) parts.add(part2);
  if (part3 != null) parts.add(part3);
  if (part4 != null) parts.add(part4);
  if (part5 != null) parts.add(part5);
  if (part6 != null) parts.add(part6);
  if (part7 != null) parts.add(part7);
  if (part8 != null) parts.add(part8);
  if (part9 != null) parts.add(part9);
  if (part10 != null) parts.add(part10);
  if (part11 != null) parts.add(part11);
  return Directory(path.joinAll(parts));
}

Future<String> getShortenedGitCommitHash() async {
  final ProcessResult gitResult = await runCommand(
    'git',
    ['rev-parse', '--short', 'HEAD']);
  if (gitResult.exitCode != 0) {
    print('stderr: ${gitResult.stderr}');
    exit(1);
  }
  return gitResult.stdout.toString().trim();
}

Future<bool> ensureDirectoryExists(final Directory directory) async {
  if (await directory.exists()) {
    return true;
  }
  try {
    await directory.create(recursive: true);
    return true;
  } catch (e) {
    throw Exception('Failed to create directory ${directory.path}: $e');
  }
}

Language getLanguage(final String languageVersionStr) {
  final List<String> split = languageVersionStr.split(':');
  if (split.length != 2) {
    throw Exception('Invalid language version format: $languageVersionStr'); 
  }
  final String languageStr = split[0];
  if (languageStr == 'd') {
    return Language.dart;
  } else if (languageStr == 'c') {
    return Language.c;
  } else {
    throw Exception('Unsupported language: $languageStr');
  }
}

String getVersionStr(final String languageVersionStr) {
  final List<String> split = languageVersionStr.split(':');
  if (split.length != 2) {
    throw Exception('Invalid language version format: $languageVersionStr'); 
  }
  return split[1];
}

Version getVersion(final String languageVersionStr) {
  final String versionStr = getVersionStr(languageVersionStr);
  if (versionStr == 'current') {
    return Version(999, 0, 0); // treat "current" as a very high version for comparison purposes
  }
  try {
    return Version.parse(versionStr);
  } catch (e) {
    throw Exception('Invalid version format: $versionStr in $languageVersionStr');
  }
}


Future<List<ClientBinary>> fetchClientBinaries({
  required final Directory binariesDirectory,
  required final List<(Language, String, ClientBinaryType)> clientBinaryTuples}) async {
  // 1. ensure binariesDirectory exists
  final bool dirExists = await ensureDirectoryExists(binariesDirectory);
  if(!dirExists) {
    throw Exception('Failed to create binaries directory: ${binariesDirectory.path}');
  }

  // 1. sort by language and version
  // e.g. 
  // 'dart': {
  //   'v5.9.4': [ClientBinaryType.sshnp, ClientBinaryType.npt, ...]
  //   'current': [ClientBinaryType.at_activate,...]
  // }
  Map<Language, Map<String, List<ClientBinaryType>>> map = {};

  // construct map
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

  List<ClientBinary> allClientBinaries = [];

  // 2. fetch binaries sorted by version and language
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
  // 1. validate parameters
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
  List<(Process, ClientBinaryType, String)> compileProcesses = [];
  List<ClientBinary> clientBinaries = [];
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
    if((await compileProcess.exitCode) != 0) {
      print('Failed to compile ${element.$2.name}. Exit code: ${await compileProcess.exitCode}');
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

  List<ClientBinary> clientBinaries = [];

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
  List<DockerImage> dockerImages = [];
  for(final String daemonVersion in daemonVersions) {
    final Language language = getLanguage(daemonVersion);
    final String version = getVersionStr(daemonVersion);
    
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

  List<(String, DockerInstance)> dockerInstances = [];
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

bool versionIsAtLeast(String versionStr, String minimumVersion) {
  if(versionStr.startsWith('v') || versionStr.startsWith('c')) {
    versionStr = versionStr.substring(1);
  }
  if(versionStr == 'current') {
    return true; // treat "current" as a very high version for comparison purposes
  }
  final Version version = Version.parse(versionStr);
  final Version minimumVersionParsed = Version.parse(minimumVersion);
  return version >= minimumVersionParsed;
}
