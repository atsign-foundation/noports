import 'dart:io';

import 'package:at_utils/at_utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/sshrv.dart';
import 'package:socket_connector/socket_connector.dart';

@visibleForTesting
class SshrvImplExec implements Sshrv<Process> {
  @override
  final String host;

  @override
  final int streamingPort;

  @override
  final int localPort;

  @override
  final bool bindLocalPort;

  @override
  final String? rvdAuthString;

  SshrvImplExec(this.host, this.streamingPort,
      {required this.localPort,
      required this.bindLocalPort,
      this.rvdAuthString});

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
    var rvArgs = [
      '-h',
      host,
      '-p',
      streamingPort.toString(),
      '--local-port',
      localPort.toString(),
    ];
    if (bindLocalPort) {
      rvArgs.add('--bind-local-port');
    }
    if (rvdAuthString != null) {
      rvArgs.addAll(['--rvd-auth', rvdAuthString!]);
    }

    stderr.writeln('$runtimeType.run(): executing $command ${rvArgs.join(' ')}');
    return Process.start(
      command,
      rvArgs,
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
  final int localPort;

  @override
  final bool bindLocalPort;

  @override
  final String? rvdAuthString;

  SshrvImplDart(
    this.host,
    this.streamingPort, {
    required this.localPort,
    required this.bindLocalPort,
    this.rvdAuthString,
  });

  @override
  Future<SocketConnector> run() async {
    final DartAesCtr algorithm = DartAesCtr.with256bits(
      macAlgorithm: Hmac.sha256(),
    );
    final secretKey = SecretKey([157, 145, 46, 127, 146, 161, 7, 96, 13, 29, 150, 203, 109, 252, 110, 92, 24, 55, 113, 121, 94, 91, 69, 63, 159, 162, 107, 49, 250, 118, 191, 113]);
    final iv = [92, 231, 193, 189, 0, 154, 112, 102, 195, 163, 78, 6, 40, 108, 218, 250];

    Stream<List<int>> encrypter(Stream<List<int>> stream) {
      return algorithm.encryptStream(
        stream,
        secretKey: secretKey,
        nonce: iv,
        onMac: (mac) {},
      );
    }

    Stream<List<int>> decrypter(Stream<List<int>> stream) {
      return algorithm.decryptStream(
        stream,
        secretKey: secretKey,
        nonce: iv,
        mac: Mac.empty,
      );
    }

    try {
      var hosts = await InternetAddress.lookup(host);

      late final SocketConnector socketConnector;

      if (bindLocalPort) {
        socketConnector = await SocketConnector.serverToSocket(
            receiverSocketAddress: hosts[0],
            receiverSocketPort: streamingPort,
            localServerPort: localPort,
            verbose: true,
            transformAtoB: encrypter,
            transformBtoA: decrypter);
      } else {
        socketConnector = await SocketConnector.socketToSocket(
            socketAddressA: InternetAddress.loopbackIPv4,
            socketPortA: localPort,
            socketAddressB: hosts[0],
            socketPortB: streamingPort,
            verbose: true,
            transformAtoB: encrypter,
            transformBtoA: decrypter);
      }

      if (rvdAuthString != null) {
        stderr.writeln('authenticating socketB');
        socketConnector.socketB?.writeln(rvdAuthString);
      }

      return socketConnector;
    } catch (e) {
      AtSignLogger('sshrv').severe(e.toString());
      rethrow;
    }
  }

  Stream<List<int>> encrypt(Stream<List<int>> s) async* {}
  Stream<List<int>> decrypt(Stream<List<int>> s) async* {}
}
