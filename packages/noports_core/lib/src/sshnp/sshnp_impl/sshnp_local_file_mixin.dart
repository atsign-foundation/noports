import 'dart:io';

import 'package:meta/meta.dart';
import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';

mixin SSHNPLocalFileMixin on SSHNPImpl {
  late final String homeDirectory;
  late final String sshHomeDirectory;
  late final String sshnpHomeDirectory;

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
    try {
      homeDirectory = getHomeDirectory(throwIfNull: true)!;
    } catch (e, s) {
      throw SSHNPError('Unable to determine the home directory',
          error: e, stackTrace: s);
    }
    sshHomeDirectory = getDefaultSshDirectory(homeDirectory);
    sshnpHomeDirectory = getDefaultSshnpDirectory(homeDirectory);

    await super.init();
    if (initializedCompleter.isCompleted) return;
  }

  @protected
  Future<bool> deleteFile(String fileName) async {
    try {
      final file = File(fileName);
      await file.delete();
      return true;
    } catch (e) {
      logger.severe("Error deleting file : $fileName");
      return false;
    }
  }
}
