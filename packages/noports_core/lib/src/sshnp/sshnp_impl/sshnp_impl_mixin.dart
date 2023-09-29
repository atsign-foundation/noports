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

  @override
  Future<void> init() async {
    await super.init();
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
      throw SSHNPError(
        'Failed to generate ephemeral keypair',
        error: e,
        stackTrace: s,
      );
    }

    try {
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

    initializedCompleter.complete();
  }

  @override
  Future<void> cleanUp() async {
    await cleanUpAfterReverseSsh(this);
    super.cleanUp();
  }

  bool get usingSshrv => sshrvdPort != null;
}

mixin SSHNPForwardDirection on SSHNPImpl {
  // Direct ssh is only ever done with a sshrvd host
  // So we should expect that sshrvdPort is never null
  // Hence overriding the getter and setter to make it non-nullable
  late int _sshrvdPort;
  @override
  int get sshrvdPort => _sshrvdPort;
  @override
  set sshrvdPort(int? port) => _sshrvdPort = port!;
}
