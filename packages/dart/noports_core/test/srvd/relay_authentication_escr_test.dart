import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:at_chops/at_chops.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class MockRelayAuthVerifyHelper extends Mock implements RelayAuthVerifyHelper {}

class MockSocket extends Mock implements Socket {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

void main() {
  group('Tests of RelayAuthenticatorESCR and RelayAuthVerifierESCR', () {
    late String relayAuthAesKey;
    late String wrongAesKey;
    late String relaySessionId;
    late String publicSigningKeyUri;
    late AtEncryptionKeyPair signingKP;
    late AtEncryptionKeyPair wrongKP;
    late RelayAuthVerifyHelper helper;
    late String wrongChallenge = AtChopsUtil.generateSymmetricKey(
      EncryptionKeyType.aes256,
    ).key;

    setUpAll(() {
      signingKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      wrongKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      publicSigningKeyUri = '_apsk.my_enrollment_id.a.__e@alice';

      relayAuthAesKey = AtChopsUtil.generateSymmetricKey(
        EncryptionKeyType.aes256,
      ).key;
      wrongAesKey = AtChopsUtil.generateSymmetricKey(
        EncryptionKeyType.aes256,
      ).key;
      relaySessionId = Uuid().v4();

      helper = MockRelayAuthVerifyHelper();
      when(
        () => helper.isSessionActive(relaySessionId),
      ).thenAnswer((_) => Future.value(true));
      when(
        () => helper.getRelayAuthAesKey(relaySessionId),
      ).thenAnswer((_) => Future.value(relayAuthAesKey));
      when(
        () => helper.lookup(relaySessionId, publicSigningKeyUri),
      ).thenAnswer((_) => Future.value(signingKP.atPublicKey.publicKey));
    });

    test('all is well', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        isSideA: false,
      );
      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'test all is well',
        helper,
      );

      when(
        () => helper.isSessionActive(relaySessionId),
      ).thenAnswer((_) => Future.value(true));
      when(
        () => helper.getRelayAuthAesKey(relaySessionId),
      ).thenAnswer((_) => Future.value(relayAuthAesKey));
      when(
        () => helper.lookup(relaySessionId, publicSigningKeyUri),
      ).thenAnswer((_) => Future.value(signingKP.atPublicKey.publicKey));

      expect(verifier.atSign, isNull);
      expect(verifier.sessionId, isNull);
      expect(verifier.isSideA, null);

      bool verified = await verifier.verifyChallengeResponse(
        await authenticator.responseToChallenge(verifier.challenge),
      );

      expect(verified, true);
      expect(verifier.atSign, '@alice');
      expect(verifier.sessionId, relaySessionId);
      expect(verifier.isSideA, false);
    });

