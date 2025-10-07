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
  final RelayAuthenticator? relayAuthenticator;

  @override
  final String? aesC2D;

  @override
  final String? ivC2D;

  @override
  final String? aesD2C;

  @override
  final String? ivD2C;

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
    required this.relayAuthenticator,
    this.aesC2D,
    this.ivC2D,
    this.aesD2C,
    this.ivD2C,
    required this.multi,
    required this.timeout,
    this.controlChannelHeartbeat,
  }) {
    logger.info('New SrvImplDart - localPort $localPort - timeout $timeout');
    if (localPort == null) {
      throw ArgumentError('localPort must be non-null');
    }
    if ((aesC2D == null && ivC2D != null) ||
        (aesC2D != null && ivC2D == null) ||
        (aesD2C == null && ivD2C != null) ||
        (aesD2C != null && ivD2C == null)) {
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
      rvArgs.addAll([
        '--heartbeat',
        controlChannelHeartbeat!.inSeconds.toString(),
      ]);
    }
    if (multi) {
      rvArgs.add('--multi');
    }
    if (bindLocalPort ?? false) {
      rvArgs.add('--bind-local-port');
    }
    Map<String, String> environment = {};

    if (relayAuthenticator != null) {
      rvArgs.addAll(relayAuthenticator!.rvArgs);
      for (final String name in relayAuthenticator!.envMap.keys) {
        environment[name] = relayAuthenticator!.envMap[name]!;
      }
    }
    if (aesC2D != null && ivC2D != null) {
      rvArgs.add('--rv-e2ee');
      environment['RV_AES_C2D'] = aesC2D!;
      environment['RV_IV_C2D'] = ivC2D!;
      if (aesD2C != null && ivD2C != null) {
        environment['RV_AES_D2C'] = aesD2C!;
        environment['RV_IV_D2C'] = ivD2C!;
      }
    }

    logger.info(
      '$runtimeType.run(): executing $command'
      ' ${rvArgs.join(' ')}',
    );
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
    p.stderr.listen(
      (List<int> l) {
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
      },
      onError: (e) {
        if (!rvPortBound.isCompleted) {
          rvPortBound.completeError(e);
        }
      },
    );

    await rvPortBound.future.timeout(Duration(seconds: 15));

    await Future.delayed(Duration(milliseconds: 100));

    return p;
  }
}

