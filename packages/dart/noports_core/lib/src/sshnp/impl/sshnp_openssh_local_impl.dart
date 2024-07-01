import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:noports_core/src/sshnp/util/ephemeral_port_binder.dart';
import 'package:noports_core/sshnp_foundation.dart';

class SshnpOpensshLocalImpl extends SshnpCore
    with
        SshnpLocalSshKeyHandler,
        OpensshSshSessionHandler,
        EphemeralPortBinder {
  SshnpOpensshLocalImpl({
    required super.atClient,
    required super.params,
    required super.logStream,
  }) {
    _sshnpdChannel = SshnpdDefaultChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
      namespace: namespace,
    );
    _srvdChannel = SrvdExecChannel(
      atClient: atClient,
      params: params,
      sessionId: sessionId,
    );
  }

  @override
  SshnpdDefaultChannel get sshnpdChannel => _sshnpdChannel;
  late final SshnpdDefaultChannel _sshnpdChannel;

  @override
  SrvdExecChannel get srvdChannel => _srvdChannel;
  late final SrvdExecChannel _srvdChannel;

  @override
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;
    await findLocalPortIfRequired();
    await super.initialize();
    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    /// Ensure that sshnp is initialized
    await callInitialization();

    var msg = 'Sending session request to the device daemon';
    logger.info(msg);
    sendProgress(msg);

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
            host: srvdChannel.rvdHost,
            port: srvdChannel.daemonPort,
            authenticateToRvd: params.authenticateDeviceToRvd,
            clientNonce: srvdChannel.clientNonce,
            rvdNonce: srvdChannel.rvdNonce,
            encryptRvdTraffic: params.encryptRvdTraffic,
            clientEphemeralPK: params.sessionKP.atPublicKey.publicKey,
            clientEphemeralPKType: params.sessionKPType.name,
          ).toJson()),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(minutes: 1),
    );

    /// Wait for a response from sshnpd
    sendProgress('Waiting for response from the device daemon');
    var acked = await sshnpdChannel.waitForDaemonResponse();
    if (acked != SshnpdAck.acknowledged) {
      throw SshnpError('No response from the device daemon');
    } else {
      sendProgress('Received response from the device daemon');
    }

    if (sshnpdChannel.ephemeralPrivateKey == null &&
        !params.encryptRvdTraffic) {
      throw SshnpError(
        'Expected an ephemeral private key from sshnpd, but it was not set',
      );
    }

    final int localRvPort;
    // If we're not encrypting traffic on the sockets, then we create an extra
    // ssh session in order to encrypt the user's "real" ssh session. And we
    // need to grab an unused local port.
    if (params.encryptRvdTraffic == false) {
      /// Find a port to use for the tunnel ssh session
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      localRvPort = server.port;
      await server.close();
    } else {
      localRvPort = localPort;
    }

    /// Start srv
    sendProgress('Creating connection to socket rendezvous');
    await srvdChannel.runSrv(
      localRvPort: localRvPort,
      sessionAESKeyString: sshnpdChannel.sessionAESKeyString,
      sessionIVString: sshnpdChannel.sessionIVString,
      multi: false,
      detached: true,
      timeout: DefaultArgs.srvTimeout,
    );

    Process? bean;

    // If we're not encrypting traffic on the sockets, then we create an extra
    // ssh session in order to encrypt the user's "real" ssh session.
    if (params.encryptRvdTraffic == false) {
      /// Load the ephemeral private key into a key pair
      AtSshKeyPair ephemeralKeyPair = AtSshKeyPair.fromPem(
        sshnpdChannel.ephemeralPrivateKey!,
        identifier: 'ephemeral_$sessionId',
        directory: keyUtil.sshnpHomeDirectory,
      );

      /// Add the key pair to the key utility
      await keyUtil.addKeyPair(keyPair: ephemeralKeyPair).catchError((e) {
        throw e;
      });

      try {
        /// Start the initial tunnel
        sendProgress('Starting tunnel session');
        bean = await startInitialTunnelSession(
          ephemeralKeyPairIdentifier: ephemeralKeyPair.identifier,
          localRvPort: localRvPort,
        );
      } finally {
        /// Remove the key pair from the key utility.
        try {
          await keyUtil.deleteKeyPair(identifier: ephemeralKeyPair.identifier);
        } catch (e) {
          logger.shout('Failed to delete ephemeral keyPair: $e');
        }
      }
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

  @override
  bool get canRunShell => false;

  @override
  Future<SshnpRemoteProcess> runShell() {
    throw UnimplementedError('$runtimeType does not implement runShell');
  }
}
