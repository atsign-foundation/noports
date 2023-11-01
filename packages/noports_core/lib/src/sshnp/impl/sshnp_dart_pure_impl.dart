import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/sshnp/brn/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/sshnp_core.dart';
import 'package:noports_core/utils.dart';

class SSHNPDartPureImpl extends SshnpCore with SSHNPDartSSHKeyHandler {
  final AtSshKeyPair _identityKeyPair;

  @override
  AtSshKeyPair get identityKeyPair => _identityKeyPair;

  SSHNPDartPureImpl({
    required super.atClient,
    required super.params,
    required AtSshKeyPair identityKeyPair,
    super.shouldInitialize,
  }) : _identityKeyPair = identityKeyPair;

  @override
  Future<void> initialize() async {
    logger.info('Initializing SSHNPForwardDartPureImpl');
    await super.initialize();
    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    SSHClient client = await startInitialTunnel();
    // Todo: consider returning a SSHNPCommand<SSHClient> instead of a SSHNPNoOpSuccess<SSHClient>
    return SshnpNoOpSuccess<SSHClient>(
      message: 'Connection established:\n$terminateMessage',
      connectionBean: client,
    );
  }
}
