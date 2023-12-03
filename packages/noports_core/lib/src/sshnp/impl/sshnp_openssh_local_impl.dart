import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp_foundation.dart';

class SshnpOpensshLocalImpl extends SshnpCore
    with SshnpLocalSshKeyHandler, SshnpOpensshSshSessionHandler {
  SshnpOpensshLocalImpl({
    required super.atClient,
    required super.params,
    required super.userKeyPairIdentifier,
  }) {
    _sshnpdChannel = SshnpdDefaultChannel(
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
  SshnpdDefaultChannel get sshnpdChannel => _sshnpdChannel;
  late final SshnpdDefaultChannel _sshnpdChannel;

  @override
  SshrvdExecChannel get sshrvdChannel => _sshrvdChannel;
  late final SshrvdExecChannel _sshrvdChannel;

  @override
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;
    await findLocalPortIfRequired();
    await super.initialize();
    completeInitialization();
  }

  @visibleForTesting
  Future<void> findLocalPortIfRequired() async {
    // find a spare local port
    if (localPort == 0) {
      logger.info('Finding a spare local port');
      try {
        ServerSocket serverSocket =
            await ServerSocket.bind(InternetAddress.loopbackIPv4, 0)
                .catchError((e) => throw e);
        localPort = serverSocket.port;
        await serverSocket.close().catchError((e) => throw e);
      } catch (e, s) {
        logger.info('Unable to find a spare local port');
        throw SshnpError('Unable to find a spare local port',
            error: e, stackTrace: s);
      }
    }
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

    if (sshnpdChannel.ephemeralPrivateKey == null) {
      throw SshnpError(
        'Expected an ephemeral private key from sshnpd, but it was not set',
      );
    }

    /// Load the ephemeral private key into a key pair
    AtSshKeyPair ephemeralKeyPair = AtSshKeyPair.fromPem(
      sshnpdChannel.ephemeralPrivateKey!,
      identifier: 'ephemeral_$sessionId',
      directory: keyUtil.sshnpHomeDirectory,
    );

    /// Add the key pair to the key utility
    await keyUtil.addKeyPair(
      keyPair: ephemeralKeyPair,
      identifier: ephemeralKeyPair.identifier,
    );

    /// Start the initial tunnel
    Process? bean = await startInitialTunnelSession(
        keyPairIdentifier: ephemeralKeyPair.identifier);

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

  @override
  bool get canRunShell => false;

  @override
  Future<SshnpRemoteProcess> runShell() {
    throw UnimplementedError('$runtimeType does not implement runShell');
  }
}
