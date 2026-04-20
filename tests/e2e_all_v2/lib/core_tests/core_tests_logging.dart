import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:e2e_all_v2/noports_version.dart';
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

  String _getClientLogFileName({
    required NoPortsVersion clientVersion,
    String? testMetadata,
    String? suffix,
  }) {
    final String language = clientVersion.language.name;
    final String version = clientVersion.version;
    String s = 'e2e_all_v2_client_${language}_${version}';
    if(testMetadata != null) {
      s += '_${testMetadata}';
    }
    if (suffix != null) {
      s += '_$suffix';
    }
    return '$s.log';
  }

  String _getDaemonLogFileName({
    required NoPortsVersion daemonVersion,
    required String deviceName,
    String? testMetadata,
    String? suffix,
  }) {
    final String language = daemonVersion.language.name;
    final String version = daemonVersion.version;
    String s = 'e2e_all_v2_${language}_${version}_${deviceName}';
    if(testMetadata != null) {
      s += '_${testMetadata}';
    }
    if (suffix != null) {
      s += '_$suffix';
    }
    return '$s.log';
  }

  File getClientStdoutLogFile({
    required NoPortsVersion clientVersion,
    required String testMetadata,
  }) {
    final String fileName = _getClientLogFileName(
      clientVersion: clientVersion,
      testMetadata: testMetadata,
      suffix: 'stdout',
    );
    return File(path.join(clientsDirectory.path, fileName));
  }

  File getClientStderrLogFile({
    required NoPortsVersion clientVersion,
    String? testMetadata,
  }) {
    final String fileName = _getClientLogFileName(
      clientVersion: clientVersion,
      testMetadata: testMetadata,
    );
    return File(path.join(clientsDirectory.path, fileName));
  }

  File getDaemonStdoutLogFile({
    required NoPortsVersion daemonVersion,
    required String deviceName,
    String? testMetadata,
  }) {
    final String fileName = _getDaemonLogFileName(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: testMetadata,
      suffix: 'stdout',
    );
    return File(path.join(daemonsDirectory.path, fileName));
  }

  File getDaemonStderrLogFile({
    required NoPortsVersion daemonVersion,
    required String deviceName,
    String? testMetadata,
  }) {
    final String fileName = _getDaemonLogFileName(
      daemonVersion: daemonVersion,
      deviceName: deviceName,
      testMetadata: testMetadata,
      suffix: 'stderr',
    );
    return File(path.join(daemonsDirectory.path, fileName));
  }
}

