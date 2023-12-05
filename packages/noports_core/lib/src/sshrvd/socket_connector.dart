import 'dart:io';
import 'dart:isolate';
import 'package:at_utils/at_logger.dart';
import 'package:socket_connector/socket_connector.dart';

typedef ConnectorParams = (SendPort, int, int, String, String, String?,SocketAuthenticator? socketAuthenticatorA, SocketAuthenticator? socketAuthenticatorB, bool);
typedef PortPair = (int, int);

final logger = AtSignLogger(' sshrvd / socket_connector ');


/// This function is meant to be run in a separate isolate
/// It starts the socket connector, and sends back the assigned ports to the main isolate
/// It then waits for socket connector to die before shutting itself down
void socketConnector(ConnectorParams params) async {
  var (sendPort, portA, portB, session, atSignA, atSignB, socketAuthenticatorA, socketAuthenticatorB, snoop) = params;

  logger.info('Starting socket connector session $session for $atSignA to $atSignB');


  /// Create the socket connector
  SocketConnector socketStream = await SocketConnector.serverToServer(
  serverAddressA: InternetAddress.anyIPv4,
  serverAddressB: InternetAddress.anyIPv4,
  serverPortA: portA,
  serverPortB: portB,
  verbose: snoop,
  socketAuthenticatorA: socketAuthenticatorA,
  socketAuthenticatorB: socketAuthenticatorB,
  );

  /// Get the assigned ports from the socket connector
  portA = socketStream.senderPort()!;
  portB = socketStream.receiverPort()!;

  logger.info('Assigned ports [$portA, $portB] for session $session');

  /// Return the assigned ports to the main isolate
  sendPort.send((portA, portB));

  /// Shut myself down once the socket connector closes
  bool closed = false;
  while (closed == false) {
  closed = await socketStream.closed();
  }

  logger.warning(
  'Finished session $session for $atSignA to $atSignB using ports [$portA, $portB]');

  Isolate.current.kill();
}
