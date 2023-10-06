import 'dart:async';

import 'package:noports_core/src/sshnp/sshnp_core.dart';
import 'package:noports_core/src/sshnp/mixins/sshnp_ssh_key_handler.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';
import 'package:noports_core/utils.dart';

abstract class SSHNPReverse extends SSHNPCore with SSHNPLocalSSHKeyHandler {
  SSHNPReverse({
    required super.atClient,
    required super.params,
    SSHRVGenerator? sshrvGenerator,
    super.shouldInitialize,
  }) : sshrvGenerator = sshrvGenerator ?? DefaultArgs.sshrvGenerator;

  /// Function used to generate a [SSHRV] instance ([SSHRV.localbinary] by default)
  final SSHRVGenerator sshrvGenerator;

  /// Set by [generateEphemeralSshKeys] during [init], if we're not doing direct ssh.
  /// sshnp generates a new keypair for each ssh session, using the algorithm specified
  /// in [params.sshAlgorithm].
  /// sshnp will write [ephemeralKeyPair] to ~/.ssh/ephemeral_$sessionId
  /// sshnp will write [ephemeralKeyPair.publicKey] to ~/.ssh/authorized_keys
  /// sshnp will send the [ephemeralKeyPair.privateKey] to sshnpd
  late final AtSSHKeyPair ephemeralKeyPair;

  /// Local username, set by [init]
  late final String localUsername;

  @override
  Future<void> init() async {
    await super.init();
    if (initializedCompleter.isCompleted) return;

    localUsername = getUserName(throwIfNull: true)!;

    logger.info('Generating ephemeral keypair');
    try {
      ephemeralKeyPair = await keyUtil.generateKeyPair(
        algorithm: params.sshAlgorithm,
        identifier: 'ephemeral_$sessionId',
        directory: keyUtil.sshnpHomeDirectory,
      );
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
      await keyUtil.authorizePublicKey(
        sshPublicKey: ephemeralKeyPair.publicKeyContents,
        localSshdPort: params.localSshdPort,
        sessionId: sessionId,
      );
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
    logger.info('Tidying up files');
// Delete the generated RSA keys and remove the entry from ~/.ssh/authorized_keys
    await keyUtil.deleteKeyPair(identifier: ephemeralKeyPair.identifier);
    await keyUtil.deauthorizePublicKey(sessionId);
    await super.cleanUp();
  }

  bool get usingSshrv => sshrvdPort != null;
}
