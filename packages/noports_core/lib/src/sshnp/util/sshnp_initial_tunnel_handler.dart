import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/sshnp/sshnp_core.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';

mixin SshnpInitialTunnelHandler<T> {
  @protected
  Future<T> startInitialTunnel({required String identifier});
}

mixin SshnpExecInitialTunnelHandler on SshnpCore
    implements SshnpInitialTunnelHandler<Process> {
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

    logger.info('$sessionId | Executing /usr/bin/ssh ${args.join(' ')}');

    // Because of the options we are using, we can wait for this process
    // to complete, because it will exit with exitCode 0 once it has connected
    // successfully
    final soutBuf = StringBuffer();
    final serrBuf = StringBuffer();
    try {
      process = await Process.start('/usr/bin/ssh', args);
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

mixin SshnpDartInitialTunnelHandler on SshnpCore
    implements SshnpInitialTunnelHandler<SSHClient> {
  /// Set up timer to check to see if all connections are down
  @visibleForTesting
  String get terminateMessage =>
      'ssh session will terminate after ${params.idleTimeout} seconds'
      ' if it is not being used';

  @override
  Future<SSHClient> startInitialTunnel({required String identifier}) async {
    // If we are starting an initial tunnel, it should be to sshrvd,
    // so it is safe to assume that sshrvdChannel is not null here
    logger.info(
        'Starting direct ssh session to ${sshrvdChannel!.host} on port ${sshrvdChannel!.sshrvdPort} with forwardLocal of $localPort');
    try {
      late final SSHClient client;

      late final SSHSocket socket;
      try {
        socket = await SSHSocket.connect(
          sshrvdChannel!.host,
          sshrvdChannel!.sshrvdPort!,
        ).catchError((e) => throw e);
      } catch (e, s) {
        var error = SshnpError(
          'Failed to open socket to ${sshrvdChannel!.host}:${sshrvdChannel!.sshrvdPort} : $e',
          error: e,
          stackTrace: s,
        );
        throw error;
      }

      try {
        AtSshKeyPair keyPair = await keyUtil.getKeyPair(identifier: identifier);
        client = SSHClient(
          socket,
          username: remoteUsername ?? getUserName(throwIfNull: true)!,
          identities: [keyPair.keyPair],
          keepAliveInterval: Duration(seconds: 15),
        );
      } catch (e, s) {
        throw SshnpError(
          'Failed to create SSHClient for ${params.remoteUsername}@${sshrvdChannel!.host}:${sshrvdChannel!.sshrvdPort} : $e',
          error: e,
          stackTrace: s,
        );
      }

      try {
        await client.authenticated.catchError((e) => throw e);
      } catch (e, s) {
        throw SshnpError(
          'Failed to authenticate as ${params.remoteUsername}@${sshrvdChannel!.host}:${sshrvdChannel!.sshrvdPort} : $e',
          error: e,
          stackTrace: s,
        );
      }

      int counter = 0;

      Future<void> startForwarding(
          {required int fLocalPort,
          required String fRemoteHost,
          required int fRemotePort}) async {
        logger.info('Starting port forwarding'
            ' from localhost:$fLocalPort on local side'
            ' to $fRemoteHost:$fRemotePort on remote side');

        /// Do the port forwarding for sshd
        final serverSocket = await ServerSocket.bind('localhost', fLocalPort);

        serverSocket.listen((socket) async {
          counter++;
          final forward = await client.forwardLocal(fRemoteHost, fRemotePort);
          unawaited(
            forward.stream.cast<List<int>>().pipe(socket).whenComplete(
              () async {
                counter--;
              },
            ),
          );
          unawaited(socket.pipe(forward.sink));
        }, onError: (Object error) {
          counter = 0;
        }, onDone: () {
          counter = 0;
        });
      }

      // Start local forwarding to the remote sshd
      await startForwarding(
        fLocalPort: localPort,
        fRemoteHost: 'localhost',
        fRemotePort: params.remoteSshdPort,
      );

      if (params.addForwardsToTunnel) {
        var optionsSplitBySpace = params.localSshOptions.join(' ').split(' ');
        logger.info('addForwardsToTunnel is true;'
            ' localSshOptions split by space is $optionsSplitBySpace');
        // parse the localSshOptions, extract all of the local port forwarding
        // directives and act on all of them
        var lsoIter = optionsSplitBySpace.iterator;
        while (lsoIter.moveNext()) {
          if (lsoIter.current == '-L') {
            // we expect the args next
            bool hasArgs = lsoIter.moveNext();
            if (!hasArgs) {
              logger.warning('localSshOptions has -L with no args');
              continue;
            }
            String argString = lsoIter.current;
            // We expect args like $localPort:$remoteHost:$remotePort
            List<String> args = argString.split(':');
            if (args.length != 3) {
              logger.warning('localSshOptions has -L with bad args $argString');
              continue;
            }
            int? fLocalPort = int.tryParse(args[0]);
            String fRemoteHost = args[1];
            int? fRemotePort = int.tryParse(args[2]);
            if (fLocalPort == null ||
                fRemoteHost.isEmpty ||
                fRemotePort == null) {
              logger.warning('localSshOptions has -L with bad args $argString');
              continue;
            }

            // Start the forwarding
            await startForwarding(
              fLocalPort: fLocalPort,
              fRemoteHost: fRemoteHost,
              fRemotePort: fRemotePort,
            );
          }
        }
      }

      logger.info(terminateMessage);
      Timer.periodic(Duration(seconds: params.idleTimeout), (timer) async {
        if (counter == 0 || client.isClosed) {
          timer.cancel();
          if (!client.isClosed) client.close();
          logger.shout(
              '$sessionId | no active connections - ssh session complete');
        }
      });
      return client;
    } on SshnpError catch (_) {
      rethrow;
    } catch (e, s) {
      throw SshnpError(
        'SSH Client failure : $e',
        error: e,
        stackTrace: s,
      );
    }
  }
}
