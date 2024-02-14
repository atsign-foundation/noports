import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_utils/at_utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/srv.dart';
import 'package:noports_core/sshnp.dart';
import 'package:socket_connector/socket_connector.dart';

@visibleForTesting
class SrvImplExec implements Srv<Process> {
  static final AtSignLogger logger = AtSignLogger('SrvImplExec');

  @override
  final String streamingHost;

  @override
  final int streamingPort;

  @override
  final int? localPort;

  @override
  final String? localHost;

  @override
  final bool? bindLocalPort;

  @override
  final String? rvdAuthString;

  @override
  final String? sessionAESKeyString;

  @override
  final String? sessionIVString;

  @override
  final bool multi;

  SrvImplExec(
    this.streamingHost,
    this.streamingPort, {
    this.localPort,
    this.localHost,
    this.bindLocalPort = false,
    this.rvdAuthString,
    this.sessionAESKeyString,
    this.sessionIVString,
    required this.multi,
  }) {
    if (localPort == null) {
      throw ArgumentError('localPort must be non-null');
    }
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
      throw SshnpError(
        'Unable to locate srv$postfix binary.\n'
        'N.B. sshnp is expected to be compiled and run from source, not via the dart command.',
      );
    }
    var rvArgs = [
      '-h',
      streamingHost,
      '-p',
      streamingPort.toString(),
      '--local-port',
      localPort.toString(),
      '--local-host',
      localHost ?? 'localhost',
    ];
    if (multi) {
      rvArgs.add('--multi');
    }
    if (bindLocalPort ?? false) {
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
      var allLines = utf8.decode(l).trim();
      for (String s in allLines.split('\n')) {
        logger.info('rv stdout | $s');
        if (s.contains(Srv.startedString) && !rvPortBound.isCompleted) {
          rvPortBound.complete();
        } else if (s.contains(Srv.completedWithExceptionString)) {
          if (!rvPortBound.isCompleted) {
            rvPortBound.completeError(s);
          }
        }
      }
    }, onError: (e) {});
    p.stderr.listen((List<int> l) {
      var allLines = utf8.decode(l).trim();
      for (String s in allLines.split('\n')) {
        logger.info('rv stderr | $s');
        if (s.contains(Srv.startedString) && !rvPortBound.isCompleted) {
          rvPortBound.complete();
        } else if (s.contains(Srv.completedWithExceptionString)) {
          if (!rvPortBound.isCompleted) {
            rvPortBound.completeError(s);
          }
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
class SrvImplInline implements Srv<SSHSocket> {
  final AtSignLogger logger = AtSignLogger('SrvImplInline');

  @override
  final String streamingHost;

  @override
  final int streamingPort;

  @override
  final int localPort = -1;

  @override
  final bool bindLocalPort = false;

  @override
  final String? localHost = null;

  @override
  final String? rvdAuthString;

  @override
  final String? sessionAESKeyString;

  @override
  final String? sessionIVString;

  @override
  final bool multi;

  SrvImplInline(
    this.streamingHost,
    this.streamingPort, {
    this.rvdAuthString,
    this.sessionAESKeyString,
    this.sessionIVString,
    this.multi = false,
  }) {
    if ((sessionAESKeyString == null && sessionIVString != null) ||
        (sessionAESKeyString != null && sessionIVString == null)) {
      throw ArgumentError('Both AES key and IV are required, or neither');
    }
  }

  @override
  Future<SSHSocket> run() async {
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
      logger.info(
          'Creating socket connection to rvd at $streamingHost:$streamingPort');
      Socket socket = await Socket.connect(streamingHost, streamingPort);

      // Authenticate if we have an rvdAuthString
      if (rvdAuthString != null) {
        logger.info('authenticating');
        socket.writeln(rvdAuthString);
        await socket.flush();
      }

      WrappedSSHSocket sshSocket =
          WrappedSSHSocket(socket, rvdAuthString, encrypter, decrypter);

      return sshSocket;
    } catch (e) {
      AtSignLogger('srv').severe(e.toString());
      rethrow;
    }
  }
}

/// - Get a hold of the underlying SSHSocket's Stream and StreamSink
/// - Wrap the StreamSink with encrypter
/// - Wrap the Stream with decrypter
class WrappedSSHSocket implements SSHSocket {
  /// The actual underlying socket
  final Socket socket;
  final String? rvdAuthString;
  final DataTransformer? encrypter;
  final DataTransformer? decrypter;

  late StreamSink<List<int>> _sink;
  late Stream<Uint8List> _stream;

  WrappedSSHSocket(
      this.socket, this.rvdAuthString, this.encrypter, this.decrypter) {
    if (encrypter == null) {
      _sink = socket;
    } else {
      StreamController<Uint8List> sc = StreamController<Uint8List>();
      Stream<List<int>> encrypted = encrypter!(sc.stream);
      encrypted.listen(socket.add);
      _sink = sc;
    }

    if (decrypter == null) {
      _stream = socket;
    } else {
      _stream = decrypter!(socket).cast<Uint8List>();
    }
  }

  @override
  Future<void> close() async {
    await socket.close();
  }

  @override
  void destroy() {
    socket.destroy();
  }

  @override
  Future<void> get done => socket.done;

  @override
  StreamSink<List<int>> get sink => _sink;

  @override
  Stream<Uint8List> get stream => _stream;
}

@visibleForTesting
class SrvImplDart implements Srv<SocketConnector> {
  @override
  final String streamingHost;

  @override
  final int streamingPort;

  @override
  final int localPort;

  @override
  final String? localHost;

  @override
  final bool bindLocalPort;

  @override
  final String? rvdAuthString;

  @override
  final String? sessionAESKeyString;

  @override
  final String? sessionIVString;

  @override
  final bool multi;

  final bool detached;

  final AtSignLogger logger = AtSignLogger(' SrvImplDart ');

  SrvImplDart(
    this.streamingHost,
    this.streamingPort, {
    required this.localPort,
    required this.bindLocalPort,
    this.localHost,
    this.rvdAuthString,
    this.sessionAESKeyString,
    this.sessionIVString,
    this.multi = false,
    required this.detached,
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
      var hosts = await InternetAddress.lookup(streamingHost);

      late SocketConnector sc;
      if (bindLocalPort) {
        if (multi) {
          sc = await _runClientSideMulti(
            hosts: hosts,
            encrypter: encrypter,
            decrypter: decrypter,
          );
        } else {
          sc = await _runClientSideSingle(
            hosts: hosts,
            encrypter: encrypter,
            decrypter: decrypter,
          );
        }
      } else {
        // daemon side
        if (multi) {
          sc = await _runDaemonSideMulti(
            hosts: hosts,
            encrypter: encrypter,
            decrypter: decrypter,
          );
        } else {
          sc = await _runDaemonSideSingle(
            hosts: hosts,
            encrypter: encrypter,
            decrypter: decrypter,
          );
        }
      }

      // Do not remove this output; it is specifically looked for in
      // [SrvImplExec.run]. Why, you ask? Well, we have to wait until the srv
      // has fully started - i.e. on the daemon side, established two outbound
      // sockets, and on the client side, established one outbound socket and
      // bound to a port. Looking for specific output when the rv is ready to
      // do its job seems to be the only way to do this.
      if (detached) {
        stderr.writeln(Srv.startedString);
      }

      return sc;
    } catch (e) {
      AtSignLogger('srv').severe(e.toString());
      rethrow;
    }
  }

  Future<SocketConnector> _runClientSideSingle({
    required List<InternetAddress> hosts,
    required DataTransformer? encrypter,
    required DataTransformer? decrypter,
  }) async {
    // client side
    SocketConnector sc = await SocketConnector.serverToSocket(
      portA: localPort,
      addressB: hosts[0],
      portB: streamingPort,
      verbose: false,
      transformAtoB: encrypter,
      transformBtoA: decrypter,
      multi: multi,
      onConnect: (Socket sideA, Socket sideB) async {
        // Authenticate the sideB socket (to the rvd)
        if (rvdAuthString != null) {
          logger.info(
              '_runClientSideSingle authenticating new connection to rvd');
          sideB.writeln(rvdAuthString);
        }
      },
    );

    return sc;
  }

  Future<SocketConnector> _runClientSideMulti({
    required List<InternetAddress> hosts,
    required DataTransformer? encrypter,
    required DataTransformer? decrypter,
  }) async {
    // client side
    SocketConnector? sc;

    Socket controlSocket = await Socket.connect(streamingHost, streamingPort,
        timeout: Duration(seconds: 1));
    // Authenticate the control socket
    if (rvdAuthString != null) {
      logger.info(
          '_runClientSideMulti authenticating control socket connection to rvd');
      controlSocket.writeln(rvdAuthString);
    }
    controlSocket.listen((event) {
      String response = String.fromCharCodes(event).trim();
      logger.info(
          '_runClientSideMulti Received control socket response: [$response]');
    }, onError: (e) {
      logger.severe('_runClientSideMulti controlSocket error: $e');
      sc?.close();
    }, onDone: () {
      logger.info('_runClientSideMulti controlSocket done');
      sc?.close();
    });

    sc = await SocketConnector.serverToSocket(
      portA: localPort,
      addressB: hosts[0],
      portB: streamingPort,
      verbose: false,
      transformAtoB: encrypter,
      transformBtoA: decrypter,
      multi: multi,
      onConnect: (Socket sideA, Socket sideB) {
        // For some bizarro reason, we can't use the logger or write to stderr
        // in this callback
        logger.info('_runClientSideMulti Sending connect request');
        controlSocket.writeln('connect');
        // Authenticate the sideB socket (to the rvd)
        if (rvdAuthString != null) {
          logger
              .info('_runClientSideMulti authenticating new connection to rvd');
          sideB.writeln(rvdAuthString);
        }
      },
    );

    // upon socketConnector.done, destroy the control socket, and complete
    unawaited(sc.done.whenComplete(() {
      logger.info('_runClientSideMulti sc.done');
      controlSocket.destroy();
    }));

    return sc;
  }

  Future<SocketConnector> _runDaemonSideMulti({
    required List<InternetAddress> hosts,
    required DataTransformer? encrypter,
    required DataTransformer? decrypter,
  }) async {
    SocketConnector sc = SocketConnector();

    // - create control socket and listen for requests
    // - for each request, create a socketToSocket connection
    Socket controlSocket = await Socket.connect(streamingHost, streamingPort,
        timeout: Duration(seconds: 1));
    if (rvdAuthString != null) {
      logger.info('authenticating control socket connection to rvd');
      controlSocket.writeln(rvdAuthString);
    }
    controlSocket.listen((event) async {
      if (event.isEmpty) {
        logger.info('Empty control message (Uint8List) received');
        return;
      }
      String request = String.fromCharCodes(event).trim();
      if (request.isEmpty) {
        logger.info('Empty control message (String) received');
        return;
      }
      switch (request) {
        case 'connect':
          logger.info('Control socket received request: [$request];'
              ' creating new socketToSocket connection');
          await SocketConnector.socketToSocket(
              connector: sc,
              addressA:
                  (await InternetAddress.lookup(localHost ?? 'localhost'))[0],
              portA: localPort,
              addressB: hosts[0],
              portB: streamingPort,
              verbose: false,
              transformAtoB: encrypter,
              transformBtoA: decrypter);
          if (rvdAuthString != null) {
            stderr.writeln('authenticating new socket connection to rvd');
            sc.connections.last.sideB.socket.writeln(rvdAuthString);
          }

          break;
        default:
          logger.severe('Unknown request to control socket: [$request]');
      }
    }, onError: (e) {
      logger.severe('controlSocket error: $e');
      sc.close();
    }, onDone: () {
      logger.info('controlSocket done');
      sc.close();
    });

    // upon socketConnector.done, destroy the control socket, and complete
    unawaited(sc.done.whenComplete(() {
      controlSocket.destroy();
    }));

    return sc;
  }

  Future<SocketConnector> _runDaemonSideSingle({
    required List<InternetAddress> hosts,
    required DataTransformer? encrypter,
    required DataTransformer? decrypter,
  }) async {
    SocketConnector socketConnector = await SocketConnector.socketToSocket(
        addressA: (await InternetAddress.lookup(localHost ?? 'localhost'))[0],
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

    return socketConnector;
  }
}
