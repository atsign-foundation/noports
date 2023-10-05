import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart' show SSHKeyPair;
import 'package:noports_core/utils.dart';
import 'package:ssh_key/ssh_key.dart';



abstract interface class SSHKeyManager {
  Future<Uint8List> getPrivateKey();
  Future<Uint8List> getPublicKey();
  Future<void> init();
  Future<void> setPrivateKey(Uint8List privateKey);
  Future<void> setPublicKey(Uint8List publicKey);
}

void main() async {
  var home = Platform.environment['HOME'];
  String pemText = await File('$home/.ssh/id_ed25519').readAsString();
  SSHKeyPair? keyPair = SSHKeyPair.fromPem(pemText).firstOrNull;

  if (keyPair == null) {
    print('No key pair found');
    return;
  }

  // await File('$home/src/af/sshnoports/.xavierchanth/test_priv_key')
  //     .writeAsString(keyPair.toPem());

  KeyPairData kpd =
      KeyPairData(type: KeyPairType.ed25519, data: keyPair.privateKey);
}
