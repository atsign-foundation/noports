import 'dart:async';
import 'dart:io';

import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/sshnp/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';

mixin SSHNPLocalFileMixin on SSHNPImpl {
  String? identityFile;
  late final String homeDirectory;
  late final String sshHomeDirectory;
  late final String sshnpHomeDirectory;

  final List<String> _cleanUpQueue = [];

  final bool _isValidPlatform =
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  Future<void> init() async {
    await super.init();

    if (!_isValidPlatform) {
      throw SSHNPError(
          'The current platform is not supported: ${Platform.operatingSystem}');
    }
    logger.info('Initializing local file system');
    try {
      homeDirectory = getHomeDirectory(throwIfNull: true)!;
      logger.info('got homeDirectory: $homeDirectory');
    } catch (e, s) {
      throw SSHNPError('Unable to determine the home directory',
          error: e, stackTrace: s);
    }

    sshHomeDirectory = getDefaultSshDirectory(homeDirectory);
    sshnpHomeDirectory = getDefaultSshnpDirectory(homeDirectory);
  }

  @override
  Future<void> cleanUp() async {
    await super.cleanUp();
    logger.info('Cleaning up local file system');
    for (var fileName in _cleanUpQueue) {
      var file = File(fileName);
      await file.delete().catchError((e) {
        logger.warning('Error deleting file: $fileName');
        return file;
      });
    }
  }
}
