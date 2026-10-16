import 'dart:async';
import 'dart:io';

import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/srv/srv_impl.dart';
import 'package:test/test.dart';

import '../harness/log_capture.dart';

/// A daemon-side srv whose requested local host can't be resolved.
class _UnresolvingSrv extends SrvImplDart {
  _UnresolvingSrv(int relayPort)
    : super(
        '127.0.0.1',
        relayPort,
        localPort: 22,
        localHost: 'requested.host',
        bindLocalPort: false,
        relayAuthenticator: null,
        multi: true,
        detached: false,
        timeout: const Duration(seconds: 30),
      );

  @override
  Future<InternetAddress> resolveRequestedLocalHost() async =>
      throw SocketException("Failed host lookup: '$localHost'");
}

/// A relay which a daemon-side srv connects its control channel to, giving
/// the test that channel's socket.
Future<({ServerSocket relay, Future<Socket> control})> _relay() async {
  final relay = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(relay.close);
  final control = relay.first.then((socket) {
    addTearDown(socket.destroy);
    return socket;
  });
  return (relay: relay, control: control);
}

/// A daemon-side srv logging at every level, its control channel connected
/// to a relay, with the relay's end of that channel; closed after the test.
Future<Socket> _srvControlChannel() async {
  final (:relay, :control) = await _relay();
  final srv = _UnresolvingSrv(relay.port)..logger.level = 'all';
  final sc = await srv.run();
  addTearDown(sc.close);
  return control;
}

void main() {
  final capture = LogCapture.install();

  group('Given srv logging at every level', () {
    test('when handling a control message fails, then the log names the'
        " message's type and the error's type, and no log line contains a"
        ' socket key or IV', () async {
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
        logged['a connect message with a key and no IV'],
        contains(allOf(contains('Malformed'), contains('connect control'))),
        reason: "the log names the malformed message's type",
      );
    });
  });
}
