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

    /// Make sure we set the keyPair before calling [super.init()]
    /// so that the keyPair is available in [SSHNPCore] to share to the daemon
    await super.init();
  }
}

mixin SSHNPDartSSHKeyHandler on SSHNPForwardDart {
  final DartSSHKeyUtil _sshKeyUtil = DartSSHKeyUtil();
  @override
  DartSSHKeyUtil get keyUtil => _sshKeyUtil;
}
