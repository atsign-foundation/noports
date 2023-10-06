import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/sshnp/mixins/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/sshnp_impl.dart';

class SSHNPForwardDartLocalImpl extends SSHNPForwardDart
    with SSHNPLocalSSHKeyHandler {
  SSHNPForwardDartLocalImpl({
    required super.atClient,
    required super.params,
    super.shouldInitialize,
  });

  @override
  Future<void> init() async {
    logger.info('Initializing SSHNPForwardDartLocalImpl');
    await super.init();
    completeInitialization();
  }

  @override
  Future<SSHNPResult> run() async {
    // TODO consider starting the tunnel in a separate isolate
    SSHClient client = await startInitialTunnel();

    return SSHNPCommand<SSHClient>(
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
