import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/sshnp_foundation.dart';

class SshnpUnsignedImpl extends SshnpCore with SshnpLocalSshKeyHandler {
  SshnpUnsignedImpl({
    required super.atClient,
    required super.params,
  }) {
    _sshnpdChannel = SshnpdUnsignedChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
      namespace: this.namespace,
    );
    _sshrvdChannel = SshrvdExecChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
    );
  }

  @override
  SshnpdUnsignedChannel get sshnpdChannel => _sshnpdChannel;
  late final SshnpdUnsignedChannel _sshnpdChannel;

  @override
  SshrvdExecChannel get sshrvdChannel => _sshrvdChannel;
  late final SshrvdExecChannel _sshrvdChannel;

  @override
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;
    await super.initialize();

    /// Generate an ephemeral key pair for this session
    AtSshKeyPair ephemeralKeyPair = await keyUtil.generateKeyPair(
      identifier: 'ephemeral_$sessionId',
      directory: keyUtil.sshnpHomeDirectory,
    );

    /// Authorize the public key so sshnpd can connect to us
    await keyUtil.authorizePublicKey(
      sshPublicKey: ephemeralKeyPair.publicKeyContents,
      localSshdPort: params.localSshdPort,
      sessionId: sessionId,
    );

    /// Share our private key with sshnpd so it can connect to us
    AtKey sendOurPrivateKeyToSshnpd = AtKey()
      ..key = 'privatekey'
      ..sharedBy = params.clientAtSign
      ..sharedWith = params.sshnpdAtSign
      ..namespace = this.namespace
      ..metadata = (Metadata()..ttl = 10000);
    await notify(
      sendOurPrivateKeyToSshnpd,
      ephemeralKeyPair.privateKeyContents,
    );

    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    /// Ensure that sshnp is initialized
    await callInitialization();

    /// Start sshrv
    var bean = await sshrvdChannel.runSshrv();

    /// Send an sshd request to sshnpd
    /// This will notify it that it can now connect to us
    await notify(
      AtKey()
        ..key = 'sshd'
        ..namespace = this.namespace
        ..sharedBy = params.clientAtSign
        ..sharedWith = params.sshnpdAtSign
        ..metadata = (Metadata()..ttl = 10000),
      '$localPort ${sshrvdChannel.port} ${keyUtil.username} ${sshrvdChannel.host} $sessionId',
    );

    /// Wait for a response from sshnpd
    var acked = await sshnpdChannel.waitForDaemonResponse();
    if (acked != SshnpdAck.acknowledged) {
      throw SshnpError('sshnpd did not acknowledge the request');
    }

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