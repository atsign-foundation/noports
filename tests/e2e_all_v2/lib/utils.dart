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


  // sort by version
  // e.g. 
  // {
  //   'v5.9.4': (Language.dart, ClientBinaryType.sshnp),
  //   'v5.9.4': (Language.dart, ClientBinaryType.npt),
  //   ...
  //   'current': (Language.dart, ClientBinaryType.at_activate),
  // }
  Map<String, (Language, ClientBinaryType)> versionToLanguageAndType = {};

  for(final (Language, String, ClientBinaryType) e in clientBinaryTuples) {
    final Language language = e.$1;
    final String version = e.$2;
    final ClientBinaryType binaryType = e.$3;
    versionToLanguageAndType[version] = (language, binaryType);
  }

  for(final String version in versionToLanguageAndType.keys) {
    final (Language language, ClientBinaryType binaryType) = versionToLanguageAndType[version]!;
    if(version == 'current') {
      final Directory currentDirectory = Directory(path.join(binariesDirectory.path, 'current'));
      ensureDirectoryExists(currentDirectory);
    }
  }

}

void _downloadRelease(final String version, final Language language) async {
  
}
