import 'dart:async';

import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/utils.dart';

mixin SSHNPReverseDirection on SSHNPImpl {
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
    await cleanUpAfterReverseSsh(this);
    super.cleanUp();
  }

  bool get usingSshrv => sshrvdPort != null;
}
