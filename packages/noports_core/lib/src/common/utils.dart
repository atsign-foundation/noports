import 'dart:convert';
import 'dart:io';
import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:path/path.dart' as path;

import 'package:path_provider/path_provider.dart' as path_provider;

/// Get the home directory or null if unknown.
Future<String> getHomeDirectory() async {
  String? homeDir;
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      homeDir = Platform.environment['HOME'];
    case 'windows':
      homeDir = Platform.environment['USERPROFILE'];
    case 'android':
      // android to try external storage first and fallback to the ApplicationSupportDirectory
      homeDir = await path_provider
          .getExternalStorageDirectory()
          .then((dir) => dir?.path);
    case 'ios':
    case 'fuchsia':
    default:
      // ios and fuchsia to use the ApplicationSupportDirectory
      homeDir = null;
  }
  return homeDir ??
      await path_provider
          .getApplicationSupportDirectory()
          .then((dir) => dir.path);
}

/// Get the local username or null if unknown
String? getUserName({bool throwIfNull = false}) {
  Map<String, String> envVars = Platform.environment;
  if (!Platform.isWindows) {
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

const String sshnpDeviceNameRegex = r'[a-zA-Z0-9_]{0,15}';

bool checkNonAscii(String test) {
  return RegExp(sshnpDeviceNameRegex).allMatches(test).first.group(0) != test;
}

String getDefaultAtKeysFilePath(String homeDirectory, String? atSign) {
  if (atSign == null) return '';
  return path.normalize('$homeDirectory/.atsign/keys/${atSign}_key.atKeys');
}

String getDefaultSshDirectory(String homeDirectory) {
  return path.normalize('$homeDirectory/.ssh/');
}

String getDefaultSshnpDirectory(String homeDirectory) {
  return path.normalize('$homeDirectory/.sshnp/');
}

String getDefaultSshnpConfigDirectory(String homeDirectory) {
  return path.normalize('$homeDirectory/.sshnp/config');
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

Future<(String, String)> generateSshKeys(
    {required bool rsa,
    required String sessionId,
    String? sshHomeDirectory}) async {
  sshHomeDirectory ??= getDefaultSshDirectory(await getHomeDirectory());
  if (!Directory(sshHomeDirectory).existsSync()) {
    Directory(sshHomeDirectory).createSync();
  }

  if (rsa) {
    await Process.run('ssh-keygen',
        ['-t', 'rsa', '-b', '4096', '-f', '${sessionId}_sshnp', '-q', '-N', ''],
        workingDirectory: sshHomeDirectory);
  } else {
    await Process.run(
        'ssh-keygen',
        [
          '-t',
          'ed25519',
          '-a',
          '100',
          '-f',
          '${sessionId}_sshnp',
          '-q',
          '-N',
          ''
        ],
        workingDirectory: sshHomeDirectory);
  }

  String sshPublicKey =
      await File('$sshHomeDirectory/${sessionId}_sshnp.pub').readAsString();
  String sshPrivateKey =
      await File('$sshHomeDirectory/${sessionId}_sshnp').readAsString();

  return (sshPublicKey, sshPrivateKey);
}

Future<void> addEphemeralKeyToAuthorizedKeys(
    {required String sshPublicKey,
    required int localSshdPort,
    String sessionId = '',
    String permissions = ''}) async {
  // Check to see if the ssh public key looks like one!
  if (!sshPublicKey.startsWith('ssh-')) {
    throw ('$sshPublicKey does not look like a public key');
  }

  String homeDirectory = await getHomeDirectory();
  var sshHomeDirectory = getDefaultSshDirectory(homeDirectory);

  if (!Directory(sshHomeDirectory).existsSync()) {
    Directory(sshHomeDirectory).createSync();
  }

  // Check to see if the ssh Publickey is already in the authorized_keys file.
  // If not, then append it.
  var authKeys = File(path.normalize('$sshHomeDirectory/authorized_keys'));

  var authKeysContent = await authKeys.readAsString();
  if (!authKeysContent.endsWith('\n')) {
    await authKeys.writeAsString('\n', mode: FileMode.append);
  }

  if (!authKeysContent.contains(sshPublicKey)) {
    if (permissions.isNotEmpty && !permissions.startsWith(',')) {
      permissions = ',$permissions';
    }
    // Set up a safe authorized_keys file, for the ssh tunnel
    await authKeys.writeAsString(
      'command="echo \\"ssh session complete\\";sleep 20"'
      ',PermitOpen="localhost:$localSshdPort"'
      '$permissions'
      ' '
      '${sshPublicKey.trim()}'
      ' '
      'sshnp_ephemeral_$sessionId\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

Future<void> removeEphemeralKeyFromAuthorizedKeys(
    String sessionId, AtSignLogger logger,
    {String? sshHomeDirectory}) async {
  try {
    sshHomeDirectory ??= getDefaultSshDirectory(await getHomeDirectory());
    final File file = File(path.normalize('$sshHomeDirectory/authorized_keys'));
    logger.info('Removing ephemeral key for session $sessionId'
        ' from ${file.absolute.path}');
    // read into List of strings
    final List<String> lines = await file.readAsLines();
    // find the line we want to remove
    lines.removeWhere((element) => element.contains(sessionId));
    // Write back the file and add a \n
    await file.writeAsString(lines.join('\n'));
    await file.writeAsString('\n', mode: FileMode.writeOnlyAppend);
  } catch (e) {
    logger.severe(
        'Unable to tidy up ${path.normalize('$sshHomeDirectory/authorized_keys')}');
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
  Map payload = envelope['payload'];
  final hashingAlgo = HashingAlgoType.values.byName(envelope['hashingAlgo']);
  final signingAlgo = SigningAlgoType.values.byName(envelope['signingAlgo']);
  final pk = await getLocallyCachedPK(atClient, requestingAtsign,
      useFileStorage: true);
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
    String fn = path.normalize(
        '${await getHomeDirectory()}/.atsign/sshnp/cached_pks/$dontAtMe');
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
        path.normalize('${await getHomeDirectory()}/.atsign/sshnp/cached_pks');
    String fileName = path.normalize('$dirName/$dontAtMe');

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
