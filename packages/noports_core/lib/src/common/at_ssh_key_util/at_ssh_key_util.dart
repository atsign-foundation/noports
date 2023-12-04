import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as path;

export 'dart_ssh_key_util.dart';
export 'local_ssh_key_util.dart';

abstract interface class AtSshKeyUtil {
  FutureOr<AtSshKeyPair> generateKeyPair({
    required String identifier,
    SupportedSshAlgorithm algorithm,
  });

  FutureOr<AtSshKeyPair> getKeyPair({
    required String identifier,
  });

  FutureOr<dynamic> addKeyPair({
    required AtSshKeyPair keyPair,
    String? identifier,
  });

  FutureOr<dynamic> deleteKeyPair({
    required String identifier,
  });
}

class AtSshKeyPair {
  final SSHKeyPair keyPair;
  final String identifier;

  AtSshKeyPair.fromPem(
    String pemText, {
    required String identifier,
    String? directory,
    String? passphrase,
  })  : identifier =
            directory == null ? identifier : path.join(directory, identifier),
        keyPair = SSHKeyPair.fromPem(pemText, passphrase).firstOrNull ??
            (throw ArgumentError.value(pemText, 'pemText', 'Invalid PEM text'));

  String get type => keyPair.type;

  String get privateKeyContents => keyPair.toPem();

  String get publicKeyContents =>
      '$type ${base64.encode(keyPair.toPublicKey().encode())}';

  String get privateKeyFileName => identifier;
  String get publicKeyFileName => '$privateKeyFileName.pub';
}
