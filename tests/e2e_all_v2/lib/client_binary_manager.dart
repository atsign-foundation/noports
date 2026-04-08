import 'dart:io';
import './client_binary.dart';
import 'package:path/path.dart' as path;

class ClientBinaryManager {
  final String testRunId;
  final Map<String, ClientBinary> _binaries = {};
  final Set<String> _extractedArchives = {}; // Track extracted archives: "language_version"

  ClientBinaryManager({required this.testRunId});

  ClientBinary getBinary({
    required ClientBinaryType binaryType,
    required ClientLanguage language,
    required String version,
  }) {
    final key = '${language.name}_${binaryType.name}_$version';
    if (!_binaries.containsKey(key)) {
      _binaries[key] = ClientBinary(
        binaryType: binaryType,
        language: language,
        version: version,
        testRunId: testRunId,
      );
    }
    return _binaries[key]!;
  }

  Future<List<ClientBinary>> ensureBinaries({
    required final List<(ClientBinaryType, ClientLanguage, String)> required,
    required final Directory baseDirectory,
  }) async {
    final List<ClientBinary> prepared = [];
    final List<ClientBinary> failed = [];

    // Group binaries by language and version to extract archives only once
    final Map<String, List<(ClientBinaryType, ClientLanguage, String)>> groupedByVersion = {};

    for (final (binaryType, language, version) in required) {
      final key = '${language.name}_$version';
      groupedByVersion.putIfAbsent(key, () => []);
      groupedByVersion[key]!.add((binaryType, language, version));
    }

    // Process each version group
    for (final entry in groupedByVersion.entries) {
      final versionKey = entry.key;
      final binaries = entry.value;

      // Get representative binary to determine language and version
      final (_, language, version) = binaries.first;

      // Check if all binaries in this group already exist
      bool allExist = true;
      final List<ClientBinary> versionBinaries = [];

      for (final (binaryType, lang, ver) in binaries) {
        final binary = getBinary(
          binaryType: binaryType,
          language: lang,
          version: ver,
        );
        versionBinaries.add(binary);

        if (!binary.exists()) {
          allExist = false;
        }
      }

      if (allExist) {
        print('All binaries for ${language.name} $version already exist');
        prepared.addAll(versionBinaries);
        continue;
      }

      // Process based on version type
      if (version == 'current') {
        // Compile each binary individually for 'current' version
        for (final binary in versionBinaries) {
          if (binary.exists()) {
            print('Binary already exists: ${binary.binaryPath}');
            prepared.add(binary);
            continue;
          }

          try {
            print('Compiling ${binary.binaryType.name} (${language.name}) version $version');
            final process = await binary.compile(logDirectory: logDirectory);
            final exitCode = await process.exitCode;

            if (exitCode == 0) {
              print('Successfully compiled: ${binary.binaryPath}');
              prepared.add(binary);
            } else {
              print('Failed to compile binary: ${binary.binaryPath} (exit code: $exitCode)');
              failed.add(binary);
            }
          } catch (e, stackTrace) {
            print('Exception compiling binary ${binary.binaryPath}: $e');
            print('Stack trace: $stackTrace');
            failed.add(binary);
          }
        }
      } else {
        // Download and extract archive once for release versions
        try {
          if (!_extractedArchives.contains(versionKey)) {
            print('Downloading and extracting archive for ${language.name} $version');
            final success = await _downloadAndExtractArchive(
              language: language,
              version: version,
              logDirectory: logDirectory,
            );

            if (!success) {
              print('Failed to download/extract archive for ${language.name} $version');
              failed.addAll(versionBinaries);
              continue;
            }

            _extractedArchives.add(versionKey);
          }

          // Verify all binaries exist after extraction
          for (final binary in versionBinaries) {
            if (binary.exists()) {
              print('Binary ready: ${binary.binaryPath}');
              prepared.add(binary);
            } else {
              print('Binary not found after extraction: ${binary.binaryPath}');
              failed.add(binary);
            }
          }
        } catch (e, stackTrace) {
          print('Exception processing archive for ${language.name} $version: $e');
          print('Stack trace: $stackTrace');
          failed.addAll(versionBinaries);
        }
      }
    }

    if (failed.isNotEmpty) {
      print('Failed to prepare ${failed.length} binaries');
    }

    return prepared;
  }

