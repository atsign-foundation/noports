import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/utils.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl_mixin.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';

class SSHNPReverseImpl extends SSHNPImpl with SSHNPReverseDirection {
  SSHNPReverseImpl({
    required AtClient atClient,
    required SSHNPParams params,
    SSHRVGenerator? sshrvGenerator,
  }) : super(atClient: atClient, params: params, sshrvGenerator: sshrvGenerator);

  @override
  Future<SSHNPResult> run() async {
    logger.info('Requesting daemon to start reverse ssh session');

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.
    SSHRV sshrv =
        sshrvGenerator(host, sshrvdPort, localSshdPort: params.localSshdPort);
    Future sshrvResult = sshrv.run();

    // send request to the daemon via notification
    await notify(
        AtKey()
          ..key = 'ssh_request'
          ..namespace = namespace
          ..sharedBy = clientAtSign
          ..sharedWith = sshnpdAtSign
          ..metadata = (Metadata()
            ..ttr = -1
            ..ttl = 10000),
        signAndWrapAndJsonEncode(atClient, {
          'direct': false,
          'sessionId': sessionId,
          'host': host,
          'port': port,
          'username': params.username,
          'remoteForwardPort': localPort,
          'privateKey': sshPrivateKey
        }),
        sessionId: sessionId);

    bool acked = await waitForDaemonResponse();
    await cleanUp();
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
    return SSHNPSuccess.base(
      localPort: localPort,
      remoteUsername: remoteUsername,
      host: 'localhost',
      privateKeyFileName: publicKeyFileName.replaceAll('.pub', ''),
      localSshOptions:
          (params.addForwardsToTunnel) ? null : params.localSshOptions,
      sshrvResult: sshrvResult,
    );
  }
}
