import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:noports_core/src/common/openssh_binary_path.dart';
import 'package:noports_core/sshnp_foundation.dart';

mixin SshnpOpensshInitialTunnelHandler on SshnpCore
    implements SshnpInitialTunnelHandler<Process?> {
  @override
  Future<Process?> startInitialTunnel({required String identifier}) async {
    Process? process;
    // If we are starting an initial tunnel, it should be to sshrvd,
    // so it is safe to assume that sshrvdChannel is not null here
    String argsString = '$remoteUsername@${sshrvdChannel!.host}'
        ' -p ${sshrvdChannel!.sshrvdPort}'
        ' -i $identifier'
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
        unawaited(Process.start(
          'powershell.exe',
          [
            '-command',
            opensshBinaryPath,
            ...args,
          ],
          runInShell: true,
          mode: ProcessStartMode.detachedWithStdio,
        ));
        // Delay to allow the detached session to pick up the keys
        await Future.delayed(Duration(seconds: 1));
      } else {
        process = await Process.start(opensshBinaryPath, args);
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
}
