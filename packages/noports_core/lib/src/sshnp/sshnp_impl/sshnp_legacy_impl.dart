import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl_mixin.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';

class SSHNPLegacyImpl extends SSHNPImpl with SSHNPReverseDirection {
  SSHNPLegacyImpl({
    required AtClient atClient,
    required SSHNPParams params,
    SSHRVGenerator? sshrvGenerator,
  }) : super(
            atClient: atClient, params: params, sshrvGenerator: sshrvGenerator);

  @override
  Future<void> init() async {
    await super.init();

    // Share our private key with sshnpd
    AtKey sendOurPrivateKeyToSshnpd = AtKey()
      ..key = 'privatekey'
      ..sharedBy = clientAtSign
      ..sharedWith = sshnpdAtSign
      ..namespace = namespace
      ..metadata = (Metadata()
        ..ttr = -1
        ..ttl = 10000);
    await notify(sendOurPrivateKeyToSshnpd, sshPrivateKey);
  }

  @override
  Future<SSHNPResult> run() async {
    logger.info('Requesting legacy daemon to start reverse ssh session');

    if (!initializedCompleter.isCompleted) {
      // Call init in case it hasn't been called yet
      unawaited(init());
      // Wait for init to complete
      // N.B. must be called this way in case the init call above is not the first init call
      await initialized;
    }

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.
    SSHRV sshrv =
        sshrvGenerator(host, sshrvdPort, localSshdPort: params.localSshdPort);
    Future sshrvResult = sshrv.run();

    // send request to the daemon via notification
    await notify(
      AtKey()
        ..key = 'sshd'
        ..namespace = namespace
        ..sharedBy = clientAtSign
        ..sharedWith = sshnpdAtSign
        ..metadata = (Metadata()
          ..ttr = -1
          ..ttl = 10000),
      '$localPort $port ${params.username} $host $sessionId',
      sessionId: sessionId,
    );

    bool acked = await waitForDaemonResponse();
    await cleanUp();
    if (!acked) {
      var error = SSHNPError(
        'sshnp timed out: waiting for daemon response\nhint: make sure the device is online',
        stackTrace: StackTrace.current,
      );
      doneCompleter.completeError(error);
      return error;
    }

    if (sshnpdAckErrors) {
      var error = SSHNPError(
        'sshnp failed: with sshnpd acknowledgement errors',
        stackTrace: StackTrace.current,
      );
      doneCompleter.completeError(error);
      return error;
    }

    doneCompleter.complete();
    return SSHNPSuccess(
      localPort: localPort,
      remoteUsername: remoteUsername,
      host: 'localhost',
      privateKeyFileName: publicKeyFileName.replaceAll('.pub', ''),
      localSshOptions:
          (params.addForwardsToTunnel) ? null : params.localSshOptions,
      connectionBean: sshrvResult,
    );
  }
}