    test('wrong signing key', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: wrongKP.atPublicKey.publicKey,
        privateSigningKey: wrongKP.atPrivateKey.privateKey,
        isSideA: true,
      );

      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'test wrong signing key',
        helper,
      );

      await expectLater(
        verifier.verifyChallengeResponse(
          await authenticator.responseToChallenge(verifier.challenge),
        ),
        throwsA(
          isA<RAVE>().having(
            (e) => e.reason,
            'reason',
            RAVEReason.signatureVerificationFailed,
          ),
        ),
      );

      expect(verifier.atSign, '@alice');
      expect(verifier.sessionId, relaySessionId);
      expect(verifier.isSideA, true);
    });

    test('wrong AES key', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: wrongAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        isSideA: true,
      );

      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'test wrong AES key',
        helper,
      );

      await expectLater(
        verifier.verifyChallengeResponse(
          await authenticator.responseToChallenge(verifier.challenge),
        ),
        throwsA(
          isA<RAVE>().having(
            (e) => e.reason,
            'reason',
            RAVEReason.decryptionFailed,
          ),
        ),
      );

      expect(verifier.atSign, null);
      expect(verifier.sessionId, relaySessionId);
      expect(verifier.isSideA, null);
    });

    test('wrong challenge', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        isSideA: false,
      );

      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'test wrong challenge',
        helper,
      );

      await expectLater(
        verifier.verifyChallengeResponse(
          await authenticator.responseToChallenge(wrongChallenge),
        ),
        throwsA(
          isA<RAVE>()
              .having((e) => e.reason, 'reason', RAVEReason.dataMismatch)
              .having(
                (e) => e.message,
                'message',
                contains('does not match challenge issued'),
              ),
        ),
      );

      expect(verifier.atSign, null);
      expect(verifier.sessionId, relaySessionId);
      expect(verifier.isSideA, false);
    });

    test('too much data', () async {
      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'too much data',
        helper,
      );

      Random r = Random();
      Uint8List data = Uint8List.fromList(List.generate(
          RelayAuthVerifier.maxAuthBufferLength + 1, (i) => r.nextInt(256)));

      late Function(Uint8List data) socketOnDataFn;
      MockSocket mockSocket = MockSocket();

      when (() => mockSocket.flush()).thenAnswer((Invocation i) async {Completer c = Completer(); c.complete(); return c.future;});
      when(
            () => mockSocket.listen(
          any(),
          onError: any(named: "onError"),
          onDone: any(named: "onDone"),
        ),
      ).thenAnswer((Invocation invocation) {
        socketOnDataFn = invocation.positionalArguments[0];

        socketOnDataFn(data);

        return MockStreamSubscription<Uint8List>();
      });

      bool somethingThrown = false;
      try {
        await verifier.verifySocketAuth(mockSocket);
      } catch (e, st) {
        expect(e.toString(), contains('Error during socket authentication:'
            ' RelayAuthVerifierException: malformedChallengeResponse :'
            ' Too much data from client (more than 4096 bytes)'));
        print('Caught $e as expected\n$st');
        somethingThrown = true;
      }
      expect(somethingThrown, true, reason: 'exception should have been thrown');


      expect(verifier.atSign, null);
      expect(verifier.sessionId, null);
      expect(verifier.isSideA, null);
    });
  });

  group('post-auth fast-path ordering', () {
    // These pin the invariant the fast path in relay_authenticators.dart and
    // relay_auth_verifiers.dart depends on: no `await` runs between
    // `authenticated = true` and the residual-buffer flush, so once a
    // listener invocation observes `authenticated`, every byte that arrived
    // before it has already reached `sc`.
    late String relayAuthAesKey;
    late String relaySessionId;
    late String publicSigningKeyUri;
    late AtEncryptionKeyPair signingKP;
    late RelayAuthVerifyHelper helper;

    setUpAll(() {
      signingKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      publicSigningKeyUri = '_apsk.my_enrollment_id.a.__e@alice';
      relayAuthAesKey = AtChopsUtil.generateSymmetricKey(
        EncryptionKeyType.aes256,
      ).key;
      relaySessionId = Uuid().v4();

      helper = MockRelayAuthVerifyHelper();
      when(
        () => helper.isSessionActive(relaySessionId),
      ).thenAnswer((_) => Future.value(true));
      when(
        () => helper.getRelayAuthAesKey(relaySessionId),
      ).thenAnswer((_) => Future.value(relayAuthAesKey));
      when(
        () => helper.lookup(relaySessionId, publicSigningKeyUri),
      ).thenAnswer((_) => Future.value(signingKP.atPublicKey.publicKey));
    });

    MockSocket mockSocketWith({
      required void Function(void Function(Uint8List)) captureOnData,
    }) {
      final mockSocket = MockSocket();
      when(() => mockSocket.flush()).thenAnswer((_) async {});
      when(() => mockSocket.writeln(any())).thenReturn(null);
      when(
        () => mockSocket.listen(
          any(),
          onError: any(named: 'onError'),
          onDone: any(named: 'onDone'),
        ),
      ).thenAnswer((invocation) {
        captureOnData(
          invocation.positionalArguments[0] as void Function(Uint8List),
        );
        return MockStreamSubscription<Uint8List>();
      });
      return mockSocket;
    }

    test(
      'RelayAuthenticatorESCR: residual bytes bundled with "ok" arrive '
      'before a later post-auth chunk, in order',
      () async {
        final authenticator = RelayAuthenticatorESCR(
          sessionId: relaySessionId,
          relayAuthAesKey: relayAuthAesKey,
          publicSigningKeyUri: publicSigningKeyUri,
          publicSigningKey: signingKP.atPublicKey.publicKey,
          privateSigningKey: signingKP.atPrivateKey.privateKey,
          isSideA: false,
        );

        late Function(Uint8List) onData;
        final mockSocket = mockSocketWith(captureOnData: (fn) => onData = fn);

        final authFuture = authenticator.authenticate(mockSocket);

        onData(Uint8List.fromList('somechallenge\n'.codeUnits));
        // Let the authenticator sign the challenge and write its response
        // before the relay's "ok" confirmation arrives.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final residual = Uint8List.fromList([1, 2, 3]);
        // The "ok" chunk and the next post-auth chunk are delivered with no
        // `await` between them, so the second `onData` call runs while the
        // first invocation may still be suspended (e.g. on the mutex). This
        // is what would expose a reorder if an `await` ever crept in between
        // `authenticated = true` and the residual flush.
        onData(Uint8List.fromList([...'ok\n'.codeUnits, ...residual]));
        onData(Uint8List.fromList([4, 5, 6]));

        final (ok, stream) = await authFuture;
        expect(ok, true);

        final received = <int>[];
        final sub = stream!.listen(received.addAll);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(received, [1, 2, 3, 4, 5, 6]);
      },
    );

    test(
      'RelayAuthVerifierESCR: residual bytes bundled with the auth response '
      'arrive before a later post-auth chunk, in order',
      () async {
        final authenticator = RelayAuthenticatorESCR(
          sessionId: relaySessionId,
          relayAuthAesKey: relayAuthAesKey,
          publicSigningKeyUri: publicSigningKeyUri,
          publicSigningKey: signingKP.atPublicKey.publicKey,
          privateSigningKey: signingKP.atPrivateKey.privateKey,
          isSideA: false,
        );
        final verifier = RelayAuthVerifierESCR(
          'post-auth fast-path ordering',
          helper,
        );

        late Function(Uint8List) onData;
        final mockSocket = mockSocketWith(captureOnData: (fn) => onData = fn);

        final verifyFuture = verifier.verifySocketAuth(mockSocket);

        final response = await authenticator.responseToChallenge(
          verifier.challenge,
        );
        final residual = Uint8List.fromList([7, 8, 9]);
        // The auth-completing chunk and the next post-auth chunk are
        // delivered with no `await` between them, so the second `onData`
        // call runs while the first invocation may still be suspended (e.g.
        // on the mutex). This is what would expose a reorder if an `await`
        // ever crept in between `authenticated = true` and the residual
        // flush.
        onData(Uint8List.fromList([...'$response\n'.codeUnits, ...residual]));
        onData(Uint8List.fromList([10, 11, 12]));

        final (ok, stream) = await verifyFuture;
        expect(ok, true);

        final received = <int>[];
        final sub = stream!.listen(received.addAll);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(received, [7, 8, 9, 10, 11, 12]);
      },
    );

    test(
      'RelayAuthVerifierESCR: rapid back-to-back post-auth chunks are not '
      'reordered by the mutex-free fast path',
      () async {
        final authenticator = RelayAuthenticatorESCR(
          sessionId: relaySessionId,
          relayAuthAesKey: relayAuthAesKey,
          publicSigningKeyUri: publicSigningKeyUri,
          publicSigningKey: signingKP.atPublicKey.publicKey,
          privateSigningKey: signingKP.atPrivateKey.privateKey,
          isSideA: false,
        );
        final verifier = RelayAuthVerifierESCR(
          'post-auth fast-path rapid chunks',
          helper,
        );

        late Function(Uint8List) onData;
        final mockSocket = mockSocketWith(captureOnData: (fn) => onData = fn);

        final verifyFuture = verifier.verifySocketAuth(mockSocket);
        final response = await authenticator.responseToChallenge(
          verifier.challenge,
        );
        onData(Uint8List.fromList('$response\n'.codeUnits));

        final (ok, stream) = await verifyFuture;
        expect(ok, true);

        final received = <int>[];
        final sub = stream!.listen(received.addAll);

        for (final chunk in [
          [1],
          [2],
          [3],
          [4],
          [5],
        ]) {
          onData(Uint8List.fromList(chunk));
        }
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(received, [1, 2, 3, 4, 5]);
      },
    );

    // The behavioral tests above exercise realistic delivery patterns, but
    // the actual race the fast path depends on spans several awaited calls
    // inside verifyChallengeResponse's crypto chain, making it impractical
    // to hit deterministically from outside. Pin the precondition directly
    // instead: no `await` may sit between `authenticated = true` and the
    // residual-buffer flush in either ESCR site.
    test(
      'structural: no await between authenticated=true and the residual '
      'flush in relay_authenticators.dart',
      () {
        final source = File(
          'lib/src/srv/relay_authenticators.dart',
        ).readAsStringSync();
        final flushIdx = source.indexOf(
          'sc.add(Uint8List.fromList(buffer));',
        );
        final flipIdx = source.indexOf('authenticated = true;');
        expect(flushIdx, greaterThan(-1));
        expect(flipIdx, greaterThan(flushIdx));
        expect(source.substring(flushIdx, flipIdx).contains('await'), isFalse);
      },
    );

    test(
      'structural: no await between authenticated=true and the residual '
      'flush in relay_auth_verifiers.dart',
      () {
        final source = File(
          'lib/src/srvd/relay_auth_verifiers.dart',
        ).readAsStringSync();
        // Anchor within the ESCR verifier only; the legacy verifier has the
        // same-looking pair further down but is synchronous and mutex-free.
        final escrSection = source.substring(
          source.indexOf('class RelayAuthVerifierESCR'),
          source.indexOf('class RelayAuthVerifierLegacy'),
        );
        final flipIdx = escrSection.indexOf('authenticated = true;');
        final flushIdx = escrSection.indexOf(
          'if (buffer.isNotEmpty) {',
          flipIdx,
        );
        expect(flipIdx, greaterThan(-1));
        expect(flushIdx, greaterThan(flipIdx));
        expect(
          escrSection.substring(flipIdx, flushIdx).contains('await'),
          isFalse,
        );
      },
    );
  });
}
