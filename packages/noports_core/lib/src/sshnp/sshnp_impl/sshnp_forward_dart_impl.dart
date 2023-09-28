import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/common/utils.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_impl_mixin.dart';
import 'package:noports_core/sshnp.dart';

class SSHNPForwardDartImpl extends SSHNPImpl with SSHNPForwardDirection {
  SSHNPForwardDartImpl({
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
      var error = SSHNPError(
          'sshnp timed out: waiting for daemon response\nhint: make sure the device is online');
      doneCompleter.completeError(error);
      return error;
    }

    if (sshnpdAckErrors) {
      var error =
          SSHNPError('sshnp failed: with sshnpd acknowledgement errors');
      doneCompleter.completeError(error);
      return error;
    }
    // 1) Execute an ssh command setting up local port forwarding.
    //    Note that this is very similar to what the daemon does when we
    //    ask for a reverse ssh
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
            ' from port $fLocalPort on localhost'
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
                fRemotePort: fRemotePort);
          }
        }
      }

      /// Set up timer to check to see if all connections are down
      logger
          .info('ssh session will terminate after ${params.idleTimeout} seconds'
              ' if it is not being used');
      Timer.periodic(Duration(seconds: params.idleTimeout), (timer) async {
        if (counter == 0) {
          timer.cancel();
          client.close();
          await client.done;
          doneCompleter.complete();
          logger.shout('$sessionId | no active connections'
              ' - ssh session complete');
        }
      });

      // All good - write the ssh command to stdout
      return SSHNPSuccess.base(
        localPort: localPort,
        remoteUsername: remoteUsername,
        host: 'localhost',
        privateKeyFileName: publicKeyFileName.replaceAll('.pub', ''),
        localSshOptions:
            (params.addForwardsToTunnel) ? null : params.localSshOptions,
        sshClient: client,
      );
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
