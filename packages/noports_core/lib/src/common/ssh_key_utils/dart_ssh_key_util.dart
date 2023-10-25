import 'dart:async';

import 'package:at_chops/at_chops.dart';
import 'package:cryptography/cryptography.dart';
import 'package:noports_core/utils.dart';
import 'package:openssh_ed25519/openssh_ed25519.dart';

class DartSSHKeyUtil implements AtSSHKeyUtil {
  static final Map<String, AtSSHKeyPair> _keyPairCache = {};

  @override
  Future<AtSSHKeyPair> generateKeyPair({
    required String identifier,
    SupportedSSHAlgorithm algorithm = DefaultArgs.sshAlgorithm,
  }) async {
    AtSSHKeyPair keyPair;
    switch (algorithm) {
      case SupportedSSHAlgorithm.rsa:
        keyPair = _generateRSAKeyPair(identifier);
      case SupportedSSHAlgorithm.ed25519:
        keyPair = await _generateEd25519KeyPair(identifier);
    }
    _keyPairCache[identifier] = keyPair;
    return keyPair;
  }

  Future<void> addKeyPair({
    required AtSSHKeyPair keyPair,
    required String identifier,
  }) async {
    _keyPairCache[identifier] = keyPair;
  }

  @override
  Future<AtSSHKeyPair> getKeyPair({required String identifier}) async {
    return _keyPairCache[identifier] ??
        await generateKeyPair(identifier: identifier);
  }

  AtSSHKeyPair _generateRSAKeyPair(String identifier) => AtSSHKeyPair.fromPem(
        AtChopsUtil.generateRSAKeyPair(keySize: 4096).privateKey.toPEM(),
        identifier: identifier,
      );

  Future<AtSSHKeyPair> _generateEd25519KeyPair(String identifier) async {
    var keyPair2 = await Ed25519().newKeyPair();
    var pemText = encodeEd25519Private(
      privateBytes: await keyPair2.extractPrivateKeyBytes(),
      publicBytes: (await keyPair2.extractPublicKey()).bytes,
    );
    return AtSSHKeyPair.fromPem(
      pemText,
      identifier: identifier,
    );
  }
}
