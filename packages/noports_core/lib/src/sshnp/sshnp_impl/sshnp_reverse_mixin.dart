import 'dart:async';
import 'dart:io';

import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_local_file_mixin.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/utils.dart';

/// Users of this mixin must also use [SSHNPLocalFileMixin]
/// e.g. class [SSHNPReverseImpl] extends [SSHNPImpl] with [SSHNPLocalFileMixin], [SSHNPReverseMixin]
/// Note that the order of mixins is important here.
mixin SSHNPReverseMixin on SSHNPLocalFileMixin {
  /// Set by [generateSshKeys] during [init], if we're not doing direct ssh.
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will write
  /// [sshPublicKey] to ~/.ssh/authorized_keys
  late final String sshPublicKey;

  /// Set by [generateSshKeys] during [init].
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will send the
  /// [sshPrivateKey] to sshnpd
  late final String sshPrivateKey;

  /// Local username, set by [init]
  late final String localUsername;

  @override
  Future<void> init() async {
    await super.init();
    if (initializedCompleter.isCompleted) return;

    localUsername = getUserName(throwIfNull: true)!;

    logger.info('Generating ephemeral keypair');
    try {
      var (String ephemeralPublicKey, String ephemeralPrivateKey) =
          await generateSshKeys(
        rsa: params.rsa,
        sessionId: sessionId,
        sshHomeDirectory: sshHomeDirectory,
      );
      sshPublicKey = ephemeralPublicKey;
      sshPrivateKey = ephemeralPrivateKey;
    } catch (e, s) {
      logger.info('Failed to generate ephemeral keypair');
      throw SSHNPError(
        'Failed to generate ephemeral keypair',
        error: e,
        stackTrace: s,
      );
    }

    try {
      logger.info('Adding ephemeral key to authorized_keys');
      await addEphemeralKeyToAuthorizedKeys(
          sshPublicKey: sshPublicKey,
          localSshdPort: params.localSshdPort,
          sessionId: sessionId);
    } catch (e, s) {
      throw SSHNPError(
        'Failed to add ephemeral key to authorized_keys',
        error: e,
        stackTrace: s,
      );
    }
  }

  @override
  Future<void> cleanUp() async {
    String homeDirectory = getHomeDirectory()!;
    var sshHomeDirectory = getDefaultSshDirectory(homeDirectory);
    logger.info('Tidying up files');
// Delete the generated RSA keys and remove the entry from ~/.ssh/authorized_keys
    await _deleteFile('$sshHomeDirectory/${sessionId}_sshnp');
    await _deleteFile('$sshHomeDirectory/${sessionId}_sshnp.pub');
    await removeEphemeralKeyFromAuthorizedKeys(sessionId, logger,
        sshHomeDirectory: sshHomeDirectory);
    super.cleanUp();
  }

  Future<bool> _deleteFile(String fileName) async {
    try {
      final file = File(fileName);
      await file.delete();
      return true;
    } catch (e) {
      logger.severe("Error deleting file : $fileName");
      return false;
    }
  }

  bool get usingSshrv => sshrvdPort != null;
}
