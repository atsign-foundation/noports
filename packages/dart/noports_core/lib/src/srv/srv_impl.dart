import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_utils/at_utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/srv.dart';
import 'package:socket_connector/socket_connector.dart';

@visibleForTesting
class SrvImplExec implements Srv<Process> {
  static final AtSignLogger logger = AtSignLogger('SrvImplExec');

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

  @override
  final String? sessionAESKeyString;

  @override
  final String? sessionIVString;

  @visibleForTesting
  static const completionString = 'rv started successfully';

  SrvImplExec(
    this.host,
    this.streamingPort, {
    required this.localPort,
    required this.bindLocalPort,
    this.rvdAuthString,
    this.sessionAESKeyString,
    this.sessionIVString,
  }) {
    if ((sessionAESKeyString == null && sessionIVString != null) ||
        (sessionAESKeyString != null && sessionIVString == null)) {
      throw ArgumentError('Both AES key and IV are required, or neither');
    }
  }

  @override
  Future<Process> run() async {
    String? command = await Srv.getLocalBinaryPath();
    String postfix = Platform.isWindows ? '.exe' : '';
    if (command == null) {
      throw Exception(
        'Unable to locate srv$postfix binary.\n'
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
    Map<String, String> environment = {};
    if (rvdAuthString != null) {
      rvArgs.addAll(['--rv-auth']);
      environment['RV_AUTH'] = rvdAuthString!;
    }
    if (sessionAESKeyString != null && sessionIVString != null) {
      rvArgs.addAll(['--rv-e2ee']);
      environment['RV_AES'] = sessionAESKeyString!;
      environment['RV_IV'] = sessionIVString!;
    }

    logger.info('$runtimeType.run(): executing $command'
        ' ${rvArgs.join(' ')}');
    Process p = await Process.start(
      command,
      rvArgs,
      mode: ProcessStartMode.detachedWithStdio,
      includeParentEnvironment: true,
      environment: environment,
    );
    Completer rvPortBound = Completer();
    p.stdout.listen((List<int> l) {
      var s = utf8.decode(l).trim();
      logger.info('rv stdout | $s');
    }, onError: (e) {});
    p.stderr.listen((List<int> l) {
      var allLines = utf8.decode(l).trim();
      for (String s in allLines.split('\n')) {
        logger.info('rv stderr | $s');
        if (s.endsWith(completionString) && !rvPortBound.isCompleted) {
          rvPortBound.complete();
        }
      }
    }, onError: (e) {
      if (!rvPortBound.isCompleted) {
        rvPortBound.completeError(e);
      }
    });

    await rvPortBound.future.timeout(Duration(seconds: 2));

    return p;
  }
}

@visibleForTesting
class SrvImplDart implements Srv<SocketConnector> {
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

  @override
  final String? sessionAESKeyString;

  @override
  final String? sessionIVString;

  SrvImplDart(
    this.host,
    this.streamingPort, {
    required this.localPort,
    required this.bindLocalPort,
    this.rvdAuthString,
    this.sessionAESKeyString,
    this.sessionIVString,
  }) {
    if ((sessionAESKeyString == null && sessionIVString != null) ||
        (sessionAESKeyString != null && sessionIVString == null)) {
      throw ArgumentError('Both AES key and IV are required, or neither');
    }
  }

  @override
  Future<SocketConnector> run() async {
    DataTransformer? encrypter;
    DataTransformer? decrypter;

    if (sessionAESKeyString != null && sessionIVString != null) {
      final DartAesCtr algorithm = DartAesCtr.with256bits(
        macAlgorithm: Hmac.sha256(),
      );
      final SecretKey sessionAESKey =
          SecretKey(base64Decode(sessionAESKeyString!));
      final List<int> sessionIV = base64Decode(sessionIVString!);

      encrypter = (Stream<List<int>> stream) {
        return algorithm.encryptStream(
          stream,
          secretKey: sessionAESKey,
          nonce: sessionIV,
          onMac: (mac) {},
        );
      };
      decrypter = (Stream<List<int>> stream) {
        return algorithm.decryptStream(
          stream,
          secretKey: sessionAESKey,
          nonce: sessionIV,
          mac: Mac.empty,
        );
      };
    }

    try {
      var hosts = await InternetAddress.lookup(host);

      late final SocketConnector socketConnector;

      if (bindLocalPort) {
        socketConnector = await SocketConnector.serverToSocket(
            portA: localPort,
            addressB: hosts[0],
            portB: streamingPort,
            verbose: false,
            transformAtoB: encrypter,
            transformBtoA: decrypter);
        if (rvdAuthString != null) {
          stderr.writeln('authenticating socketB');
          socketConnector.pendingB.first.socket.writeln(rvdAuthString);
        }
      } else {
        socketConnector = await SocketConnector.socketToSocket(
            addressA: InternetAddress.loopbackIPv4,
            portA: localPort,
            addressB: hosts[0],
            portB: streamingPort,
            verbose: false,
            transformAtoB: encrypter,
            transformBtoA: decrypter);
        if (rvdAuthString != null) {
          stderr.writeln('authenticating socketB');
          socketConnector.connections.first.sideB.socket.writeln(rvdAuthString);
        }
      }

      // Do not remove this output; it is specifically looked for in
      // [SrvImplExec.run]. Why, you ask? Well, we have to wait until the srv
      // has fully started - i.e. on the daemon side, established two outbound
      // sockets, and on the client side, established one outbound socket and
      // bound to a port. Looking for specific output when the rv is ready to
      // do its job seems to be the only way to do this.
      stderr.writeln(SrvImplExec.completionString);

      return socketConnector;
    } catch (e) {
      AtSignLogger('srv').severe(e.toString());
      rethrow;
    }
  }

  Stream<List<int>> encrypt(Stream<List<int>> s) async* {}

  Stream<List<int>> decrypt(Stream<List<int>> s) async* {}
}
