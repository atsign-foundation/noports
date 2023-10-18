import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/sshnp/mixins/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/sshnp_core.dart';
import 'package:noports_core/utils.dart';

class SSHNPForwardDartPureImpl extends SSHNPForwardDart
    with SSHNPDartSSHKeyHandler {
  final AtSSHKeyPair _identityKeyPair;

  @override
  AtSSHKeyPair get identityKeyPair => _identityKeyPair;

  SSHNPForwardDartPureImpl({
    required super.atClient,
    required super.params,
    required AtSSHKeyPair identityKeyPair,
    super.shouldInitialize,
  }) : _identityKeyPair = identityKeyPair;

  @override
  Future<void> init() async {
    logger.info('Initializing SSHNPForwardDartPureImpl');
    await super.init();
    completeInitialization();
  }

  @override
  Future<SSHNPResult> run() async {
    SSHClient client = await startInitialTunnel();
    // Todo: consider returning a SSHNPCommand<SSHClient> instead of a SSHNPNoOpSuccess<SSHClient>
    return SSHNPNoOpSuccess<SSHClient>(
      message: 'Connection established:\n$terminateMessage',
      connectionBean: client,
    );
  }
}
