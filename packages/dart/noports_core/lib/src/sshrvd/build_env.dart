import 'dart:io';

class BuildEnv {
  static final bool enableSnoop = (Platform.environment['ENABLE_SNOOP'] ?? "false").toLowerCase() == 'true';
}
