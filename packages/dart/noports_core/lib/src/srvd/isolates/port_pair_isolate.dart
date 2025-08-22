import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
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

  PortPairWorker({
    required super.toMain,
    required super.logTraffic,
    required super.verbose,
    required super.loggingTag,
  }) {
    reqHandlers['start'] = startSession;
    reqHandlers['stop'] = stop;
  }

  @override
  Future<void> run() async {
    await sessionStarted.future;

    /// Shut myself down once the socket connector closes
    logger.info('Waiting for connector to close');
    await connector!.done;

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

    RelayAuthVerifier? authVerifierA;
    RelayAuthVerifier? authVerifierB;

    (authVerifierA, authVerifierB) = await createAuthVerifiers(
      srvdSessionParams,
    );

    /// Create the socket connector
    connector = await SocketConnector.serverToServer(
      addressA: InternetAddress.anyIPv4,
      addressB: InternetAddress.anyIPv4,
      portA: 0,
      portB: 0,
      verbose: verbose,
      logTraffic: logTraffic,
      socketAuthVerifierA: authVerifierA?.verifySocketAuth,
      socketAuthVerifierB: authVerifierB?.verifySocketAuth,
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
