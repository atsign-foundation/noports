import 'dart:io';
import 'dart:convert';
import 'package:at_utils/at_utils.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

final AtSignLogger logger = AtSignLogger('client_binaries');

enum ClientBinaryType {
  sshnp,
  npt,
  srv,
  npp_client,
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
    return path.join(
      'binaries',
      testRunId,
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

    logger.info('Downloading archive $archiveName from $downloadUrl');

    final File binaryFile = File(binaryPath);
    await binaryFile.parent.create(recursive: true);

    // Download archive to temp location
    final String tempDir = path.join(binaryFile.parent.path, 'temp_$archiveName');
    final String archivePath = path.join(Directory.systemTemp.path, archiveName);

    final List<String> curlArgs = [
      '-L',
      '-o', archivePath,
      downloadUrl,
    ];

    logger.info('Executing curl ${curlArgs.join(' ')}');
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

      logger.info('Download logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    final exitCode = await curlProcess.exitCode;
    if (exitCode != 0) {
      logger.severe('Failed to download archive (exit code: $exitCode)');
      logger.severe('Download URL: $downloadUrl');
      logger.severe('Archive path: $archivePath');
      if (logDirectory != null) {
        logger.severe('Check logs in: $logDirectory');
      }
      return curlProcess;
    }

    // Extract archive
    logger.info('Extracting archive $archivePath');
    await Directory(tempDir).create(recursive: true);

    ProcessResult extractResult;
    if (archiveExt == 'tgz') {
      extractResult = await Process.run('tar', ['-xzf', archivePath, '-C', tempDir]);
    } else {
      extractResult = await Process.run('unzip', ['-q', archivePath, '-d', tempDir]);
    }

    if (extractResult.exitCode != 0) {
      logger.severe('Failed to extract archive (exit code: ${extractResult.exitCode})');
      logger.severe('Archive path: $archivePath');
      logger.severe('Extract stderr: ${extractResult.stderr}');
      return curlProcess; // Return original process for consistency
    }

    // Find and move the specific binary we need
    final String extractedBinaryPath = path.join(tempDir, 'sshnp', binaryName);
    final File extractedBinary = File(extractedBinaryPath);

    if (!extractedBinary.existsSync()) {
      logger.severe('Binary $binaryName not found in extracted archive');
      logger.severe('Expected path: $extractedBinaryPath');
      return curlProcess;
    }

    await extractedBinary.copy(binaryPath);
    await Process.run('chmod', ['+x', binaryPath]);

    // Clean up
    await File(archivePath).delete();
    await Directory(tempDir).delete(recursive: true);

    logger.info('Downloaded and extracted: $binaryPath');

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
    logger.info('Running dart pub get in $packageDir');
    final ProcessResult pubGetResult = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: packageDir,
    );

    if (pubGetResult.exitCode != 0) {
      logger.severe('Failed to run dart pub get (exit code: ${pubGetResult.exitCode})');
      logger.severe('Package directory: $packageDir');
      logger.severe('Stderr: ${pubGetResult.stderr}');
      if (logDirectory != null) {
        logger.severe('Check logs in: $logDirectory');
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

    logger.info('Executing dart ${args.join(' ')}');
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

      logger.info('Compile logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      logger.severe('Failed to compile $binaryName (exit code: $exitCode)');
      logger.severe('Source path: $sourcePath');
      logger.severe('Output path: $outputPath');
      if (logDirectory != null) {
        logger.severe('Check logs in: $logDirectory');
      }
    } else {
      logger.info('Successfully compiled: $binaryPath');
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

    logger.info('Executing $binaryPath ${args.join(' ')}');
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

      logger.info('Execute logs: ${stdoutFile.path} / ${stderrFile.path}');
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
    }
  }

  String _getPackageDirectory() {
    return 'packages/dart/sshnoports';
  }
}

class ClientBinaryManager {
  final String testRunId;
  final Map<String, ClientBinary> _binaries = {};

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

    for (final (binaryType, language, version) in required) {
      final binary = getBinary(
        binaryType: binaryType,
        language: language,
        version: version,
      );

      if (binary.exists()) {
        logger.info('Binary already exists: ${binary.binaryPath}');
        prepared.add(binary);
        continue;
      }

      try {
        Process process;
        if (version == 'current') {
          logger.info('Compiling ${binaryType.name} (${language.name}) version $version');
          process = await binary.compile(logDirectory: logDirectory);
        } else {
          logger.info('Downloading ${binaryType.name} (${language.name}) version $version');
          process = await binary.download(logDirectory: logDirectory);
        }

        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          logger.info('Successfully prepared binary: ${binary.binaryPath}');
          prepared.add(binary);
        } else {
          final action = version == 'current' ? 'compile' : 'download';
          logger.severe('Failed to $action binary: ${binary.binaryPath} (exit code: $exitCode)');
          logger.severe('Binary type: ${binaryType.name}, Language: ${language.name}, Version: $version');
          if (logDirectory != null) {
            logger.severe('Check error logs in: $logDirectory');
          }
          failed.add(binary);
        }
      } catch (e, stackTrace) {
        logger.severe('Exception preparing binary ${binary.binaryPath}: $e');
        logger.severe('Stack trace: $stackTrace');
        logger.severe('Binary type: ${binaryType.name}, Language: ${language.name}, Version: $version');
        failed.add(binary);
      }
    }

    if (failed.isNotEmpty) {
      logger.warning('Failed to prepare ${failed.length} binaries');
    }

    return prepared;
  }

  Future<void> cleanup() async {
    final dir = Directory(path.join('binaries', testRunId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      logger.info('Cleaned up binaries directory: ${dir.path}');
    }
  }
}
