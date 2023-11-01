import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as path;

export 'ssh_key_utils/dart_ssh_key_util.dart';
export 'ssh_key_utils/local_ssh_key_util.dart';

class AtSshKeyPair {
  @protected
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

  // TODO consider adding this function
  // void destroy() {
  //   throw UnimplementedError();
  // }
}

abstract interface class AtSSHKeyUtil {
  FutureOr<AtSshKeyPair> generateKeyPair({
    required String identifier,
    SupportedSSHAlgorithm algorithm,
  });

  FutureOr<AtSshKeyPair> getKeyPair({
    required String identifier,
  });
}
