import 'dart:convert';
import 'dart:io';

/// The address every npt these tests start listens on, and the address the
/// tests connect to it on, so a connection reaches npt rather than another
/// listener holding the same port number, such as one of srvd's.
const String nptLocalHost = '127.0.0.1';

/// The arguments that tell npt to listen on [nptLocalHost].
const List<String> nptLocalHostArgs = ['--local-host', nptLocalHost];

/// Whether a fresh connection to npt's [port] reads sshd's banner within 5s.
Future<bool> bannerReadable(int port) async {
  try {
    final Socket socket = await Socket.connect(
      nptLocalHost,
      port,
      timeout: const Duration(seconds: 5),
    );
    try {
      return await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .any((chunk) => chunk.contains('SSH-'))
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } finally {
      socket.destroy();
    }
  } catch (_) {
    return false;
  }
}
