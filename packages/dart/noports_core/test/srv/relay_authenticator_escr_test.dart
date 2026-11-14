import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class MockSocket extends Mock implements Socket {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

/// A socket double that hands the authenticator's data callback to the test,
/// which plays the relay.
class FakeRelaySocket {
  final MockSocket socket = MockSocket();
  late void Function(Uint8List) send;

  FakeRelaySocket() {
    when(() => socket.flush()).thenAnswer((_) async {});
    when(() => socket.writeln(any())).thenReturn(null);
    when(
      () => socket.listen(
        any(),
        onError: any(named: 'onError'),
        onDone: any(named: 'onDone'),
      ),
    ).thenAnswer((invocation) {
      send = invocation.positionalArguments[0] as void Function(Uint8List);
      return MockStreamSubscription<Uint8List>();
    });
  }

  void sendText(String s) => send(Uint8List.fromList(s.codeUnits));
}

void main() {
  late RsaKeyPair signingKP;
  late String relayAuthAesKey;
  late String sessionId;

  setUpAll(() {
    signingKP = RsaKeyPair.generate(keySize: 2048);
    relayAuthAesKey = AESKey.generate(32).key;
    sessionId = Uuid().v4();
  });

  RelayAuthenticatorESCR authenticator() => RelayAuthenticatorESCR(
    sessionId: sessionId,
    relayAuthAesKey: relayAuthAesKey,
    publicSigningKeyUri: '_apsk.my_enrollment_id.a.__e@alice',
    publicSigningKey: signingKP.atPublicKey.publicKey,
    privateSigningKey: signingKP.atPrivateKey.privateKey,
    signingAlgo: SigningAlgoType.rsa2048,
    isSideA: false,
  );

  group('Given an srv authenticating to a relay with ESCR', () {
    test('when the relay sends 64 bytes with no newline, then authentication'
        ' fails with an error naming the 63-byte line limit and the srv closes'
        ' its relay socket', () {
      // Each arm sends the 64-byte payload `copies` times, splitting each
      // copy into `chunks` writes. With more than one chunk no single write
      // exceeds the limit, only the accumulated line does; with more than
      // one copy, data keeps arriving after authentication has failed.
      for (final (answered, before, after, copies, chunks) in [
        (false, '', '', 1, 1),
        (false, 'somechallenge\n', '', 1, 1),
        (false, '', '\n', 1, 1),
        (false, '', '', 2, 1),
        (false, '', '', 1, 2),
        (false, '', '', 1, 64),
        (true, '', '', 1, 1),
        (true, '', '', 1, 64),
      ]) {
        final arm =
            'after an answered challenge: $answered, preceded by "$before",'
            ' followed by "$after", sent $copies time(s), each split across'
            ' $chunks write(s)';
        final payload = [
          ...before.codeUnits,
          ...List.filled(64, 0x41),
          ...after.codeUnits,
        ];
        final chunkSize = (payload.length / chunks).ceil();
        fakeAsync((time) {
          final relay = FakeRelaySocket();
          Object? error;
          final raised = <Object>[];
          runZonedGuarded(() {
            authenticator()
                .authenticate(relay.socket)
                .then(
                  (_) {},
                  onError: (Object e) {
                    error = e;
                  },
                );
            if (answered) {
              relay.sendText('somechallenge\n');
              time.flushMicrotasks();
            }
            for (var copy = 0; copy < copies; copy++) {
              for (var i = 0; i < payload.length; i += chunkSize) {
                relay.send(
                  Uint8List.fromList(
                    payload.sublist(
                      i,
                      (i + chunkSize).clamp(0, payload.length),
                    ),
                  ),
                );
                time.flushMicrotasks();
              }
            }
          }, (e, _) => raised.add(e));

          expect(
            '$error',
            'Relay sent a line longer than 63 bytes during authentication',
            reason: arm,
          );
          expect(raised, isEmpty, reason: arm);
          verify(() => relay.socket.destroy()).called(1);
          if (answered) {
            verify(() => relay.socket.writeln(any())).called(1);
          } else {
            verifyNever(() => relay.socket.writeln(any()));
          }
        });
      }
    });

    test(
      'when the relay sends a 63-byte challenge line, then the srv answers it',
      () {
        fakeAsync((time) {
          final relay = FakeRelaySocket();
          (bool, Stream<Uint8List>?)? result;
          authenticator().authenticate(relay.socket).then((r) {
            result = r;
          });

          relay.sendText('A' * 30);
          time.flushMicrotasks();
          verifyNever(() => relay.socket.writeln(any()));
          relay.sendText('${'A' * 33}\n');
          time.flushMicrotasks();

          final response = verify(
            () => relay.socket.writeln(captureAny()),
          ).captured.single;
          expect(response, startsWith('$sessionId:'));
          relay.sendText('ok\n');
          time.flushMicrotasks();
          expect(
            result?.$1,
            isTrue,
            reason: 'a 63-byte challenge is within the limit',
          );
          verifyNever(() => relay.socket.destroy());
        });
      },
    );

    test(
      'when the relay sends "ok" and 65536 bytes of session data in one write,'
      ' then authentication succeeds and all 65536 bytes reach the session'
      ' stream',
      () {
        fakeAsync((time) {
          final relay = FakeRelaySocket();
          (bool, Stream<Uint8List>?)? result;
          authenticator().authenticate(relay.socket).then((r) {
            result = r;
          });

          relay.sendText('somechallenge\n');
          time.flushMicrotasks();
          final sessionData = Uint8List(65536);
          for (var i = 0; i < sessionData.length; i++) {
            sessionData[i] = i % 251;
          }
          relay.send(Uint8List.fromList([...'ok\n'.codeUnits, ...sessionData]));
          time.flushMicrotasks();

          expect(result?.$1, isTrue);
          final received = <int>[];
          result!.$2!.listen(received.addAll);
          time.flushMicrotasks();
          expect(received, sessionData);
          verifyNever(() => relay.socket.destroy());
        });
      },
    );

    test('when the relay sends 64 bytes with no newline, then authentication'
        ' fails with an error naming the 63-byte line limit and the srv closes'
        ' its relay socket (loopback socket)', () async {
      final relay = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(relay.close);
      final relaySide = relay.first;
      final socket = await Socket.connect(relay.address, relay.port);
      // Listen for the failure before the relay sends anything, so the error
      // cannot complete the future while it has no listener.
      final failed = expectLater(
        authenticator().authenticate(socket),
        throwsA(predicate((e) => '$e'.contains('63'))),
      );
      final fromSrv = await relaySide;
      final srvClosed = fromSrv.drain<void>();

      fromSrv.add(List.filled(64, 0x41));
      await fromSrv.flush();

      await failed;
      await srvClosed.timeout(const Duration(seconds: 5));
      fromSrv.destroy();
    });
  });
}
