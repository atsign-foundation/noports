import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:socket_connector/socket_connector.dart';

import 'relay_auth_verifiers.dart';

typedef ConnectorParams = (
  SendPort,
  int, // portA
  int, // portB
  String, // session params
  bool, // logTraffic
  bool, // verbose
);
typedef PortPair = (int, int);

/// This function is meant to be run in a separate isolate
/// It starts the socket connector, and sends back the assigned ports to the main isolate
/// It then waits for socket connector to die before shutting itself down
void socketConnector(ConnectorParams connectorParams) async {
  var (
    sendPort,
    portA,
    portB,
    srvdSessionParamsJsonString,
    logTraffic,
    verbose,
  ) = connectorParams;

  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  if (verbose) {
    AtSignLogger.root_level = 'INFO';
  } else {
    AtSignLogger.root_level = 'WARNING';
  }

  final logger = AtSignLogger(' srvd / socket_connector ');

  SrvdSessionParams srvdSessionParams =
      SrvdSessionParams.fromJson(jsonDecode(srvdSessionParamsJsonString));
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
    portA: portA,
    portB: portB,
    verbose: verbose,
    logTraffic: logTraffic,
    socketAuthVerifierA: socketAuthVerifierA,
    socketAuthVerifierB: socketAuthVerifierB,
  );

  /// Get the assigned ports from the socket connector
  portA = connector.sideAPort!;
  portB = connector.sideBPort!;

  logger.info('Assigned ports [$portA, $portB]'
      ' for session ${srvdSessionParams.sessionId}');

  // Make a ReceivePort so the main isolate can send messages to us
  ReceivePort receivePort = ReceivePort(srvdSessionParams.sessionId);

  /// Return the assigned ports to the main isolate
  sendPort.send(((portA, portB), receivePort.sendPort));

  receivePort.listen((msg) {
    switch (msg) {
      case 'kill':
        logger.shout('Received $msg from main isolate - terminating');
        connector.close();
        break;
      default:
        logger.shout('Received $msg from main isolate - ignoring');
        break;
    }
  });

  /// Shut myself down once the socket connector closes
  logger.info('Waiting for connector to close');
  await connector.done;

  logger.shout('Finished session ${srvdSessionParams.sessionId}'
      ' for ${srvdSessionParams.atSignA} to ${srvdSessionParams.atSignB}'
      ' using ports [$portA, $portB]');

  Isolate.current.kill();
}
