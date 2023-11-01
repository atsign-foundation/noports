import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/mixins/sshnpd_payload_handler.dart';
import 'package:noports_core/src/sshnp/reverse_direction/sshnp_reverse.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';

class SSHNPVersion3Impl extends SSHNPReverse with SSHNPDVersion3PayloadHandler {
  SSHNPVersion3Impl({
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
    logger.info('Initializing SSHNPLegacyImpl');
    await super.initialize();
    if (!isSafeToInitialize) return;

    // Share our private key with sshnpd
    AtKey sendOurPrivateKeyToSshnpd = AtKey()
      ..key = 'privatekey'
      ..sharedBy = clientAtSign
      ..sharedWith = sshnpdAtSign
      ..namespace = this.namespace
      ..metadata = (Metadata()
        ..ttr = -1
        ..ttl = 10000);
    await notify(
        sendOurPrivateKeyToSshnpd, ephemeralKeyPair.privateKeyContents);

    completeInitialization();
  }

  @override
  Future<SshnpResult> run() async {
    await callInitialization();

    logger.info('Requesting legacy daemon to start reverse ssh session');

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
        ..key = 'sshd'
        ..namespace = this.namespace
        ..sharedBy = clientAtSign
        ..sharedWith = sshnpdAtSign
        ..metadata = (Metadata()
          ..ttr = -1
          ..ttl = 10000),
      '$localPort $port $localUsername $host $sessionId',
    );

    bool acked = await waitForDaemonResponse();
    if (!acked) {
      var error = SshnpError(
        'sshnp timed out: waiting for daemon response\nhint: make sure the device is online',
        stackTrace: StackTrace.current,
      );
      doneCompleter.completeError(error);
      return error;
    }

    if (sshnpdAckErrors) {
      var error = SshnpError(
        'sshnp failed: with sshnpd acknowledgement errors',
        stackTrace: StackTrace.current,
      );
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
