import 'dart:io';

import 'package:socket_connector/socket_connector.dart';

void main() async {
  // Create a server to server socket connector to use for testing
  SocketConnector sc = await SocketConnector.serverToServer(
    addressA: InternetAddress.anyIPv4,
    addressB: InternetAddress.anyIPv4,
    portA: 9000,
    portB: 8000,
    verbose: true,
    logTraffic: true,
  );
  await sc.done;
}
