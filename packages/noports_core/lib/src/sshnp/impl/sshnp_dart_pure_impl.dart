import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/sshnp_foundation.dart';

class SshnpDartPureImpl extends SshnpCore
    with SshnpDartSshKeyHandler, DartSshSessionHandler {
  SshnpDartPureImpl({
    required super.atClient,
    required super.params,
    required AtSshKeyPair? identityKeyPair
  }) {
    this.identityKeyPair = identityKeyPair;
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
    if (params.identityFile != null) {
      identityKeyPair =
          await keyUtil.getKeyPair(identifier: params.identityFile!);
    }
    completeInitialization();
  }

  SSHClient? tunnelSshClient;

  @override
  Future<SshnpResult> run() async {
    /// Ensure that sshnp is initialized
    await callInitialization();

    logger.info('Sending request to sshnpd');
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
    );

    /// Add the key pair to the key utility
    await keyUtil.addKeyPair(keyPair: ephemeralKeyPair);

    /// Start the initial tunnel
    tunnelSshClient = await startInitialTunnelSession(
        ephemeralKeyPairIdentifier: ephemeralKeyPair.identifier);

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
      connectionBean: tunnelSshClient,
    );
  }

  @override
  bool get canRunShell => true;

  @override
  Future<SshnpRemoteProcess> runShell() async {
    if (tunnelSshClient == null) {
      throw StateError(
          'Cannot execute runShell, tunnel has not yet been created');
    }

    SSHClient userSession =
        await startUserSession(tunnelSession: tunnelSshClient!);

    SSHSession shell = await userSession.shell();

    return SSHSessionAsSshnpRemoteProcess(shell);
  }
}

class SSHSessionAsSshnpRemoteProcess implements SshnpRemoteProcess {
  SSHSession sshSession;

  SSHSessionAsSshnpRemoteProcess(this.sshSession);

  @override
  Future<void> get done => sshSession.done;

  @override
  StreamSink<List<int>> get stdin => sshSession.stdin;

  @override
  Stream<List<int>> get stdout => sshSession.stdout;

  @override
  Stream<List<int>> get stderr => sshSession.stderr;
}
