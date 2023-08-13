import 'dart:convert';
import 'dart:io';
import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';

/// Get the home directory or null if unknown.
String? getHomeDirectory({bool throwIfNull = false}) {
  String? homeDir;
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      homeDir = Platform.environment['HOME'];
    case 'windows':
      homeDir = Platform.environment['USERPROFILE'];
    case 'android':
      // Probably want internal storage.
      homeDir = '/storage/sdcard0';
    case 'ios':
    // iOS doesn't really have a home directory.
    case 'fuchsia':
    // I have no idea.
    default:
      homeDir = null;
  }
  if (throwIfNull && homeDir == null) {
    throw ('\nUnable to determine your home directory: please set environment variable\n\n');
  }
  return homeDir;
}

/// Get the local username or null if unknown
String? getUserName({bool throwIfNull = false}) {
  Map<String, String> envVars = Platform.environment;
  if (Platform.isLinux || Platform.isMacOS) {
    return envVars['USER'];
  } else if (Platform.isWindows) {
    return envVars['USERPROFILE'];
  }
  if (throwIfNull) {
    throw ('\nUnable to determine your username: please set environment variable\n\n');
  }
  return null;
}

Future<bool> fileExists(String file) async {
  bool f = await File(file).exists();
  return f;
}

const String asciiMatcher = r'[a-zA-Z0-9_]{0,15}';

bool checkNonAscii(String test) {
  return RegExp(asciiMatcher).allMatches(test).first.group(0) != test;
}

String getDefaultAtKeysFilePath(String homeDirectory, String? atSign) {
  if (atSign == null) return '';
  return '$homeDirectory/.atsign/keys/${atSign}_key.atKeys'
      .replaceAll('/', Platform.pathSeparator);
}

String getDefaultSshDirectory(String homeDirectory) {
  return '$homeDirectory/.ssh/'.replaceAll('/', Platform.pathSeparator);
}

String getDefaultSshnpDirectory(String homeDirectory) {
  return '$homeDirectory/.sshnp/'.replaceAll('/', Platform.pathSeparator);
}

String getDefaultSshnpConfigDirectory(String homeDirectory) {
  return '$homeDirectory/.sshnp/config'.replaceAll('/', Platform.pathSeparator);
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

/// Assert that the value for key k in Map m is non-null and is of Type t.
/// Throws an ArgumentError if the value is null, or is not of Type t.
void assertValidValue(Map m, String k, Type t) {
  var v = m[k];
  if (v == null || v.runtimeType != t) {
    throw ArgumentError(
        'Parameter $k should be a $t but is actually a ${v.runtimeType} with value $v');
  }
}

/// Return the command which this program should execute in order to start the
/// sshrv program.
/// - In normal usage, sshnp and sshrv are compiled to exe before use, thus the
/// path is [Platform.resolvedExecutable] but with the last part (`sshnp` in
/// this case) replaced with `sshrv`
String getSshrvCommand() {
  late String sshnpDir;
  List<String> pathList =
      Platform.resolvedExecutable.split(Platform.pathSeparator);

  String programName = pathList.last;
  if (programName == 'sshnp' || programName == 'sshnpd') {
    pathList.removeLast();
    sshnpDir = pathList.join(Platform.pathSeparator);

    return '$sshnpDir${Platform.pathSeparator}sshrv';
  } else {
    throw Exception(
        'noports programs are expected to be run from a compiled executable, not via the dart command');
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

Future<void> verifyEnvelopeSignature(AtClient atClient, String requestingAtsign,
    AtSignLogger logger, Map envelope) async {
  final String signature = envelope['signature'];
  Map params = envelope['payload'];
  final hashingAlgo = HashingAlgoType.values.byName(envelope['hashingAlgo']);
  final signingAlgo = SigningAlgoType.values.byName(envelope['signingAlgo']);
  final pk = await getLocallyCachedPK(atClient, requestingAtsign,
      useFileStorage: true);
  AtSigningVerificationInput input = AtSigningVerificationInput(
      jsonEncode(params), base64Decode(signature), pk)
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
/// - in the atClient's storage by default ([useFileStorage] == true) in a
///   "local" record like `local:alice.cached_pks.sshnp@<atClient's atSign>`
/// - in file storage at `~/.atsign/sshnp/cached_pks/alice`
///
/// Note that for storage, the leading `@` in the atSign is stripped off.
Future<String> getLocallyCachedPK(AtClient atClient, String atSign,
    {bool useFileStorage = true}) async {
  atSign = AtUtils.fixAtSign(atSign);

  String? cachedPK =
      await _fetchFromLocalPKCache(atClient, atSign, useFileStorage);
  if (cachedPK != null) {
    return cachedPK;
  }

  var s = 'public:publickey$atSign';
  final AtValue av = await atClient.get(AtKey.fromString(s));
  if (av.value == null) {
    throw AtPublicKeyNotFoundException('Failed to retrieve $s');
  }

  await _storeToLocalPKCache(av.value, atClient, atSign, useFileStorage);

  return av.value;
}

Future<String?> _fetchFromLocalPKCache(
    AtClient atClient, String atSign, bool useFileStorage) async {
  String dontAtMe = atSign.substring(1);
  if (useFileStorage) {
    String fn = '${getHomeDirectory(throwIfNull: true)}'
            '/.atsign/sshnp/cached_pks/$dontAtMe'
        .replaceAll('/', Platform.pathSeparator);
    File f = File(fn);
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
    String pk, AtClient atClient, String atSign, bool useFileStorage) async {
  String dontAtMe = atSign.substring(1);
  if (useFileStorage) {
    String dirName =
        '${getHomeDirectory(throwIfNull: true)}/.atsign/sshnp/cached_pks'
            .replaceAll('/', Platform.pathSeparator);
    String fileName =
        '$dirName/$dontAtMe'.replaceAll('/', Platform.pathSeparator);

    File f = File(fileName);
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
