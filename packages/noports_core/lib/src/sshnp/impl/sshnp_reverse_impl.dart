import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/util/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_default_channel.dart';
import 'package:noports_core/src/sshnp/util/sshrvd_channel/sshrvd_exec_channel.dart';
import 'package:noports_core/src/sshnp/models/sshnp_result.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/utils.dart';

class SshnpReverseImpl extends SshnpCore with SshnpLocalSshKeyHandler {
  SshnpReverseImpl({
    required super.atClient,
    required super.params,
  });

  @override
  SshnpdDefaultChannel get sshnpdChannel => SshnpdDefaultChannel(
        atClient: atClient,
        params: params,
        sessionId: sessionId,
        namespace: this.namespace,
      );

  @override
  SshrvdExecChannel get sshrvdChannel => SshrvdExecChannel(
        atClient: atClient,
        params: params,
        sessionId: sessionId,
      );

  late final AtSshKeyPair ephemeralKeyPair;

  @override
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;
    await super.initialize();

    /// Generate an ephemeral key pair for this session
    ephemeralKeyPair = await keyUtil.generateKeyPair(
      identifier: 'ephemeral_$sessionId',
      directory: keyUtil.sshnpHomeDirectory,
    );

    /// Authorize the public key so sshnpd can connect to us
    await keyUtil.authorizePublicKey(
      sshPublicKey: ephemeralKeyPair.publicKeyContents,
      localSshdPort: params.localSshdPort,
      sessionId: sessionId,
    );

    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    /// Ensure that sshnp is initialized
    await callInitialization();

    /// Start sshrv
    var bean = await sshrvdChannel.runSshrv();

    /// Send a reverse sshdrequest to sshnpd
    /// This will notify it that it can now connect to us
    await notify(
      AtKey()
        ..key = 'ssh_request'
        ..namespace = this.namespace
        ..sharedBy = params.clientAtSign
        ..sharedWith = params.sshnpdAtSign
        ..metadata = (Metadata()..ttl = 10000),
      signAndWrapAndJsonEncode(
        atClient,
        {
          'direct': false,
          'sessionId': sessionId,
          'host': sshrvdChannel.host,
          'port': sshrvdChannel.port,
          'username': keyUtil.username,
          'remoteForwardPort': localPort,
          'privateKey': ephemeralKeyPair.privateKeyContents,
        },
      ),
    );

    /// Wait for a response from sshnpd
    await sshnpdChannel.waitForDaemonResponse();

    /// Ensure that we clean up after ourselves
    await callDisposal();

    /// Return the command to be executed externally
    return SshnpCommand(
      localPort: localPort,
      host: sshrvdChannel.host,
      remoteUsername: remoteUsername,
      localSshOptions:
          (params.addForwardsToTunnel) ? null : params.localSshOptions,
      privateKeyFileName: identityKeyPair?.identifier,
      connectionBean: bean,
    );
  }
}
