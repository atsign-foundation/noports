import 'dart:async';
import 'dart:io';

import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/srv/srv_impl.dart';
import 'package:test/test.dart';

import '../harness/log_capture.dart';

/// A daemon-side srv whose requested local host resolves to the loopback
/// address when [resolves], and can't be resolved otherwise.
class _Srv extends SrvImplDart {
  _Srv(int relayPort, {required super.localPort, required this.resolves})
    : super(
        '127.0.0.1',
        relayPort,
        localHost: 'requested.host',
        bindLocalPort: false,
        relayAuthenticator: null,
        multi: true,
        detached: false,
        timeout: const Duration(seconds: 30),
      );

  final bool resolves;

  @override
  Future<InternetAddress> resolveRequestedLocalHost() async => resolves
      ? InternetAddress.loopbackIPv4
      : throw SocketException("Failed host lookup: '$localHost'");
}

/// A server on the loopback address which accepts every connection, giving
/// the test the first; closed after the test.
Future<({ServerSocket server, Future<Socket> first})> _server() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(server.close);
  final first = Completer<Socket>();
  server.listen((socket) {
    addTearDown(socket.destroy);
    if (!first.isCompleted) first.complete(socket);
  });
  return (server: server, first: first.future);
}

/// A daemon-side srv logging at every level, its control channel connected
/// to a relay, with the relay's end of that channel; closed after the test.
/// Its requested host is [localPort] on the loopback address when
/// [resolves], and can't be resolved otherwise.
Future<Socket> _srvControlChannel({
  int localPort = 22,
  bool resolves = false,
}) async {
  final (server: relay, first: control) = await _server();
  final srv = _Srv(relay.port, localPort: localPort, resolves: resolves)
    ..logger.level = 'all';
  final sc = await srv.run();
  addTearDown(sc.close);
  return control;
}

/// [key] with one character replaced by one that isn't base64.
String _notBase64(String key) => key.replaceRange(10, 11, '*');

void main() {
  final capture = LogCapture.install();

  group('Given srv logging at every level,', () {
    test('when handling a control message fails, then the log names the'
        " message's type and the error's type, and no log line contains a"
        ' socket key or IV.', () async {
      final keysSent = <String, List<String>>{};
      final logged = <String, List<String>>{};

      Future<void> handle(
        String failure,
        Future<Socket> control,
        String message,
        List<String> keysAndIvs,
        bool Function(String) done,
      ) async {
        final from = capture.records.length;
        int handled() => capture.records.where((r) => done(r.message)).length;
        final before = handled();
        (await control).write(message);
        await capture.waitFor(failure, (_) => handled() > before);
        keysSent[failure] = keysAndIvs;
        logged[failure] = [
          for (final r in capture.records.skip(from)) r.message,
        ];
      }

      final twinKeys = [
        generateAes256Key(),
        generateIvBase64(),
        generateAes256Key(),
        generateIvBase64(),
      ];
      final control = _srvControlChannel();
      await handle(
        'a connect message whose requested host cannot be resolved',
        control,
        'connect:${twinKeys.join(':')}\n',
        twinKeys,
        (m) => m.contains('while handling'),
      );

      final key = generateAes256Key();
      await handle(
        'a connect message with a key and no IV',
        control,
        'connect:$key\n',
        [key],
        (m) => m.contains('Malformed'),
      );

      final legacyKeys = [generateAes256Key(), generateIvBase64()];
      await handle(
        'a connect message from a client older than 5.6.1, without a newline,'
            ' whose requested host cannot be resolved',
        _srvControlChannel(),
        'connect:${legacyKeys.join(':')}',
        legacyKeys,
        (m) => m.contains('while handling'),
      );

      final relayKey = _notBase64(generateAes256Key());
      final relayIv = generateIvBase64();
      await handle(
        'a connect message whose key for the relay is not base64',
        _srvControlChannel(resolves: true),
        'connect:$relayKey:$relayIv\n',
        [relayKey, relayIv],
        (m) => m.contains('Failed to connect to relay'),
      );

      final (server: requestedHost, first: _) = await _server();
      final localKeys = [
        generateAes256Key(),
        generateIvBase64(),
        _notBase64(generateAes256Key()),
        generateIvBase64(),
      ];
      await handle(
        'a connect message whose key for the requested host is not base64',
        _srvControlChannel(localPort: requestedHost.port, resolves: true),
        'connect:${localKeys.join(':')}\n',
        localKeys,
        (m) => m.contains('Failed to connect locally'),
      );

      final unknownKeys = [generateAes256Key(), generateIvBase64()];
      await handle(
        'a control message of a type srv does not know, carrying a key and IV',
        _srvControlChannel(),
        'conect:${unknownKeys.join(':')}\n',
        unknownKeys,
        (m) => m.contains('unknown'),
      );

      await capture.untilQuiet();
      expect(
        {
          for (final MapEntry(key: failure, value: keysAndIvs)
              in keysSent.entries)
            failure: {
              for (final keyOrIv in keysAndIvs)
                ...recordsHoldingKey(capture.records, keyOrIv),
            },
        }..removeWhere((_, holding) => holding.isEmpty),
        isEmpty,
        reason: 'no line srv logs holds a socket key or IV',
      );
      for (final failure in [
        'a connect message whose requested host cannot be resolved',
        'a connect message from a client older than 5.6.1, without a newline,'
            ' whose requested host cannot be resolved',
      ]) {
        expect(
          logged[failure],
          contains(
            allOf(contains('SocketException'), contains('connect control')),
          ),
          reason:
              "the log names the message's type and the error's type for"
              ' $failure',
        );
      }
      expect(
        logged['a control message of a type srv does not know, carrying a key and IV'],
        contains(allOf(contains('unknown'), contains('conect control'))),
        reason: "the log names the unknown message's type",
      );
      expect(
        logged['a connect message with a key and no IV'],
        contains(allOf(contains('Malformed'), contains('connect control'))),
        reason: "the log names the malformed message's type",
      );
      for (final failure in [
        'a connect message whose key for the relay is not base64',
        'a connect message whose key for the requested host is not base64',
      ]) {
        expect(
          logged[failure],
          containsAll([
            contains('received connect request'),
            contains('FormatException'),
          ]),
          reason:
              "the log names the message's type and the error's type for"
              ' $failure',
        );
      }
    });
  });
}
