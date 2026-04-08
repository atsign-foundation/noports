import 'package:e2e_all_v2/docker_image.dart';
import 'package:path/path.dart' as path;

import './utils.dart';
import 'dart:io';

enum ClientBinaryType {
  sshnp,
  npt,
  srv,
  npp_client,
  at_activate,
}

class ClientBinary {
  final ClientBinaryType binaryType; // sshnp, npt, srv, npp_client, etc,.
  final Language language; // dart or c
  final String version; // "current", "v5.9.4", "v5.11.2", "v5.13.0"

  ClientBinary({
    required this.binaryType,
    required this.language,
    required this.version,
  });

  bool exists() {
    return File(binaryPath).existsSync();
  }

  Future<bool> download() async {
    if (version == 'current') {
      throw Exception('Cannot download "current" version. Use compile() instead.');
    }

    // GitHub release URL pattern for archives:
    // https://github.com/atsign-foundation/noports/releases/download/v5.9.4/sshnp-linux-x64.tgz
    // https://github.com/atsign-foundation/noports/releases/download/v5.9.4/sshnp-macos-x64.zip
    final String os = getOsString();
    final String arch = getArchString();
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

    final ProcessResult curlProcessResult = await runCommand('curl', ['-L', '-o', archivePath, downloadUrl]);
    
    if (curlProcessResult.exitCode != 0) {
      print('Failed to download archive (exit code: $exitCode)');
      print('Download URL: $downloadUrl');
      print('Archive path: $archivePath');
      return curlProcessResult.process; // Return original process for consistency
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

    final String sourcePath = _getSourcePath(); // e.g. packages/dart/sshnoports/bin/sshnp.dart
    final String outputPath = binaryPath; // e.g. e2e_all/$testRunId/binaries/dart_current/sshnp
    final String packageDir = _getPackageDirectory(); // e.g. packages/dart/sshnoports

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
}
