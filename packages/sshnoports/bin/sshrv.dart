// dart packages
import 'dart:io';

// external packages
import 'package:socket_connector/socket_connector.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2 || args.length > 3) {
    print('sshrv <host> <port> [<local ssh port>]');
    exit(-1);
  }
  String host = args[0];
  String streamingPort = args[1];
  String localSshPort ="22";
  if (args.length == 3) {
    localSshPort = args[2];
  }
    
  
  try {
    var hosts = await InternetAddress.lookup(host);

    // ignore: unused_local_variable
    var socketStream = await SocketConnector.socketToSocket(
        socketAddressA: InternetAddress.loopbackIPv4,
        socketPortA: int.parse(localSshPort),
        socketAddressB: hosts[0],
        socketPortB: int.parse(streamingPort),
        verbose: false);
  } catch (e) {
    print('sshrv error: ${e.toString()}');
  }
}
