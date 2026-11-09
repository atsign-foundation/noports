import 'dart:io';

import 'package:npe2e/revocation_tests/revocation_tests.dart';
import 'package:npe2e/revocation_tests/revocation_tests_params.dart';
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
      expect(
        nptTunnelArgs(
          _params,
          'aDevice',
          File('atKeys'),
        ),
        containsAllInOrder(nptLocalHostArgs),
        reason: 'the pack tells npt to listen where the check connects',
      );
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

/// The command-line parameters of a revocation test run, for building the
/// args the pack starts an npt tunnel with.
final RevocationTestsParams _params = RevocationTestsParams.parse([
  '--client-atsign',
  '@client',
  '--daemon-atsign',
  '@daemon',
  '--relay-atsign',
  '@relay',
  '--root-domain',
  'vip.ve.atsign.zone:64',
]);

/// A listener on [port] at [nptLocalHost], where the pack tells npt to
/// listen; null, with the test marked skipped, when this platform refuses it
/// the port beside srvd's.
Future<ServerSocket?> _bindAsNpt(int port) async {
  try {
    return await ServerSocket.bind(nptLocalHost, port);
  } on SocketException catch (e) {
    markTestSkipped(
      "this platform refuses npt's listener on $nptLocalHost the port beside"
      " srvd's: ${e.osError?.message ?? e.message}",
    );
    return null;
  }
}
