import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/src/sshnp/util/ephemeral_port_binder.dart';
import 'package:noports_core/sshnp_foundation.dart';

class SshnpUnsignedImpl extends SshnpCore
    with SshnpLocalSshKeyHandler, EphemeralPortBinder {
  SshnpUnsignedImpl({
    required super.atClient,
    required super.params,
  }) {
    if (Platform.isWindows) {
      throw SshnpError(
        'Windows is not supported by unsigned sshnp clients.',
      );
    }
    _sshnpdChannel = SshnpdUnsignedChannel(
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
  SshnpdUnsignedChannel get sshnpdChannel => _sshnpdChannel;
  late final SshnpdUnsignedChannel _sshnpdChannel;

  @override
  SrvdExecChannel get srvdChannel => _srvdChannel;
  late final SrvdExecChannel _srvdChannel;

  @override
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;
    await findLocalPortIfRequired();
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
      ..namespace = namespace
      ..metadata = (Metadata()..ttl = 10000);
    await notify(
      sendOurPrivateKeyToSshnpd,
      ephemeralKeyPair.privateKeyContents,
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
    );

    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    /// Ensure that sshnp is initialized
    await callInitialization();

    /// Send an sshd request to sshnpd
    /// This will notify it that it can now connect to us
    await notify(
      AtKey()
        ..key = 'sshd'
        ..namespace = namespace
        ..sharedBy = params.clientAtSign
        ..sharedWith = params.sshnpdAtSign
        ..metadata = (Metadata()..ttl = 10000),
      '$localPort ${srvdChannel.port} ${keyUtil.username} ${srvdChannel.host} $sessionId',
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
    );

    /// Wait for a response from sshnpd
    var acked = await sshnpdChannel.waitForDaemonResponse();
    if (acked != SshnpdAck.acknowledged) {
      throw SshnpError('sshnpd did not acknowledge the request');
    }

    /// Start srv
    var bean = await srvdChannel.runSrv(directSsh: false);

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
