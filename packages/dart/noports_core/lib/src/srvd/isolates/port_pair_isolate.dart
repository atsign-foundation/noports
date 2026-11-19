import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/connection_tracker.dart';
import 'package:noports_core/src/srvd/isolates/relay_worker.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:socket_connector/socket_connector.dart';

import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';

class PortPairWorker extends RelayWorker {
  /// Completes once we've started the session;
  final Completer sessionStarted = Completer();

  /// Set when we receive a message to start the session
  late SrvdSessionParams srvdSessionParams;

  /// Set when we start the session
  SocketConnector? connector;

  /// Reports the session's connections to main; set when we start the session
  ConnectionTracker? tracker;

  /// How long a side's close waits for its pending data before the side is
  /// destroyed.
  final Duration closeFlushTimeout;

  /// How often the session's progress is reported to main.
  final Duration progressInterval;

  /// The connector's grace period: how long from its creation it waits for
  /// connections before closing itself once none is established.
  final Duration connectorTimeout;

  /// How long a socket has to authenticate before the connector closes it.
  final Duration authTimeout;

  /// Set when we start the session
  int? portA;

  /// Set when we start the session
  int? portB;

  /// The per-side verifiers; side B's is kept so that the client's auth_modes
  /// notification (see [handleAuthModes]) can give it its mode.
  RelayAuthVerifierAuto? _authVerifierA;
  RelayAuthVerifierAuto? _authVerifierB;

  /// Side B's verifier, once the session has started.
  @visibleForTesting
  RelayAuthVerifierAuto? get authVerifierB => _authVerifierB;

  PortPairWorker({
    required super.toMain,
    required super.logTraffic,
    required super.verbose,
    required super.loggingTag,
    required super.relayAuthDetectWindowMs,
    this.closeFlushTimeout = SocketConnector.defaultCloseFlushTimeout,
    this.progressInterval = defaultProgressInterval,
    this.connectorTimeout = SocketConnector.defaultTimeout,
    this.authTimeout = SocketConnector.defaultTimeout,
  }) {
    reqHandlers['start'] = startSession;
    reqHandlers['stop'] = stop;
    reqHandlers['end'] = end;
    reqHandlers['auth_modes'] = handleAuthModes;
  }

  /// Gives side B the mode the requesting client named for it, which the main
  /// isolate forwards only for a session whose request left side B's mode to
  /// the client.
  Future<void> handleAuthModes(IIRequest req) async {
    final String sideB = req.payload['sideB'];
    logger.info('Side B auth mode received: $sideB');
    _authVerifierB?.setKnownMode(RelayAuthMode.values.byName(sideB));
  }

  @override
  Future<void> run() async {
    await sessionStarted.future;

    /// Shut myself down once the socket connector closes
    logger.info('Waiting for connector to close');
    await connector!.done;

    logger.info('Sending sessionComplete to main isolate');
    await tracker!.complete();

    logger.shout(
      'Finished session ${srvdSessionParams.sessionId}'
      ' for ${srvdSessionParams.atSignA} to ${srvdSessionParams.atSignB}'
      ' using ports [$portA, $portB]',
    );

    Isolate.current.kill();
  }

  @override
  Future<void> stop([IIRequest? req]) async {
    if (connector != null) {
      tracker?.stopping();
      connector!.close();
    } else {
      logger.shout('Connector not yet started - killing this isolate');
      Isolate.current.kill();
    }
  }

  /// Ends the session at once: as [stop], with its sockets destroyed first,
  /// so that no side is given time to take its pending data.
  Future<void> end([IIRequest? req]) async {
    final SocketConnector? started = connector;
    if (started != null) destroySockets(started, tracker);
    await stop(req);
  }

  Future<void> startSession(IIRequest req) async {
    srvdSessionParams = req.payload;
    logger.info(
      'Starting socket connector session ${srvdSessionParams.sessionId}'
      ' for ${srvdSessionParams.atSignA} to ${srvdSessionParams.atSignB}',
    );

    final (authVerifierA, authVerifierB) = await createAuthVerifiers(
      srvdSessionParams,
    );
    _authVerifierA = authVerifierA;
    _authVerifierB = authVerifierB;

    /// Create the socket connector
    connector = await SocketConnector.serverToServer(
      addressA: InternetAddress.anyIPv4,
      addressB: InternetAddress.anyIPv4,
      portA: 0,
      portB: 0,
      verbose: verbose,
      logTraffic: logTraffic,
      socketAuthVerifierA: _authVerifierA?.verifySocketAuth,
      socketAuthVerifierB: _authVerifierB?.verifySocketAuth,
      timeout: connectorTimeout,
      authTimeout: authTimeout,
      closeFlushTimeout: closeFlushTimeout,
    );

    tracker = ConnectionTracker(
      sessionId: srvdSessionParams.sessionId,
      toMain: toMain,
      opened: connector!.connectionStream,
      closed: connector!.connectionClosedStream,
      stats: () => connector!.stats,
      closeFlushTimeout: closeFlushTimeout,
      progressInterval: progressInterval,
    );

    /// Connector created, so complete the sessionStarted future
    sessionStarted.complete();

    /// Get the assigned ports from the socket connector
    portA = connector!.sideAPort!;
    portB = connector!.sideBPort!;

    // and send them to the main isolate
    PortPair ports = (portA!, portB!);
    toMain.send(ports);

    logger.info(
      'Assigned ports [$portA, $portB]'
      ' for session ${srvdSessionParams.sessionId}',
    );
  }

  Map<String, dynamic> lookups = {};
  Random random = Random();

  @override
  Future<String> lookup(String sessionId, String atKey) async {
    if (lookups.containsKey(atKey)) {
      return lookups[atKey];
    } else {
      final resp = await rpcToMain(
        IIRequest.create('lookup', {'key': atKey, 'sessionId': sessionId}),
      );
      lookups[atKey] = resp.payload;
      return resp.payload;
    }
  }

  @override
  Future<bool> isSessionActive(String sessionId) async {
    return !(connector?.closed ?? true);
  }

  @override
  Future<String> getRelayAuthAesKey(String sessionId) async {
    if (srvdSessionParams.relayAuthAesKey == null) {
      throw StateError('relayAuthAesKey is null');
    } else {
      return srvdSessionParams.relayAuthAesKey!;
    }
  }
}
