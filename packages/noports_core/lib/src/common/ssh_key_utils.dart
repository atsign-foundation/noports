import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:openssh_ed25519/openssh_ed25519.dart';
import 'package:path/path.dart' as path;
import 'package:posix/posix.dart' show chmod;

class AtSSHKeyPair {
  @protected
  final SSHKeyPair keyPair;

  final String? directory;
  final String? identifier;

  AtSSHKeyPair.fromPem(
    String pemText, {
    String? passphrase,
    this.directory,
    this.identifier,
  }) : keyPair = SSHKeyPair.fromPem(pemText, passphrase).firstOrNull ??
            (throw ArgumentError.value(pemText, 'pemText', 'Invalid PEM text'));

  String get type => keyPair.type;

  String get privateKeyContents => keyPair.toPem();

  String get publicKeyContents =>
      '$type ${base64.encode(keyPair.toPublicKey().encode())}';

  String? get privateKeyFileName =>
      identifier == null ? null : path.join(directory ?? '', identifier ?? '');

  String? get publicKeyFileName =>
      identifier == null ? null : '${privateKeyFileName!}.pub';
}

abstract interface class AtSSHKeyUtil {
  FutureOr<AtSSHKeyPair> generateKeyPair({
    required String identifier,
    required SupportedSSHAlgorithm algorithm,
  });
}

class DartSSHKeyUtil implements AtSSHKeyUtil {
  @override
  FutureOr<AtSSHKeyPair> generateKeyPair({
    required String identifier,
    required SupportedSSHAlgorithm algorithm,
  }) {
    switch (algorithm) {
      case SupportedSSHAlgorithm.rsa:
        return _generateRSAKeyPair(identifier);
      case SupportedSSHAlgorithm.ed25519:
        return _generateEd25519KeyPair(identifier);
    }
  }

  AtSSHKeyPair _generateRSAKeyPair(String identifier) => AtSSHKeyPair.fromPem(
        AtChopsUtil.generateRSAKeyPair(keySize: 4096).privateKey.toPEM(),
        identifier: identifier,
      );

  Future<AtSSHKeyPair> _generateEd25519KeyPair(String identifier) async {
    var keyPair2 = await Ed25519().newKeyPair();
    var pemText = encodeEd25519Private(
      privateBytes: await keyPair2.extractPrivateKeyBytes(),
      publicBytes: (await keyPair2.extractPublicKey()).bytes,
    );
    return AtSSHKeyPair.fromPem(
      pemText,
      identifier: identifier,
    );
  }
}

class LocalSSHKeyUtil implements AtSSHKeyUtil {
  static const _sshKeygenArgMap = {
    SupportedSSHAlgorithm.rsa: ['-t', 'rsa', '-b', '4096'],
    SupportedSSHAlgorithm.ed25519: ['-t', 'ed25519', '-a', '100'],
  };

  final String homeDirectory;

  LocalSSHKeyUtil({String? homeDirectory})
      : homeDirectory = homeDirectory ?? getHomeDirectory(throwIfNull: true)!;

  String get sshHomeDirectory => path.normalize('$homeDirectory/.ssh/');
  String get sshnpHomeDirectory => path.normalize('$homeDirectory/.sshnp/');

  Future<List<File>> writeKeyPair({
    required AtSSHKeyPair keyPair,
    required String identifier,
    String? directory,
  }) async {
    File privateKeyFile =
        File(path.join(directory ?? sshnpHomeDirectory, identifier));
    File publicKeyFile =
        File(path.join(directory ?? sshnpHomeDirectory, '$identifier.pub'));

    await Future.wait([
      privateKeyFile.writeAsString(keyPair.privateKeyContents),
      publicKeyFile.writeAsString(keyPair.publicKeyContents),
    ]);

    chmod(privateKeyFile.path, '600');
    chmod(publicKeyFile.path, '644');

    return [privateKeyFile, publicKeyFile];
  }


  Future<List<FileSystemEntity>> deleteKeyPair(
      {required String identifier, String? directory}) async {
    String workingDirectory = directory ?? sshnpHomeDirectory;

    return Future.wait([
      File(path.join(workingDirectory, identifier)).delete(),
      File(path.join(workingDirectory, '$identifier.pub')).delete(),
    ]);
  }

  @override
  Future<AtSSHKeyPair> generateKeyPair({
    required SupportedSSHAlgorithm algorithm,
    required String identifier,
    String? directory,
    String? passphrase,
  }) async {
    String workingDirectory = directory ?? sshnpHomeDirectory;

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
