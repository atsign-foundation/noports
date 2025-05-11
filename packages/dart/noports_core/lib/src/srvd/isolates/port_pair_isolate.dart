import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:socket_connector/socket_connector.dart';

import '../relay_auth_verifiers.dart';
import '../types.dart';

/// This function is meant to be run in a separate isolate
/// It starts the socket connector, and sends back the assigned ports to the main isolate
/// It then waits for socket connector to die before shutting itself down
void portPairIsolateEntryPoint(ConnectorParams connectorParams) async {
  PortPairWorker worker = PortPairWorker(
    toMain: connectorParams.$1,
    logTraffic: connectorParams.$2,
    verbose: connectorParams.$3,
    loggingTag: connectorParams.$4,
  );

  await worker.run();
}

class PortPairWorker extends RelayWorker {
  PortPairWorker({
    required super.toMain,
    required super.logTraffic,
    required super.verbose,
    required super.loggingTag,
  });

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

  @override
  Future<void> stop() async {
    if (connector != null) {
      connector!.close();
    } else {
      logger.shout('Connector not yet started - killing this isolate');
      Isolate.current.kill();
    }
  }

  @override
  Future<void> run() async {
    fromMain.listen((msg) async {
      if (msg is Map) {
        String req = msg['req'];
        switch (req) {
          case 'stop':
            logger.shout('Received "stop" request - terminating');
            await stop();
            break;
          case 'start':
            srvdSessionParams = msg['payload'];
            await startSession();
            break;
          default:
            logger.shout('Received $msg from main isolate - terminating');
            await stop();
            break;
        }
        return;
      }

      logger.shout('Unhandled message from main isolate - exiting');
      await stop();
    });

    await sessionStarted.future;

    /// Shut myself down once the socket connector closes
    logger.info('Waiting for connector to close');
    await connector!.done;

    logger.shout('Finished session ${srvdSessionParams.sessionId}'
        ' for ${srvdSessionParams.atSignA} to ${srvdSessionParams.atSignB}'
        ' using ports [$portA, $portB]');

    Isolate.current.kill();
  }

  Future<void> startSession() async {
    logger.info(
        'Starting socket connector session for ${srvdSessionParams.toJson()}');

    /// Create the socketAuthVerifiers as required
    Map expectedPayloadForSignature = {
      'sessionId': srvdSessionParams.sessionId,
      'clientNonce': srvdSessionParams.clientNonce,
      'rvdNonce': srvdSessionParams.rvdNonce,
    };

    SocketAuthVerifier? socketAuthVerifierA;
    if (srvdSessionParams.authenticateSocketA) {
      String? pkAtSignA = srvdSessionParams.publicKeyA;
      if (pkAtSignA == null) {
        logger.shout('Cannot spawn socket connector.'
            ' Authenticator for ${srvdSessionParams.atSignA}'
            ' could not be created as PublicKey could not be'
            ' fetched from the atServer.');
        throw Exception('Failed to create SocketAuthenticator'
            ' for ${srvdSessionParams.atSignA} due to failure to get public key for ${srvdSessionParams.atSignA}');
      }
      socketAuthVerifierA = RelayAuthVerifierLegacy(
        pkAtSignA,
        jsonEncode(expectedPayloadForSignature),
        srvdSessionParams.rvdNonce!,
        srvdSessionParams.atSignA,
        srvdSessionParams.atSignA,
        srvdSessionParams.sessionId,
      ).verifySocketAuth;
    }

    SocketAuthVerifier? socketAuthVerifierB;
    if (srvdSessionParams.authenticateSocketB) {
      String? pkAtSignB = srvdSessionParams.publicKeyB;
      if (pkAtSignB == null) {
        logger.shout('Cannot spawn socket connector.'
            ' Authenticator for ${srvdSessionParams.atSignB}'
            ' could not be created as PublicKey could not be'
            ' fetched from the atServer');
        throw Exception('Failed to create SocketAuthenticator'
            ' for ${srvdSessionParams.atSignB} due to failure to get public key for ${srvdSessionParams.atSignB}');
      }
      socketAuthVerifierB = RelayAuthVerifierLegacy(
        pkAtSignB,
        jsonEncode(expectedPayloadForSignature),
        srvdSessionParams.rvdNonce!,
        srvdSessionParams.atSignB!,
        srvdSessionParams.atSignB!,
        srvdSessionParams.sessionId,
      ).verifySocketAuth;
    }

    /// Create the socket connector
    SocketConnector connector = await SocketConnector.serverToServer(
      addressA: InternetAddress.anyIPv4,
      addressB: InternetAddress.anyIPv4,
      portA: 0,
      portB: 0,
      verbose: verbose,
      logTraffic: logTraffic,
      socketAuthVerifierA: socketAuthVerifierA,
      socketAuthVerifierB: socketAuthVerifierB,
    );

    /// Get the assigned ports from the socket connector
    portA = connector.sideAPort!;
    portB = connector.sideBPort!;

    // and send them to the main isolate
    PortPair ports = (portA!, portB!);
    toMain.send(ports);

    logger.info('Assigned ports [$portA, $portB]'
        ' for session ${srvdSessionParams.sessionId}');
  }
}
