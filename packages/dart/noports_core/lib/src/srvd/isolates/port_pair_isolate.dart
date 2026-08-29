import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:noports_core/src/common/types.dart';
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

  /// Set when we start the session
  int? portA;

  /// Set when we start the session
  int? portB;

  /// The per-side auto-detecting verifiers, kept so that a definitive
  /// auth-modes notification (see [handleAuthModes]) can steer their detection.
  RelayAuthVerifierAuto? _authVerifierA;
  RelayAuthVerifierAuto? _authVerifierB;

  PortPairWorker({
    required super.toMain,
    required super.logTraffic,
    required super.verbose,
    required super.loggingTag,
    required super.relayAuthDetectWindowMs,
  }) {
    reqHandlers['start'] = startSession;
    reqHandlers['stop'] = stop;
    reqHandlers['auth_modes'] = handleAuthModes;
  }

  /// Handle a definitive auth-modes message forwarded from the main isolate:
  /// the requesting client has learnt which mode each side will use and told
  /// the relay, so we can skip the detection window (see [RelayAuthVerifierAuto]).
  Future<void> handleAuthModes(IIRequest req) async {
    final payload = req.payload;
    final String? sideA = payload['sideA'];
    final String? sideB = payload['sideB'];
    logger.info('Definitive auth modes received: sideA=$sideA sideB=$sideB');
    if (sideA != null) {
      _authVerifierA?.setKnownMode(RelayAuthMode.values.byName(sideA));
    }
    if (sideB != null) {
      _authVerifierB?.setKnownMode(RelayAuthMode.values.byName(sideB));
    }
  }

  @override
  Future<void> run() async {
    await sessionStarted.future;

    /// Shut myself down once the socket connector closes
    logger.info('Waiting for connector to close');
    await connector!.done;

    logger.info('Sending sessionComplete to main isolate');
    toMain.send(
      IIRequest.create('sessionComplete', {
        'sessionId': srvdSessionParams.sessionId,
        'stats': connector!.stats,
      }),
    );

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
      connector!.close();
    } else {
      logger.shout('Connector not yet started - killing this isolate');
      Isolate.current.kill();
    }
  }

  Future<void> startSession(IIRequest req) async {
    srvdSessionParams = req.payload;
    logger.info('Starting socket connector session for $srvdSessionParams');

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
    );

    connector!.connectionStream.listen(
      (Connection c) => toMain.send(
        IIRequest.create('newConnection', {
          'sessionId': srvdSessionParams.sessionId,
          'stats': connector!.stats,
        }),
      ),
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
