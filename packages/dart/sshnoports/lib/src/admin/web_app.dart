import 'dart:io';

import 'package:path/path.dart' as path;

/// The directory np_admin serves its web app from.
///
/// Run from source, when [script] is a .dart or .dill file in
/// packages/dart/sshnoports/bin, it is the web app's build output in this
/// repository, apps/admin/webapp/dist; otherwise it is web/admin beside
/// [executable]. [script] and [executable] default to [Platform.script] and
/// [Platform.resolvedExecutable], and are passed only by tests.
Directory webAppDirectory({Uri? script, String? executable}) {
  final String scriptPath =
      (script ?? Platform.script).toFilePath(windows: Platform.isWindows);
  if (scriptPath.endsWith('.dart') || scriptPath.endsWith('.dill')) {
    return Directory(path.normalize(path.join(path.dirname(scriptPath), '..',
        '..', '..', '..', 'apps', 'admin', 'webapp', 'dist')));
  }
  return Directory(path.join(
      path.dirname(executable ?? Platform.resolvedExecutable), 'web', 'admin'));
}
