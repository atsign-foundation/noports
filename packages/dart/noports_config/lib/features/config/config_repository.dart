import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:noports_config/features/config/model/sshnpd_config_document.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/linux_service_manager.dart';
import 'package:noports_config/platform/privileged_runner.dart';
import 'package:path/path.dart' as p;

/// Reads and writes the daemon's sshnpd.yaml on disk.
///
/// Reading is done as the current user. Writing goes through
/// [PrivilegedRunner] only where the config directory is root owned
/// (see [DaemonPaths.configNeedsPrivileges]).
class ConfigRepository {
  ConfigRepository({
    DaemonPaths? paths,
    Future<String> Function()? template,
    PrivilegedRunner? runner,
    String? Function()? ownerGroup,
  }) : _paths = paths,
       _template = template ?? _bundledTemplate,
       _runner = runner,
       _ownerGroup = ownerGroup ?? _defaultOwnerGroup;

  final DaemonPaths? _paths;
  final Future<String> Function() _template;
  final PrivilegedRunner? _runner;
  final String? Function() _ownerGroup;

  /// Group that may read a privileged (Linux) config: the primary group of
  /// the account the daemon runs as, which is the user of this app. Null
  /// means leave owner and mode alone.
  String? get ownerGroup => _ownerGroup();

  static String? _defaultOwnerGroup() =>
      Platform.isLinux ? LinuxServiceManager.currentUser().group : null;

  DaemonPaths get paths => _paths ?? DaemonPaths.instance;
  PrivilegedRunner get runner => _runner ?? PrivilegedRunner.instance;

  File get file => paths.configFile;

  static Future<String> _bundledTemplate() =>
      rootBundle.loadString('assets/sshnpd.template.yaml');

  /// Loads the file. If there is none yet, seeds from a legacy location or
  /// the bundled template; either way `existed` is false so the first save
  /// creates the real file.
  Future<({SshnpdConfigDocument doc, bool existed})> load() async {
    if (await file.exists()) {
      final text = await _read();
      if (text.trim().isNotEmpty) {
        return (doc: SshnpdConfigDocument.parse(text), existed: true);
      }
    }
    for (final legacy in paths.legacyConfigFiles) {
      try {
        if (await legacy.exists()) {
          final text = await legacy.readAsString();
          if (text.trim().isNotEmpty) {
            return (doc: SshnpdConfigDocument.parse(text), existed: false);
          }
        }
      } catch (_) {
        // unreadable legacy file: ignore
      }
    }
    return (doc: SshnpdConfigDocument.parse(await _template()), existed: false);
  }

  /// The file's text. A root-owned config this user cannot open (a new
  /// file used to be written root:root 640, and an administrator may have
  /// tightened it) is read with administrator rights instead, so the app
  /// can still show it and the next save puts owner and mode right.
  Future<String> _read() async {
    try {
      return await file.readAsString();
    } on FileSystemException {
      if (!paths.configNeedsPrivileges) rethrow;
      return runner.runShell('cat ${PrivilegedRunner.q(file.path)}');
    }
  }

  /// Writes [doc], keeping one backup of the previous contents. The text is
  /// staged in a temp file the user owns and moved into place with admin
  /// rights.
  ///
  /// [andThen], when given, is a POSIX shell script run after the file is
  /// in place. Where the write needs administrator rights it goes into the
  /// same privileged call, so "save and restart" asks for the password
  /// once; elsewhere it runs through the runner on its own.
  Future<void> save(SshnpdConfigDocument doc, {String? andThen}) async {
    // Staged in a directory only this user can enter, at 0600: the file can
    // hold the keys passphrase, and on Linux root copies it after the
    // prompt is answered, so nothing else may swap it in the meantime.
    final stagingDir = await Directory.systemTemp.createTemp('noports-config-');
    final staged = File(p.join(stagingDir.path, 'sshnpd.yaml'));
    try {
      if (!Platform.isWindows) {
        await Process.run('chmod', ['700', stagingDir.path]);
      }
      await staged.writeAsString(doc.source, flush: true);
      if (!Platform.isWindows) await Process.run('chmod', ['600', staged.path]);

      if (!paths.configNeedsPrivileges) {
        // User owned (macOS) or already elevated (Windows). Writing into
        // the existing file keeps whatever mode it has; a new one is
        // private to the user.
        await paths.configDir.create(recursive: true);
        final existed = await file.exists();
        if (existed) await file.copy('${file.path}.bak');
        await file.writeAsString(doc.source, flush: true);
        if (!existed && !Platform.isWindows) {
          await Process.run('chmod', ['600', file.path]);
        }
        if (andThen != null) await runner.runShell(andThen);
      } else {
        final q = PrivilegedRunner.q;
        final dir = q(paths.configDir.path);
        final dest = q(file.path);
        final src = q(staged.path);
        // The file can hold the keys passphrase, so it is root-owned, mode
        // 640, readable through the group of the account the daemon runs
        // as (the package ships it 0644; universal.sh sets the same
        // root:<user> 640). The backup gets the same treatment.
        final group = ownerGroup;
        final own = group == null
            ? ''
            : ' && for f in $dest $dest.bak; do '
                  'if [ -f "\$f" ]; then chown root:${q(group)} "\$f" && '
                  'chmod 640 "\$f" || exit 1; fi; done';
        await runner.runShell(
          'mkdir -p $dir && '
          'if [ -f $dest ]; then cp -p $dest $dest.bak && cat $src > $dest; '
          'else install -m 640 $src $dest; fi'
          '$own'
          '${andThen == null ? '' : ' && $andThen'}',
        );
      }
    } finally {
      try {
        await stagingDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
