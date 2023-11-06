import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/sshnp_foundation.dart';

class SshnpDartLocalImpl extends SshnpCore
    with SshnpLocalSshKeyHandler, SshnpDartInitialTunnelHandler {
  SshnpDartLocalImpl({
    required super.atClient,
    required super.params,
  }) {
    _sshnpdChannel = SshnpdDefaultChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
      namespace: this.namespace,
    );
    _sshrvdChannel = SshrvdDartChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
    );
  }

  @override
  SshnpdDefaultChannel get sshnpdChannel => _sshnpdChannel;
  late final SshnpdDefaultChannel _sshnpdChannel;

  @override
  SshrvdDartChannel get sshrvdChannel => _sshrvdChannel;
  late final SshrvdDartChannel _sshrvdChannel;

  @override
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;
    await super.initialize();
    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    /// Ensure that sshnp is initialized
    await callInitialization();

    /// Send an ssh request to sshnpd
    await notify(
      AtKey()
        ..key = 'ssh_request'
        ..namespace = this.namespace
        ..sharedBy = params.clientAtSign
        ..sharedWith = params.sshnpdAtSign
        ..metadata = (Metadata()..ttl = 10000),
      signAndWrapAndJsonEncode(atClient, {
        'direct': true,
        'sessionId': sessionId,
        'host': sshrvdChannel.host,
        'port': sshrvdChannel.port,
      }),
    );

    /// Wait for a response from sshnpd
    var acked = await sshnpdChannel.waitForDaemonResponse();
    if (acked != SshnpdAck.acknowledged) {
      throw SshnpError('sshnpd did not acknowledge the request');
    }

    /// Load the ephemeral private key into a key pair
    AtSshKeyPair ephemeralKeyPair = AtSshKeyPair.fromPem(
      sshnpdChannel.ephemeralPrivateKey,
      identifier: 'ephemeral_$sessionId',
      directory: keyUtil.sshnpHomeDirectory,
    );

    /// Add the key pair to the key utility
    await keyUtil.addKeyPair(
      keyPair: ephemeralKeyPair,
      identifier: ephemeralKeyPair.identifier,
    );

    /// Start the initial tunnel
    SSHClient bean =
        await startInitialTunnel(identifier: ephemeralKeyPair.identifier);

    /// Remove the key pair from the key utility
    await keyUtil.deleteKeyPair(identifier: ephemeralKeyPair.identifier);

    /// Ensure that we clean up after ourselves
    await callDisposal();

    /// Return the command to be executed externally
    return SshnpCommand(
      localPort: localPort,
      host: 'localhost',
      remoteUsername: remoteUsername,
      localSshOptions:
          (params.addForwardsToTunnel) ? null : params.localSshOptions,
      privateKeyFileName: identityKeyPair?.identifier,
      connectionBean: bean,
    );
  }
}