import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_forward_direction.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/sshnp.dart';

class SSHNPForwardDartImpl extends SSHNPImpl with SSHNPForwardDirection {
  SSHNPForwardDartImpl({
    required AtClient atClient,
    required SSHNPParams params,
    bool? shouldInitialize,
  }) : super(
          atClient: atClient,
          params: params,
          shouldInitialize: shouldInitialize,
        );

  @override
  Future<SSHNPResult> run() async {
    await startAndWaitForInit();

    var error = await requestSocketTunnelFromDaemon();
    if (error != null) {
      return error;
    }

    logger.info(
        'Starting direct ssh session for ${params.username} to $host on port $sshrvdPort with forwardLocal of $localPort');
    try {
      late final SSHClient client;

      late final SSHSocket socket;
      try {
        socket = await SSHSocket.connect(host, sshrvdPort);
      } catch (e, s) {
        var error = SSHNPError(
          'Failed to open socket to $host:$port : $e',
          error: e,
          stackTrace: s,
        );
        doneCompleter.completeError(error);
        return error;
      }

      try {
        client = SSHClient(
          socket,
          username: remoteUsername,
          identities: [
            // A single private key file may contain multiple keys.
            ...SSHKeyPair.fromPem(ephemeralPrivateKey)
          ],
          keepAliveInterval: Duration(seconds: 15),
        );
      } catch (e, s) {
        var error = SSHNPError(
          'Failed to create SSHClient for ${params.username}@$host:$port : $e',
          error: e,
          stackTrace: s,
        );
        doneCompleter.completeError(error);
        return error;
      }

      try {
        await client.authenticated;
      } catch (e, s) {
        var error = SSHNPError(
          'Failed to authenticate as ${params.username}@$host:$port : $e',
          error: e,
          stackTrace: s,
        );
        doneCompleter.completeError(error);
        return error;
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
          fRemotePort: params.remoteSshdPort);

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

      /// Set up timer to check to see if all connections are down
      String terminateMessage =
          'ssh session will terminate after ${params.idleTimeout} seconds'
          ' if it is not being used';
      logger.info(terminateMessage);
      Timer.periodic(Duration(seconds: params.idleTimeout), (timer) async {
        if (counter == 0 || client.isClosed) {
          timer.cancel();
          if (!client.isClosed) client.close();
          await client.done;
          doneCompleter.complete();
          logger.shout(
              '$sessionId | no active connections - ssh session complete');
        }
      });

      return SSHNPNoOpSuccess<SSHClient>(
          message: 'Connection established:\n$terminateMessage',
          connectionBean: client);
    } on SSHNPError catch (e, s) {
      doneCompleter.completeError(e, s);
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
