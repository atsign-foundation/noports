import 'dart:async';

import 'package:noports_core/src/sshnp/channels/sshnpd/sshnpd_channel.dart';
import 'package:noports_core/src/sshnp/channels/sshrvd/sshrvd_channel.dart';
import 'package:noports_core/src/sshnp/brn/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/channels/sshnpd/sshnpd_default_channel.dart';
import 'package:noports_core/src/sshnp/channels/sshrvd/sshrvd_exec_channel.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/sshnp_core.dart';

class NewSshnpDartLocalImpl extends SshnpCore with SshnpLocalSSHKeyHandler {
  NewSshnpDartLocalImpl({
    required super.atClient,
    required super.params,
  });

  @override
  SshnpdChannel get sshnpdChannel => SshnpdDefaultChannel(
        atClient: atClient,
        params: params,
        sessionId: sessionId,
        namespace: namespace,
      );

  @override
  SshrvdChannel get sshrvdChannel => SshrvdExecChannel(
        atClient: atClient,
        params: params,
        sessionId: sessionId,
      );

  @override
  Future<void> initialize() async {
    if (isSafeToInitialize) {
      logger.info('Initializing NewSSHNPDartLocalImpl');
    }

    await super.initialize();
  }

  @override
  Future<SshnpResult> run() async {
    //TODO
    return SshnpNoOpSuccess();
  }
}
