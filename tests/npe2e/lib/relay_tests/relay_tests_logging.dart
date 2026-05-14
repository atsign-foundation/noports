import 'dart:io';

import 'package:npe2e/noports_version.dart';
import 'package:npe2e/utils.dart';
import 'package:path/path.dart' as path;

class RelayTestLogger {
  final Directory logsDirectory;
  final String testName;

  late final Directory testLogsDirectory;
  late final Directory clientsDirectory;
  late final Directory daemonsDirectory;
  late final Directory relaysDirectory;

  RelayTestLogger({required this.logsDirectory, required this.testName}) {
    testLogsDirectory = Directory(path.join(logsDirectory.path, testName));
    clientsDirectory = Directory(path.join(testLogsDirectory.path, 'clients'));
    daemonsDirectory = Directory(path.join(testLogsDirectory.path, 'daemons'));
    relaysDirectory = Directory(path.join(testLogsDirectory.path, 'relays'));

    ensureDirectoryExistsSync(testLogsDirectory);
    ensureDirectoryExistsSync(clientsDirectory);
    ensureDirectoryExistsSync(daemonsDirectory);
    ensureDirectoryExistsSync(relaysDirectory);
  }

  File getClientStdoutLogFile({
    required NoPortsVersion clientVersion,
    required NoPortsVersion daemonVersion,
    NoPortsVersion? relayVersion,
    required String testMetadata,
  }) {
    return File(
      path.join(
        clientsDirectory.path,
        '${_baseName(clientVersion, daemonVersion, relayVersion, testMetadata)}_stdout.log',
      ),
    );
  }

  File getClientStderrLogFile({
    required NoPortsVersion clientVersion,
    required NoPortsVersion daemonVersion,
    NoPortsVersion? relayVersion,
    required String testMetadata,
  }) {
    return File(
      path.join(
        clientsDirectory.path,
        '${_baseName(clientVersion, daemonVersion, relayVersion, testMetadata)}_stderr.log',
      ),
    );
  }

  File getDaemonStdoutLogFile({
    required NoPortsVersion daemonVersion,
    required String deviceName,
    required String testMetadata,
  }) {
    return File(
      path.join(
        daemonsDirectory.path,
        'npe2e_relay_daemon_${daemonVersion.language.name}_${daemonVersion.version}_${deviceName}_${testMetadata}_stdout.log',
      ),
    );
  }

  File getDaemonStderrLogFile({
    required NoPortsVersion daemonVersion,
    required String deviceName,
    required String testMetadata,
  }) {
    return File(
      path.join(
        daemonsDirectory.path,
        'npe2e_relay_daemon_${daemonVersion.language.name}_${daemonVersion.version}_${deviceName}_${testMetadata}_stderr.log',
      ),
    );
  }

  File getRelayStdoutLogFile({
    required NoPortsVersion relayVersion,
    required String relayKind,
    required String testMetadata,
  }) {
    return File(
      path.join(
        relaysDirectory.path,
        'npe2e_relay_${relayKind}_${relayVersion.language.name}_${relayVersion.version}_${testMetadata}_stdout.log',
      ),
    );
  }

  File getRelayStderrLogFile({
    required NoPortsVersion relayVersion,
    required String relayKind,
    required String testMetadata,
  }) {
    return File(
      path.join(
        relaysDirectory.path,
        'npe2e_relay_${relayKind}_${relayVersion.language.name}_${relayVersion.version}_${testMetadata}_stderr.log',
      ),
    );
  }

  String _baseName(
    NoPortsVersion clientVersion,
    NoPortsVersion daemonVersion,
    NoPortsVersion? relayVersion,
    String testMetadata,
  ) {
    final String relay = relayVersion == null
        ? 'prod'
        : '${relayVersion.language.name}_${relayVersion.version}';
    return 'npe2e_relay_client_${clientVersion.language.name}_${clientVersion.version}_${daemonVersion.language.name}_${daemonVersion.version}_${relay}_$testMetadata';
  }
}
