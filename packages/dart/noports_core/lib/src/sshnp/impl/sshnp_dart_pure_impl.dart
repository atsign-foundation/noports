import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:noports_core/sshnp_foundation.dart';

class SshnpDartPureImpl extends SshnpCore
    with SshnpDartSshKeyHandler, DartSshSessionHandler {
  SshnpDartPureImpl({
    required super.atClient,
    required super.params,
    required AtSshKeyPair? identityKeyPair,
  }) {
    // TODO Defensive code to prevent use of rvd auth and rv traffic encryption
    // TODO until they have been properly implemented with an in-memory RV.
    // TODO At that time, make these four params "final" again
    if (params.discoverDaemonFeatures) {
      logger.shout('$runtimeType: disabling discoverDaemonFeatures flag');
      params.discoverDaemonFeatures = false;
    }
    if (params.encryptRvdTraffic) {
      logger.shout('$runtimeType: disabling encryptRvdTraffic flag');
      params.encryptRvdTraffic = false;
    }
    if (params.authenticateDeviceToRvd) {
      logger.shout('$runtimeType: disabling authenticateDeviceToRvd flag');
      params.authenticateDeviceToRvd = false;
    }
    if (params.authenticateClientToRvd) {
      logger.shout('$runtimeType: disabling authenticateClientToRvd flag');
      params.authenticateClientToRvd = false;
    }
    this.identityKeyPair = identityKeyPair;
    _sshnpdChannel = SshnpdDefaultChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
      namespace: namespace,
    );
    _srvdChannel = SrvdDartChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
    );
  }

  @override
  SshnpdDefaultChannel get sshnpdChannel => _sshnpdChannel;
  late final SshnpdDefaultChannel _sshnpdChannel;

  @override
  SrvdDartChannel get srvdChannel => _srvdChannel;
  late final SrvdDartChannel _srvdChannel;

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
        ..namespace = namespace
        ..sharedBy = params.clientAtSign
        ..sharedWith = params.sshnpdAtSign
        ..metadata = (Metadata()..ttl = 10000),
      signAndWrapAndJsonEncode(
          atClient,
          SshnpSessionRequest(
            direct: true,
            sessionId: sessionId,
            host: srvdChannel.host,
            port: srvdChannel.port,
            authenticateToRvd: params.authenticateDeviceToRvd,
            clientNonce: srvdChannel.clientNonce,
            rvdNonce: srvdChannel.rvdNonce,
            encryptRvdTraffic: params.encryptRvdTraffic,
            clientEphemeralPK: params.sessionKP.atPublicKey.publicKey,
            clientEphemeralPKType: params.sessionKPType.name,
          ).toJson()),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
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
