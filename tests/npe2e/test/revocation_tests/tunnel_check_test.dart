import 'dart:io';

import 'package:npe2e/revocation_tests/tunnel_check.dart';
import 'package:test/test.dart';

void main() {
  for (final (family, srvdAddress, v6Only) in [
    ('IPv4', InternetAddress.anyIPv4, false),
    ('IPv6', InternetAddress.loopbackIPv6, true),
  ]) {
    test('The banner check reaches npt when srvd holds the same port number on'
        ' $family: when npt listens where the pack tells it to, on the port'
        " srvd holds, then the check reads sshd's banner from npt", () async {
      final ServerSocket srvd = await ServerSocket.bind(
        srvdAddress,
        0,
        v6Only: v6Only,
      );
      addTearDown(srvd.close);
      srvd.listen((socket) => socket.write('relay auth challenge\n'));
      final ServerSocket? npt = await _bindAsNpt(srvd.port);
      if (npt == null) return;
      addTearDown(npt.close);
      npt.listen((socket) => socket.write('SSH-2.0-OpenSSH_test\r\n'));

      expect(
        await bannerReadable(npt.port),
        isTrue,
        reason:
            "the check reads sshd's banner through npt, not srvd's challenge",
      );
    });
  }
}

/// A listener on [port] where [nptLocalHostArgs] tell npt to listen, or at
/// npt's own default, localhost, when they name nowhere; null, with the test
/// marked skipped, when this platform refuses it the port beside srvd's.
Future<ServerSocket?> _bindAsNpt(int port) async {
  final int flag = nptLocalHostArgs.indexOf('--local-host');
  final String host = flag >= 0 && flag + 1 < nptLocalHostArgs.length
      ? nptLocalHostArgs[flag + 1]
      : 'localhost';
  try {
    return await ServerSocket.bind(host, port);
  } on SocketException catch (e) {
    markTestSkipped(
      "this platform refuses npt's listener on $host the port beside srvd's:"
      ' ${e.osError?.message ?? e.message}',
    );
    return null;
  }
}
