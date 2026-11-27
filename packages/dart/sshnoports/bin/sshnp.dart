import 'dart:io';

import 'package:sshnoports/src/commands/sshnp.dart' as sshnp;

Future<void> main(List<String> args) {
  // NOTE Platform.resolvedExecutable must be read before any other statement.
  Platform.resolvedExecutable;
  return sshnp.main(args);
}
