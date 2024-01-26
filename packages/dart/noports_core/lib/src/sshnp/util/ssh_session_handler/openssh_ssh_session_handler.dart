import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/src/common/openssh_binary_path.dart';
import 'package:noports_core/sshnp_foundation.dart';

mixin OpensshSshSessionHandler on SshnpCore implements SshSessionHandler<Process?> {
  @override
  Future<Process?> startInitialTunnelSession({
    required String ephemeralKeyPairIdentifier,
    int? localRvPort,
    SSHSocket? sshSocket,
    @visibleForTesting ProcessStarter startProcess = Process.start,
  }) async {
    Process? process;
    // If we are starting an initial tunnel, it should be to the local srv,
    // so it is safe to assume that localRvPort is non-null
    String argsString = '$tunnelUsername@localhost'
        ' -p ${localRvPort!}'
        ' -i $ephemeralKeyPairIdentifier'
        ' -L $localPort:localhost:${params.remoteSshdPort}'
        ' -o LogLevel=VERBOSE'
        ' -t -t'
        ' -o StrictHostKeyChecking=accept-new'
        ' -o IdentitiesOnly=yes'
        ' -o BatchMode=yes'
        ' -o ExitOnForwardFailure=yes'
        ' -n'
        ' -f' // fork after authentication - this is important
        ;
    if (params.addForwardsToTunnel) {
      argsString += ' ${params.localSshOptions.join(' ')}';
    }
    argsString += ' sleep 15';

    List<String> args = argsString.split(' ');

    logger.info('$sessionId | Executing $opensshBinaryPath ${args.join(' ')}');

    // Because of the options we are using, we can wait for this process
    // to complete, because it will exit with exitCode 0 once it has connected
    // successfully
    final soutBuf = StringBuffer();
    final serrBuf = StringBuffer();
    try {
      if (Platform.isWindows) {
        // We have to do special stuff on Windows because -f doesn't fork
        // properly in the Windows OpenSSH client:
        // This incantation opens the initial tunnel in a separate powershell
        // window. It's not necessary (and currently not possible) to capture
        // the process since there is a physical window the user can close to
        // end the session
        unawaited(startProcess(
          'powershell.exe',
          [
            '-command',
            opensshBinaryPath,
            ...args,
          ],
          runInShell: true,
          mode: ProcessStartMode.detachedWithStdio,
        ));
        // Delay to allow the initial connection to get in place
        int waiter = 0;
        int counter = 0;
        while (waiter == 0) {
          Socket? sock;
          try {
            sock = await Socket.connect('localhost', localPort);
          } catch (e) {
            logger.info("waiting for initial ssh tunnel");
            await sock?.close();
            counter++;
          }
          if (sock?.remotePort == localPort) {
            await sock?.close();
            waiter = 1;
          }
          await Future.delayed(Duration(milliseconds: 200));
          if (counter > 5) {
            throw SshnpError(
              'SSHNP failed to start the initial ssh tunnel',
            );
          }
        }
      } else {
        process = await startProcess(opensshBinaryPath, args);
        process.stdout.transform(Utf8Decoder()).listen((String s) {
          soutBuf.write(s);
          logger.info(' $sessionId | sshStdOut | $s');
        }, onError: (e) {});
        process.stderr.transform(Utf8Decoder()).listen((String s) {
          serrBuf.write(s);
          logger.info(' $sessionId | sshStdErr | $s');
        }, onError: (e) {});
        await process.exitCode.timeout(Duration(seconds: 10));
      }
    } on TimeoutException catch (e) {
      throw SshnpError(
        'SSHNP failed to start the initial tunnel',
        error: e,
      );
    }
    return process;
  }

  @override
  Future<Process?> startUserSession({
    required Process? tunnelSession,
  }) async {
    throw UnimplementedError();
  }
}
