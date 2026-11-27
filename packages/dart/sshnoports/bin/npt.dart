import 'dart:io';

import 'package:sshnoports/src/commands/npt.dart' as npt;

Future<void> main(List<String> args) {
  // NOTE Platform.resolvedExecutable must be read before any other statement.
  Platform.resolvedExecutable;
  return npt.main(args);
}
