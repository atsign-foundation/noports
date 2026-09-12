import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:noports_config/features/config/model/sshnpd_config_document.dart';
import 'package:noports_config/platform/daemon_paths.dart';

/// Reads and writes the daemon's sshnpd.yaml on disk.
class ConfigRepository {
  ConfigRepository({DaemonPaths? paths, Future<String> Function()? template})
      : _paths = paths,
        _template = template ?? _bundledTemplate;

  final DaemonPaths? _paths;
  final Future<String> Function() _template;

  DaemonPaths get paths => _paths ?? DaemonPaths.instance;

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

  /// Writes [doc] atomically, keeping one backup of the previous contents.
  Future<void> save(SshnpdConfigDocument doc) async {
    await paths.configDir.create(recursive: true);
    if (await file.exists()) {
      try {
        await file.copy('${file.path}.bak');
      } on FileSystemException {
        // A missing backup is not worth failing the save for.
      }
    }
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(doc.source, flush: true);
    await tmp.rename(file.path);
  }
}
