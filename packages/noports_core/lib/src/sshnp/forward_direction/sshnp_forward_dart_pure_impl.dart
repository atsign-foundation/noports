import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/common/ssh_key_utils.dart';
import 'package:noports_core/src/sshnp/mixins/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/sshnp_impl.dart';

class SSHNPForwardDartPureImpl extends SSHNPForwardDart
    with SSHNPDartSSHKeyHandler {
  @override
  AtSSHKeyPair identityKeyPair;

  @override
  String get publicKeyContents => identityKeyPair.publicKeyContents;

  SSHNPForwardDartPureImpl({
    required super.atClient,
    required super.params,
    required this.identityKeyPair,
    super.shouldInitialize,
  });

  @override
  Future<void> init() async {
    await super.init();
    completeInitialization();
  }

  @override
  Future<SSHNPResult> run() async {
    SSHClient client = await startInitialTunnel();
    return SSHNPNoOpSuccess<SSHClient>(
      message: 'Connection established:\n$terminateMessage',
      connectionBean: client,
    );
  }
}
