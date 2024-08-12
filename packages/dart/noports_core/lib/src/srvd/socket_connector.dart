import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:socket_connector/socket_connector.dart';

import 'signature_verifying_socket_authenticator.dart';

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

  await runZonedGuarded(() async {
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
      socketAuthVerifierA = SignatureAuthVerifier(
        pkAtSignA,
        jsonEncode(expectedPayloadForSignature),
        srvdSessionParams.rvdNonce!,
        srvdSessionParams.atSignA,
      ).authenticate;
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
      socketAuthVerifierB = SignatureAuthVerifier(
        pkAtSignB,
        jsonEncode(expectedPayloadForSignature),
        srvdSessionParams.rvdNonce!,
        srvdSessionParams.atSignB!,
      ).authenticate;
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
      // backlog: 10000,
    );

    /// Get the assigned ports from the socket connector
    portA = connector.sideAPort!;
    portB = connector.sideBPort!;

    logger.info('Assigned ports [$portA, $portB]'
        ' for session ${srvdSessionParams.sessionId}');

    /// Return the assigned ports to the main isolate
    sendPort.send((portA, portB));

    /// Shut myself down once the socket connector closes
    logger.info('Waiting for connector to close');

    await connector.done;

    logger.shout('Finished session ${srvdSessionParams.sessionId}'
        ' for ${srvdSessionParams.atSignA} to ${srvdSessionParams.atSignB}'
        ' using ports [$portA, $portB]');
  }, (Object error, StackTrace stackTrace) async {
    logger.shout(
        'Error: session ${srvdSessionParams.sessionId}: ${error.toString()}');
    logger.shout('Stack Trace: ${stackTrace.toString()}');
  });

  Isolate.current.kill();
}
