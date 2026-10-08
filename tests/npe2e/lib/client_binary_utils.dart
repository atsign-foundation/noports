import 'dart:io';

import 'package:npe2e/client_binary.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/os_utils.dart';
import 'package:npe2e/process_utils.dart';
import 'package:npe2e/utils.dart';
import 'package:path/path.dart' as path;

Future<List<ClientBinary>> fetchClientBinariesParallel({
  required final Directory
  binariesDirectory, // where all binaries will go (subdirectories will be created in here according to version)
  required final List<(NoPortsVersion, ClientBinaryType)>
  clientBinariesToDownload,
}) async {
  // 1. ensure binariesDirectory exists
  final bool dirExists = await ensureDirectoryExists(binariesDirectory);
  if (!dirExists) {
    throw Exception(
      'Failed to create binaries directory: ${binariesDirectory.path}',
    );
  }

  // 2. sort by language and version
  // e.g.
  // 'dart': {
  //   'v5.9.4': [ClientBinaryType.sshnp, ClientBinaryType.npt, ...]
  //   'current': [ClientBinaryType.at_activate,...]
  // }
  final Map<Language, Map<String, List<ClientBinaryType>>> map = {};
  for (final (NoPortsVersion noPortsVersion, ClientBinaryType clientBinaryType)
      in clientBinariesToDownload) {
    final Language language = noPortsVersion.language;
    final String version = noPortsVersion.version;
    if (language != Language.dart) {
      throw Exception(
        'Currently only dart client binaries are supported. Found language: ${language.name}',
      );
    }
    map.putIfAbsent(language, () => {});
    map[language]!.putIfAbsent(version, () => []);
    map[language]![version]!.add(clientBinaryType);
  }

  // 3. Create subdirectories
  // Have a map that will have associated directory objects
  // E.g.:
  // 'dart': {
  //   'v5.9.4': Directory('path/to/binaries/dart/v5.9.4'),
  final Map<Language, Map<String, Directory>> dirMap = {};
  for (final Language language in map.keys) {
    final Map<String, List<ClientBinaryType>> versionMap = map[language]!;
    for (final String version in versionMap.keys) {
      final String dirPath = path.join(
        binariesDirectory.path,
        language.name,
        version,
      );
      final Directory dir = Directory(dirPath);
      final bool dirExists = await ensureDirectoryExists(dir);
      if (!dirExists) {
        throw Exception('Failed to create directory for binaries: ${dir.path}');
      }
      dirMap.putIfAbsent(language, () => {});
      dirMap[language]![version] = dir;
    }
  }

  // 4. For each language and version, trigger the appropriate download/compilation functions in parallel
  final List<Future<List<ClientBinary>>> futures = [];
  for (final Language language in map.keys) {
    final Map<String, List<ClientBinaryType>> versionMap = map[language]!;
    for (final String version in versionMap.keys) {
      final List<ClientBinaryType> clientBinaryTypes = versionMap[version]!;
      final Directory outputDirectory = dirMap[language]![version]!;
      if (version == 'current') {
        futures.add(
          Future.wait(
            compileDartCurrentBinariesList(
              noPortsVersion: NoPortsVersion(
                language: language,
                version: version,
              ),
              clientBinaryTypes: clientBinaryTypes,
              outputDirectory: outputDirectory,
            ),
          ),
        );
      } else {
        futures.add(
          downloadDartReleaseBinariesList(
            noPortsVersion: NoPortsVersion(
              language: language,
              version: version,
            ),
            clientBinaryTypes: clientBinaryTypes,
            outputDirectory: outputDirectory,
          ),
        );
      }
    }
  }

  // 5. wait for all to complete and flatten results
  final List<List<ClientBinary>> listOfLists = await Future.wait(futures);
  final List<ClientBinary> clientBinaries = listOfLists
      .expand((x) => x)
      .toList();
  return clientBinaries;
}

Future<ClientBinary> compileDartCurrentBinary({
  required final NoPortsVersion noPortsVersion,
  required final ClientBinaryType clientBinaryType,
  required final Directory outputDirectory,
}) async {
  if (noPortsVersion.language != Language.dart) {
    throw Exception(
      'Currently only dart client binaries are supported. Found language: ${noPortsVersion.language.name}',
    );
  }

  final bool dirExists = await ensureDirectoryExists(outputDirectory);
  if (!dirExists) {
    throw Exception(
      'Failed to create directory for compiling current binaries: ${outputDirectory.path}',
    );
  }

  final String outputPath = path.join(
    outputDirectory.path,
    clientBinaryType.name,
  );
  const String executable = 'dart';
  final List<String> args = [
    'compile',
    'exe',
    path.join(
      'packages',
      'dart',
      'sshnoports',
      'bin',
      '${clientBinaryType.name}.dart',
    ),
    '-o',
    outputPath,
  ];

  final ProcessResult processResult = await runCommand(executable, args);
  if (processResult.exitCode != 0) {
    throw Exception(
      'Failed to compile current binary for ${clientBinaryType.name}: ${processResult.stderr}',
    );
  }

  final File outputFile = File(outputPath);
  if (!(await outputFile.exists())) {
    throw Exception(
      'Expected output binary not found after compilation: ${outputFile.path}',
    );
  }

  return ClientBinary(
    binaryType: clientBinaryType,
    noPortsVersion: noPortsVersion,
    file: outputFile,
  );
}

