import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/utils.dart';

mixin SSHNPForwardDirection on SSHNPImpl {
  // Direct ssh is only ever done with a sshrvd host
  // So we should expect that sshrvdPort is never null
  // Hence overriding the getter and setter to make it non-nullable
  late int _sshrvdPort;
  @override
  int get sshrvdPort => _sshrvdPort;
  @override
  set sshrvdPort(int? port) => _sshrvdPort = port!;

  @override
  Future<void> init() async {
    await super.init();
    if (initializedCompleter.isCompleted) return;
    initializedCompleter.complete();
  }

  Future<SSHNPResult?> requestSocketTunnelFromDaemon() async {
    logger.info(
        'Requesting daemon to set up socket tunnel for direct ssh session');
// send request to the daemon via notification
    await notify(
        AtKey()
          ..key = 'ssh_request'
          ..namespace = this.namespace
          ..sharedBy = clientAtSign
          ..sharedWith = sshnpdAtSign
          ..metadata = (Metadata()
            ..ttr = -1
            ..ttl = 10000),
        signAndWrapAndJsonEncode(atClient, {
          'direct': true,
          'sessionId': sessionId,
          'host': host,
          'port': port
        }),
        sessionId: sessionId);

    bool acked = await waitForDaemonResponse();
    if (!acked) {
      var error = SSHNPError(
          'sshnp timed out: waiting for daemon response\nhint: make sure the device is online',
          stackTrace: StackTrace.current);
      doneCompleter.completeError(error);
      return error;
    }

    if (sshnpdAckErrors) {
      var error = SSHNPError('sshnp failed: with sshnpd acknowledgement errors',
          stackTrace: StackTrace.current);
      doneCompleter.completeError(error);
      return error;
    }

    return null;
  }
}
