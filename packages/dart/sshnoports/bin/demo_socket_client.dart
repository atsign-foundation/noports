import 'dart:io';

/// - simple client which talks to a demo_socket_server
/// - sends a request for N kBytes of data to be sent to us
/// - listens for the data and writes a message at the end
/// saying how much it received vs expected
void main(List<String> args) async {
  // connect to socket on localhost, port args[0]
  int port = int.parse(args[0]);
  final socket = await Socket.connect('127.0.0.1', port);

  // send a request for N kBytes of data to be sent to us
  int numKbsToRequest = int.parse(args[1]);
  socket.writeln('$numKbsToRequest');
  await socket.flush();

  int expected = numKbsToRequest * 1024;
  int received = 0;
  socket.listen(
    (data) {
      received += data.length;
    },
    onDone: () {
      stdout.writeln('Received $received bytes ($expected expected)');
      exit(0);
    },
    onError: (err) {
      stdout.writeln('Error: $err');
      stdout.writeln('Received $received bytes ($expected expected)');
      exit(0);
    },
  );
}
