import 'dart:io';

/// Simple server program which binds to port args[0] and then,
/// for each new socket connection
/// - listens for a request to send data (see demo_socket_client.dart)
/// - sends that much data
/// - closes the socket
///
/// Sample usage:
/// - dart demo_socket_server.dart 12345
/// - dart demo_socket_client.dart 12345
void main(List<String> args) async {
  int port = int.parse(args[0]);
  final server = await ServerSocket.bind(
    InternetAddress.loopbackIPv4,
    port,
  );

  List<int> kb = List.filled(1024, 65);

  server.listen((socket) {
    stdout.writeln('New socket connection');
    socket.listen((bytes) async {
      String s = String.fromCharCodes(bytes);
      if (s.trim().isEmpty) {
        return;
      }
      int numKbsToSend = int.parse(s);
      stdout.writeln('Received request to send $numKbsToSend kBytes');
      for (int i = 0; i < numKbsToSend; i++) {
        socket.add(kb);
      }
      await socket.flush();
      stdout.writeln('Wrote $numKbsToSend kBytes');
      socket.destroy();
      stdout.writeln('Socket closed.\n');
    });
  });
}
