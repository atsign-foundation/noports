import 'dart:async';
import 'dart:io';

import 'package:noports_core/src/sshnp/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/utils.dart';

mixin SSHNPLocalFileHandler on SSHNPImpl {
  final LocalSSHKeyUtil _sshKeyUtil = LocalSSHKeyUtil();
  @override
  LocalSSHKeyUtil get keyUtil => _sshKeyUtil;

  final bool _isValidPlatform =
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  Future<void> init() async {
    await super.init();

    if (!_isValidPlatform) {
      throw SSHNPError(
          'The current platform is not supported: ${Platform.operatingSystem}');
    }
  }
}
