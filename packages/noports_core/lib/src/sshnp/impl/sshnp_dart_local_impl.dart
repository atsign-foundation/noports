import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/sshnp/brn/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/sshnp_core.dart';

class SSHNPDartLocalImpl extends SshnpCore with SshnpLocalSSHKeyHandler {
  SSHNPDartLocalImpl({
    required super.atClient,
    required super.params,
    super.shouldInitialize,
  });

  @override
  Future<void> initialize() async {
    logger.info('Initializing SSHNPForwardDartLocalImpl');
    await super.initialize();
    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    // TODO consider starting the tunnel in a separate isolate
    SSHClient client = await startInitialTunnel();

    return SshnpCommand<SSHClient>(
      localPort: localPort,
      remoteUsername: remoteUsername,
      host: 'localhost',
      privateKeyFileName: identityKeyPair?.privateKeyFileName,
      localSshOptions:
          (params.addForwardsToTunnel) ? null : params.localSshOptions,
      connectionBean: client,
    );
  }
}
