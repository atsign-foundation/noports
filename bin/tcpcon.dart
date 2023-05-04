// dart packages
import 'dart:io';

// external packages
import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:socket_connector/socket_connector.dart';

Future<void> main(List<String> args) async {
  String host = args[0];
  String streamingPort = args[1];

  var hosts = await InternetAddress.lookup(host);

  // ignore: unused_local_variable
  var socketStream = await SocketConnector.socketToSocket(
      socketAddressA: InternetAddress.loopbackIPv4,
      socketPortA: 22,
      socketAddressB: hosts[0],
      socketPortB: int.parse(streamingPort),
      verbose: false);
}
