import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/sshrvd/sshrvd_impl.dart';
import 'package:socket_connector/socket_connector.dart';

import 'signature_verifying_socket_authenticator.dart';

typedef ConnectorParams = (
  SendPort,
  int,
  int,
  String,
  bool
);
typedef PortPair = (int, int);

final logger = AtSignLogger(' sshrvd / socket_connector ');

/// This function is meant to be run in a separate isolate
/// It starts the socket connector, and sends back the assigned ports to the main isolate
/// It then waits for socket connector to die before shutting itself down
void socketConnector(ConnectorParams connectorParams) async {
  var (
    sendPort,
    portA,
    portB,
    sshrvdSessionParamsJsonString,
    snoop
  ) = connectorParams;

  SshrvdSessionParams sshrvdSessionParams = SshrvdSessionParams.fromJson(jsonDecode(sshrvdSessionParamsJsonString));
  logger.info(
      'Starting socket connector session for ${sshrvdSessionParams.toJson()}');

  /// Create the socketAuthVerifiers as required
  Map expectedPayloadForSignature = {
    'sessionId': sshrvdSessionParams.sessionId,
    'clientNonce': sshrvdSessionParams.clientNonce,
    'rvdNonce': sshrvdSessionParams.rvdNonce,
  };

  SocketAuthVerifier? socketAuthVerifierA;
  if (sshrvdSessionParams.authenticateSocketA) {
    String? pkAtSignA = sshrvdSessionParams.publicKeyA;
    if (pkAtSignA == null) {
      logger.shout(
          'Cannot spawn socket connector.'
              ' Authenticator for ${sshrvdSessionParams.atSignA}'
              ' could not be created as PublicKey could not be'
              ' fetched from the atServer.');
      throw Exception(
          'Failed to create SocketAuthenticator'
              ' for ${sshrvdSessionParams.atSignA} due to failure to get public key for ${sshrvdSessionParams.atSignA}');
    }
    socketAuthVerifierA = SignatureAuthVerifier(
        pkAtSignA, jsonEncode(expectedPayloadForSignature), sshrvdSessionParams.rvdNonce!, sshrvdSessionParams.atSignA);
  }

  SocketAuthVerifier? socketAuthVerifierB;
  if (sshrvdSessionParams.authenticateSocketB) {
    String? pkAtSignB = sshrvdSessionParams.publicKeyB;
    if (pkAtSignB == null) {
      logger.shout(
          'Cannot spawn socket connector.'
              ' Authenticator for ${sshrvdSessionParams.atSignB}'
              ' could not be created as PublicKey could not be'
              ' fetched from the atServer');
      throw Exception(
          'Failed to create SocketAuthenticator'
              ' for ${sshrvdSessionParams.atSignB} due to failure to get public key for ${sshrvdSessionParams.atSignB}');
    }
    socketAuthVerifierB = SignatureAuthVerifier(
        pkAtSignB, jsonEncode(expectedPayloadForSignature), sshrvdSessionParams.rvdNonce!, sshrvdSessionParams.atSignB!);
  }


  logger.shout('Calling serverToServer with authVerifiers A: $socketAuthVerifierA and B: $socketAuthVerifierB');
  /// Create the socket connector
  SocketConnector socketStream = await SocketConnector.serverToServer(
      serverAddressA: InternetAddress.anyIPv4,
      serverAddressB: InternetAddress.anyIPv4,
      serverPortA: portA,
      serverPortB: portB,
      verbose: snoop,
      socketAuthVerifierA: socketAuthVerifierA,
      socketAuthVerifierB: socketAuthVerifierB);

  /// Get the assigned ports from the socket connector
  portA = socketStream.senderPort()!;
  portB = socketStream.receiverPort()!;

  logger.info('Assigned ports [$portA, $portB]'
      ' for session ${sshrvdSessionParams.sessionId}');

  /// Return the assigned ports to the main isolate
  sendPort.send((portA, portB));

  /// Shut myself down once the socket connector closes
  bool closed = false;
  while (closed == false) {
    closed = await socketStream.closed();
  }

  logger.warning(
      'Finished session ${sshrvdSessionParams.sessionId}'
          ' for ${sshrvdSessionParams.atSignA} to ${sshrvdSessionParams.atSignB}'
          ' using ports [$portA, $portB]');

  Isolate.current.kill();
}
