import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;

import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_forward_direction.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_local_file_mixin.dart';
import 'package:noports_core/sshnp.dart';
import 'package:path/path.dart' as path;

class SSHNPForwardExecImpl extends SSHNPImpl
    with SSHNPForwardDirection, SSHNPLocalFileMixin {
  late String ephemeralPrivateKeyPath;
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

      ephemeralPrivateKeyPath = path.normalize(
          '$sshnpHomeDirectory/sessions/$sessionId/ephemeral_private_key');
      File tmpFile = File(ephemeralPrivateKeyPath);
      await tmpFile.create(recursive: true);
      await tmpFile.writeAsString(ephemeralPrivateKey,
          mode: FileMode.write, flush: true);
      await Process.run('chmod', ['go-rwx', ephemeralPrivateKeyPath]);

      String argsString = '$remoteUsername@$host'
          ' -p $sshrvdPort'
          ' -i $ephemeralPrivateKeyPath'
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
      return SSHNPCommand<Process>(
        localPort: localPort,
        remoteUsername: remoteUsername,
        host: 'localhost',
        privateKeyFileName: params.identityFile?.replaceAll('.pub', ''),
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

  @override
  Future<void> cleanUp() async {
    await deleteFile(ephemeralPrivateKeyPath);
    super.cleanUp();
  }
}
