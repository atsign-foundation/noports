import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';

import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:path/path.dart' as path;

const String sshnpDeviceNameRegex = r'[a-z0-9_][a-z0-9_\-]{1,35}';
const String invalidDeviceNameMsg =
    'Device name must only contain alphanumeric characters, "-", or "_"'
    'and may not start with "-". Maximum length of 36 characters.';
const String deviceNameFormatHelp =
    'Alphanumeric characters, "-" or "_" allowed, max length 36.'
    ' First character cannot be "-".';
const String invalidSshKeyPermissionsMsg =
    'Detected newline characters in the ssh public key permissions which malforms the authorized_keys file.';

bool isUnprintable(int codeUnit) {
  return (codeUnit < 33 || codeUnit > 127);
}

/// Returns deviceName with uppercase latin replaced by lowercase, and
/// whitespace replaced with underscores. Note that multiple consecutive
/// whitespace characters will be replaced by a single underscore.
String snakifyDeviceName(String deviceName) {
  return deviceName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}

/// Returns false if the device name does not match [sshnpDeviceNameRegex]
bool invalidDeviceName(String test) {
  return RegExp(sshnpDeviceNameRegex).allMatches(test).first.group(0) != test;
}

/// Checks if the provided atSign's atServer has been properly activated with a public RSA key.
/// `atClient` must be authenticated
/// `atSign` is the atSign to check
/// Returns `true`, if the atSign's cloud secondary server has an existing `public:publickey@` in their server,
/// Returns `false`, if the atSign's cloud secondary *exists*, but does not have an existing `public:publickey@`
/// Throws [AtClientException] if the cloud secondary is invalid or not reachable
Future<bool> atSignIsActivated(final AtClient atClient, String atSign) async {
  final Metadata metadata = Metadata()
    ..isPublic = true
    ..namespaceAware = false;

  final AtKey publicKey = AtKey()
    ..sharedBy = atSign
    ..key = 'publickey'
    ..metadata = metadata;

  try {
    await atClient.get(publicKey);
    return true;
  } catch (e) {
    if (e is AtKeyNotFoundException ||
        (e is AtClientException &&
            e.message.contains("public:publickey") &&
            e.message.contains("does not exist in keystore"))) {
      return false;
    }
    rethrow;
  }
}

void assertValidValue(String name, dynamic v, Type t) {
  if (v == null || v.runtimeType != t) {
    throw ArgumentError(
      'Parameter $name should be a $t but is actually a ${v.runtimeType} with value $v',
    );
  }
}