  Future<bool> _downloadAndExtractArchive({
    required ClientLanguage language,
    required String version,
    String? logDirectory,
  }) async {
    final String os = Platform.isMacOS ? 'macos' : (Platform.isLinux ? 'linux' : 'windows');
    final String arch = Platform.version.contains('x64') ? 'x64' : 'arm64';
    final String archiveExt = Platform.isWindows ? 'zip' : (Platform.isMacOS ? 'zip' : 'tgz');
    final String archiveName = 'sshnp-$os-$arch.$archiveExt';
    final String downloadUrl = 'https://github.com/atsign-foundation/noports/releases/download/$version/$archiveName';

    // Create extraction directory: e2e_all/$testRunId/binaries/{language}_{version}/
    final String extractDir = path.join('e2e_all', testRunId, 'binaries', '${language.name}_$version');
    await Directory(extractDir).create(recursive: true);

    final String archivePath = path.join(extractDir, archiveName);
    final String tempExtractDir = path.join(extractDir, 'temp_extract');

    // Download archive
    print('Downloading $archiveName from $downloadUrl');
    final List<String> curlArgs = ['-L', '-o', archivePath, downloadUrl];

    final Process curlProcess = await Process.start('curl', curlArgs);

    if (logDirectory != null) {
      await Directory(logDirectory).create(recursive: true);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/download_${language.name}_${version}_$timestamp';

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      curlProcess.stdout.listen((data) {
        stdoutFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      curlProcess.stderr.listen((data) {
        stderrFile.writeAsBytesSync(data, mode: FileMode.append);
      });
    }

    final exitCode = await curlProcess.exitCode;
    if (exitCode != 0) {
      print('Failed to download archive (exit code: $exitCode)');
      return false;
    }

    // Extract archive
    print('Extracting archive to $tempExtractDir');
    await Directory(tempExtractDir).create(recursive: true);

    ProcessResult extractResult;
    if (archiveExt == 'tgz') {
      extractResult = await Process.run('tar', ['-xzf', archivePath, '-C', tempExtractDir]);
    } else {
      extractResult = await Process.run('unzip', ['-q', archivePath, '-d', tempExtractDir]);
    }

    if (extractResult.exitCode != 0) {
      print('Failed to extract archive (exit code: ${extractResult.exitCode})');
      print('Extract stderr: ${extractResult.stderr}');
      return false;
    }

    // Move extracted binaries directly to their final locations
    // Binaries in the archive are in: temp_extract/sshnp/{binary_name}
    // We need them in: e2e_all/$testRunId/binaries/{language}_{version}/{binary_name}
    final Directory extractedSshnpDir = Directory(path.join(tempExtractDir, 'sshnp'));
    if (await extractedSshnpDir.exists()) {
      await for (final file in extractedSshnpDir.list()) {
        if (file is File) {
          final String fileName = path.basename(file.path);
          // Binaries should be copied directly to the version directory root
          // since _getBinaryPath() expects them there
          final String destPath = path.join(extractDir, fileName);
          await file.copy(destPath);
          await Process.run('chmod', ['+x', destPath]);
          print('Extracted binary: $destPath');
        }
      }
    } else {
      print('Warning: sshnp directory not found in extracted archive');
    }

    // Clean up
    await File(archivePath).delete();
    await Directory(tempExtractDir).delete(recursive: true);

    print('Successfully extracted archive for ${language.name} $version');
    return true;
  }


  Future<void> cleanup() async {
    final dir = Directory(path.join('e2e_all', testRunId, 'binaries'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      print('Cleaned up binaries directory: ${dir.path}');
    }
  }
}
