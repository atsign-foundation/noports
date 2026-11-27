import 'dart:io';

import 'package:sshnoports/src/commands/np_admin.dart' as np_admin;

Future<void> main(List<String> args) {
  // NOTE Platform.resolvedExecutable must be read before any other statement.
  Platform.resolvedExecutable;
  return np_admin.main(args);
}
