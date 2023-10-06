import 'dart:async';
import 'dart:io';

import 'package:noports_core/src/sshnp/sshnp_core.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/utils.dart';

mixin SSHNPLocalSSHKeyHandler on SSHNPCore {
  final LocalSSHKeyUtil _sshKeyUtil = LocalSSHKeyUtil();
  @override
  LocalSSHKeyUtil get keyUtil => _sshKeyUtil;

  @override
  Future<String?> get publicKeyContents async => params.identityFile == null
      ? null
      : (await keyUtil.getKeyPair(identifier: params.identityFile!))
          .publicKeyContents;

  @override
  Future<void> init() async {
    await super.init();

    if (!keyUtil.isValidPlatform) {
      throw SSHNPError(
          'The current platform is not supported: ${Platform.operatingSystem}');
    }
  }
}

mixin SSHNPDartSSHKeyHandler on SSHNPForwardDart {
  final DartSSHKeyUtil _sshKeyUtil = DartSSHKeyUtil();
  @override
  DartSSHKeyUtil get keyUtil => _sshKeyUtil;
}
