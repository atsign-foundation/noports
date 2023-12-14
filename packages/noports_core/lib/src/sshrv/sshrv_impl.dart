import 'dart:io';

import 'package:at_utils/at_utils.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/sshrv.dart';
import 'package:socket_connector/socket_connector.dart';

import 'package:noports_core/src/common/default_args.dart';

import 'auth_provider.dart';

@visibleForTesting
class SshrvImplExec implements Sshrv<Process> {
  @override
  final String host;

  @override
  final int streamingPort;

  @override
  final int localSshdPort;

  @override
  SocketAuthenticationProvider? authenticationProvider;


  SshrvImplExec(
    this.host,
    this.streamingPort, {
    this.localSshdPort = DefaultArgs.localSshdPort, this.authenticationProvider
  });

  @override
  Future<Process> run() async {
    String? command = await Sshrv.getLocalBinaryPath();
    String postfix = Platform.isWindows ? '.exe' : '';
    if (command == null) {
      throw Exception(
        'Unable to locate sshrv$postfix binary.\n'
        'N.B. sshnp is expected to be compiled and run from source, not via the dart command.',
      );
    }
    return Process.start(
      command,
      [host, streamingPort.toString(), localSshdPort.toString()],
      mode: ProcessStartMode.detached,
    );
  }
}

@visibleForTesting
class SshrvImplDart implements Sshrv<SocketConnector> {
  @override
  final String host;

  @override
  final int streamingPort;

  @override
  final int localSshdPort;

  @override
  SocketAuthenticationProvider? authenticationProvider;

  SshrvImplDart(
    this.host,
    this.streamingPort, {
    this.localSshdPort = 22, SocketAuthenticationProvider? authenticationProvider
  });

  @override
  Future<SocketConnector> run() async {
    try {
      var hosts = await InternetAddress.lookup(host);

      SocketConnector socketConnector =  await SocketConnector.socketToSocket(
        socketAddressA: InternetAddress.loopbackIPv4,
        socketPortA: localSshdPort,
        socketAddressB: hosts[0],
        socketPortB: streamingPort,
        verbose: true,
      );

      // TBD - Gary/Xavier/Jagan
      // Should we expose the sockets from socketConnector? whats the best way to do this.
      //authenticationProvider?.authenticate(socketConnector.socketB);
      return socketConnector;
    } catch (e) {
      AtSignLogger('sshrv').severe(e.toString());
      rethrow;
    }
  }
}
