import 'dart:typed_data';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';

/// Reads the atKeys for [atsign] out of the keychain and returns the bytes of a
/// self-encryption-key encrypted `.atKeys` file, matching the format produced
/// by the atSign tooling.
Future<Uint8List> exportAtKeysBytes(String atsign) async {
  final KeychainAtKeysIo io = KeychainAtKeysIo();
  final AtKeys atKeys = await io.read(atsign);
  final String atKeysData = await io.encryptAtKeysWithSelfEncKey(
    atKeys,
    PkamAuthMode.keysFile,
    atsign,
  );
  return Uint8List.fromList(atKeysData.codeUnits);
}
