import 'dart:io';

import 'package:noports_core/sshnp_foundation.dart';

mixin SshnpLocalSshKeyHandler on SshnpCore implements SshnpKeyHandler {
  @override
  LocalSshKeyUtil get keyUtil => _sshKeyUtil;
  final LocalSshKeyUtil _sshKeyUtil = LocalSshKeyUtil();

  @override
  AtSshKeyPair? get identityKeyPair => _identityKeyPair;
  AtSshKeyPair? _identityKeyPair;

  @override
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;
    logger.info('Initializing SshnpLocalSshKeyHandler');

    if (!keyUtil.isValidPlatform) {
      throw SshnpError(
          'The current platform is not supported with the local SSH key handler: ${Platform.operatingSystem}');
    }

    if (params.identityFile != null) {
      logger.info('Loading identity key pair from ${params.identityFile}');
      _identityKeyPair = await keyUtil.getKeyPair(
        identifier: params.identityFile!,
        passphrase: params.identityPassphrase,
      );
    }

    await super.initialize();
  }
}