void assertNullOrValidValue(String name, dynamic v, Type t) {
  if (v == null) {
    return;
  } else {
    return assertValidValue(name, v, t);
  }
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Returns true if [v] is a session id: a String holding a UUID in its
/// 8-4-4-4-12 hexadecimal form, which is how clients generate them.
bool isValidSessionId(dynamic v) => v is String && _uuidPattern.hasMatch(v);

/// Throws an [ArgumentError] unless [v] is a session id as defined by
/// [isValidSessionId].
void assertValidSessionId(dynamic v) {
  if (!isValidSessionId(v)) {
    throw ArgumentError.value(v, 'sessionId', 'must be a UUID');
  }
}

/// Assert that the value for key k in Map m is non-null and is of Type t.
/// Throws an ArgumentError if the value is null, or is not of Type t.
void assertValidMapValue(Map m, String k, Type t) {
  var v = m[k];
  if (v == null || v.runtimeType != t) {
    throw ArgumentError(
      'Parameter $k should be a $t but is actually a ${v.runtimeType} with value $v',
    );
  }
}

/// Assert that the value for key k in Map m is non-null and is of Type t.
/// Throws an ArgumentError if the value is null, or is not of Type t.
void assertNullOrValidMapValue(Map m, String k, Type t) {
  var v = m[k];
  if (v == null) {
    return;
  } else {
    return assertValidMapValue(m, k, t);
  }
}

/// Wraps [payload] in an envelope signed with [atClient]'s atSign encryption
/// key, which [verifyEnvelopeSignature] checks against that atSign's
/// `public:publickey`.
Future<String> signAndWrapAndJsonEncode(AtClient atClient, Map payload) async =>
    jsonEncode(await signAndWrap(atClient, payload));

/// The envelope [signAndWrapAndJsonEncode] encodes.
Future<Map<String, Object?>> signAndWrap(AtClient atClient, Map payload) async {
  final keyPair = await _encryptionKeyPair(atClient);
  return {
    'payload': payload,
    'signature': rsaSignString(
      jsonEncode(payload),
      privateKey: keyPair.atPrivateKey.privateKey,
    ),
    'hashingAlgo': HashingAlgoType.sha256.name,
    'signingAlgo': SigningAlgoType.rsa2048.name,
  };
}

/// Reads [atClient]'s envelope signing keypair now, so that later signatures
/// do not depend on its key source still being readable then.
Future<void> loadEnvelopeSigningKey(AtClient atClient) async {
  await _encryptionKeyPair(atClient);
}

/// Each client's encryption keypair, with the atSign it was read for. An
/// atSign's encryption keypair does not rotate, and a file-backed key source
/// may run a passphrase KDF on every read.
final Expando<({String atSign, RsaKeyPair keyPair})> _encryptionKeyPairs =
    Expando('encryptionKeyPairs');

Future<RsaKeyPair> _encryptionKeyPair(AtClient atClient) async {
  final atSign = atClient.getCurrentAtSign();
  final cached = _encryptionKeyPairs[atClient];
  if (cached != null && cached.atSign == atSign) {
    return cached.keyPair;
  }
  final io = atClient.atKeysIo;
  if (atSign == null || io == null) {
    throw AtClientException.message(
      'Cannot sign: the AtClient for $atSign has no key source',
    );
  }
  final keyPair = (await io.read(atSign)).encryptionKeyPair;
  if (keyPair == null) {
    throw AtClientException.message(
      'Cannot sign: the keys for $atSign hold no RSA encryption keypair',
    );
  }
  _encryptionKeyPairs[atClient] = (atSign: atSign, keyPair: keyPair);
  return keyPair;
}

Future<void> verifyEnvelopeSignature(
  AtClient atClient,
  String requestingAtsign,
  AtSignLogger logger,
  Map envelope) async {
  final String signature = envelope['signature'];
  Map payload = envelope['payload'];
  final hashingAlgo = HashingAlgoType.values.byName(envelope['hashingAlgo']);
  final signingAlgo = SigningAlgoType.values.byName(envelope['signingAlgo']);
  if (signingAlgo != SigningAlgoType.rsa2048) {
    throw AtSigningVerificationException(
      'Unsupported signingAlgo ${signingAlgo.name} from $requestingAtsign',
    );
  }
  // final pk = await getLocallyCachedPK(atClient, requestingAtsign, fs: fs);
  final pk = await getRemotePK(atClient: atClient, atSign: requestingAtsign);
  final verified = await rsaVerifyString(
    jsonEncode(payload),
    signature: signature,
    publicKey: pk,
    hashing: hashingAlgo,
  );
  logger.info('Signature verification result: $verified');
  if (!verified) {
    throw AtSigningVerificationException(
      'signature verification returned false using cached public key for $requestingAtsign $pk',
    );
  }
}

/// Remove all PKs which this atSign has cached in filesystem or in
/// atClient storage
Future<void> clearLocallyCachedPKs({
  required AtSignLogger logger,
  FileSystem? fs,
  AtClient? atClient,
}) async {
  if (fs != null) {
    String dirName = path
        .normalize('${getHomeDirectory()}/.atsign/sshnp/cached_pks')
        .replaceAll('/', Platform.pathSeparator);
    Directory d = fs.directory(dirName);
    if (await d.exists()) {
      logger.shout('Deleting $dirName');
      await d.delete(recursive: true);
    }
  }

  if (atClient != null) {
    // find all `local:` keys which end with `.cached_pks.sshnp`
    List<AtKey> keys = await atClient.getAtKeys(
      regex: r'^local:.*\.cached_pks\.sshnp',
    );
    for (final key in keys) {
      logger.shout('Deleting $key');
      await atClient.delete(key);
    }
  }
}

Future<String> getRemotePK({
  required AtClient atClient,
  required String atSign,
}) async {
  atSign = AtUtils.fixAtSign(atSign);
  var s = 'public:publickey$atSign';
  final AtValue av = await atClient.get(AtKey.fromString(s));
  if (av.value == null) {
    throw AtPublicKeyNotFoundException('Failed to retrieve $s');
  }
  return av.value;
}

/// Feb 5, 2026 - Decided that we should no longer cache public key locally
/// If the PK for [atSign] is in the sshnp local cache, then return it.
/// If it is not, then fetch it via the [atClient], and store it.
///
/// The PK (for e.g. @alice) is stored
/// - in the atClient's storage if [useFileStorage] == false in a
///   "local" record like `local:alice.cached_pks.sshnp@<atClient's atSign>`
/// - in file storage if [useFileStorage] == true (default) at
///   `~/.atsign/sshnp/cached_pks/alice`
///
/// Note that for storage, the leading `@` in the atSign is stripped off.
// Future<String> getLocallyCachedPK(
//   AtClient atClient,
//   String atSign, {
//   FileSystem? fs,
// }) async {
//   atSign = AtUtils.fixAtSign(atSign);
//
//   String? cachedPK = await _fetchFromLocalPKCache(atClient, atSign, fs: fs);
//   if (cachedPK != null) {
//     return cachedPK;
//   }
//
//   var s = 'public:publickey$atSign';
//   final AtValue av = await atClient.get(AtKey.fromString(s));
//   if (av.value == null) {
//     throw AtPublicKeyNotFoundException('Failed to retrieve $s');
//   }
//
//   await _storeToLocalPKCache(av.value, atClient, atSign, fs: fs);
//
//   return av.value;
// }
//
// Future<String?> _fetchFromLocalPKCache(
//   AtClient atClient,
//   String atSign, {
//   FileSystem? fs,
// }) async {
//   String dontAtMe = atSign.substring(1);
//   if (fs != null) {
//     String fn = path.normalize(
//       '${getHomeDirectory()}/.atsign/sshnp/cached_pks/$dontAtMe',
//     );
//     File f = fs.file(fn);
//     if (await f.exists()) {
//       return (await f.readAsString()).trim();
//     } else {
//       return null;
//     }
//   } else {
//     late final AtValue av;
//     try {
//       av = await atClient.get(
//         AtKey.fromString(
//           'local:$dontAtMe.cached_pks.sshnp@${atClient.getCurrentAtSign()!}',
//         ),
//       );
//       return av.value;
//     } on AtKeyNotFoundException catch (_) {
//       return null;
//     }
//   }
// }
//
// Future<bool> _storeToLocalPKCache(
//   String pk,
//   AtClient atClient,
//   String atSign, {
//   FileSystem? fs,
// }) async {
//   String dontAtMe = atSign.substring(1);
//   if (fs != null) {
//     String dirName = path.normalize(
//       '${getHomeDirectory()}/.atsign/sshnp/cached_pks',
//     );
//     String fileName = path.normalize('$dirName/$dontAtMe');
//
//     File f = fs.file(fileName);
//     if (!await f.exists()) {
//       await f.create(recursive: true);
//       await Process.run('chmod', ['-R', 'go-rwx', dirName]);
//     }
//     await f.writeAsString('$pk\n');
//     return true;
//   } else {
//     await atClient.put(
//       AtKey.fromString(
//         'local:$dontAtMe.cached_pks.sshnp@${atClient.getCurrentAtSign()!}',
//       ),
//       pk,
//     );
//     return true;
//   }
// }
