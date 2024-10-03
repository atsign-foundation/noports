import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';

import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:path/path.dart' as path;

const String sshnpDeviceNameRegex = r'[a-z0-9][a-z0-9_\-]{1,35}';
const String invalidDeviceNameMsg = 'Device name must be alphanumeric'
    ' snake case, max length 36. First char must be a-z or 0-9.';
const String deviceNameFormatHelp = 'Alphanumeric snake case, max length 36. First char must be a-z or 0-9.';
const String invalidSshKeyPermissionsMsg =
    'Detected newline characters in the ssh public key permissions which malforms the authorized_keys file.';

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
        'Parameter $name should be a $t but is actually a ${v.runtimeType} with value $v');
  }
}

void assertNullOrValidValue(String name, dynamic v, Type t) {
  if (v == null) {
    return;
  } else {
    return assertValidValue(name, v, t);
  }
}

/// Assert that the value for key k in Map m is non-null and is of Type t.
/// Throws an ArgumentError if the value is null, or is not of Type t.
void assertValidMapValue(Map m, String k, Type t) {
  var v = m[k];
  if (v == null || v.runtimeType != t) {
    throw ArgumentError(
        'Parameter $k should be a $t but is actually a ${v.runtimeType} with value $v');
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

String signAndWrapAndJsonEncode(AtClient atClient, Map payload) {
  Map envelope = {'payload': payload};

  final AtSigningInput signingInput = AtSigningInput(jsonEncode(payload))
    ..signingMode = AtSigningMode.data;
  final AtSigningResult sr = atClient.atChops!.sign(signingInput);

  final String signature = sr.result.toString();
  envelope['signature'] = signature;
  envelope['hashingAlgo'] = sr.atSigningMetaData.hashingAlgoType!.name;
  envelope['signingAlgo'] = sr.atSigningMetaData.signingAlgoType!.name;
  return jsonEncode(envelope);
}

Future<void> verifyEnvelopeSignature(
  AtClient atClient,
  String requestingAtsign,
  AtSignLogger logger,
  Map envelope, {
  FileSystem? fs,
}) async {
  final String signature = envelope['signature'];
  Map payload = envelope['payload'];
  final hashingAlgo = HashingAlgoType.values.byName(envelope['hashingAlgo']);
  final signingAlgo = SigningAlgoType.values.byName(envelope['signingAlgo']);
  final pk = await getLocallyCachedPK(atClient, requestingAtsign, fs: fs);
  AtSigningVerificationInput input = AtSigningVerificationInput(
      jsonEncode(payload), base64Decode(signature), pk)
    ..signingMode = AtSigningMode.data
    ..signingAlgoType = signingAlgo
    ..hashingAlgoType = hashingAlgo;

  AtSigningResult svr = atClient.atChops!.verify(input);
  logger.info('Signing Verification Result: $svr');
  logger.info('svr.result is a ${svr.result.runtimeType}');
  logger.info('svr.result is ${svr.result}');
  if (svr.result != true) {
    throw AtSigningVerificationException(
        'signature verification returned false using cached public key for $requestingAtsign $pk');
  }
}

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
Future<String> getLocallyCachedPK(
  AtClient atClient,
  String atSign, {
  FileSystem? fs,
}) async {
  atSign = AtUtils.fixAtSign(atSign);

  String? cachedPK = await _fetchFromLocalPKCache(atClient, atSign, fs: fs);
  if (cachedPK != null) {
    return cachedPK;
  }

  var s = 'public:publickey$atSign';
  final AtValue av = await atClient.get(AtKey.fromString(s));
  if (av.value == null) {
    throw AtPublicKeyNotFoundException('Failed to retrieve $s');
  }

  await _storeToLocalPKCache(av.value, atClient, atSign, fs: fs);

  return av.value;
}

Future<String?> _fetchFromLocalPKCache(
  AtClient atClient,
  String atSign, {
  FileSystem? fs,
}) async {
  String dontAtMe = atSign.substring(1);
  if (fs != null) {
    String fn = path
        .normalize('${getHomeDirectory()}/.atsign/sshnp/cached_pks/$dontAtMe');
    File f = fs.file(fn);
    if (await f.exists()) {
      return (await f.readAsString()).trim();
    } else {
      return null;
    }
  } else {
    late final AtValue av;
    try {
      av = await atClient.get(AtKey.fromString(
          'local:$dontAtMe.cached_pks.sshnp@${atClient.getCurrentAtSign()!}'));
      return av.value;
    } on AtKeyNotFoundException catch (_) {
      return null;
    }
  }
}

Future<bool> _storeToLocalPKCache(
  String pk,
  AtClient atClient,
  String atSign, {
  FileSystem? fs,
}) async {
  String dontAtMe = atSign.substring(1);
  if (fs != null) {
    String dirName =
        path.normalize('${getHomeDirectory()}/.atsign/sshnp/cached_pks');
    String fileName = path.normalize('$dirName/$dontAtMe');

    File f = fs.file(fileName);
    if (!await f.exists()) {
      await f.create(recursive: true);
      await Process.run('chmod', ['-R', 'go-rwx', dirName]);
    }
    await f.writeAsString('$pk\n');
    return true;
  } else {
    await atClient.put(
        AtKey.fromString(
            'local:$dontAtMe.cached_pks.sshnp@${atClient.getCurrentAtSign()!}'),
        pk);
    return true;
  }
}
