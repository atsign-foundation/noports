// dart packages
import 'dart:io';

// external packages
import 'package:socket_connector/socket_connector.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2 || args.length > 2) {
    print('sshrv <host> <port>');
    exit(-1);
  }
  String host = args[0];
  String streamingPort = args[1];
  try {
    var hosts = await InternetAddress.lookup(host);

    // ignore: unused_local_variable
    var socketStream = await SocketConnector.socketToSocket(
        socketAddressA: InternetAddress.loopbackIPv4,
        socketPortA: 22,
        socketAddressB: hosts[0],
        socketPortB: int.parse(streamingPort),
        verbose: false);
  } catch (e) {
    print('sshrv error: ${e.toString()}');
  }
}
