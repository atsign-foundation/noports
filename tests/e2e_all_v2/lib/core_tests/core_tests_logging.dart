import 'dart:io';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/language.dart';
import 'package:e2e_all_v2/utils.dart';

// each test gets its own log directory with subdirectories for daemons and clients
class CoreTestLogger {
  final Directory logsDirectory;
  final String testName;

  late final Directory testLogsDirectory;
  late final Directory daemonsDirectory;
  late final Directory clientsDirectory;

  CoreTestLogger({
    required this.logsDirectory,
    required this.testName,
  }) {
    testLogsDirectory = Directory(path.join(logsDirectory.path, testName));
    daemonsDirectory = Directory(path.join(testLogsDirectory.path, 'daemons'));
    clientsDirectory = Directory(path.join(testLogsDirectory.path, 'clients'));

    ensureDirectoryExists(testLogsDirectory);
    ensureDirectoryExists(daemonsDirectory);
    ensureDirectoryExists(clientsDirectory);
  }

  String generateClientLogFileName({
    required Language language,
    required String version,
    required String testMetadata,
    String? daemonInfo,
  }) {
    if (daemonInfo != null) {
      return 'e2e_all_v2_client_${language.name}_${version}_daemon_${daemonInfo}_$testMetadata.log';
    }
    return 'e2e_all_v2_client_${language.name}_${version}_$testMetadata.log';
  }

  String generateDaemonLogFileName({
    required Language language,
    required String version,
    required String deviceName,
    required String testMetadata,
  }) {
    return 'e2e_all_v2_${language.name}_${version}_${deviceName}_$testMetadata.log';
  }

  File getClientStdoutLogFile({
    required Language language,
    required String version,
    required String testMetadata,
    String? daemonInfo,
  }) {
    final String fileName = generateClientLogFileName(
      language: language,
      version: version,
      testMetadata: '${testMetadata}_stdout',
      daemonInfo: daemonInfo,
    );
    return File(path.join(clientsDirectory.path, fileName));
  }

  File getClientStderrLogFile({
    required Language language,
    required String version,
    required String testMetadata,
    String? daemonInfo,
  }) {
    final String fileName = generateClientLogFileName(
      language: language,
      version: version,
      testMetadata: '${testMetadata}_stderr',
      daemonInfo: daemonInfo,
    );
    return File(path.join(clientsDirectory.path, fileName));
  }

  File getDaemonStdoutLogFile({
    required Language language,
    required String version,
    required String deviceName,
    required String testMetadata,
  }) {
    final String fileName = generateDaemonLogFileName(
      language: language,
      version: version,
      deviceName: deviceName,
      testMetadata: '${testMetadata}_stdout',
    );
    return File(path.join(daemonsDirectory.path, fileName));
  }

  File getDaemonStderrLogFile({
    required Language language,
    required String version,
    required String deviceName,
    required String testMetadata,
  }) {
    final String fileName = generateDaemonLogFileName(
      language: language,
      version: version,
      deviceName: deviceName,
      testMetadata: '${testMetadata}_stderr',
    );
    return File(path.join(daemonsDirectory.path, fileName));
  }
}

class DaemonLogCapture {
  final DockerInstance dockerInstance;
  final File stdoutFragmentFile;
  final File stderrFragmentFile;

  Process? _captureProcess;

  DaemonLogCapture({
    required this.dockerInstance,
    required this.stdoutFragmentFile,
    required this.stderrFragmentFile,
  });

  Future<void> start() async {
    _captureProcess = await startCommand(
      'docker',
      ['logs', '--follow', '--tail', '0', dockerInstance.containerName],
    );

    _captureProcess!.stdout.listen((data) {
      stdoutFragmentFile.writeAsBytesSync(data, mode: FileMode.append);
    });

    _captureProcess!.stderr.listen((data) {
      stderrFragmentFile.writeAsBytesSync(data, mode: FileMode.append);
    });
  }

  Future<void> stop() async {
    _captureProcess?.kill();
    await _captureProcess?.exitCode;
  }
}
