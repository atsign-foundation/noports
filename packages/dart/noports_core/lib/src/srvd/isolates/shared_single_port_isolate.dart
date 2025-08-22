import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/srv/srv_impl.dart';
import 'package:noports_core/src/srvd/isolates/relay_worker.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:socket_connector/socket_connector.dart';

class SessionInfo {
  final SrvdSessionParams params;
  final SocketConnector connector;
  final Map<String, String> lookups = {};

  String get atSignA => params.atSignA!;

  String get atSignB => params.atSignB!;

  SessionInfo(this.params, this.connector);
}

/// - Binds to the required port (in [run])
/// - [startSession] handles requests from the main isolate to start sessions
///   (sessionID, sideA atSign, sideB atSign), and is responsible for
///   - creating the SocketConnector
///   - Creating a SessionInfo and adding to the [sessions] Map
///   - Removing from [sessions] when the SocketConnector is `done`
/// - [socketHandler] handles new sockets
///   - creates a RelayAuthVerifier for the new socket
///   - verifies the socket's authentication
///   - checks that the socket is for a currently live session
///   - double-checks the socket is from one of that session's atSigns
///   - Assigns verified sockets to that session's SocketConnector
class SinglePortWorker extends RelayWorker {
  final String address;
  final bool useTLS;
  final int bindPort;
  final Completer stopped = Completer();
  ServerSocket? _serverSocket;
  SecureServerSocket? _secureServerSocket;

  Map<String, SessionInfo> sessions = {};

  SinglePortWorker({
    required super.toMain,
    required super.logTraffic,
    required super.verbose,
    required super.loggingTag,
    required this.address,
    required this.useTLS,
    required this.bindPort,
  }) {
    reqHandlers['start'] = startSession;
    reqHandlers['stop'] = stop;
  }

  @override
  Future<String> lookup(String sessionId, String atKey) async {
    SessionInfo? si = sessions[sessionId];
    if (si == null) {
      throw StateError('Cannot lookup $atKey - session $sessionId has ended');
    }
    if (si.lookups[atKey] != null) {
      return si.lookups[atKey]!;
    } else {
      final resp = await rpcToMain(
        IIRequest.create('lookup', {'key': atKey, 'sessionId': sessionId}),
      );
      si.lookups[atKey] = resp.payload;
      return resp.payload;
    }
  }

  @override
  Future<bool> isSessionActive(String sessionId) async {
    return sessions.containsKey(sessionId);
  }

  @override
  Future<String> getRelayAuthAesKey(String sessionId) async {
    SessionInfo? si = sessions[sessionId];
    if (si == null) {
      throw StateError(
        'Cannot getRelayAuthAesKey'
        ' - session $sessionId has ended',
      );
    }
    return si.params.relayAuthAesKey!;
  }

  /// Try to bind a ServerSocket to [bindPort], then listen to it
  /// Wait until the isolate is stopped
  @override
  Future<void> run() async {
    try {
      // Try to bind to the port
      if (useTLS) {
        // We will create a SecureServerSocket with a security context which
        // expects certs etc to be in a particular place.
        throw UnimplementedError('Not yet implemented');
        // final _serverSocket = await SecureServerSocket.bind(....);
      } else {
        try {
          _serverSocket = await ServerSocket.bind(address, bindPort);
          _serverSocket!.listen(socketHandler);
        } catch (e) {
          toMain.send(IIRequest.create('handleIsolateFailure', e.toString()));
        }
      }

      // Wait until session is ended
      await stopped.future;
      logger.shout('Isolate exiting');
    } catch (e) {
      logger.shout('run() caught error $e - isolate will exit');
      await _stop();
    }

    Isolate.current.kill();
  }

  void socketHandler(Socket socket) async {
    String sockStr = 'new socket';
    try {
      // asking for remoteAddress and remotePort may throw an exception
      // hence we put it within the try-catch block
      sockStr = 'host ${socket.remoteAddress} port ${socket.remotePort}';
      final rav = RelayAuthVerifierESCR(
        'to port $bindPort from $sockStr',
        this,
      );
      if (verbose) {
        logger.info('New connection from $sockStr');
      }

      bool authenticated;
      Stream<Uint8List>? verifiedSocketStream;
      (authenticated, verifiedSocketStream) =
          await rav.verifySocketAuth(socket).timeout(Duration(seconds: 10));
      if (authenticated) {
        logger.info(
          'Authenticated socket connection verified'
          ' for ${rav.atSign}'
          ' in session ${rav.sessionId!}',
        );
      } else {
        throw Exception(
          'verifySocketAuth did not throw an exception,'
          ' but authenticated is false',
        );
      }

      if (rav.sessionId == null || rav.atSign == null || rav.isSideA == null) {
        throw Exception(
          'Verified? But sessionId == ${rav.sessionId} and atSign == ${rav.atSign} and isSideA == ${rav.isSideA}',
        );
      }
      String sessionId = rav.sessionId!;
      String atSign = rav.atSign!;
      if (!(await isSessionActive(sessionId))) {
        throw Exception('Session not active: $sessionId');
      }
      SessionInfo si = sessions[sessionId]!;
      if (atSign != si.atSignA && atSign != si.atSignB) {
        throw Exception(
          'Connection from $atSign'
          ' which is not one of the atSigns (${si.atSignA}, ${si.atSignB})'
          ' for this session $sessionId',
        );
      }
      Side side = Side(socket, rav.isSideA!);

      side.stream = verifiedSocketStream!;

      unawaited(
        si.connector.handleSingleConnection(side).catchError((err) {
          side.socket.destroy();
        }),
      );
    } catch (e) {
      logger.info('Error "$e" while authenticating socket from $sockStr');
      try {
        socket.destroy();
      } catch (_) {}
    }
  }

  Future<void> _stop() async {
    try {
      await _serverSocket?.close();
      await _secureServerSocket?.close();
    } catch (e) {
      logger.shout('Error $e while closing server socket');
    }
    stopped.complete();
  }

  @override
  Future<void> stop([IIRequest? req]) async {
    if (!stopped.isCompleted) {
      if (req?.payload != false) {
        logger.shout('Stopped by main');
      }
      await _stop();
    }
  }

  Future<void> startSession(IIRequest req) async {
    SrvdSessionParams params = req.payload;
    logger.info('Starting socket connector session for $params');

    if (params.relayAuthMode == RelayAuthMode.payload) {
      logger.shout(
        'relayAuthMode may not be "payload".'
        ' Invalid params $params',
      );
      return;
    }

    if (!(params.authenticateSocketA && params.authenticateSocketB)) {
      logger.shout(
        'Both sides are required to authenticate;'
        ' Invalid params $params',
      );
      return;
    }

    if (sessions.containsKey(params.sessionId)) {
      logger.shout('Cannot start; session ${params.sessionId} already started');
      return;
    }

    AtSignLogger sessionLogger = AtSignLogger(
      ' relay session ${params.sessionId} ',
    );
    final connector = SocketConnector(
      verbose: verbose,
      logTraffic: logTraffic,
      logger: ioSinkForLogger(sessionLogger),
    );

    sessions[params.sessionId] = SessionInfo(params, connector);

    // When the session ends, we want to clean it up
    unawaited(
      connector.done.whenComplete(() {
        logger.shout('sc.done for ${params.sessionId}');
        sessions.remove(params.sessionId);
      }),
    );
  }
}
