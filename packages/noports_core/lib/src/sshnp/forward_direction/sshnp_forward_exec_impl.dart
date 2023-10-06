import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;

import 'package:noports_core/src/sshnp/forward_direction/sshnp_forward.dart';
import 'package:noports_core/src/sshnp/mixins/sshnpd_payload_handler.dart';
import 'package:noports_core/src/sshnp/mixins/sshnp_ssh_key_handler.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';

class SSHNPForwardExecImpl extends SSHNPForward
    with SSHNPLocalSSHKeyHandler, DefaultSSHNPDPayloadHandler {
  late AtSSHKeyPair ephemeralKeyPair;

  SSHNPForwardExecImpl({
    required AtClient atClient,
    required SSHNPParams params,
    bool? shouldInitialize,
  }) : super(
          atClient: atClient,
          params: params,
          shouldInitialize: shouldInitialize,
        );

  @override
  Future<void> init() async {
    await super.init();

    ephemeralKeyPair = AtSSHKeyPair.fromPem(
      ephemeralPrivateKey,
      identifier: 'ephemeral_$sessionId',
      directory: keyUtil.sshnpHomeDirectory,
    );

    completeInitialization();
  }

  @override
  Future<SSHNPResult> run() async {
    await startAndWaitForInit();

    var error = await requestSocketTunnelFromDaemon();
    if (error != null) {
      return error;
    }

    logger.info(
        'Starting direct ssh session to $host on port $sshrvdPort with forwardLocal of $localPort');

    try {
      String? errorMessage;
      Process? process;

      await keyUtil.addKeyPair(
        keyPair: ephemeralKeyPair,
        identifier: ephemeralKeyPair.identifier,
      );

      String argsString = '$remoteUsername@$host'
          ' -p $sshrvdPort'
          ' -i ${ephemeralKeyPair.privateKeyFileName}'
          ' -L $localPort:localhost:${params.remoteSshdPort}'
          ' -o LogLevel=VERBOSE'
          ' -t -t'
          ' -o StrictHostKeyChecking=accept-new'
          ' -o IdentitiesOnly=yes'
          ' -o BatchMode=yes'
          ' -o ExitOnForwardFailure=yes'
          ' -f' // fork after authentication - this is important
          ;
      if (params.addForwardsToTunnel) {
        argsString += ' ${params.localSshOptions.join(' ')}';
      }
      argsString += ' sleep 15';

      List<String> args = argsString.split(' ');

      logger.info('$sessionId | Executing /usr/bin/ssh ${args.join(' ')}');

      // Because of the options we are using, we can wait for this process
      // to complete, because it will exit with exitCode 0 once it has connected
      // successfully
      late int sshExitCode;
      final soutBuf = StringBuffer();
      final serrBuf = StringBuffer();
      try {
        process = await Process.start('/usr/bin/ssh', args);
        process.stdout.transform(Utf8Decoder()).listen((String s) {
          soutBuf.write(s);
          logger.info('$sessionId | sshStdOut | $s');
        }, onError: (e) {});
        process.stderr.transform(Utf8Decoder()).listen((String s) {
          serrBuf.write(s);
          logger.info('$sessionId | sshStdErr | $s');
        }, onError: (e) {});
        sshExitCode = await process.exitCode.timeout(Duration(seconds: 10));
        // ignore: unused_catch_clause
      } on TimeoutException catch (e) {
        sshExitCode = 6464;
      }

      await keyUtil.deleteKeyPair(
        identifier: ephemeralKeyPair.identifier,
      );

      if (sshExitCode != 0) {
        if (sshExitCode == 6464) {
          logger.shout(
              '$sessionId | Command timed out: /usr/bin/ssh ${args.join(' ')}');
          errorMessage = 'Failed to establish connection - timed out';
        } else {
          logger.shout('$sessionId | Exit code $sshExitCode from'
              ' /usr/bin/ssh ${args.join(' ')}');
          errorMessage =
              'Failed to establish connection - exit code $sshExitCode';
        }
        throw SSHNPError(errorMessage);
      }

      doneCompleter.complete();
      return SSHNPCommand<Process>(
        localPort: localPort,
        remoteUsername: remoteUsername,
        host: 'localhost',
        privateKeyFileName: identityKeyPair?.privateKeyFileName,
        localSshOptions:
            (params.addForwardsToTunnel) ? null : params.localSshOptions,
        connectionBean: process,
      );
    } on SSHNPError catch (e) {
      doneCompleter.completeError(e, e.stackTrace);
      return e;
    } catch (e, s) {
      doneCompleter.completeError(e, s);
      return SSHNPError(
        'SSH Client failure : $e',
        error: e,
        stackTrace: s,
      );
    }
  }
}
