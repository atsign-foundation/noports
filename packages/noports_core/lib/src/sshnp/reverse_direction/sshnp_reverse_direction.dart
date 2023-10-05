import 'dart:async';

import 'package:noports_core/src/sshnp/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_local_file_mixin.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';
import 'package:noports_core/utils.dart';

abstract class SSHNPReverseDirection extends SSHNPImpl
    with SSHNPLocalFileMixin {
  SSHNPReverseDirection({
    required super.atClient,
    required super.params,
    SSHRVGenerator? sshrvGenerator,
    super.shouldInitialize,
  }) : sshrvGenerator = sshrvGenerator ?? DefaultArgs.sshrvGenerator;

  /// Function used to generate a [SSHRV] instance ([SSHRV.localbinary] by default)
  final SSHRVGenerator sshrvGenerator;

  /// Set by [generateEphemeralSshKeys] during [init], if we're not doing direct ssh.
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will write
  /// [sshPublicKey] to ~/.ssh/authorized_keys
  late final String sshPublicKey;

  /// Set by [generateEphemeralSshKeys] during [init].
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
          await generateEphemeralSshKeys(
        algorithm: params.sshAlgorithm,
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
    await cleanUpEphemeralSshKeys(
        sessionId: sessionId, sshHomeDirectory: sshHomeDirectory);
    await removeEphemeralKeyFromAuthorizedKeys(sessionId, logger,
        sshHomeDirectory: sshHomeDirectory);
    await super.cleanUp();
  }

  bool get usingSshrv => sshrvdPort != null;
}
