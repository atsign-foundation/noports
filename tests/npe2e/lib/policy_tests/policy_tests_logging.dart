import 'dart:io';

import 'package:npe2e/noports_version.dart';
import 'package:npe2e/utils.dart';
import 'package:path/path.dart' as path;

// Each policy test gets its own log directory with subdirectories for clients,
// daemons, and policy services.
class PolicyTestLogger {
  final Directory logsDirectory;
  final String testName;

  late final Directory testLogsDirectory;
  late final Directory clientsDirectory;
  late final Directory daemonsDirectory;
  late final Directory policiesDirectory;

  PolicyTestLogger({required this.logsDirectory, required this.testName}) {
    testLogsDirectory = Directory(path.join(logsDirectory.path, testName));
    clientsDirectory = Directory(path.join(testLogsDirectory.path, 'clients'));
    daemonsDirectory = Directory(path.join(testLogsDirectory.path, 'daemons'));
    policiesDirectory = Directory(
      path.join(testLogsDirectory.path, 'policies'),
    );

    ensureDirectoryExistsSync(testLogsDirectory);
    ensureDirectoryExistsSync(clientsDirectory);
    ensureDirectoryExistsSync(daemonsDirectory);
    ensureDirectoryExistsSync(policiesDirectory);
  }

  String _getClientLogFileName({
    required NoPortsVersion clientVersion,
    required NoPortsVersion daemonVersion,
    required NoPortsVersion policyVersion,
    String? testMetadata,
    String? suffix,
  }) {
    String s =
        'npe2e_policy_client_${clientVersion.language.name}_${clientVersion.version}_${daemonVersion.language.name}_${daemonVersion.version}_${policyVersion.language.name}_${policyVersion.version}';
    if (testMetadata != null) {
      s += '_$testMetadata';
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
    String s = 'npe2e_policy_daemon_${language}_${version}_$deviceName';
    if (testMetadata != null) {
      s += '_$testMetadata';
    }
    if (suffix != null) {
      s += '_$suffix';
    }
    return '$s.log';
  }

  String _getPolicyLogFileName({
    required NoPortsVersion policyVersion,
    required String policyName,
    String? testMetadata,
    String? suffix,
  }) {
    final String language = policyVersion.language.name;
    final String version = policyVersion.version;
    String s = 'npe2e_policy_${language}_${version}_$policyName';
    if (testMetadata != null) {
      s += '_$testMetadata';
    }
    if (suffix != null) {
      s += '_$suffix';
    }
    return '$s.log';
  }

  File getClientStdoutLogFile({
    required NoPortsVersion clientVersion,
    required NoPortsVersion daemonVersion,
    required NoPortsVersion policyVersion,
    required String testMetadata,
  }) {
    final String fileName = _getClientLogFileName(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      testMetadata: testMetadata,
      suffix: 'stdout',
    );
    return File(path.join(clientsDirectory.path, fileName));
  }

  File getClientStderrLogFile({
    required NoPortsVersion clientVersion,
    required NoPortsVersion daemonVersion,
    required NoPortsVersion policyVersion,
    String? testMetadata,
  }) {
    final String fileName = _getClientLogFileName(
      clientVersion: clientVersion,
      daemonVersion: daemonVersion,
      policyVersion: policyVersion,
      testMetadata: testMetadata,
      suffix: 'stderr',
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

  File getPolicyStdoutLogFile({
    required NoPortsVersion policyVersion,
    required String policyName,
    String? testMetadata,
  }) {
    final String fileName = _getPolicyLogFileName(
      policyVersion: policyVersion,
      policyName: policyName,
      testMetadata: testMetadata,
      suffix: 'stdout',
    );
    return File(path.join(policiesDirectory.path, fileName));
  }

  File getPolicyStderrLogFile({
    required NoPortsVersion policyVersion,
    required String policyName,
    String? testMetadata,
  }) {
    final String fileName = _getPolicyLogFileName(
      policyVersion: policyVersion,
      policyName: policyName,
      testMetadata: testMetadata,
      suffix: 'stderr',
    );
    return File(path.join(policiesDirectory.path, fileName));
  }
}
