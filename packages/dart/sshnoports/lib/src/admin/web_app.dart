import 'dart:io';

import 'package:path/path.dart' as path;

/// The directory np_admin serves its web app from: web/admin beside
/// [executable] when [executable] is atsc or np_admin, or else the web app's
/// build output in this repository, as found from the sshnoports package.
Directory webAppDirectory(String executable) {
  final String postfix = Platform.isWindows ? '.exe' : '';
  final String name = path.basename(executable);
  if (name == 'atsc$postfix' || name == 'np_admin$postfix') {
    return Directory(path.join(path.dirname(executable), 'web', 'admin'));
  }
  return Directory(
    path.join('..', '..', '..', 'apps', 'admin', 'webapp', 'dist'),
  );
}
