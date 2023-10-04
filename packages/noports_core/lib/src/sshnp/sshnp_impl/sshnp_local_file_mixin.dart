import 'dart:io';

import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';

mixin SSHNPLocalFileMixin on SSHNPImpl {
  late final String sshHomeDirectory;

  final bool _isValidPlatform =
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  Future<void> init() async {
    if (!params.allowLocalFileSystem) {
      throw SSHNPError(
          'The current client type requires allowLocalFileSystem to be true: $runtimeType');
    }
    if (!_isValidPlatform) {
      throw SSHNPError(
          'The current platform is not supported: ${Platform.operatingSystem}');
    }
    await super.init();
    
    if (initializedCompleter.isCompleted) return;
  }
}
