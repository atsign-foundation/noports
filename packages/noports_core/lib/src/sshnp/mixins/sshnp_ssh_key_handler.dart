import 'dart:async';
import 'dart:io';

import 'package:noports_core/src/sshnp/sshnp_core.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/utils.dart';

mixin SSHNPLocalSSHKeyHandler on SSHNPCore {
  final LocalSSHKeyUtil _sshKeyUtil = LocalSSHKeyUtil();
  @override
  LocalSSHKeyUtil get keyUtil => _sshKeyUtil;

  AtSSHKeyPair? _identityKeyPair;

  @override
  AtSSHKeyPair? get identityKeyPair => _identityKeyPair;

  @override
  Future<void> init() async {
    await super.init();

    if (!keyUtil.isValidPlatform) {
      throw SSHNPError(
          'The current platform is not supported: ${Platform.operatingSystem}');
    }

    if (params.identityFile != null) {
      _identityKeyPair = await keyUtil.getKeyPair(
        identifier: params.identityFile!,
        passphrase: params.identityPassphrase,
      );
    }
  }
}

mixin SSHNPDartSSHKeyHandler on SSHNPForwardDart {
  final DartSSHKeyUtil _sshKeyUtil = DartSSHKeyUtil();
  @override
  DartSSHKeyUtil get keyUtil => _sshKeyUtil;
}
