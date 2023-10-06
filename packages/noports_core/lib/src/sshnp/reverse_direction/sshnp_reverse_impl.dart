import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/sshnp/mixins/sshnpd_payload_handler.dart';
import 'package:noports_core/src/sshnp/reverse_direction/sshnp_reverse_direction.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';

class SSHNPReverseImpl extends SSHNPReverseDirection
    with DefaultSSHNPDPayloadHandler {
  SSHNPReverseImpl({
    required AtClient atClient,
    required SSHNPParams params,
    SSHRVGenerator? sshrvGenerator,
    bool? shouldInitialize,
  }) : super(
          atClient: atClient,
          params: params,
          sshrvGenerator: sshrvGenerator,
          shouldInitialize: shouldInitialize,
        );

  @override
  Future<void> init() async {
    await super.init();
    completeInitialization();
  }

  @override
  Future<SSHNPResult> run() async {
    await startAndWaitForInit();

    logger.info('Requesting daemon to start reverse ssh session');

    Future? sshrvResult;
    if (usingSshrv) {
      // Connect to rendezvous point using background process.
      // sshnp (this program) can then exit without issue.
      SSHRV sshrv = sshrvGenerator(host, sshrvdPort!,
          localSshdPort: params.localSshdPort);
      sshrvResult = sshrv.run();
    }
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
      signAndWrapAndJsonEncode(
        atClient,
        {
          'direct': false,
          'sessionId': sessionId,
          'host': host,
          'port': port,
          'username': localUsername,
          'remoteForwardPort': localPort,
          'privateKey': sshPrivateKey,
        },
      ),
    );

    bool acked = await waitForDaemonResponse();
    if (!acked) {
      var error =
          SSHNPError('sshnp connection timeout: waiting for daemon response');
      doneCompleter.completeError(error);
      return error;
    }

    if (sshnpdAckErrors) {
      var error =
          SSHNPError('sshnp failed: with sshnpd acknowledgement errors');
      doneCompleter.completeError(error);
      return error;
    }

    doneCompleter.complete();
    return SSHNPCommand(
      localPort: localPort,
      remoteUsername: remoteUsername,
      host: 'localhost',
      privateKeyFileName: params.identityFile?.replaceAll('.pub', ''),
      localSshOptions:
          (params.addForwardsToTunnel) ? null : params.localSshOptions,
      connectionBean: sshrvResult,
    );
  }
}
