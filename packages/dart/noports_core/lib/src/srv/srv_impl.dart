import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_utils/at_utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:mutex/mutex.dart';
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

  @override
  final Duration timeout;

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
    required this.timeout,
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
        "It's possible that either the binary is missing, or you are trying to run from source."
        "If the binary is missing, make sure the srv is installed, try reinstalling."
        "If you are trying to run from source, first compile sshnp.dart & srv.dart and try running the generated binary.",
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
      '--timeout',
      timeout.inSeconds.toString(),
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

    await rvPortBound.future.timeout(Duration(seconds: 3));

    await Future.delayed(Duration(milliseconds: 100));

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

  @override
  final Duration timeout;

  SrvImplInline(
    this.streamingHost,
    this.streamingPort, {
    this.rvdAuthString,
    this.sessionAESKeyString,
    this.sessionIVString,
    this.multi = false,
    required this.timeout,
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
      logger.info('Creating socket connection to rvd'
          ' at $streamingHost:$streamingPort');
      Socket socket = await Socket.connect(streamingHost, streamingPort);

      // Authenticate if we have an rvdAuthString
      if (rvdAuthString != null) {
        logger.info('run() authenticating to rvd');
        socket.writeln(rvdAuthString);
        await socket.flush();
      }

      WrappedSSHSocket sshSocket =
          WrappedSSHSocket(socket, rvdAuthString, encrypter, decrypter);

      return sshSocket;
    } catch (e) {
      logger.severe(e.toString());
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

  @override
  final Duration timeout;

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
    required this.timeout,
  }) {
    logger.info('New SrvImplDart - localPort $localPort');
    if ((sessionAESKeyString == null && sessionIVString != null) ||
        (sessionAESKeyString != null && sessionIVString == null)) {
      throw ArgumentError('Both AES key and IV are required, or neither');
    }
  }

  DataTransformer createEncrypter(String aesKeyBase64, String ivBase64) {
    final DartAesCtr algorithm = DartAesCtr.with256bits(
      macAlgorithm: MacAlgorithm.empty,
    );
    final SecretKey sessionAESKey = SecretKey(base64Decode(aesKeyBase64));
    final List<int> sessionIV = base64Decode(ivBase64);

    return (Stream<List<int>> stream) {
      return algorithm.encryptStream(
        stream,
        secretKey: sessionAESKey,
        nonce: sessionIV,
        onMac: (mac) {},
      );
    };
  }

  DataTransformer createDecrypter(String aesKeyBase64, String ivBase64) {
    final DartAesCtr algorithm = DartAesCtr.with256bits(
      macAlgorithm: MacAlgorithm.empty,
    );
    final SecretKey sessionAESKey = SecretKey(base64Decode(aesKeyBase64));
    final List<int> sessionIV = base64Decode(ivBase64);

    return (Stream<List<int>> stream) {
      return algorithm.decryptStream(
        stream,
        secretKey: sessionAESKey,
        nonce: sessionIV,
        mac: Mac.empty,
      );
    };
  }

  @override
  Future<SocketConnector> run() async {
    try {
      var hosts = await InternetAddress.lookup(streamingHost);
      late SocketConnector sc;
      // Determines whether the traffic in the socket is encrypted or transmitted in plain text.
      bool encryptRvdTraffic =
          (sessionAESKeyString != null && sessionIVString != null);

      if (bindLocalPort) {
        if (multi) {
          if (encryptRvdTraffic == true &&
              (sessionAESKeyString == null || sessionIVString == null)) {
            throw ArgumentError('Symmetric session encryption key required');
          }
          sc = await _runClientSideMulti(hosts: hosts, timeout: timeout);
        } else {
          sc = await _runClientSideSingle(hosts: hosts, timeout: timeout);
        }
      } else {
        // daemon side
        if (multi) {
          if (encryptRvdTraffic == true &&
              (sessionAESKeyString == null || sessionIVString == null)) {
            throw ArgumentError('Symmetric session encryption key required');
          }
          sc = await _runDaemonSideMulti(hosts: hosts, timeout: timeout);
        } else {
          sc = await _runDaemonSideSingle(hosts: hosts);
        }
      }

      // Do not remove this output; it is specifically looked for in
      // [SrvImplExec.run]. Why, you ask? Well, we have to wait until the srv
      // has fully started - i.e. on the daemon side, established two outbound
      // sockets, and on the client side, established one outbound socket and
      // bound to a port. Looking for specific output when the rv is ready to
      // do its job seems to be the only way to do this.
      if (detached) {
        try {
          stderr.writeln(Srv.startedString);
        } catch (e, st) {
          logger.severe('Failed to write ${Srv.startedString}'
              ' to stderr: ${e.toString()} ;'
              ' stackTrace follows:\n'
              '$st');
        }
      }

      return sc;
    } catch (e) {
      logger.severe(e.toString());
      rethrow;
    }
  }

  Future<SocketConnector> _runClientSideSingle({
    required List<InternetAddress> hosts,
    required Duration timeout,
  }) async {
    DataTransformer? encrypter;
    DataTransformer? decrypter;
    if (sessionAESKeyString != null && sessionIVString != null) {
      encrypter = createEncrypter(sessionAESKeyString!, sessionIVString!);
      decrypter = createDecrypter(sessionAESKeyString!, sessionIVString!);
    }
    // client side
    SocketConnector sc = await SocketConnector.serverToSocket(
      portA: localPort,
      addressB: hosts[0],
      portB: streamingPort,
      verbose: false,
      logger: ioSinkForLogger(logger),
      transformAtoB: encrypter,
      transformBtoA: decrypter,
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) async {
        logger.info('beforeJoining called');
        // Authenticate the sideB socket (to the rvd)
        if (rvdAuthString != null) {
          logger.info('_runClientSideSingle authenticating'
              ' new connection to rvd');
          sideB.socket.writeln(rvdAuthString);
        }
      },
    );
    return sc;
  }

  Future<SocketConnector> _runClientSideMulti({
    required List<InternetAddress> hosts,
    required Duration timeout,
  }) async {
    // client side
    SocketConnector? socketConnector;
    Socket sessionControlSocket = await Socket.connect(
        streamingHost, streamingPort,
        timeout: Duration(seconds: 10));
    // Authenticate the control socket
    if (rvdAuthString != null) {
      logger.info('_runClientSideMulti authenticating'
          ' control socket connection to rvd');
      sessionControlSocket.writeln(rvdAuthString);
    }

    if (sessionAESKeyString != null && sessionIVString != null) {
      logger
          .info('_runClientSideMulti: On the client-side traffic is encrypted');
      socketConnector = await _clientSideEncryptedSocket(
          sessionControlSocket, socketConnector, hosts, timeout);
    } else {
      logger.info(
          '_runClientSideMulti: On the client-side traffic is transmitted in plain text');
      socketConnector = await _clientSidePlainSocket(
          sessionControlSocket, socketConnector, hosts, timeout);
    }

    logger.info('_runClientSideMulti serverToSocket is ready');
    // upon socketConnector.done, destroy the control socket, and complete
    unawaited(socketConnector.done.whenComplete(() {
      logger.info('_runClientSideMulti sc.done');
      sessionControlSocket.destroy();
    }));
    return socketConnector;
  }

  /// On the client side, the data in this socket remains unencrypted and is transmitted in plain text
  Future<SocketConnector> _clientSidePlainSocket(
      Socket sessionControlSocket,
      SocketConnector? socketConnector,
      List<InternetAddress> hosts,
      Duration timeout) async {
    sessionControlSocket.listen((event) {
      String response = String.fromCharCodes(event).trim();
      logger.info('_runClientSideMulti'
          ' Received control socket response: [$response]');
    }, onError: (e) {
      logger.severe('_runClientSideMulti controlSocket error: $e');
      socketConnector?.close();
    }, onDone: () {
      logger.info('_runClientSideMulti controlSocket done');
      socketConnector?.close();
    });
    socketConnector = await SocketConnector.serverToSocket(
      portA: localPort,
      addressB: hosts[0],
      portB: streamingPort,
      verbose: false,
      logger: ioSinkForLogger(logger),
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) {
        logger.info('_runClientSideMulti Sending connect request');
        sessionControlSocket
            .add(Uint8List.fromList('connect:no:encrypt\n'.codeUnits));
        // Authenticate the sideB socket (to the rvd)
        if (rvdAuthString != null) {
          logger
              .info('_runClientSideMulti authenticating new connection to rvd');
          sideB.socket.writeln(rvdAuthString);
        }
      },
    );
    return socketConnector;
  }

  /// On the client side, the data in encrypted and is transmitted through this socket.
  Future<SocketConnector> _clientSideEncryptedSocket(
      Socket sessionControlSocket,
      SocketConnector? socketConnector,
      List<InternetAddress> hosts,
      Duration timeout) async {
    DataTransformer controlEncrypter =
        createEncrypter(sessionAESKeyString!, sessionIVString!);
    DataTransformer controlDecrypter =
        createDecrypter(sessionAESKeyString!, sessionIVString!);

    // Listen to stream which is decrypting the socket stream
    // Write to a stream controller which encrypts and writes to the socket
    Stream<List<int>> controlStream = controlDecrypter(sessionControlSocket);
    StreamController<Uint8List> controlSink = StreamController<Uint8List>();
    controlEncrypter(controlSink.stream).listen(sessionControlSocket.add);

    controlStream.listen((event) {
      String response = String.fromCharCodes(event).trim();
      logger.info('_runClientSideMulti'
          ' Received control socket response: [$response]');
    }, onError: (e) {
      logger.severe('_runClientSideMulti controlSocket error: $e');
      socketConnector?.close();
    }, onDone: () {
      logger.info('_runClientSideMulti controlSocket done');
      socketConnector?.close();
    });

    logger.info('_runClientSideMulti calling SocketConnector.serverToSocket');
    socketConnector = await SocketConnector.serverToSocket(
      portA: localPort,
      addressB: hosts[0],
      portB: streamingPort,
      verbose: false,
      logger: ioSinkForLogger(logger),
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) {
        logger.info('_runClientSideMulti Sending connect request');

        String socketAESKey =
            AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;
        String socketIV =
            base64Encode(AtChopsUtil.generateRandomIV(16).ivBytes);
        controlSink.add(
            Uint8List.fromList('connect:$socketAESKey:$socketIV\n'.codeUnits));
        // Authenticate the sideB socket (to the rvd)
        if (rvdAuthString != null) {
          logger
              .info('_runClientSideMulti authenticating new connection to rvd');
          sideB.socket.writeln(rvdAuthString);
        }
        sideA.transformer = createEncrypter(socketAESKey, socketIV);
        sideB.transformer = createDecrypter(socketAESKey, socketIV);
      },
    );
    return socketConnector;
  }

  Future _handleMultiConnectRequest(
    SocketConnector sc,
    List<InternetAddress> hosts,
    String request,
  ) async {
    List<String> args = request.split(":");
    switch (args.first) {
      case 'connect':
        // Handles the request from the socket where data needs no encryption.
        // When --no-encrypt-rvd-traffic flag is set to true.
        if (request == 'connect:no:encrypt') {
          await SocketConnector.socketToSocket(
              connector: sc,
              addressA:
                  (await InternetAddress.lookup(localHost ?? 'localhost'))[0],
              portA: localPort,
              addressB: hosts[0],
              portB: streamingPort,
              verbose: false,
              logger: ioSinkForLogger(logger));
          if (rvdAuthString != null) {
            logger.info('_runDaemonSideMulti authenticating'
                ' new socket connection to rvd');
            sc.connections.last.sideB.socket.writeln(rvdAuthString);
          }
          return;
        } else {
          // In this case, the data in the socket is encrypted.
          if (args.length != 3) {
            logger.severe('Unknown request to control socket: [$request]');
            return;
          }
          logger.info('_runDaemonSideMulti'
              ' Control socket received ${args.first} request - '
              ' creating new socketToSocket connection');
          await SocketConnector.socketToSocket(
              connector: sc,
              addressA:
                  (await InternetAddress.lookup(localHost ?? 'localhost'))[0],
              portA: localPort,
              addressB: hosts[0],
              portB: streamingPort,
              verbose: false,
              logger: ioSinkForLogger(logger),
              transformAtoB: createEncrypter(args[1], args[2]),
              transformBtoA: createDecrypter(args[1], args[2]));
          if (rvdAuthString != null) {
            logger.info('_runDaemonSideMulti authenticating'
                ' new socket connection to rvd');
            sc.connections.last.sideB.socket.writeln(rvdAuthString);
          }
        }
        break;
      default:
        logger.severe('Unknown request to control socket: [$request]');
    }
  }

  Future<SocketConnector> _runDaemonSideMulti({
    required List<InternetAddress> hosts,
    required Duration timeout,
  }) async {
    SocketConnector sc = SocketConnector(timeout: timeout);

    // - create control socket and listen for requests
    // - for each request, create a socketToSocket connection
    Socket sessionControlSocket = await Socket.connect(
        streamingHost, streamingPort,
        timeout: Duration(seconds: 10));
    // Authenticate the control socket
    if (rvdAuthString != null) {
      logger.info('_runDaemonSideMulti authenticating'
          ' control socket connection to rvd');
      sessionControlSocket.writeln(rvdAuthString);
    }

    if (sessionAESKeyString != null && sessionIVString != null) {
      logger
          .info('_runDaemonSideMulti: On the daemon side traffic is encrypted');
      _daemonSideEncryptedSocket(sessionControlSocket, sc, hosts);
    } else {
      logger.info(
          '_runDaemonSideMulti: On the daemon side traffic is transmitted in plain text');
      _daemonSidePlainSocket(sessionControlSocket, sc, hosts);
    }

    // upon socketConnector.done, destroy the control socket, and complete
    unawaited(sc.done.whenComplete(() {
      sessionControlSocket.destroy();
    }));

    return sc;
  }

  void _daemonSidePlainSocket(Socket sessionControlSocket, SocketConnector sc,
      List<InternetAddress> hosts) {
    Mutex controlStreamMutex = Mutex();
    sessionControlSocket.listen((event) async {
      await _sessionControlSocketListener(controlStreamMutex, event, sc, hosts);
    }, onError: (e) {
      logger.severe('controlSocket error: $e');
      sc.close();
    }, onDone: () {
      logger.info('controlSocket done');
      sc.close();
    });
  }

  void _daemonSideEncryptedSocket(Socket sessionControlSocket,
      SocketConnector sc, List<InternetAddress> hosts) {
    DataTransformer controlEncrypter =
        createEncrypter(sessionAESKeyString!, sessionIVString!);
    DataTransformer controlDecrypter =
        createDecrypter(sessionAESKeyString!, sessionIVString!);

    // Listen to stream which is decrypting the socket stream
    // Write to a stream controller which encrypts and writes to the socket
    Stream<List<int>> controlStream = controlDecrypter(sessionControlSocket);
    StreamController<Uint8List> controlSink = StreamController<Uint8List>();
    controlEncrypter(controlSink.stream).listen(sessionControlSocket.add);

    Mutex controlStreamMutex = Mutex();
    controlStream.listen((event) async {
      logger.info('Received event on control socket.');
      await _sessionControlSocketListener(controlStreamMutex, event, sc, hosts);
    }, onError: (e) {
      logger.severe('controlSocket error: $e');
      sc.close();
    }, onDone: () {
      logger.info('controlSocket done');
      sc.close();
    });
  }

  Future<void> _sessionControlSocketListener(Mutex controlStreamMutex,
      List<int> event, SocketConnector sc, List<InternetAddress> hosts) async {
    try {
      await controlStreamMutex.acquire();
      if (event.isEmpty) {
        logger.info('Empty control message (Uint8List) received');
        return;
      }
      String eventStr = String.fromCharCodes(event).trim();
      if (eventStr.isEmpty) {
        logger.info('Empty control message (String) received');
        return;
      }
      // TODO The code below (splitting by `connect:`) resolves a
      // particular issue for the moment, but the overall approach
      // to handling control messages needs to be redone, e.g. :
      // Ideally - send the control request, and a newline
      //   => as of this commit, this is the case
      // Receive - wait for newline, handle the request, repeat
      //   => older npt clients don't send `\n` so we will need to add some
      //      magic to handle both (a) older clients which don't send `\n`
      //      as well as (b) newer ones which do. Cleanest is to add a
      //      flag to the npt request from the client stating that it sends
      //      `\n` . If so then we handle that cleanly; if not then we use
      //      this approach (split by `connect:`)
      List<String> requests = eventStr.split('connect:');
      for (String request in requests) {
        if (request.isNotEmpty) {
          await _handleMultiConnectRequest(sc, hosts, 'connect:$request');
        }
      }
    } finally {
      controlStreamMutex.release();
    }
  }

  Future<SocketConnector> _runDaemonSideSingle({
    required List<InternetAddress> hosts,
  }) async {
    DataTransformer? encrypter;
    DataTransformer? decrypter;
    if (sessionAESKeyString != null && sessionIVString != null) {
      encrypter = createEncrypter(sessionAESKeyString!, sessionIVString!);
      decrypter = createDecrypter(sessionAESKeyString!, sessionIVString!);
    }
    SocketConnector socketConnector = await SocketConnector.socketToSocket(
        addressA: (await InternetAddress.lookup(localHost ?? 'localhost'))[0],
        portA: localPort,
        addressB: hosts[0],
        portB: streamingPort,
        verbose: false,
        logger: ioSinkForLogger(logger),
        transformAtoB: encrypter,
        transformBtoA: decrypter);
    if (rvdAuthString != null) {
      logger.info('_runDaemonSideSingle authenticating socketB to rvd');
      socketConnector.connections.first.sideB.socket.writeln(rvdAuthString);
    }

    return socketConnector;
  }
}

IOSink ioSinkForLogger(AtSignLogger l) {
  StreamController<List<int>> logSinkSc = StreamController<List<int>>();
  logSinkSc.stream.listen((event) {
    l.shout(' (SocketConnector) | ${String.fromCharCodes(event)}');
  });
  return IOSink(logSinkSc.sink);
}
