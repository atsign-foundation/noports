import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/validation_utils.dart';
import 'package:noports_core/src/sshnp/mixins/sshnpd_payload_handler.dart';
import 'package:noports_core/src/sshnp/reverse_direction/sshnp_reverse.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';

class SSHNPReverseImpl extends SSHNPReverse with SSHNPDDefaultPayloadHandler {
  SSHNPReverseImpl({
    required AtClient atClient,
    required SshnpParams params,
    SshrvGenerator? sshrvGenerator,
    bool? shouldInitialize,
  }) : super(
          atClient: atClient,
          params: params,
          sshrvGenerator: sshrvGenerator,
          shouldInitialize: shouldInitialize,
        );

  @override
  Future<void> initialize() async {
    logger.info('Initializing SSHNPReverseImpl');
    await super.initialize();
    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    await callInitialization();

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
          'privateKey': ephemeralKeyPair.privateKeyContents,
        },
      ),
    );

    bool acked = await waitForDaemonResponse();
    if (!acked) {
      var error =
          SshnpError('sshnp connection timeout: waiting for daemon response');
      doneCompleter.completeError(error);
      return error;
    }

    if (sshnpdAckErrors) {
      var error =
          SshnpError('sshnp failed: with sshnpd acknowledgement errors');
      doneCompleter.completeError(error);
      return error;
    }

    doneCompleter.complete();
    return SshnpCommand(
      localPort: localPort,
      remoteUsername: remoteUsername,
      host: 'localhost',
      privateKeyFileName: identityKeyPair?.privateKeyFileName,
      localSshOptions:
          (params.addForwardsToTunnel) ? null : params.localSshOptions,
      connectionBean: sshrvResult,
    );
  }
}
