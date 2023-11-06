import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:noports_core/sshnp_foundation.dart';

const String _windowsOpensshPath = r'C:\Windows\System32\OpenSSH\ssh.exe';
const String _unixOpensshPath = '/usr/bin/ssh';

mixin SshnpOpensshInitialTunnelHandler on SshnpCore
    implements SshnpInitialTunnelHandler<Process> {
  String get opensshBinaryPath =>
      Platform.isWindows ? _windowsOpensshPath : _unixOpensshPath;

  @override
  Future<Process> startInitialTunnel({required String identifier}) async {
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
    } on TimeoutException catch (e) {
      throw SshnpError(
        'ssh process timed out after 10 seconds',
        error: e,
      );
    }
    return process;
  }
}
