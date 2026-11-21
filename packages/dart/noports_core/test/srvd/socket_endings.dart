import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// How long a test waits for a verification or a stream to finish before
/// reporting it as still pending, well inside the relay's authentication limit.
const Duration hangGuard = Duration(seconds: 5);

/// A connected loopback pair: the relay's accepted socket and its peer.
Future<(Socket relaySide, Socket peer)> loopbackPair() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final accepted = server.first;
  final peer = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
  final relaySide = await accepted;
  await server.close();
  return (relaySide, peer);
}

/// What [verification] came to within [hangGuard]: `authenticated`,
/// `failed: <error>`, or that it was still pending when the guard ran out.
Future<String> outcomeWithin(Future<(bool, Stream<Uint8List>?)> verification) =>
    verification
        .then(
          (result) => result.$1 ? 'authenticated' : 'not authenticated',
          onError: (Object e) => 'failed: $e',
        )
        .timeout(
          hangGuard,
          onTimeout: () =>
              'still pending at the ${hangGuard.inSeconds} s hang guard',
        );

/// The lines [peer] reads from the relay.
StreamIterator<String> linesFrom(Socket peer) =>
    StreamIterator(utf8.decoder.bind(peer).transform(const LineSplitter()));

/// What [lines] gives next within [hangGuard]: `line: <line>`, `done`, or
/// that it was still open when the guard ran out.
Future<String> nextLineWithin(StreamIterator<String> lines) => lines
    .moveNext()
    .then((more) => more ? 'line: ${lines.current}' : 'done')
    .timeout(
      hangGuard,
      onTimeout: () => 'still open at the ${hangGuard.inSeconds} s hang guard',
    );

/// How [stream] ends within [hangGuard]: `done`, `error: <error>`, or that it
/// was still open when the guard ran out.
Future<String> endingWithin(Stream<Uint8List> stream) {
  final ending = Completer<String>();
  stream.listen(
    (_) {},
    onError: (Object e) {
      if (!ending.isCompleted) ending.complete('error: $e');
    },
    onDone: () {
      if (!ending.isCompleted) ending.complete('done');
    },
  );
  return ending.future.timeout(
    hangGuard,
    onTimeout: () => 'still open at the ${hangGuard.inSeconds} s hang guard',
  );
}
