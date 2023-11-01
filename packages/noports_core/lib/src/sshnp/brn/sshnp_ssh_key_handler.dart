import 'dart:async';
import 'dart:io';

import 'package:noports_core/src/sshnp/sshnp_core.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/utils.dart';

mixin SshnpLocalSSHKeyHandler on SshnpCore {
  final LocalSshKeyUtil _sshKeyUtil = LocalSshKeyUtil();
  @override
  LocalSshKeyUtil get keyUtil => _sshKeyUtil;

  AtSshKeyPair? _identityKeyPair;

  @override
  AtSshKeyPair? get identityKeyPair => _identityKeyPair;

  @override
  Future<void> initialize() async {
    if (isSafeToInitialize) {
      logger.info('Initializing SSHNPLocalSSHKeyHandler');

      if (!keyUtil.isValidPlatform) {
        throw SshnpError(
            'The current platform is not supported: ${Platform.operatingSystem}');
      }

      if (params.identityFile != null) {
        logger.info('Loading identity key pair from ${params.identityFile}');
        _identityKeyPair = await keyUtil.getKeyPair(
          identifier: params.identityFile!,
          passphrase: params.identityPassphrase,
        );
      }
    }

    /// Make sure we set the keyPair before calling [super.init()]
    /// so that the keyPair is available in [SSHNPCore] to share to the daemon
    await super.initialize();
    completeInitialization();
  }
}

mixin SSHNPDartSSHKeyHandler on SshnpCore {
  final DartSSHKeyUtil _sshKeyUtil = DartSSHKeyUtil();
  @override
  DartSSHKeyUtil get keyUtil => _sshKeyUtil;
}
