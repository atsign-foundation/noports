/// Goal: no relay-auth key, socket key or IV, or whole request reaches a log
/// record. Non-goals: hiding other error detail, which is logged in full, a
/// malformed field's value among it, and sanitising a third-party component's
/// own error text.
library;

import 'dart:async';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srv/srv_impl.dart';
import 'package:test/test.dart';

import '../harness/log_capture.dart';

/// A daemon-side srv whose lookup of its requested local host throws
/// [lookupError] when given, and otherwise resolves to the loopback address
/// when [resolves], and can't be resolved when not.
class _Srv extends SrvImplDart {
  _Srv(
    int relayPort, {
    required super.localPort,
    required this.resolves,
    this.lookupError,
    super.relayAuthenticator,
  }) : super(
         '127.0.0.1',
         relayPort,
         localHost: 'requested.host',
         bindLocalPort: false,
         multi: true,
         detached: false,
         timeout: const Duration(seconds: 30),
       );

  final bool resolves;
  final Object? lookupError;

  @override
  Future<InternetAddress> resolveRequestedLocalHost() async {
    if (lookupError != null) throw lookupError!;
    return resolves
        ? InternetAddress.loopbackIPv4
        : throw SocketException("Failed host lookup: '$localHost'");
  }
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
/// to [relay] or a new relay, with the relay's end of that channel; closed
/// after the test. Its lookup of its requested host throws [lookupError] when
/// given; otherwise the host is [localPort] on the loopback address when
/// [resolves], and can't be resolved when not.
Future<Socket> _srvControlChannel({
  int localPort = 22,
  bool resolves = false,
  Object? lookupError,
  ({ServerSocket server, Future<Socket> first})? relay,
}) async {
  final (server: relayServer, first: control) = relay ?? await _server();
  final srv = _Srv(
    relayServer.port,
    localPort: localPort,
    resolves: resolves,
    lookupError: lookupError,
  )..logger.level = 'all';
  final sc = await srv.run();
  addTearDown(sc.close);
  return control;
}

/// [key] with its character at offset 10 replaced by one that isn't base64.
String _notBase64(String key) => key.replaceRange(10, 11, '*');

/// A FormatException at offset 14 of a source holding [socketKey].
FormatException _holding(String socketKey) =>
    FormatException('Unexpected character', '{"socketKey":"$socketKey"}', 14);

/// A loopback port nothing listens on.
Future<int> _closedPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

void main() {
  final capture = LogCapture.install();

  group('Given srv logging at every level,', () {
    test('when handling a control message fails, then the log names the'
        " message's type and gives the error, and no log line contains a"
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

      final socketKey = generateAes256Key();
      final formatKeys = [generateAes256Key(), generateIvBase64()];
      await handle(
        'a connect message whose requested host lookup throws a'
            ' FormatException holding a socket key',
        _srvControlChannel(lookupError: _holding(socketKey)),
        'connect:${formatKeys.join(':')}\n',
        [...formatKeys, socketKey],
        (m) => m.contains('while handling'),
      );

      final legacySocketKey = generateAes256Key();
      final legacyFormatKeys = [generateAes256Key(), generateIvBase64()];
      await handle(
        'a connect message from a client older than 5.6.1, without a newline,'
            ' whose requested host lookup throws a FormatException holding a'
            ' socket key',
        _srvControlChannel(lookupError: _holding(legacySocketKey)),
        'connect:${legacyFormatKeys.join(':')}',
        [...legacyFormatKeys, legacySocketKey],
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

      final relay = await _server();
      final refusingRelay = _srvControlChannel(resolves: true, relay: relay)
          .then((control) async {
            await relay.server.close();
            return control;
          });
      final refusedRelayKeys = [generateAes256Key(), generateIvBase64()];
      await handle(
        'a connect message whose relay refuses the connection',
        refusingRelay,
        'connect:${refusedRelayKeys.join(':')}\n',
        refusedRelayKeys,
        (m) => m.contains('Failed to connect to relay'),
      );

      final requestedPort = await _closedPort();
      final refusedLocalKeys = [generateAes256Key(), generateIvBase64()];
      await handle(
        'a connect message whose requested host refuses the connection',
        _srvControlChannel(localPort: requestedPort, resolves: true),
        'connect:${refusedLocalKeys.join(':')}\n',
        refusedLocalKeys,
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
            allOf(
              contains("SocketException: Failed host lookup: 'requested.host'"),
              contains('connect control'),
            ),
          ),
          reason:
              "the log names the message's type and gives the error's text"
              ' for $failure',
        );
      }
      for (final failure in [
        'a connect message whose requested host lookup throws a'
            ' FormatException holding a socket key',
        'a connect message from a client older than 5.6.1, without a newline,'
            ' whose requested host lookup throws a FormatException holding a'
            ' socket key',
      ]) {
        expect(
          logged[failure],
          contains(
            allOf(
              contains('FormatException: Unexpected character (at offset 14)'),
              contains('connect control'),
            ),
          ),
          reason:
              "the log names the message's type and gives the error's type,"
              ' message and offset for $failure',
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
            contains('FormatException: Invalid character (at offset 10)'),
          ]),
          reason:
              "the log names the message's type and gives the error's type,"
              ' message and offset for $failure',
        );
      }
      for (final failure in [
        'a connect message whose relay refuses the connection',
        'a connect message whose requested host refuses the connection',
      ]) {
        expect(
          logged[failure],
          containsAll([
            contains('received connect request'),
            allOf(
              contains('SocketException: Connection refused (OS Error: '),
              contains('), address = 127.0.0.1, port = '),
            ),
          ]),
          reason:
              "the log names the message's type and gives the error's text,"
              ' with its host and port, for $failure',
        );
      }
    });

    test('when its relay authentication fails on a relay-auth key that'
        " isn't valid base64, then the log gives the error's message and"
        ' offset, and no log line contains the key.', () async {
      final (server: relay, first: control) = await _server();
      final key = generateAes256Key().replaceRange(32, 33, '*');
      final signing = RsaKeyPair.generate();
      final srv = _Srv(
        relay.port,
        localPort: 22,
        resolves: false,
        relayAuthenticator: RelayAuthenticatorESCR(
          sessionId: 'relay-auth-logs',
          relayAuthAesKey: key,
          publicSigningKeyUri: 'public:signing.sshnp@bob',
          publicSigningKey: signing.atPublicKey.publicKey,
          privateSigningKey: signing.atPrivateKey.privateKey,
          signingAlgo: SigningAlgoType.rsa2048,
          isSideA: false,
        ),
      )..logger.level = 'all';

      final running = srv.run();
      (await control).write('challenge\n');
      await expectLater(
        running,
        throwsA(anything),
        reason: "srv's relay authentication of its control socket fails",
      );

      await capture.untilQuiet();
      expect(
        recordsHoldingKey(capture.records, key),
        isEmpty,
        reason: 'no line srv logs holds the relay-auth key',
      );
      expect(
        [for (final r in capture.records) r.message],
        contains(
          allOf(
            contains('Failed to authenticate control socket'),
            contains('FormatException: Invalid character (at offset 32)'),
          ),
        ),
        reason: "the log gives the error's message and offset",
      );
    });
  });
}
