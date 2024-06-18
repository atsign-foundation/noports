import 'dart:async';

import 'package:meta/meta.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as path;
import 'package:posix/posix.dart' show chmod;

class LocalSshKeyUtil implements AtSshKeyUtil {
  static const _sshKeygenArgMap = {
    SupportedSshAlgorithm.rsa: ['-t', 'rsa', '-b', '4096'],
    SupportedSshAlgorithm.ed25519: ['-t', 'ed25519', '-a', '100'],
  };

  static final Map<String, AtSshKeyPair> _keyPairCache = {};

  @visibleForTesting
  final FileSystem fs;

  final String homeDirectory;
  late final String sshHomeDirectory;
  late final String sshnpHomeDirectory;
  bool cacheKeys;

  LocalSshKeyUtil({
    String? homeDirectory,
    this.cacheKeys = true,
    @visibleForTesting this.fs = const LocalFileSystem(),
  }) : homeDirectory = homeDirectory ?? getHomeDirectory(throwIfNull: true)! {
    sshHomeDirectory = path.normalize('$homeDirectory/.ssh/');
    sshnpHomeDirectory = path.normalize('$homeDirectory/.sshnp/');

    if (!fs.directory(sshHomeDirectory).existsSync()) {
      fs.directory(sshHomeDirectory).createSync(recursive: true);
    }
    if (!fs.directory(sshnpHomeDirectory).existsSync()) {
      fs.directory(sshnpHomeDirectory).createSync(recursive: true);
    }
    if (!Platform.isWindows) {
      chmod(sshHomeDirectory, '700');
      chmod(sshnpHomeDirectory, '700');
    }
  }

  bool get isValidPlatform =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  String get _defaultDirectory => sshnpHomeDirectory;

  String get username => getUserName(throwIfNull: true)!;

  List<File> _filesFromIdentifier({required String identifier}) {
    return [
      fs.file(path.normalize(identifier)),
      fs.file(path.normalize('$identifier.pub')),
    ];
  }

  @override
  Future<List<File>> addKeyPair({
    required AtSshKeyPair keyPair,
    String? identifier,
  }) async {
    var files =
        _filesFromIdentifier(identifier: identifier ?? keyPair.identifier);
    await Future.wait([
      files[0].create(recursive: true),
      files[1].create(recursive: true),
    ]).catchError((e) => throw e);

    await Future.wait([
      files[0].writeAsString(keyPair.privateKeyContents),
      files[1].writeAsString(keyPair.publicKeyContents),
    ]).catchError((e) => throw e);

    if (!Platform.isWindows) {
      chmod(files[0].path, '600');
      chmod(files[1].path, '644');
    }

    return files;
  }

  @override
  Future<AtSshKeyPair> getKeyPair(
      {required String identifier, String? passphrase}) async {
    if (_keyPairCache.containsKey((identifier))) {
      return _keyPairCache[(identifier)]!;
    }
    var files = _filesFromIdentifier(identifier: identifier);
    var keyPair = AtSshKeyPair.fromPem(
      await files[0].readAsString(),
      identifier: identifier,
      passphrase: passphrase,
    );

    if (cacheKeys) {
      _keyPairCache[identifier] = keyPair;
    }
    return keyPair;
  }

  @override
  Future<List<FileSystemEntity>> deleteKeyPair(
      {required String identifier}) async {
    var files = _filesFromIdentifier(identifier: identifier);

    return Future.wait(files.map(
      (f) => f.delete(),
    )).catchError((e) => throw e);
  }

  @override
  Future<AtSshKeyPair> generateKeyPair({
    required String identifier,
    SupportedSshAlgorithm algorithm = DefaultArgs.sshAlgorithm,
    String? directory,
    String? passphrase,
    @visibleForTesting ProcessRunner processRunner = Process.run,
  }) async {
    String workingDirectory = directory ?? _defaultDirectory;

    await processRunner(
      'ssh-keygen',
      [..._sshKeygenArgMap[algorithm]!, '-f', identifier, '-q', '-N', ''],
      workingDirectory: workingDirectory,
    );

    String pemText =
        await fs.file(path.join(workingDirectory, identifier)).readAsString();

    return AtSshKeyPair.fromPem(
      pemText,
      passphrase: passphrase,
      directory: workingDirectory,
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
    // Check to see if the ssh public key is
    // supported keys by the dartssh2 package
    if (!sshPublicKey.startsWith(RegExp(
        r'^(ecdsa-sha2-nistp)|(rsa-sha2-)|(ssh-rsa)|(ssh-ed25519)|(ecdsa-sha2-nistp)'))) {
      throw ('$sshPublicKey does not look like a public key');
    }

    // Check to see if the ssh Publickey is already in the authorized_keys file.
    // If not, then append it.
    var authKeys = fs.file(path.normalize('$sshHomeDirectory/authorized_keys'));

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
          fs.file(path.normalize('$sshHomeDirectory/authorized_keys'));
      // read into List of strings
      final List<String> lines = await file.readAsLines();
      // find the line we want to remove
      lines.removeWhere((element) => element.contains(sessionId));
      // Write back the file and add a \n
      await file.writeAsString(lines.join('\n'));
      await file.writeAsString('\n', mode: FileMode.writeOnlyAppend);
    } catch (e) {
      throw SshnpError(
        'Failed to remove ephemeral key from authorized_keys',
        error: e,
      );
    }
  }
}
