import 'dart:io';

import 'package:sshnoports/src/commands/sshnpd.dart' as sshnpd;

Future<void> main(List<String> args) {
  // NOTE Platform.resolvedExecutable must be read before any other statement.
  Platform.resolvedExecutable;
  return sshnpd.main(args);
}
