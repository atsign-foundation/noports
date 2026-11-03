import 'dart:io';

import 'package:npe2e/revocation_tests/tunnel_check.dart';
import 'package:test/test.dart';

void main() {
  test('the banner check reaches npt when srvd holds the same port number on'
      ' IPv4', () async {
    final ServerSocket srvd = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    addTearDown(srvd.close);
    srvd.listen((socket) => socket.write('relay auth challenge\n'));
    final ServerSocket npt = await _bindAsNpt(srvd.port);
    addTearDown(npt.close);
    npt.listen((socket) => socket.write('SSH-2.0-OpenSSH_test\r\n'));

    expect(
      await bannerReadable(npt.port),
      isTrue,
      reason: "the check reads sshd's banner through npt, not srvd's challenge",
    );
  });
}

/// A listener where npt is told to listen, on [port] when this platform lets
/// that address share the port with srvd's listener, otherwise on whichever
/// port the platform gives it, as npt's own pick of a free port would be.
Future<ServerSocket> _bindAsNpt(int port) async {
  try {
    return await ServerSocket.bind(nptLocalHost, port);
  } on SocketException {
    return ServerSocket.bind(nptLocalHost, 0);
  }
}
