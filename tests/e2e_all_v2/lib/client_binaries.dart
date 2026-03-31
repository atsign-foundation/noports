import 'dart:io';
import 'dart:convert';
import 'package:at_utils/at_utils.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

final AtSignLogger logger = AtSignLogger('client_binaries');

enum ClientBinaryType {
  sshnp,
  sshnpd,
  npt,
  npp,
  srvd,
  npa,
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

    // GitHub release URL pattern:
    // https://github.com/atsign-foundation/noports/releases/download/v5.9.4/sshnp-linux-x64
    final String os = _getOsString();
    final String arch = _getArchString();
    final String downloadUrl =
        'https://github.com/atsign-foundation/noports/releases/download/$version/${binaryType.name}-$os-$arch';

    logger.info('Downloading $binaryName from $downloadUrl');

    final File binaryFile = File(binaryPath);
    await binaryFile.parent.create(recursive: true);

    final List<String> args = [
      '-L', 
      '-o', binaryPath,
      downloadUrl,
    ];

    logger.info('Executing curl ${args.join(' ')}');
    final Process process = await Process.start('curl', args);

    if (logDirectory != null) {
      await Directory(logDirectory).create(recursive: true);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/download_${language.name}_${binaryType.name}_${version}_$timestamp';

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      process.stdout.listen((data) {
        stdoutFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      process.stderr.listen((data) {
        stderrFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      logger.info('Download logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      await Process.run('chmod', ['+x', binaryPath]);
      logger.info('Downloaded and made executable: $binaryPath');
    }

    return process;
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

    await File(outputPath).parent.create(recursive: true);

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
      case ClientBinaryType.sshnpd:
        return 'packages/dart/sshnoports/bin/sshnpd.dart';
      case ClientBinaryType.npt:
        return 'packages/dart/sshnoports/bin/npt.dart';
      case ClientBinaryType.npp:
        return 'packages/dart/sshnoports/bin/npp.dart';
      case ClientBinaryType.srvd:
        return 'packages/dart/sshnoports/bin/srvd.dart';
      case ClientBinaryType.npa:
        return 'packages/dart/sshnoports/bin/npa.dart';
    }
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
          process = await binary.compile(logDirectory: logDirectory);
        } else {
          process = await binary.download(logDirectory: logDirectory);
        }

        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          logger.info('Successfully prepared binary: ${binary.binaryPath}');
          prepared.add(binary);
        } else {
          logger.severe('Failed to prepare binary: ${binary.binaryPath} (exit code: $exitCode)');
          failed.add(binary);
        }
      } catch (e) {
        logger.severe('Error preparing binary ${binary.binaryPath}: $e');
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
