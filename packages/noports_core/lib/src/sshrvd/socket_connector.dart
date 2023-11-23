import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:at_utils/at_logger.dart';
import 'package:socket_connector/socket_connector.dart';

typedef ConnectorParams = (SendPort, int, int, String, String, String, bool);
typedef PortPair = (int, int);

final logger = AtSignLogger(' sshrvd / socket_connector ');

/// Purely for illustration purposes.
class DoNothingSocketAuthenticator extends SocketAuthenticator {
  final BytesBuilder buffer = BytesBuilder();

  final String session;
  final String atSign;

  DoNothingSocketAuthenticator(this.session, this.atSign);

  @override
  onData(Uint8List data, Socket socket) {
    return (true, data);
  }
}

/// This function is meant to be run in a separate isolate
/// It starts the socket connector, and sends back the assigned ports to the main isolate
/// It then waits for socket connector to die before shutting itself down
void socketConnector(ConnectorParams params) async {
  var (sendPort, portA, portB, session, atSignA, atSignB, snoop) = params;

  logger.info('Starting socket connector session $session for $atSignA to $atSignB');

  // TODO These instances shouldn't be created here.
  // Instead, the caller should add them into ConnectorParams and we should
  // get them from there.
  SocketAuthenticator socketAuthenticatorA = DoNothingSocketAuthenticator(session, atSignA);
  SocketAuthenticator socketAuthenticatorB = DoNothingSocketAuthenticator(session, atSignB);
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