List<Future<ClientBinary>> compileDartCurrentBinariesList({
  required final NoPortsVersion noPortsVersion,
  required final List<ClientBinaryType> clientBinaryTypes,
  required final Directory
  outputDirectory, // where the compiled binaries will be placed
}) {
  final List<Future<ClientBinary>> futures = [];
  for (final ClientBinaryType clientBinaryType in clientBinaryTypes) {
    futures.add(
      compileDartCurrentBinary(
        noPortsVersion: noPortsVersion,
        clientBinaryType: clientBinaryType,
        outputDirectory: outputDirectory,
      ),
    );
  }
  return futures;
}

Future<List<ClientBinary>> downloadDartReleaseBinariesList({
  required final NoPortsVersion noPortsVersion,
  required final List<ClientBinaryType> clientBinaryTypes,
  required final Directory outputDirectory,
}) async {
  if (noPortsVersion.language != Language.dart) {
    throw Exception(
      'Currently only dart client binaries are supported. Found language: ${noPortsVersion.language.name}',
    );
  }
  // 1. construct $archiveName and $downloadUrl
  final String osStr = getOsString();
  final String archStr = getArchString();
  String archiveExt;
  switch (Platform.operatingSystem) {
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
  final String downloadUrl =
      'https://github.com/atsign-foundation/noports/releases/download/${noPortsVersion.version}/$archiveName';

  // 2. get tgz/zip
  final ProcessResult curlProcessResult = await runCommand('curl', [
    '-L',
    '-o',
    path.join(outputDirectory.path, archiveName),
    downloadUrl,
  ]);
  if (curlProcessResult.exitCode != 0) {
    throw Exception(
      'Failed to download archive from $downloadUrl: ${curlProcessResult.stderr}',
    );
  }

  // 3. create temporary extraction directory: $directory/temp_extract/
  final Directory tempExtractDir = Directory(
    path.join(outputDirectory.path, 'temp_extract'),
  );
  await ensureDirectoryExists(tempExtractDir);

  // 4. extract archive to temporary directory
  ProcessResult extractResult;
  switch (Platform.operatingSystem) {
    case 'linux':
      extractResult = await runCommand('tar', [
        '-xzf',
        path.join(outputDirectory.path, archiveName),
        '-C',
        tempExtractDir.path,
      ]);
      break;
    case 'windows':
      extractResult = await runCommand('powershell', [
        '-Command',
        'Expand-Archive',
        '-Path',
        path.join(outputDirectory.path, archiveName),
        '-DestinationPath',
        tempExtractDir.path,
      ]);
      break;
    case 'macos':
      extractResult = await runCommand('unzip', [
        '-q',
        path.join(outputDirectory.path, archiveName),
        '-d',
        tempExtractDir.path,
      ]);
      break;
    default:
      throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }
  if (extractResult.exitCode != 0) {
    throw Exception('Failed to extract archive: ${extractResult.stderr}');
  }

  final List<ClientBinary> clientBinaries = [];

  // 5. move binaries from temporary extraction directory to final location: $directory/{binaryType}/
  for (final ClientBinaryType binaryType in clientBinaryTypes) {
    final String binaryName = binaryType.name;
    final File extractedBinary = File(
      path.join(tempExtractDir.path, 'sshnp', binaryName),
    );
    if (!(await extractedBinary.exists())) {
      throw Exception(
        'Expected binary not found in extracted archive: ${extractedBinary.path}',
      );
    }
    final String finalBinaryPath = path.join(outputDirectory.path, binaryName);
    final File binary = await extractedBinary.copy(finalBinaryPath);
    if (!(await binary.exists())) {
      throw Exception(
        'Failed to move binary to final location: ${binary.path}',
      );
    }
    clientBinaries.add(
      ClientBinary(
        binaryType: binaryType,
        noPortsVersion: noPortsVersion,
        file: binary,
      ),
    );
  }

  // 6. clean up temporary extraction directory and archive
  try {
    await tempExtractDir.delete(recursive: true);
  } catch (e) {
    print('Warning: Failed to clean up temporary files: $e');
  }
  return clientBinaries;
}
