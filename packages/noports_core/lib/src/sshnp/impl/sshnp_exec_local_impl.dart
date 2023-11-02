import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/util/sshnp_initial_tunnel_handler.dart';
import 'package:noports_core/src/sshnp/util/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_default_channel.dart';
import 'package:noports_core/src/sshnp/util/sshrvd_channel/sshrvd_channel.dart';
import 'package:noports_core/src/sshnp/util/sshrvd_channel/sshrvd_exec_channel.dart';
import 'package:noports_core/src/sshnp/models/sshnp_result.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/utils.dart';

class SshnpExecLocalImpl extends SshnpCore
    with SshnpLocalSshKeyHandler, SshnpExecInitialTunnelHandler {
  SshnpExecLocalImpl({
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
  SshrvdChannel get sshrvdChannel => SshrvdExecChannel(
        atClient: atClient,
        params: params,
        sessionId: sessionId,
      );

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
    await sshnpdChannel.waitForDaemonResponse();

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
    Process bean =
        await startInitialTunnel(identifier: ephemeralKeyPair.identifier);

    /// Remove the key pair from the key utility
    await keyUtil.deleteKeyPair(identifier: ephemeralKeyPair.identifier);

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
