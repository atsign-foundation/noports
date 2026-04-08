import 'dart:io';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

Future<ProcessResult> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  printCommand = false,
}) async {
  print('    Running command: "$executable ${arguments.join(' ')}"');
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if (result.exitCode != 0) {
    print('Error running command: $executable ${arguments.join(' ')}');
    print('Exit code: ${result.exitCode}');
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
  }
  if(printCommand) {
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
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
  print('    Starting command: "$executable ${arguments.join(' ')}"');
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printCommand) {
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      print('stdout: $data');
    });
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      print('stderr: $data');
    });
  }
  return process;
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
    ['rev-parse', '--short', 'HEAD'],
    printCommand: true);
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
      } else {
        allClientBinaries.addAll(await _downloadRelease(language: language, version: version, clientBinaryTypes: clientBinaryTypes, directory: dir));
      }
    }
  }
}

String _getBinaryPath(ClientBinaryType binaryType) {
  switch(binaryType) {
    case ClientBinaryType.sshnp:
      return 'sshnp';
    case ClientBinaryType.npt:
      return 'npt';
    case ClientBinaryType.srv:
      return 'srv';
    case ClientBinaryType.npp_client:
      return 'npp_client';
    case ClientBinaryType.at_activate:
      return 'at_activate';
    default:
      throw Exception('Unsupported ClientBinaryType: ${binaryType.name}');
  }
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
    final String targetBinaryPath = _getBinaryPath(binaryType);
    final String outputPath = path.join(directory.path, binaryType.name); // e.g. /path/to/binaries/dart/current/sshnp
    final Process compileProcess = await startCommand(
      'dart', 
      ['compile', 'exe', targetBinaryPath, '-o', outputPath]);
    compileProcesses.add((compileProcess, binaryType, outputPath));
  }

  // 3. wait for processes to finish and check exit codes
  for(final (Process, ClientBinaryType, String) element in compileProcesses) {
    final Process compileProcess = element.$1;
    if((await compileProcess.exitCode) != 0) {
      print('Failed to compile ${element.$2.name}. Exit code: ${await compileProcess.exitCode}');
      compileProcess.stderr.transform(SystemEncoding().decoder).listen((data) {
        print('Compile stderr: $data');
      });
      throw Exception('Failed to compile ${element.$2.name}. Exit code: $exitCode');
    }

    File outputFile = File(element.$3);
    if(!(await outputFile.exists())) {
      throw Exception('Expected output binary not found after compilation: ${outputFile.path}');
    }
    
    final ClientBinaryType binaryType = element.$2;
    final String outputPath = element.$3;
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
    ['-L', '-o', path.join(directory.path, archiveName), downloadUrl],
    printCommand: true);
  if(curlProcessResult.exitCode != 0) {
    throw Exception('Failed to download archive from $downloadUrl: ${curlProcessResult.stderr}');
  }

  // 3. create temporary extraction directory: $directory/temp_extract/
  final Directory tempExtractDir = Directory(path.join(directory.path, 'temp_extract'));
  ensureDirectoryExists(tempExtractDir);

  // 4. extract archive to temporary directory
  final ProcessResult extractProcessResult = Platform.isWindows || Platform.isMacOS
    ? await runCommand('unzip', [path.join(directory.path, archiveName), '-d', tempExtractDir.path], printCommand: true)
    : await runCommand('tar', ['-xzf', path.join(directory.path, archiveName), '-C', tempExtractDir.path], printCommand: true);
  if(extractProcessResult.exitCode != 0) {
    throw Exception('Failed to extract archive ${path.join(directory.path, archiveName)}: ${extractProcessResult.stderr}');
  }

  List<ClientBinary> clientBinaries = [];

  // 5. move binaries from temporary extraction directory to final location: $directory/{binaryType}/
  for(final ClientBinaryType binaryType in clientBinaryTypes) {
    final String binaryName = binaryType.name;
    final File extractedBinary = File(path.join(tempExtractDir.path, binaryName));
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
        version: version));
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
