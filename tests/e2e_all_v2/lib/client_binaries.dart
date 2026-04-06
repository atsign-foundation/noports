import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;


enum ClientBinaryType {
  sshnp,
  npt,
  srv,
  npp_client,
  at_activate,
}

enum ClientLanguage {
  dart,
  c,
}

class ClientBinary {
  final ClientBinaryType binaryType;
  final ClientLanguage language;
  final String version; // "current", "v5.9.4", "v5.11.2", "v5.13.0"
  final String testRunId;

  late String binaryPath;
  late String binaryName;

  ClientBinary({
    required this.binaryType,
    required this.language,
    required this.version,
    required this.testRunId,
  }) {
    binaryName = _getBinaryName();
    binaryPath = _getBinaryPath();
  }

  String _getBinaryName() {
    final String base = binaryType.name;
    if (Platform.isWindows) {
      return '$base.exe';
    }
    return base;
  }

  String _getBinaryPath() {
    // Structure: e2e_all/$testRunId/binaries/{language}_{version}/{binaryName}
    return path.join(
      'e2e_all',
      testRunId,
      'binaries',
      '${language.name}_$version',
      binaryName,
    );
  }

  bool exists() {
    return File(binaryPath).existsSync();
  }

  Future<Process> download({String? logDirectory}) async {
    if (version == 'current') {
      throw Exception('Cannot download "current" version. Use compile() instead.');
    }

    // GitHub release URL pattern for archives:
    // https://github.com/atsign-foundation/noports/releases/download/v5.9.4/sshnp-linux-x64.tgz
    // https://github.com/atsign-foundation/noports/releases/download/v5.9.4/sshnp-macos-x64.zip
    final String os = _getOsString();
    final String arch = _getArchString();
    final String archiveExt = Platform.isWindows ? 'zip' : (Platform.isMacOS ? 'zip' : 'tgz');
    final String archiveName = 'sshnp-$os-$arch.$archiveExt';
    final String downloadUrl = 'https://github.com/atsign-foundation/noports/releases/download/$version/$archiveName';

    print('Downloading archive $archiveName from $downloadUrl');

    final File binaryFile = File(binaryPath);
    await binaryFile.parent.create(recursive: true);

    // Download archive to project temp location
    final String tempDir = path.join(binaryFile.parent.path, 'temp_extract');
    final String archivePath = path.join(binaryFile.parent.path, archiveName);

    final List<String> curlArgs = [
      '-L',
      '-o', archivePath,
      downloadUrl,
    ];

    print('Executing curl ${curlArgs.join(' ')}');
    final Process curlProcess = await Process.start('curl', curlArgs);

    if (logDirectory != null) {
      await Directory(logDirectory).create(recursive: true);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/download_${language.name}_${binaryType.name}_${version}_$timestamp';

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      curlProcess.stdout.listen((data) {
        stdoutFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      curlProcess.stderr.listen((data) {
        stderrFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      print('Download logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    final exitCode = await curlProcess.exitCode;
    if (exitCode != 0) {
      print('Failed to download archive (exit code: $exitCode)');
      print('Download URL: $downloadUrl');
      print('Archive path: $archivePath');
      if (logDirectory != null) {
        print('Check logs in: $logDirectory');
      }
      return curlProcess;
    }

    // Extract archive
    print('Extracting archive $archivePath');
    await Directory(tempDir).create(recursive: true);

    ProcessResult extractResult;
    if (archiveExt == 'tgz') {
      extractResult = await Process.run('tar', ['-xzf', archivePath, '-C', tempDir]);
    } else {
      extractResult = await Process.run('unzip', ['-q', archivePath, '-d', tempDir]);
    }

    if (extractResult.exitCode != 0) {
      print('Failed to extract archive (exit code: ${extractResult.exitCode})');
      print('Archive path: $archivePath');
      print('Extract stderr: ${extractResult.stderr}');
      return curlProcess; // Return original process for consistency
    }

    // Find and move the specific binary we need
    final String extractedBinaryPath = path.join(tempDir, 'sshnp', binaryName);
    final File extractedBinary = File(extractedBinaryPath);

    if (!extractedBinary.existsSync()) {
      print('Binary $binaryName not found in extracted archive');
      print('Expected path: $extractedBinaryPath');
      return curlProcess;
    }

    await extractedBinary.copy(binaryPath);
    await Process.run('chmod', ['+x', binaryPath]);

    // Clean up
    await File(archivePath).delete();
    await Directory(tempDir).delete(recursive: true);

    print('Downloaded and extracted: $binaryPath');

    return curlProcess;
  }

  Future<Process> compile({String? logDirectory}) async {
    if (version != 'current') {
      throw Exception('compile() only works for "current" version. Use download() for releases.');
    }

    if (language != ClientLanguage.dart) {
      throw Exception('Compilation only supported for Dart binaries currently');
    }

    final String sourcePath = _getSourcePath();
    final String outputPath = binaryPath;
    final String packageDir = _getPackageDirectory();

    await File(outputPath).parent.create(recursive: true);

    // First, run dart pub get to fetch dependencies
    print('Running dart pub get in $packageDir');
    final ProcessResult pubGetResult = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: packageDir,
    );

    if (pubGetResult.exitCode != 0) {
      print('Failed to run dart pub get (exit code: ${pubGetResult.exitCode})');
      print('Package directory: $packageDir');
      print('Stderr: ${pubGetResult.stderr}');
      if (logDirectory != null) {
        print('Check logs in: $logDirectory');
      }
      // Create a fake process to return for consistency
      final Process fakeProcess = await Process.start('echo', ['dart pub get failed']);
      await fakeProcess.exitCode;
      return fakeProcess;
    }

    final List<String> args = [
      'compile',
      'exe',
      sourcePath,
      '-o', outputPath,
    ];

    print('Executing dart ${args.join(' ')}');
    final Process process = await Process.start('dart', args);

    if (logDirectory != null) {
      await Directory(logDirectory).create(recursive: true);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/compile_${language.name}_${binaryType.name}_${version}_$timestamp';

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      process.stdout.listen((data) {
        stdoutFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      process.stderr.listen((data) {
        stderrFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      print('Compile logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      print('Failed to compile $binaryName (exit code: $exitCode)');
      print('Source path: $sourcePath');
      print('Output path: $outputPath');
      if (logDirectory != null) {
        print('Check logs in: $logDirectory');
      }
    } else {
      print('Successfully compiled: $binaryPath');
    }

    return process;
  }

  Future<Process> execute({
    required List<String> args,
    String? logDirectory,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (!exists()) {
      throw Exception('Binary does not exist: $binaryPath');
    }

    print('Executing $binaryPath ${args.join(' ')}');
    final Process process = await Process.start(
      binaryPath,
      args,
      workingDirectory: workingDirectory,
      environment: environment,
    );

    if (logDirectory != null) {
      await Directory(logDirectory).create(recursive: true);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/execute_${language.name}_${binaryType.name}_${version}_$timestamp';

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      process.stdout.listen((data) {
        stdoutFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      process.stderr.listen((data) {
        stderrFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      print('Execute logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    return process;
  }

  String _getOsString() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }

  String _getArchString() {
    final String arch = Platform.version.contains('x64') ? 'x64' : 'arm64';
    return arch;
  }

  String _getSourcePath() {
    switch (binaryType) {
      case ClientBinaryType.sshnp:
        return 'packages/dart/sshnoports/bin/sshnp.dart';
      case ClientBinaryType.npt:
        return 'packages/dart/sshnoports/bin/npt.dart';
      case ClientBinaryType.srv:
        return 'packages/dart/sshnoports/bin/srv.dart';
      case ClientBinaryType.npp_client:
        return 'packages/dart/sshnoports/bin/npp_client.dart';
      case ClientBinaryType.at_activate:
        return 'packages/dart/sshnoports/bin/at_activate.dart';
    }
  }

  String _getPackageDirectory() {
    return 'packages/dart/sshnoports';
  }
}

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
    required List<(ClientBinaryType, ClientLanguage, String)> required,
    String? logDirectory,
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
