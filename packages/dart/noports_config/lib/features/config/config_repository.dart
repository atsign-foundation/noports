import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:noports_config/features/config/model/sshnpd_config_document.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/privileged_runner.dart';

/// Reads and writes the daemon's sshnpd.yaml on disk.
///
/// Reading is done as the current user (the file is world readable).
/// Writing goes through [PrivilegedRunner] because the config directory is
/// owned by root / administrators.
class ConfigRepository {
  ConfigRepository({
    DaemonPaths? paths,
    Future<String> Function()? template,
    PrivilegedRunner? runner,
  }) : _paths = paths,
       _template = template ?? _bundledTemplate,
       _runner = runner;

  final DaemonPaths? _paths;
  final Future<String> Function() _template;
  final PrivilegedRunner? _runner;

  DaemonPaths get paths => _paths ?? DaemonPaths.instance;
  PrivilegedRunner get runner => _runner ?? PrivilegedRunner.instance;

  File get file => paths.configFile;

  static Future<String> _bundledTemplate() =>
      rootBundle.loadString('assets/sshnpd.template.yaml');

  /// Loads the file, or the bundled template if there is none yet.
  Future<({SshnpdConfigDocument doc, bool existed})> load() async {
    if (await file.exists()) {
      final text = await file.readAsString();
      if (text.trim().isNotEmpty) {
        return (doc: SshnpdConfigDocument.parse(text), existed: true);
      }
    }
    return (doc: SshnpdConfigDocument.parse(await _template()), existed: false);
  }

  /// Writes [doc], keeping one backup of the previous contents. The text is
  /// staged in a temp file the user owns and moved into place with admin
  /// rights.
  Future<void> save(SshnpdConfigDocument doc) async {
    final staged = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}sshnpd-${DateTime.now().microsecondsSinceEpoch}.yaml',
    );
    await staged.writeAsString(doc.source, flush: true);
    try {
      if (Platform.isWindows) {
        // Already elevated: plain file operations.
        await paths.configDir.create(recursive: true);
        if (await file.exists()) await file.copy('${file.path}.bak');
        await staged.copy(file.path);
      } else {
        final q = PrivilegedRunner.q;
        final dir = q(paths.configDir.path);
        final dest = q(file.path);
        final src = q(staged.path);
        await runner.runShell(
          'mkdir -p $dir && '
          '( [ -f $dest ] && cp -p $dest $dest.bak || true ) && '
          'install -m 644 $src $dest',
        );
      }
    } finally {
      try {
        await staged.delete();
      } catch (_) {}
    }
  }
}
