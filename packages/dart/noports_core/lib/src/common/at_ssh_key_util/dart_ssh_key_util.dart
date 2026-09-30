import 'dart:async';

import 'package:at_chops/at_chops.dart' show RsaKeyPair;
import 'package:cryptography/cryptography.dart' show Ed25519;
import 'package:noports_core/utils.dart';
import 'package:openssh_ed25519/openssh_ed25519.dart';

class DartSshKeyUtil implements AtSshKeyUtil {
  static final Map<String, AtSshKeyPair> _keyPairCache = {};

  @override
  Future<AtSshKeyPair> generateKeyPair({
    required String identifier,
    SupportedSshAlgorithm algorithm = DefaultArgs.sshAlgorithm,
  }) async {
    AtSshKeyPair keyPair;
    switch (algorithm) {
      case SupportedSshAlgorithm.rsa:
        keyPair = _generateRSAKeyPair(identifier);
      case SupportedSshAlgorithm.ed25519:
        keyPair = await _generateEd25519KeyPair(identifier);
    }
    _keyPairCache[identifier] = keyPair;
    return keyPair;
  }

  @override
  Future<AtSshKeyPair> getKeyPair({required String identifier}) async {
    return _keyPairCache[identifier] ??
        await generateKeyPair(identifier: identifier);
  }

  AtSshKeyPair _generateRSAKeyPair(String identifier) => AtSshKeyPair.fromPem(
        '-----BEGIN RSA PRIVATE KEY-----\n'
        '${RsaKeyPair.generate(keySize: 4096).atPrivateKey.privateKey}\n'
        '-----END RSA PRIVATE KEY-----',
        identifier: identifier,
      );

  Future<AtSshKeyPair> _generateEd25519KeyPair(String identifier) async {
    var keyPair2 = await Ed25519().newKeyPair();
    var pemText = encodeEd25519Private(
      privateBytes: await keyPair2.extractPrivateKeyBytes(),
      publicBytes: (await keyPair2.extractPublicKey()).bytes,
    );
    return AtSshKeyPair.fromPem(pemText, identifier: identifier);
  }

  @override
  FutureOr addKeyPair({required AtSshKeyPair keyPair, String? identifier}) {
    _keyPairCache[identifier ?? keyPair.identifier] = keyPair;
  }

  @override
  FutureOr deleteKeyPair({required String identifier}) {
    _keyPairCache.remove(identifier);
  }
}
