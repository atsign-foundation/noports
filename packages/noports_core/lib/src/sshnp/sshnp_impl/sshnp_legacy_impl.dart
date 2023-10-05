import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_local_file_mixin.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_reverse_mixin.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';

class SSHNPLegacyImpl extends SSHNPImpl
    with SSHNPLocalFileMixin, SSHNPReverseMixin {
  SSHNPLegacyImpl({
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

    // Share our private key with sshnpd
    AtKey sendOurPrivateKeyToSshnpd = AtKey()
      ..key = 'privatekey'
      ..sharedBy = clientAtSign
      ..sharedWith = sshnpdAtSign
      ..namespace = this.namespace
      ..metadata = (Metadata()
        ..ttr = -1
        ..ttl = 10000);
    await notify(sendOurPrivateKeyToSshnpd, sshPrivateKey);

    completeInitialization();
  }

  @override
  Future<SSHNPResult> run() async {
    await startAndWaitForInit();

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
      sessionId: sessionId,
    );

    bool acked = await waitForDaemonResponse();
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
