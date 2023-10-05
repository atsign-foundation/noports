import 'dart:async';
import 'dart:io';
import 'package:at_utils/at_utils.dart';
import 'package:path/path.dart' as path;

/// Get the home directory or null if unknown.
String? getHomeDirectory({bool throwIfNull = false}) {
  String? homeDir;
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      homeDir = Platform.environment['HOME'];
      break;
    case 'windows':
      homeDir = Platform.environment['USERPROFILE'];
      break;
    default:
      // ios and fuchsia to use the ApplicationSupportDirectory
      homeDir = null;
      break;
  }
  print('homeDir: $homeDir');
  if (throwIfNull && homeDir == null) {
    throw ('Unable to determine your username: please set environment variable');
  }
  return homeDir;
}

/// Get the local username or null if unknown
String? getUserName({bool throwIfNull = false}) {
  Map<String, String> envVars = Platform.environment;
  String? userName;
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      userName = envVars['USER'];
      break;
    case 'windows':
      userName = envVars['USERNAME'];
      break;
    default:
      userName = null;
      break;
  }
  if (throwIfNull && userName == null) {
    throw ('Unable to determine your username: please set environment variable');
  }
  return null;
}

Future<bool> fileExists(String file) async {
  bool f = await File(file).exists();
  return f;
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

(String, String, String) _getEphemeralKeysPath(
    String? sshHomeDirectory, String sessionId) {
  sshHomeDirectory ??= getDefaultSshDirectory(getHomeDirectory()!);
  if (!Directory(sshHomeDirectory).existsSync()) {
    Directory(sshHomeDirectory).createSync();
  }

  return (
    sshHomeDirectory,
    '$sshHomeDirectory/${sessionId}_sshnp.pub',
    '$sshHomeDirectory/${sessionId}_sshnp'
  );
}

Future<(String, String)> generateEphemeralSshKeys(
    {required bool rsa,
    required String sessionId,
    String? sshHomeDirectory}) async {
  var (normalizedSshHomeDirectory, sshPublicKeyPath, sshPrivateKeyPath) =
      _getEphemeralKeysPath(sshHomeDirectory, sessionId);
  sshHomeDirectory = normalizedSshHomeDirectory;

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

  var keys = await Future.wait([
    File(sshPublicKeyPath).readAsString(),
    File(sshPrivateKeyPath).readAsString()
  ]);

  return (keys[0], keys[1]);
}

Future<void> cleanUpEphemeralSshKeys({
  required String sessionId,
  String? sshHomeDirectory,
}) async {
  var (_, sshPublicKeyPath, sshPrivateKeyPath) =
      _getEphemeralKeysPath(sshHomeDirectory, sessionId);
  await Future.wait([
    File(sshPublicKeyPath).delete(),
    File(sshPrivateKeyPath).delete(),
  ]);
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

  String homeDirectory = getHomeDirectory()!;
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
    sshHomeDirectory ??= getDefaultSshDirectory(getHomeDirectory()!);
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
