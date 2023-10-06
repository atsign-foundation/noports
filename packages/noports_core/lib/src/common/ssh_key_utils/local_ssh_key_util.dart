import 'dart:async';
import 'dart:io';

import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as path;
import 'package:posix/posix.dart' show chmod;

class LocalSSHKeyUtil implements AtSSHKeyUtil {
  static const _sshKeygenArgMap = {
    SupportedSSHAlgorithm.rsa: ['-t', 'rsa', '-b', '4096'],
    SupportedSSHAlgorithm.ed25519: ['-t', 'ed25519', '-a', '100'],
  };

  static final Map<String, AtSSHKeyPair> _keyPairCache = {};

  final String homeDirectory;
  bool cacheKeys;
  LocalSSHKeyUtil({String? homeDirectory, this.cacheKeys = true})
      : homeDirectory = homeDirectory ?? getHomeDirectory(throwIfNull: true)!;

  bool get isValidPlatform =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  String get sshHomeDirectory => path.normalize('$homeDirectory/.ssh/');
  String get sshnpHomeDirectory => path.normalize('$homeDirectory/.sshnp/');

  String get _defaultDirectory => sshnpHomeDirectory;

  List<File> _filesFromIdentifier({required String identifier}) {
    return [
      File(path.normalize(identifier)),
      File(path.normalize('$identifier.pub')),
    ];
  }

  Future<List<File>> addKeyPair({
    required AtSSHKeyPair keyPair,
    required String identifier,
  }) async {
    var files = _filesFromIdentifier(identifier: identifier);
    await Future.wait([
      files[0].writeAsString(keyPair.privateKeyContents),
      files[1].writeAsString(keyPair.publicKeyContents),
    ]).catchError((e) => throw e);

    chmod(files[0].path, '600');
    chmod(files[1].path, '644');

    return files;
  }

  @override
  Future<AtSSHKeyPair> getKeyPair(
      {required String identifier, String? passphrase}) async {
    if (_keyPairCache.containsKey((identifier))) {
      return _keyPairCache[(identifier)]!;
    }
    var files = _filesFromIdentifier(identifier: identifier);
    var keyPair = AtSSHKeyPair.fromPem(
      await files[0].readAsString(),
      identifier: identifier,
      passphrase: passphrase,
    );

    if (cacheKeys) {
      _keyPairCache[identifier] = keyPair;
    }
    return keyPair;
  }

  Future<List<FileSystemEntity>> deleteKeyPair(
      {required String identifier}) async {
    var files = _filesFromIdentifier(identifier: identifier);

    return Future.wait(files.map(
      (f) => f.delete(),
    )).catchError((e) => throw e);
  }

  @override
  Future<AtSSHKeyPair> generateKeyPair({
    required String identifier,
    SupportedSSHAlgorithm algorithm = DefaultArgs.sshAlgorithm,
    String? directory,
    String? passphrase,
  }) async {
    String workingDirectory = directory ?? _defaultDirectory;

    await Process.run(
      'ssh-keygen',
      [..._sshKeygenArgMap[algorithm]!, '-f', identifier, '-q', '-N', ''],
      workingDirectory: workingDirectory,
    );

    String pemText =
        await File(path.join(workingDirectory, identifier)).readAsString();

    return AtSSHKeyPair.fromPem(
      pemText,
      passphrase: passphrase,
      directory: directory,
      identifier: identifier,
    );
  }

  /// Add the public key to the authorized_keys file.
  Future<void> authorizePublicKey({
    required String sshPublicKey,
    required int localSshdPort,
    String sessionId = '',
    String permissions = '',
  }) async {
    // Check to see if the ssh public key looks like one!
    if (!sshPublicKey.startsWith('ssh-')) {
      throw ('$sshPublicKey does not look like a public key');
    }

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

  Future<void> deauthorizePublicKey(String sessionId) async {
    try {
      final File file =
          File(path.normalize('$sshHomeDirectory/authorized_keys'));
      // read into List of strings
      final List<String> lines = await file.readAsLines();
      // find the line we want to remove
      lines.removeWhere((element) => element.contains(sessionId));
      // Write back the file and add a \n
      await file.writeAsString(lines.join('\n'));
      await file.writeAsString('\n', mode: FileMode.writeOnlyAppend);
    } catch (e) {
      throw SSHNPError(
        'Failed to remove ephemeral key from authorized_keys',
        error: e,
      );
    }
  }
}