/// Only used on client side
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
  final RelayAuthenticator? relayAuthenticator;

  @override
  final String? aesC2D;

  @override
  final String? ivC2D;

  @override
  final String? aesD2C;

  @override
  final String? ivD2C;

  @override
  final bool multi;

  @override
  final Duration timeout;

  @override
  final Duration? controlChannelHeartbeat;

  SrvImplInline(
    this.streamingHost,
    this.streamingPort, {
    required this.relayAuthenticator,
    this.aesC2D,
    this.ivC2D,
    this.aesD2C,
    this.ivD2C,
    this.multi = false,
    required this.timeout,
    required this.controlChannelHeartbeat,
  }) {
    logger.info('New SrvImplInline - timeout $timeout');
    if ((aesC2D == null && ivC2D != null) ||
        (aesC2D != null && ivC2D == null) ||
        (aesD2C == null && ivD2C != null) ||
        (aesD2C != null && ivD2C == null)) {
      throw ArgumentError('Both AES key and IV are required, or neither');
    }
  }

  @override
  Future<SSHSocket> run() async {
    DataTransformer? encrypter;
    DataTransformer? decrypter;

    // Only used on client side, so we know to use C2D for the encrypter
    // and D2C for the decrypter (or C2D for backwards compatibility)
    if (aesC2D != null && ivC2D != null) {
      final DartAesCtr algorithm = DartAesCtr.with256bits(
        macAlgorithm: Hmac.sha256(),
      );
      final SecretKey sessionAESKeyC2D = SecretKey(base64Decode(aesC2D!));
      final List<int> sessionIVC2D = base64Decode(ivC2D!);

      encrypter = (Stream<List<int>> stream) {
        return algorithm.encryptStream(
          stream,
          secretKey: sessionAESKeyC2D,
          nonce: sessionIVC2D,
          onMac: (mac) {},
        );
      };
      if (aesD2C == null) {
        // backwards compatibility - use the same AES & IV
        decrypter = (Stream<List<int>> stream) {
          return algorithm.decryptStream(
            stream,
            secretKey: sessionAESKeyC2D,
            nonce: sessionIVC2D,
            mac: Mac.empty,
          );
        };
      } else {
        final SecretKey sessionAESKeyD2C = SecretKey(base64Decode(aesD2C!));
        final List<int> sessionIVD2C = base64Decode(ivD2C!);
        decrypter = (Stream<List<int>> stream) {
          return algorithm.decryptStream(
            stream,
            secretKey: sessionAESKeyD2C,
            nonce: sessionIVD2C,
            mac: Mac.empty,
          );
        };
      }
    }

    try {
      logger.info(
        'Creating socket connection to rvd'
        ' at $streamingHost:$streamingPort',
      );
      Socket socket = await Socket.connect(streamingHost, streamingPort);

      // Authenticate if we have a relayAuthenticator
      Stream<Uint8List>? socketStream;
      if (relayAuthenticator != null) {
        bool authenticated;
        logger.info('run() authenticating to rvd');
        (authenticated, socketStream) = await relayAuthenticator!.authenticate(
          socket,
        );
        if (!authenticated) {
          throw Exception('Authentication failed');
        }
      } else {
        socketStream = socket;
      }

      WrappedSSHSocket sshSocket = WrappedSSHSocket(
        socketStream!,
        socket,
        encrypter,
        decrypter,
        onClose: () async => socket.close(),
        onDestroy: () => socket.destroy(),
      );

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
  final Stream<Uint8List> underlyingStream;
  final IOSink underlyingSink;
  final DataTransformer? encrypter;
  final DataTransformer? decrypter;

  late StreamSink<List<int>> _sink;
  late Stream<Uint8List> _stream;

  Future<void> Function() onClose;
  void Function() onDestroy;

  WrappedSSHSocket(
    this.underlyingStream,
    this.underlyingSink,
    this.encrypter,
    this.decrypter, {
    required this.onClose,
    required this.onDestroy,
  }) {
    if (encrypter == null) {
      _sink = underlyingSink;
    } else {
      StreamController<Uint8List> sc = StreamController<Uint8List>();
      Stream<List<int>> encrypted = encrypter!(sc.stream);
      encrypted.listen(underlyingSink.add);
      _sink = sc;
    }

    if (decrypter == null) {
      _stream = underlyingStream;
    } else {
      _stream = decrypter!(underlyingStream).cast<Uint8List>();
    }
  }

  @override
  Future<void> close() async {
    await onClose();
  }

  @override
  void destroy() {
    onDestroy();
  }

  @override
  Future<void> get done => sink.done;

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
  final RelayAuthenticator? relayAuthenticator;

  @override
  final String? aesC2D;

  @override
  final String? ivC2D;

  @override
  final String? aesD2C;

  @override
  final String? ivD2C;

  @override
  final bool multi;

  final bool detached;

  @override
  final Duration timeout;

  @override
  final Duration? controlChannelHeartbeat;

  final AtSignLogger logger = AtSignLogger(' SrvImplDart ');

  late bool twinKeys;

  SrvImplDart(
    this.streamingHost,
    this.streamingPort, {
    required this.localPort,
    required this.bindLocalPort,
    this.localHost,
    required this.relayAuthenticator,
    this.aesC2D,
    this.ivC2D,
    this.aesD2C,
    this.ivD2C,
    this.multi = false,
    required this.detached,
    required this.timeout,
    this.controlChannelHeartbeat,
  }) {
    logger.info('New SrvImplDart - localPort $localPort - timeout $timeout');
    if ((aesC2D == null && ivC2D != null) ||
        (aesC2D != null && ivC2D == null) ||
        (aesD2C == null && ivD2C != null) ||
        (aesD2C != null && ivD2C == null)) {
      throw ArgumentError('Both AES key and IV are required, or neither');
    }
    twinKeys = (aesD2C != null);
  }

  DataTransformer createEncrypter(String aesKeyBase64, String ivBase64) {
    final DartAesCtr algorithm = DartAesCtr.with256bits(
      macAlgorithm: MacAlgorithm.empty,
    );
    final SecretKey aesKey = SecretKey(base64Decode(aesKeyBase64));
    final List<int> iv = base64Decode(ivBase64);

    return (Stream<List<int>> stream) {
      return algorithm.encryptStream(
        stream,
        secretKey: aesKey,
        nonce: iv,
        onMac: (mac) {},
      );
    };
  }

  DataTransformer createDecrypter(String aesKeyBase64, String ivBase64) {
    final DartAesCtr algorithm = DartAesCtr.with256bits(
      macAlgorithm: MacAlgorithm.empty,
    );
    final SecretKey aesKey = SecretKey(base64Decode(aesKeyBase64));
    final List<int> iv = base64Decode(ivBase64);

    return (Stream<List<int>> stream) {
      return algorithm.decryptStream(
        stream,
        secretKey: aesKey,
        nonce: iv,
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
      bool encryptRvdTraffic = (aesC2D != null && ivC2D != null);

      // If we are binding a local port, we are running on the client side.
      // Use aesC2D for encryption, aesD2C for decryption
      if (bindLocalPort) {
        if (multi) {
          if (encryptRvdTraffic == true && (aesC2D == null || ivC2D == null)) {
            throw ArgumentError('Symmetric session encryption key required');
          }
          sc = await _runClientSideMulti(
            relayAddress: relayAddress,
            timeout: timeout,
          );
        } else {
          sc = await _runClientSideSingle(
            relayAddress: relayAddress,
            timeout: timeout,
          );
        }
      } else {
        // daemon side
        if (multi) {
          if (encryptRvdTraffic == true && (aesC2D == null || ivC2D == null)) {
            throw ArgumentError('Symmetric session encryption key required');
          }
          sc = await _runDaemonSideMulti(
            relayAddress: relayAddress,
            timeout: timeout,
          );
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
          logger.severe(
            'Failed to write ${Srv.startedString}'
            ' to stderr: ${e.toString()} ;'
            ' stackTrace follows:\n'
            '$st',
          );
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
    if (aesC2D != null && ivC2D != null) {
      encrypter = createEncrypter(aesC2D!, ivC2D!);
      if (aesD2C == null) {
        // Backwards compatibility - use the same key & iv
        decrypter = createDecrypter(aesC2D!, ivC2D!);
      } else {
        decrypter = createDecrypter(aesD2C!, ivD2C!);
      }
    }
    // client side
    InternetAddress localAddress = await resolveRequestedLocalHost();
    SocketConnector sc = await SocketConnector.serverToSocket(
      portA: localPort,
      addressA: localAddress,
      addressB: relayAddress,
      portB: streamingPort,
      verbose: Platform.environment['SRV_TRACE'] == 'true',
      logger: ioSinkForLogger(logger),
      transformAtoB: encrypter,
      transformBtoA: decrypter,
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) async {
        logger.info('beforeJoining called');
        // Authenticate the sideB socket (to the rvd)
        if (relayAuthenticator != null) {
          logger.info(
            '_runClientSideSingle authenticating'
            ' new connection to rvd',
          );
          try {
            var (authenticated, authenticatedStream) = await relayAuthenticator!
                .authenticate(sideB.socket);
            if (!authenticated || authenticatedStream == null) {
              sideB.socket.destroy();
            } else {
              sideB.stream = authenticatedStream;
            }
          } catch (err) {
            logger.severe(
              '_runClientSideSingle'
              ' Failed to authenticate to relay: $err',
            );
            sideB.socket.destroy();
          }
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
      streamingHost,
      streamingPort,
      timeout: Duration(seconds: 10),
    );
    // Authenticate the control channel
    Stream<Uint8List>? authenticatedControlSocketStream;
    if (relayAuthenticator != null) {
      logger.info(
        '_runClientSideMulti authenticating'
        ' control channel connection to rvd',
      );
      bool authenticated;
      try {
        (authenticated, authenticatedControlSocketStream) =
            await relayAuthenticator!.authenticate(sessionControlSocket);
        if (!authenticated || authenticatedControlSocketStream == null) {
          sessionControlSocket.destroy();
          throw Exception(
            '_runClientSideMulti'
            ' Failed to authenticate control socket',
          );
        }
      } catch (err) {
        logger.severe(
          '_runClientSideMulti'
          ' Failed to authenticate control socket: $err',
        );
        sessionControlSocket.destroy();
        rethrow;
      }
    } else {
      authenticatedControlSocketStream = sessionControlSocket;
    }

    if (aesC2D != null && ivC2D != null) {
      logger.info(
        '_runClientSideMulti:'
        ' On the client-side traffic is encrypted',
      );
      socketConnector = await _clientSideEncryptedSocket(
        authenticatedControlSocketStream,
        sessionControlSocket,
        socketConnector,
        relayAddress,
        timeout,
      );
    } else {
      logger.info(
        '_runClientSideMulti:'
        ' On the client-side traffic is transmitted in plain text',
      );
      socketConnector = await _clientSidePlainSocket(
        authenticatedControlSocketStream,
        sessionControlSocket,
        socketConnector,
        relayAddress,
        timeout,
      );
    }

    logger.info('_runClientSideMulti serverToSocket is ready');
    // upon socketConnector.done, destroy the control channel, and complete
    unawaited(
      socketConnector.done.whenComplete(() {
        logger.info('_runClientSideMulti sc.done');
        sessionControlSocket.destroy();
      }),
    );
    return socketConnector;
  }

  /// On the client side, the data in this socket remains unencrypted and is transmitted in plain text
  Future<SocketConnector> _clientSidePlainSocket(
    Stream<Uint8List> sessionControlSocketStream,
    IOSink sessionControlSocketSink,
    SocketConnector? socketConnector,
    InternetAddress relayAddress,
    Duration timeout,
  ) async {
    sessionControlSocketStream.listen(
      (event) {
        String response = String.fromCharCodes(event).trim();
        logger.info(
          '_runClientSideMulti (_client_sidePlainSocket)'
          ' Received control channel response: [$response]',
        );
      },
      onError: (e) {
        logger.severe(
          '_runClientSideMulti (_clientSidePlainSocket)'
          ' controlSocket error: $e',
        );
        socketConnector?.close();
      },
      onDone: () {
        logger.info(
          '_runClientSideMulti (_clientSidePlainSocket)'
          ' controlSocket done',
        );
        socketConnector?.close();
      },
    );
    InternetAddress localAddress = await resolveRequestedLocalHost();
    socketConnector = await SocketConnector.serverToSocket(
      portA: localPort,
      addressA: localAddress,
      addressB: relayAddress,
      portB: streamingPort,
      verbose: Platform.environment['SRV_TRACE'] == 'true',
      logger: ioSinkForLogger(logger),
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) async {
        logger.info(
          '_runClientSideMulti (_clientSidePlainSocket)'
          ' Sending connect request',
        );
        sessionControlSocketSink.add(
          Uint8List.fromList('connect:no:encrypt\n'.codeUnits),
        );
        // Authenticate the sideB socket (to the rvd)
        if (relayAuthenticator != null) {
          logger.info(
            '_runClientSideMulti (_clientSidePlainSocket)'
            'authenticating new connection to rvd',
          );
          try {
            var (authenticated, authenticatedStream) = await relayAuthenticator!
                .authenticate(sideB.socket);
            if (!authenticated || authenticatedStream == null) {
              sideB.socket.destroy();
            } else {
              sideB.stream = authenticatedStream;
            }
          } catch (err) {
            logger.severe(
              '_runClientSideMulti (_clientSidePlainSocket)'
              ' Failed to authenticate to relay: $err',
            );
            sideB.socket.destroy();
          }
        }
      },
    );
    return socketConnector;
  }

  /// On the client side, the data in encrypted and is transmitted through this socket.
  Future<SocketConnector> _clientSideEncryptedSocket(
    Stream<Uint8List> sessionControlSocketStream,
    IOSink sessionControlSocketSink,
    SocketConnector? socketConnector,
    InternetAddress relayAddress,
    Duration timeout,
  ) async {
    DataTransformer controlEncrypter = createEncrypter(aesC2D!, ivC2D!);
    DataTransformer controlDecrypter;
    if (aesD2C == null) {
      // Backwards compatibility - use same key & iv
      controlDecrypter = createDecrypter(aesC2D!, ivC2D!);
    } else {
      controlDecrypter = createDecrypter(aesD2C!, ivD2C!);
    }

    // Listen to stream which is decrypting the socket stream
    // Write to a stream controller which encrypts and writes to the socket
    Stream<List<int>> controlStream = controlDecrypter(
      sessionControlSocketStream,
    );
    StreamController<Uint8List> controlSink = StreamController<Uint8List>();
    controlEncrypter(controlSink.stream).listen(sessionControlSocketSink.add);

    controlStream.listen(
      (event) {
        String response = String.fromCharCodes(event).trim();
        logger.info(
          '_runClientSideMulti (_clientSideEncryptedSocket)'
          ' Received control channel response: [$response]',
        );
      },
      onError: (e) {
        logger.severe(
          '_runClientSideMulti  (_clientSideEncryptedSocket)'
          ' controlSocket error: $e',
        );
        socketConnector?.close();
      },
      onDone: () {
        logger.info(
          '_runClientSideMulti  (_clientSideEncryptedSocket)'
          ' controlSocket done',
        );
        socketConnector?.close();
      },
    );

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
    logger.info(
      '_runClientSideMulti  (_clientSideEncryptedSocket)'
      ' calling SocketConnector.serverToSocket',
    );
    InternetAddress localAddress = await resolveRequestedLocalHost();
    socketConnector = await SocketConnector.serverToSocket(
      portA: localPort,
      addressA: localAddress,
      addressB: relayAddress,
      portB: streamingPort,
      verbose: Platform.environment['SRV_TRACE'] == 'true',
      logger: ioSinkForLogger(logger),
      multi: multi,
      timeout: timeout,
      beforeJoining: (Side sideA, Side sideB) async {
        logger.info('_runClientSideMulti Sending connect request');

        // Authenticate the sideB socket (to the rvd)
        try {
          if (relayAuthenticator != null) {
            logger.info(
              '_runClientSideMulti  (_clientSideEncryptedSocket)'
              ' authenticating new connection to rvd',
            );
            var (authenticated, authenticatedStream) = await relayAuthenticator!
                .authenticate(sideB.socket);
            if (!authenticated || authenticatedStream == null) {
              sideB.socket.destroy();
            } else {
              sideB.stream = authenticatedStream;
            }
          }
          String socketAESKeyC2D = AtChopsUtil.generateSymmetricKey(
            EncryptionKeyType.aes256,
          ).key;
          String socketIVC2D = base64Encode(
            AtChopsUtil.generateRandomIV(16).ivBytes,
          );

          String socketAESKeyD2C, socketIVD2C;

          if (twinKeys) {
            socketAESKeyD2C = AtChopsUtil.generateSymmetricKey(
              EncryptionKeyType.aes256,
            ).key;
            socketIVD2C = base64Encode(
              AtChopsUtil.generateRandomIV(16).ivBytes,
            );
          } else {
            // Backwards compatibility
            socketAESKeyD2C = socketAESKeyC2D;
            socketIVD2C = socketIVC2D;
          }

          sideA.transformer = createEncrypter(socketAESKeyC2D, socketIVC2D);
          sideB.transformer = createDecrypter(socketAESKeyD2C, socketIVD2C);

          logger.info(
            '_runClientSideMulti (_clientSideEncryptedSocket)'
            ' Client side connected.'
            ' Sending connect (twinKeys) request to daemon',
          );

          if (twinKeys) {
            logger.info(
              '_runClientSideMulti (_clientSideEncryptedSocket)'
              ' Client side connected.'
              ' Sending connect (twinKeys) request to daemon',
            );
            controlSink.add(
              Uint8List.fromList(
                'connect:$socketAESKeyC2D:$socketIVC2D:$socketAESKeyD2C:$socketIVD2C\n'
                    .codeUnits,
              ),
            );
          } else {
            logger.info(
              '_runClientSideMulti (_clientSideEncryptedSocket)'
              ' Client side connected.'
              ' Sending connect request to daemon',
            );
            controlSink.add(
              Uint8List.fromList(
                'connect:$socketAESKeyC2D:$socketIVC2D\n'.codeUnits,
              ),
            );
          }
        } catch (err) {
          logger.severe(
            '_runClientSideMulti (_clientSideEncryptedSocket)'
            ' Failed to authenticate to relay: $err'
            '\n\tWill destroy local socket also',
          ); // TODO add retries like on daemon side
          sideB.socket.destroy();
          sideA.socket.destroy();
        }
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
    logger.info(
      '_runDaemonSideMulti'
      ' control channel received connect request - '
      ' creating new socketToSocket connection',
    );

    InternetAddress localAddress = await resolveRequestedLocalHost();

    // First, connect to the relay.
    // If it fails, return, as we can't do anything more
    late Side sideB;
    logger.info(
      '_runDaemonSideMulti: Connecting side B (relay - $relayAddress:$streamingPort)',
    );
    bool candidateConnected = false;
    try {
      int attempts = 4;
      for (int i = 1; i <= attempts && !candidateConnected; i++) {
        Side candidateSideB = Side(
          await Socket.connect(relayAddress, streamingPort),
          false,
          transformer: decrypter,
        );
        unawaited(
          candidateSideB.socket.done
              .then((v) => logger.info('relay socket done'))
              .catchError(
                (err) => logger.warning('relay socket done with error $err'),
              ),
        );
        if (relayAuthenticator == null) {
          candidateConnected = true;
        } else {
          logger.info(
            '_runDaemonSideMulti authenticating'
            ' new socket connection to relay',
          );
          try {
            var (authenticated, authenticatedStream) = await relayAuthenticator!
                .authenticate(candidateSideB.socket);
            logger.info(
              '_runDaemonSideMulti authentication apparently complete'
              '\n\t=> authenticated: $authenticated'
              '\n\t=> stream: $authenticatedStream',
            );
            if (!authenticated || authenticatedStream == null) {
              candidateSideB.socket.destroy();
            } else {
              candidateSideB.stream = authenticatedStream;
              sideB = candidateSideB;
              candidateConnected = true;
            }
          } catch (err) {
            logger.info(
              '_runDaemonSideMulti (_handleMultiConnectRequest)'
              ' Failed to authenticate to relay: $err',
            );
            candidateSideB.socket.destroy();
          }
        }
        if (!candidateConnected && i < attempts) {
          logger.info('Will try again in 1 second');
          await Future.delayed(Duration(seconds: 1));
        }
      }
      if (!candidateConnected) {
        logger.shout('Failed to authenticate to relay $attempts times');
        sc.close();
        return;
      }
    } catch (e) {
      logger.shout(
        'Failed to connect to relay ($relayAddress:$streamingPort) with error : $e',
      );
      sc.close();
      return;
    }

    // Now, connect to the local host:port
    // If it fails, we need to close the socket connection to the relay
    late Socket sideASocketActual;
    late Side sideA;
    logger.info(
      '_runDaemonSideMulti:'
      ' Connecting side A (local - $localAddress:$localPort)',
    );

    try {
      sideASocketActual = await Socket.connect(localAddress, localPort);
      sideA = Side(sideASocketActual, true, transformer: encrypter);
    } catch (e) {
      logger.shout(
        'Failed to connect locally ($localAddress:$localPort)'
        ' with error : $e',
      );
      logger.shout('Closing sideB (relay) socket connection');
      sideB.socket.destroy();

      return;
    }

    // Finally, let's have the socket connector join the sides together
    unawaited(
      sc.handleSingleConnection(sideB).catchError((err) {
        logger.severe(
          'ERROR $err in _runDaemonSideMulti from handleSingleConnection on sideB (relay - $relayAddress:$streamingPort)',
        );
      }),
    );
    unawaited(
      sc.handleSingleConnection(sideA).catchError((err) {
        logger.severe(
          'ERROR $err in _runDaemonSideMulti from handleSingleConnection on sideA (local - $localAddress:$localPort)',
        );
      }),
    );

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
          String aesC2D = args[1];
          String ivC2D = args[2];
          decrypter = createDecrypter(aesC2D, ivC2D);
          if (args.length == 3) {
            // we only have one key & iv
            encrypter = createEncrypter(aesC2D, ivC2D);
          } else {
            // we have two keys & ivs
            String aesD2C = args[3];
            String ivD2C = args[4];
            encrypter = createEncrypter(aesD2C, ivD2C);
          }
        }

        await _handleMultiConnectRequest(
          sc,
          relayAddress,
          encrypter,
          decrypter,
        );
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
    logger.info(
      '_runDaemonSideMulti: creating SocketConnector with timeout $timeout',
    );
    SocketConnector sc = SocketConnector(
      timeout: timeout,
      verbose: Platform.environment['SRV_TRACE'] == 'true',
      logger: ioSinkForLogger(logger),
    );

    // - create control channel and listen for requests
    // - for each request, create a socketToSocket connection
    Socket sessionControlSocket = await Socket.connect(
      streamingHost,
      streamingPort,
      timeout: Duration(seconds: 10),
    );
    // Authenticate the control channel
    Stream<Uint8List>? authenticatedControlSocketStream;
    if (relayAuthenticator != null) {
      logger.info(
        '_runDaemonSideMulti authenticating'
        ' control channel connection to rvd',
      );
      bool authenticated;
      try {
        (authenticated, authenticatedControlSocketStream) =
            await relayAuthenticator!.authenticate(sessionControlSocket);
        if (!authenticated || authenticatedControlSocketStream == null) {
          sessionControlSocket.destroy();
          throw Exception(
            '_runDaemonSideMulti'
            ' Failed to authenticate control socket',
          );
        }
      } catch (err) {
        logger.severe(
          '_runDaemonSideMulti'
          ' Failed to authenticate control socket: $err',
        );
        sessionControlSocket.destroy();
        rethrow;
      }
    } else {
      authenticatedControlSocketStream = sessionControlSocket;
    }

    if (aesC2D != null && ivC2D != null) {
      logger.info(
        '_runDaemonSideMulti: On the daemon side traffic is encrypted',
      );
      _daemonSideEncryptedSocket(
        authenticatedControlSocketStream,
        sessionControlSocket,
        sc,
        relayAddress,
      );
    } else {
      logger.info(
        '_runDaemonSideMulti: On the daemon side traffic is transmitted in plain text',
      );
      _daemonSidePlainSocket(
        authenticatedControlSocketStream,
        sessionControlSocket,
        sc,
        relayAddress,
      );
    }

    // upon socketConnector.done, destroy the control channel, and complete
    unawaited(
      sc.done.whenComplete(() {
        sessionControlSocket.destroy();
      }),
    );

    return sc;
  }

  void _daemonSidePlainSocket(
    Stream<Uint8List> sessionControlSocketStream,
    IOSink sessionControlSocketSink,
    SocketConnector sc,
    InternetAddress relayAddress,
  ) {
    _startDaemonControlSocketListener(
      sessionControlSocketStream,
      sessionControlSocketSink,
      sc,
      relayAddress,
    );
  }

  void _daemonSideEncryptedSocket(
    Stream<Uint8List> sessionControlSocketStream,
    IOSink sessionControlSocketSink,
    SocketConnector sc,
    InternetAddress relayAddress,
  ) {
    DataTransformer controlDecrypter = createDecrypter(aesC2D!, ivC2D!);

    DataTransformer controlEncrypter;
    if (aesD2C == null) {
      // backwards compatibility - use the same key for the encryption
      controlEncrypter = createEncrypter(aesC2D!, ivC2D!);
    } else {
      controlEncrypter = createEncrypter(aesD2C!, ivD2C!);
    }

    // Listen to stream which is decrypting the socket stream
    // Write to a stream controller which encrypts and writes to the socket
    Stream<List<int>> controlStream = controlDecrypter(
      sessionControlSocketStream,
    );
    StreamController<Uint8List> controlSink = StreamController<Uint8List>();
    controlEncrypter(controlSink.stream).listen(sessionControlSocketSink.add);

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
    bool receivedNewline = false;
    sessionControlStream.listen(
      (data) async {
        try {
          await controlStreamMutex.acquire();
          for (int element = 0; element < data.length; element++) {
            // If it's a '\n' then complete data has been received, so process it
            if (data[element] == newLineCodeUnit) {
              receivedNewline = true;
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
                    'Caught (will rethrow) error: $e\nStack Trace:\n$st',
                  );
                  rethrow;
                }
              } catch (e) {
                logger.severe('$e while handling control message: $controlMsg');
              } finally {
                rcvBuffer.clear();
              }
            } else {
              rcvBuffer.addByte(data[element]);
              if (!receivedNewline) {
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
                    logger.shout(
                      'Backwards compatibility handler will process'
                      ' ${rcvBuffer.length() / oldMagic} messages',
                    );
                    try {
                      List<int> toProcess = rcvBuffer.getData().toList();
                      while (toProcess.isNotEmpty) {
                        String controlMsg = utf8
                            .decode(toProcess.sublist(0, oldMagic))
                            .trim();
                        toProcess = toProcess.sublist(oldMagic);
                        try {
                          await _handleControlMessage(
                            sc,
                            relayAddress,
                            controlMsg,
                          );
                        } catch (e) {
                          logger.severe(
                            '$e while handling control message: $controlMsg',
                          );
                        }
                      }
                    } finally {
                      rcvBuffer.clear();
                    }
                  }
                }
              }
            }
          }
        } finally {
          controlStreamMutex.release();
        }
      },
      onError: (e) {
        logger.severe('controlSocket error: $e');
        sc.close();
      },
      onDone: () {
        logger.info('controlSocket done');
        sc.close();
      },
    );
  }

  Future<InternetAddress> resolveRequestedLocalHost() async {
    String hostToLookup = localHost ?? 'localhost';
    logger.info(
      'Resolving local host: $hostToLookup (localHost field = $localHost)',
    );
    List<InternetAddress> candidates = await InternetAddress.lookup(
      hostToLookup,
      type: InternetAddressType.any, // Let OS choose IPv4 or IPv6
    );
    if (candidates.isEmpty) {
      throw Exception("Cannot resolve address for $hostToLookup");
    }
    logger.info('Resolved local host $hostToLookup to ${candidates[0]}');
    return candidates[0];
  }

  Future<SocketConnector> _runDaemonSideSingle({
    required InternetAddress relayAddress,
  }) async {
    DataTransformer? encrypter;
    DataTransformer? decrypter;
    if (aesC2D != null && ivC2D != null) {
      decrypter = createDecrypter(aesC2D!, ivC2D!);
      if (aesD2C == null) {
        encrypter = createEncrypter(aesC2D!, ivC2D!);
      } else {
        encrypter = createEncrypter(aesD2C!, ivD2C!);
      }
    }
    InternetAddress localAddress = await resolveRequestedLocalHost();

    bool verbose = Platform.environment['SRV_TRACE'] == 'true';
    IOSink logSink = ioSinkForLogger(logger);
    SocketConnector socketConnector = SocketConnector(
      verbose: verbose,
      logger: ioSinkForLogger(logger),
    );
    if (verbose) {
      logSink.writeln(
        'socket_connector:'
        ' Connecting to $localAddress:$localPort',
      );
    }
    Socket sideASocket = await Socket.connect(localAddress, localPort);
    Side sideA = Side(sideASocket, true, transformer: encrypter);
    unawaited(
      socketConnector.handleSingleConnection(sideA).catchError((err) {
        logSink.writeln(
          'ERROR $err in _runDaemonSideSingle from handleSingleConnection on sideA (local)',
        );
      }),
    );

    if (verbose) {
      logSink.writeln(
        'socket_connector: Connecting to $relayAddress:$streamingPort',
      );
    }
    Socket sideBSocket = await Socket.connect(relayAddress, streamingPort);
    Side sideB = Side(sideBSocket, false, transformer: decrypter);

    // Authenticate the sideB socket (to the rvd)
    if (relayAuthenticator != null) {
      logger.info('_runDaemonSideSingle authenticating socketB to rvd');
      try {
        var (authenticated, authenticatedStream) = await relayAuthenticator!
            .authenticate(sideB.socket);
        if (!authenticated || authenticatedStream == null) {
          sideB.socket.destroy();
        } else {
          sideB.stream = authenticatedStream;
        }
      } catch (err) {
        logger.severe(
          '_runDaemonSideSingle'
          ' Failed to authenticate socketB: $err',
        );
        sideB.socket.destroy();
        sideA.socket.destroy();
      }
    }

    unawaited(
      socketConnector.handleSingleConnection(sideB).catchError((err) {
        logSink.writeln(
          'ERROR $err in _runDaemonSideSingle from handleSingleConnection on sideB (relay)',
        );
      }),
    );

    if (verbose) {
      logSink.writeln('socket_connector: started');
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
