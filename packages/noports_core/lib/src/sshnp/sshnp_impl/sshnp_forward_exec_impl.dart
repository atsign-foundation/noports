import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:noports_core/src/common/utils.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl_mixin.dart';
import 'package:noports_core/sshnp.dart';
import 'package:path/path.dart' as path;

class SSHNPForwardExecImpl extends SSHNPImpl with SSHNPForwardDirection {
  SSHNPForwardExecImpl({
    required AtClient atClient,
    required SSHNPParams params,
  }) : super(atClient: atClient, params: params);

  @override
  Future<SSHNPResult> run() async {
    logger.info(
        'Requesting daemon to set up socket tunnel for direct ssh session');
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
          'direct': true,
          'sessionId': sessionId,
          'host': host,
          'port': port
        }),
        sessionId: sessionId);

    bool acked = await waitForDaemonResponse();
    if (!acked) {
      return SSHNPError(
          'sshnp timed out: waiting for daemon response\nhint: make sure the device is online');
    }

    if (sshnpdAckErrors) {
      return SSHNPError('sshnp failed: with sshnpd acknowledgement errors');
    }
    // 1) Execute an ssh command setting up local port forwarding.
    //    Note that this is very similar to what the daemon does when we
    //    ask for a reverse ssh
    logger.info(
        'Starting direct ssh session for ${params.username} to $host on port $sshrvdPort with forwardLocal of $localPort');

    try {
      String? errorMessage;
      Process? process;

      // If using exec then we can assume we're on something unix-y
      // So we can write the ephemeralPrivateKey to a tmp file,
      // set its permissions appropriately, and remove it after we've
      // executed the command
      var tmpFileName =
          path.normalize('$sshHomeDirectory/tmp/ephemeral_$sessionId');
      File tmpFile = File(tmpFileName);
      await tmpFile.create(recursive: true);
      await tmpFile.writeAsString(ephemeralPrivateKey,
          mode: FileMode.write, flush: true);
      await Process.run('chmod', ['go-rwx', tmpFileName]);

      String argsString = '$remoteUsername@$host'
          ' -p $sshrvdPort'
          ' -i $tmpFileName'
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

      await tmpFile.delete();

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

      // All good - write the ssh command to stdout
      return SSHNPSuccess<Process>(
        localPort: localPort,
        remoteUsername: remoteUsername,
        host: 'localhost',
        privateKeyFileName: publicKeyFileName.replaceAll('.pub', ''),
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
