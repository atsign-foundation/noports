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
import 'package:at_commons/at_commons.dart' as at_commons;

const newLineCodeUnit = 10;

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

  @override
  final Duration? controlChannelHeartbeat;

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
    this.controlChannelHeartbeat,
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
    if (controlChannelHeartbeat != null) {
      rvArgs.addAll(
          ['--heartbeat', controlChannelHeartbeat!.inSeconds.toString()]);
    }
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

  @override
  final Duration? controlChannelHeartbeat;

  SrvImplInline(
    this.streamingHost,
    this.streamingPort, {
    this.rvdAuthString,
    this.sessionAESKeyString,
    this.sessionIVString,
    this.multi = false,
    required this.timeout,
    required this.controlChannelHeartbeat,
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

  @override
  final Duration? controlChannelHeartbeat;

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
    this.controlChannelHeartbeat,
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
      var relayAddresses = await InternetAddress.lookup(streamingHost);
      if (relayAddresses.isEmpty) {
        throw Exception('Cannot resolve relay host $streamingHost');
      }
      InternetAddress relayAddress = relayAddresses[0];
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
          sc = await _runClientSideMulti(
              relayAddress: relayAddress, timeout: timeout);
        } else {
          sc = await _runClientSideSingle(
              relayAddress: relayAddress, timeout: timeout);
        }
      } else {
        // daemon side
        if (multi) {
          if (encryptRvdTraffic == true &&
              (sessionAESKeyString == null || sessionIVString == null)) {
            throw ArgumentError('Symmetric session encryption key required');
          }
          sc = await _runDaemonSideMulti(
              relayAddress: relayAddress, timeout: timeout);
        } else {
          sc = await _runDaemonSideSingle(relayAddress: relayAddress);
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
    required InternetAddress relayAddress,
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
      addressB: relayAddress,
      portB: streamingPort,
      verbose: Platform.environment['SRV_TRACE'] == 'true',
      logger: ioSinkForLogger(logger),
      transformAtoB: encrypter,
      transformBtoA: decrypter,
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) {
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
    required InternetAddress relayAddress,
    required Duration timeout,
  }) async {
    // client side
    SocketConnector? socketConnector;
    Socket sessionControlSocket = await Socket.connect(
        streamingHost, streamingPort,
        timeout: Duration(seconds: 10));
    // Authenticate the control channel
    if (rvdAuthString != null) {
      logger.info('_runClientSideMulti authenticating'
          ' control channel connection to rvd');
      sessionControlSocket.writeln(rvdAuthString);
    }

    if (sessionAESKeyString != null && sessionIVString != null) {
      logger
          .info('_runClientSideMulti: On the client-side traffic is encrypted');
      socketConnector = await _clientSideEncryptedSocket(
          sessionControlSocket, socketConnector, relayAddress, timeout);
    } else {
      logger.info(
          '_runClientSideMulti: On the client-side traffic is transmitted in plain text');
      socketConnector = await _clientSidePlainSocket(
          sessionControlSocket, socketConnector, relayAddress, timeout);
    }

    logger.info('_runClientSideMulti serverToSocket is ready');
    // upon socketConnector.done, destroy the control channel, and complete
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
      InternetAddress relayAddress,
      Duration timeout) async {
    sessionControlSocket.listen((event) {
      String response = String.fromCharCodes(event).trim();
      logger.info('_runClientSideMulti'
          ' Received control channel response: [$response]');
    }, onError: (e) {
      logger.severe('_runClientSideMulti controlSocket error: $e');
      socketConnector?.close();
    }, onDone: () {
      logger.info('_runClientSideMulti controlSocket done');
      socketConnector?.close();
    });
    socketConnector = await SocketConnector.serverToSocket(
      portA: localPort,
      addressB: relayAddress,
      portB: streamingPort,
      verbose: Platform.environment['SRV_TRACE'] == 'true',
      logger: ioSinkForLogger(logger),
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) {
        logger.info('_runClientSideMulti Sending connect request');
        sessionControlSocket.add(
          Uint8List.fromList('connect:no:encrypt\n'.codeUnits),
        );
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
      InternetAddress relayAddress,
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
          ' Received control channel response: [$response]');
    }, onError: (e) {
      logger.severe('_runClientSideMulti controlSocket error: $e');
      socketConnector?.close();
    }, onDone: () {
      logger.info('_runClientSideMulti controlSocket done');
      socketConnector?.close();
    });

    if (controlChannelHeartbeat != null) {
      bool heartbeatInProgress = false;
      int heartbeatCounter = 1;
      Timer.periodic(controlChannelHeartbeat!, (timer) async {
        if (heartbeatInProgress) {
          logger.warning('control channel heartbeat already in progress');
          return;
        }
        try {
          heartbeatInProgress = true;
          logger.info('Sending heartbeat $heartbeatCounter on control channel');
          controlSink.add(
            Uint8List.fromList('heartbeat:$heartbeatCounter\n'.codeUnits),
          );
          heartbeatCounter++;
        } finally {
          heartbeatInProgress = false;
        }
      });
    }

    logger.info('_runClientSideMulti calling SocketConnector.serverToSocket');
    socketConnector = await SocketConnector.serverToSocket(
      portA: localPort,
      addressB: relayAddress,
      portB: streamingPort,
      verbose: Platform.environment['SRV_TRACE'] == 'true',
      logger: ioSinkForLogger(logger),
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) async {
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

  Future<void> _handleMultiConnectRequest(
    SocketConnector sc,
    InternetAddress relayAddress,
    DataTransformer? encrypter,
    DataTransformer? decrypter,
  ) async {
    logger.info('_runDaemonSideMulti'
        ' control channel received connect request - '
        ' creating new socketToSocket connection');

    InternetAddress localAddress = await resolveRequestedLocalHost();

    // First, connect to the relay.
    // If it fails, return, as we can't do anything more
    late Socket sideBSocket;
    late Side sideB;
    logger.info(
        'socket_connector: Connecting side B (relay - $relayAddress:$streamingPort)');
    try {
      sideBSocket = await Socket.connect(relayAddress, streamingPort);
      sideB = Side(sideBSocket, false, transformer: decrypter);
      unawaited(sideBSocket.done
          .then((v) => logger.info('relay socket done'))
          .catchError(
              (err) => logger.warning('relay socket done with error $err')));
      if (rvdAuthString != null) {
        logger.info('_runDaemonSideMulti authenticating'
            ' new socket connection to relay');
        sideBSocket.writeln(rvdAuthString);
        await sideBSocket.flush();
      }
    } catch (e) {
      logger.shout('Failed to connect to relay ($relayAddress:$streamingPort)'
          ' with error : $e');
      return;
    }

    // Now, connect to the local host:port
    // If it fails, we need to close the socket connection to the relay
    late Socket sideASocket;
    late Side sideA;
    logger.info(
        'socket_connector: Connecting side A (local - $localAddress:$localPort)');

    try {
      sideASocket = await Socket.connect(localAddress, localPort);
      sideA = Side(sideASocket, true, transformer: encrypter);
    } catch (e) {
      logger.shout('Failed to connect locally ($localAddress:$localPort)'
          ' with error : $e');
      logger.shout('Closing sideB (relay) socket connection');
      sideBSocket.destroy();

      return;
    }

    // Finally, let's have the socket connector join the sides together
    unawaited(sc.handleSingleConnection(sideB).catchError((err) {
      logger.severe(
          'ERROR $err from handleSingleConnection on sideB (relay - $relayAddress:$streamingPort)');
    }));
    unawaited(sc.handleSingleConnection(sideA).catchError((err) {
      logger.severe(
          'ERROR $err from handleSingleConnection on sideA (local - $localAddress:$localPort)');
    }));

    logger.info('socket_connector: started');
  }

  Future<void> _handleControlMessage(
    SocketConnector sc,
    InternetAddress relayAddress,
    String message,
  ) async {
    message = message.trim();
    List<String> args = message.split(":");
    DataTransformer? encrypter;
    DataTransformer? decrypter;
    switch (args.first) {
      case 'connect':
        if (message == 'connect:no:encrypt') {
          // unencrypted session
          encrypter = null;
          decrypter = null;
        } else {
          // Encrypted session, we expect params
          if (args.length < 3) {
            logger.severe('Malformed control message: [$message]');
            return;
          }
          decrypter = createDecrypter(args[1], args[2]);
          encrypter = createEncrypter(args[1], args[2]);
        }

        await _handleMultiConnectRequest(
            sc, relayAddress, encrypter, decrypter);
        break;
      case 'heartbeat':
        logger.info('Received control message: $message');
        break;
      default:
        logger.shout('Received unknown control message: [$message]');
        return;
    }
  }

  Future<SocketConnector> _runDaemonSideMulti({
    required InternetAddress relayAddress,
    required Duration timeout,
  }) async {
    SocketConnector sc = SocketConnector(
      timeout: timeout,
      verbose: Platform.environment['SRV_TRACE'] == 'true',
      logger: ioSinkForLogger(logger),
    );

    // - create control channel and listen for requests
    // - for each request, create a socketToSocket connection
    Socket sessionControlSocket = await Socket.connect(
        streamingHost, streamingPort,
        timeout: Duration(seconds: 10));
    // Authenticate the control channel
    if (rvdAuthString != null) {
      logger.info('_runDaemonSideMulti authenticating'
          ' control channel connection to rvd');
      sessionControlSocket.writeln(rvdAuthString);
    }

    if (sessionAESKeyString != null && sessionIVString != null) {
      logger
          .info('_runDaemonSideMulti: On the daemon side traffic is encrypted');
      _daemonSideEncryptedSocket(sessionControlSocket, sc, relayAddress);
    } else {
      logger.info(
          '_runDaemonSideMulti: On the daemon side traffic is transmitted in plain text');
      _daemonSidePlainSocket(sessionControlSocket, sc, relayAddress);
    }

    // upon socketConnector.done, destroy the control channel, and complete
    unawaited(sc.done.whenComplete(() {
      sessionControlSocket.destroy();
    }));

    return sc;
  }

  /// Start the control stream listener on the control channel itself
  /// since there is no encryption / decryption
  void _daemonSidePlainSocket(Socket sessionControlSocket, SocketConnector sc,
      InternetAddress relayAddress) {
    _startDaemonControlSocketListener(
      sessionControlSocket,
      sessionControlSocket,
      sc,
      relayAddress,
    );
  }

  /// Set up encrypter & decrypter and then start the control stream listener
  void _daemonSideEncryptedSocket(Socket sessionControlSocket,
      SocketConnector sc, InternetAddress relayAddress) {
    DataTransformer controlEncrypter =
        createEncrypter(sessionAESKeyString!, sessionIVString!);
    DataTransformer controlDecrypter =
        createDecrypter(sessionAESKeyString!, sessionIVString!);

    // Listen to stream which is decrypting the socket stream
    // Write to a stream controller which encrypts and writes to the socket
    Stream<List<int>> controlStream = controlDecrypter(sessionControlSocket);
    StreamController<Uint8List> controlSink = StreamController<Uint8List>();
    controlEncrypter(controlSink.stream).listen(sessionControlSocket.add);

    _startDaemonControlSocketListener(
      controlStream,
      controlSink,
      sc,
      relayAddress,
    );
  }

  void _startDaemonControlSocketListener(
    Stream<List<int>> sessionControlStream,
    StreamSink<List<int>> sessionControlSink,
    SocketConnector sc,
    InternetAddress relayAddress,
  ) {
    logger.info('Starting control channel listener');
    at_commons.ByteBuffer rcvBuffer = at_commons.ByteBuffer(capacity: 4096);
    Mutex controlStreamMutex = Mutex();
    sessionControlStream.listen((data) async {
      try {
        await controlStreamMutex.acquire();
        for (int element = 0; element < data.length; element++) {
          // If it's a '\n' then complete data has been received, so process it
          if (data[element] == newLineCodeUnit) {
            String controlMsg = '';
            try {
              controlMsg = utf8.decode(rcvBuffer.getData().toList()).trim();
              try {
                if (controlMsg.isEmpty) {
                  logger.info('Empty control message (Uint8List) received');
                  return;
                }
                await _handleControlMessage(sc, relayAddress, controlMsg);
              } catch (e, st) {
                logger.shout(
                    'Caught (will rethrow) error: $e\nStack Trace:\n$st');
                rethrow;
              }
            } catch (e) {
              logger.severe('$e while handling control message: $controlMsg');
            } finally {
              rcvBuffer.clear();
            }
          } else {
            rcvBuffer.addByte(data[element]);
            // Backwards compatibility for clients prior to 5.6.1
            // IF we're at the LAST byte in the received data
            // AND the rcvBuffer length is currently *precisely* an exact
            // multiple of the length of
            //   'connect:$socketAESKey:$socketIV'
            //       7   1     44      1   24
            // i.e. an exact multiple of 77
            // THEN we should also go ahead and process the request (or requests)
            int oldMagic = 7 + 1 + 44 + 1 + 24;
            if (element == data.length - 1) {
              if (rcvBuffer.length() % oldMagic == 0) {
                logger.shout('Backwards compatibility handler will process'
                    ' ${rcvBuffer.length() / oldMagic} messages');
                try {
                  List<int> toProcess = rcvBuffer.getData().toList();
                  while (toProcess.isNotEmpty) {
                    String controlMsg =
                        utf8.decode(toProcess.sublist(0, oldMagic)).trim();
                    toProcess = toProcess.sublist(oldMagic);
                    try {
                      await _handleControlMessage(sc, relayAddress, controlMsg);
                    } catch (e) {
                      logger.severe(
                          '$e while handling control message: $controlMsg');
                    }
                  }
                } finally {
                  rcvBuffer.clear();
                }
              }
            }
          }
        }
      } finally {
        controlStreamMutex.release();
      }
    }, onError: (e) {
      logger.severe('controlSocket error: $e');
      sc.close();
    }, onDone: () {
      logger.info('controlSocket done');
      sc.close();
    });
  }

  Future<InternetAddress> resolveRequestedLocalHost() async {
    String hostToLookup = localHost ?? 'localhost';
    List<InternetAddress> candidates = await InternetAddress.lookup(
        hostToLookup,
        type: InternetAddressType.IPv4);
    if (candidates.isEmpty) {
      candidates = await InternetAddress.lookup(hostToLookup,
          type: InternetAddressType.IPv6);
    }
    if (candidates.isEmpty) {
      throw Exception("Cannot resolve address for $hostToLookup");
    }
    return candidates[0];
  }

  Future<SocketConnector> _runDaemonSideSingle({
    required InternetAddress relayAddress,
  }) async {
    DataTransformer? encrypter;
    DataTransformer? decrypter;
    if (sessionAESKeyString != null && sessionIVString != null) {
      encrypter = createEncrypter(sessionAESKeyString!, sessionIVString!);
      decrypter = createDecrypter(sessionAESKeyString!, sessionIVString!);
    }
    InternetAddress localAddress = await resolveRequestedLocalHost();

    SocketConnector socketConnector = await SocketConnector.socketToSocket(
        addressA: localAddress,
        portA: localPort,
        addressB: relayAddress,
        portB: streamingPort,
        verbose: Platform.environment['SRV_TRACE'] == 'true',
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
