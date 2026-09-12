import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:noports_config/features/config/model/sshnpd_config_document.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/service_manager.dart';

enum CheckLevel { pass, warn, fail }

class HealthResult extends Equatable {
  const HealthResult(this.title, this.level, this.message);
  final String title;
  final CheckLevel level;
  final String message;

  @override
  List<Object?> get props => [title, level, message];
}

/// One diagnostic. Add a class here and register it in [HealthChecks.all]
/// to extend the Diagnostics tab.
abstract class HealthCheck {
  String get title;
  Future<HealthResult> run(HealthContext ctx);

  HealthResult pass(String m) => HealthResult(title, CheckLevel.pass, m);
  HealthResult warn(String m) => HealthResult(title, CheckLevel.warn, m);
  HealthResult fail(String m) => HealthResult(title, CheckLevel.fail, m);
}

class HealthContext {
  HealthContext({
    required this.doc,
    required this.paths,
    required this.services,
    required this.keys,
    required this.configExists,
  });
  final SshnpdConfigDocument? doc;
  final bool configExists;
  final DaemonPaths paths;
  final ServiceManager services;
  final KeysRepository keys;
}

class ConfigFileCheck extends HealthCheck {
  @override
  String get title => 'Configuration file';
  @override
  Future<HealthResult> run(HealthContext ctx) async {
    final path = ctx.paths.configFile.path;
    if (!ctx.configExists) return fail('$path does not exist. Save the configuration to create it.');
    if (ctx.doc == null) return fail('$path could not be parsed as YAML.');
    final problems = ctx.doc!.validate();
    if (problems.isNotEmpty) {
      return fail(problems.map((p) => p.message).join('\n'));
    }
    return pass('Found and valid at $path');
  }
}

class KeysFileCheck extends HealthCheck {
  @override
  String get title => 'Device atSign keys';
  @override
  Future<HealthResult> run(HealthContext ctx) async {
    final doc = ctx.doc;
    if (doc == null || doc.atsign == null) return fail('No device atSign configured.');
    final file = ctx.keys.resolve(doc.atsign, doc.keysFile);
    if (file == null) return fail('Could not work out where the keys file should be.');
    if (!file.existsSync()) {
      final hint = Platform.isWindows && doc.keysFile == null
          ? ' The service runs as LocalSystem, whose home directory is not yours, '
                'so import the keys on the Keys tab rather than relying on ~/.atsign/keys.'
          : '';
      return fail('${file.path} not found.$hint');
    }
    if (!KeysRepository.looksLikeAtKeys(file)) return fail('${file.path} is not a valid .atKeys file.');
    final fileAtsign = KeysRepository.atsignOf(file);
    if (fileAtsign != null && fileAtsign != doc.atsign) {
      return warn('${file.path} belongs to $fileAtsign but the device atSign is ${doc.atsign}.');
    }
    return pass('Keys for ${doc.atsign} at ${file.path}');
  }
}

class AccessCheck extends HealthCheck {
  @override
  String get title => 'Access control';
  @override
  Future<HealthResult> run(HealthContext ctx) async {
    final doc = ctx.doc;
    if (doc == null) return fail('No configuration.');
    if (doc.managers.isEmpty && doc.policyManager == null) {
      return fail('No manager atSigns and no policy atSign. Nobody can connect.');
    }
    final parts = <String>[];
    if (doc.managers.isNotEmpty) parts.add('managers ${doc.managers.join(', ')}');
    if (doc.policyManager != null) parts.add('policy ${doc.policyManager}');
    return pass(parts.join('; '));
  }
}

class BinaryCheck extends HealthCheck {
  @override
  String get title => 'sshnpd binary';
  @override
  Future<HealthResult> run(HealthContext ctx) async {
    final bin = ctx.paths.sshnpdBinary;
    if (!bin.existsSync()) return fail('${bin.path} not found. Reinstall NoPorts.');
    try {
      final r = await Process.run(bin.path, ['--version']);
      final v = (r.stdout.toString() + r.stderr.toString()).trim().split('\n').first;
      return pass('${bin.path} ($v)');
    } catch (e) {
      return warn('${bin.path} exists but could not be run: $e');
    }
  }
}

class RootServerCheck extends HealthCheck {
  @override
  String get title => 'atDirectory reachable';
  @override
  Future<HealthResult> run(HealthContext ctx) async {
    var root = ctx.doc?.rootDomain ?? 'root.atsign.org';
    var port = 64;
    if (root.startsWith('proxy:')) root = root.substring(6);
    final i = root.lastIndexOf(':');
    if (i > 0) {
      port = int.tryParse(root.substring(i + 1)) ?? port;
      root = root.substring(0, i);
    }
    try {
      final s = await Socket.connect(root, port, timeout: const Duration(seconds: 5));
      s.destroy();
      return pass('$root:$port');
    } catch (e) {
      return fail('Could not connect to $root:$port. Check network and firewall. ($e)');
    }
  }
}

class ServiceCheck extends HealthCheck {
  @override
  String get title => 'Daemon service';
  @override
  Future<HealthResult> run(HealthContext ctx) async {
    final s = await ctx.services.status();
    switch (s.state) {
      case ServiceState.notInstalled:
        return fail('Service ${ctx.services.serviceName} is not installed.');
      case ServiceState.running:
        return pass('Running${s.pid != null ? ' (pid ${s.pid})' : ''}, start mode ${s.startType ?? 'unknown'}');
      case ServiceState.stopped:
        final exit = s.exitCode != null ? ' Last exit code ${s.exitCode}.' : '';
        return warn('Installed but not running.$exit');
      default:
        return warn('State: ${s.state.name}');
    }
  }
}

class HealthChecks {
  HealthChecks._();
  static List<HealthCheck> all() => [
    ConfigFileCheck(),
    KeysFileCheck(),
    AccessCheck(),
    BinaryCheck(),
    RootServerCheck(),
    ServiceCheck(),
  ];
}
