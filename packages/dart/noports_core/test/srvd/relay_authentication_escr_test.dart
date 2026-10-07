import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:at_auth/at_auth.dart'
    show ApskSigningKey, KeyEntryStatus, apskAdvertisement;
import 'package:at_chops/at_chops.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/session_crypto.dart';
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
    late RsaKeyPair signingKP;
    late RsaKeyPair wrongKP;
    late RelayAuthVerifyHelper helper;
    late String wrongChallenge = AESKey.generate(32).key;

    setUpAll(() {
      signingKP = RsaKeyPair.generate(keySize: 2048);
      wrongKP = RsaKeyPair.generate(keySize: 2048);
      publicSigningKeyUri = '_apsk.my_enrollment_id.a.__e@alice';

      relayAuthAesKey = AESKey.generate(32).key;
      wrongAesKey = AESKey.generate(32).key;
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

    /// A helper for [relaySessionId] that serves [signingKP]'s public key for
    /// any key URI, so the only thing that can refuse is the check under test.
    MockRelayAuthVerifyHelper sessionHelper({bool active = true}) {
      final h = MockRelayAuthVerifyHelper();
      when(() => h.isSessionActive(relaySessionId))
          .thenAnswer((_) async => active);
      when(() => h.getRelayAuthAesKey(relaySessionId))
          .thenAnswer((_) async => relayAuthAesKey);
      when(() => h.lookup(relaySessionId, any()))
          .thenAnswer((_) async => signingKP.atPublicKey.publicKey);
      return h;
    }

    /// Builds a response as [RelayAuthenticatorESCR] does, but from a signed
    /// payload the test chooses, so one field can be wrong and the rest valid.
    Future<String> escrResponse(
      Object? payload, {
      String signingAlgo = 'rsa2048',
      String? signingKeyUri,
    }) async {
      final envelope = {
        'p': payload,
        's': rsaSignString(
          jsonEncode(payload),
          privateKey: signingKP.atPrivateKey.privateKey,
        ),
        'ha': 'sha256',
        'sa': signingAlgo,
        'sk': signingKeyUri ?? publicSigningKeyUri,
      };
      final iv = generateIv();
      final encrypted = await aesEncryptString(
        base64Encode(jsonEncode(envelope).codeUnits),
        key: relayAuthAesKey,
        iv: iv,
      );
      return '$relaySessionId:'
          '${base64Encode(jsonEncode({'iv': base64Encode(iv.ivBytes), 'e': encrypted}).codeUnits)}';
    }

    Matcher refusedWith(RAVEReason reason, String message) => throwsA(
          isA<RAVE>()
              .having((e) => e.reason, 'reason', reason)
              .having((e) => e.message, 'message', contains(message)),
        );

    test('all is well', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        signingAlgo: SigningAlgoType.rsa2048,
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
        signingAlgo: SigningAlgoType.rsa2048,
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

    for (final label in ['rsa2048', 'rsa4096', 'ecc_secp256r1']) {
      test('signing algorithm $label', () async {
        final checkedHelper = sessionHelper();
        final verifier = RelayAuthVerifierESCR(
          'test signing algorithm $label',
          checkedHelper,
        );
        final response = await escrResponse(
          {'sid': relaySessionId, 'c': verifier.challenge, 'side': 'a'},
          signingAlgo: label,
        );

        if (label == 'rsa2048') {
          expect(await verifier.verifyChallengeResponse(response), true);
          return;
        }
        await expectLater(
          verifier.verifyChallengeResponse(response),
          throwsA(
            isA<RAVE>().having(
              (e) => e.reason,
              'reason',
              RAVEReason.signatureVerificationFailed,
            ),
          ),
        );
        verifyNever(() => checkedHelper.lookup(any(), any()));
      });
    }

    test('an envelope naming no key is refused when two keys could have'
        ' signed it', () async {
      final checkedHelper = sessionHelper();
      when(() => checkedHelper.lookup(relaySessionId, any())).thenAnswer(
        (_) async => jsonEncode(apskAdvertisement(keys: [
          for (final kp in [signingKP, wrongKP])
            ApskSigningKey.forPublicKey(
              alg: SigningAlgoType.rsa2048,
              pub: kp.atPublicKey.publicKey,
            ),
        ])),
      );
      final verifier = RelayAuthVerifierESCR('two keys', checkedHelper);

      await expectLater(
        verifier.verifyChallengeResponse(await escrResponse(
          {'sid': relaySessionId, 'c': verifier.challenge, 'side': 'a'},
        )),
        refusedWith(RAVEReason.signatureVerificationFailed, 'names no key'),
      );
    });

    test('wrong AES key', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: wrongAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        signingAlgo: SigningAlgoType.rsa2048,
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
        signingAlgo: SigningAlgoType.rsa2048,
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
            ' Too much data from client (more than 16384 bytes)'));
        print('Caught $e as expected\n$st');
        somethingThrown = true;
      }
      expect(somethingThrown, true, reason: 'exception should have been thrown');


      expect(verifier.atSign, null);
      expect(verifier.sessionId, null);
      expect(verifier.isSideA, null);
    });

    test('is single-use: verifying a second response throws', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        signingAlgo: SigningAlgoType.rsa2048,
        isSideA: false,
      );
      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'single-use',
        helper,
      );

      // First use is fine.
      final verified = await verifier.verifyChallengeResponse(
        await authenticator.responseToChallenge(verifier.challenge),
      );
      expect(verified, true);

      // A second use would reuse this verifier's (already issued) challenge
      // across connections, so it must be refused.
      await expectLater(
        verifier.verifyChallengeResponse(
          await authenticator.responseToChallenge(verifier.challenge),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a signature over another session id is refused', () async {
      final h = sessionHelper();
      final verifier = RelayAuthVerifierESCR('test other session', h);
      final response = await escrResponse({
        'sid': Uuid().v4(),
        'c': verifier.challenge,
        'side': 'a',
      });

      await expectLater(
        verifier.verifyChallengeResponse(response),
        refusedWith(
          RAVEReason.dataMismatch,
          'does not match expected sessionId',
        ),
      );
      verifyNever(() => h.lookup(any(), any()));
    });

    for (final uri in [
      'public:signing_publickey@alice',
      '_apsk.my_enrollment_id.a.__e.evil@alice',
    ]) {
      test('a signing key outside the per-enrollment namespace is refused'
          ' ($uri)', () async {
        final h = sessionHelper();
        final verifier = RelayAuthVerifierESCR('test namespace', h);
        final response = await escrResponse(
          {'sid': relaySessionId, 'c': verifier.challenge, 'side': 'a'},
          signingKeyUri: uri,
        );

        await expectLater(
          verifier.verifyChallengeResponse(response),
          refusedWith(
            RAVEReason.signatureVerificationFailed,
            'is not in the per-enrollment data namespace',
          ),
        );
        verifyNever(() => h.lookup(any(), any()));
      });
    }

    // NOTE the signer is taken from after the key's last '@', but the lookup
    // parses the whole key, so any other shape could make them disagree.
    for (final uri in [
      '_apsk.my_enrollment_id.a.__e@mallory.a.__e@alice',
      'public:_apsk.my_enrollment_id.a.__e@mallory.a.__e@alice',
      'public:_apsk.my_enrollment_id.a.__e@eve:z.a.__e@alice',
      'cached:public:_apsk.my_enrollment_id.a.__e@alice',
      'public:_apsk.my_enrollment_id.a.__e@alice:x',
    ]) {
      test('a signing key not shaped like an enrollment key is refused ($uri)',
          () async {
        final h = sessionHelper();
        final verifier = RelayAuthVerifierESCR('test key shape', h);
        final response = await escrResponse(
          {'sid': relaySessionId, 'c': verifier.challenge, 'side': 'a'},
          signingKeyUri: uri,
        );

        await expectLater(
          verifier.verifyChallengeResponse(response),
          refusedWith(
            RAVEReason.signatureVerificationFailed,
            'is not of the form',
          ),
        );
        verifyNever(() => h.lookup(any(), any()));
      });
    }

    test('a public signing key URI, as clients send it, is accepted', () async {
      final h = sessionHelper();
      final verifier = RelayAuthVerifierESCR('test public uri', h);
      final uri = 'public:_apsk.${Uuid().v4()}.a.__e@alice';
      final response = await escrResponse(
        {'sid': relaySessionId, 'c': verifier.challenge, 'side': 'a'},
        signingKeyUri: uri,
      );

      expect(await verifier.verifyChallengeResponse(response), true);
      expect(verifier.atSign, '@alice');
      verify(() => h.lookup(relaySessionId, uri)).called(1);
    });

    test('a response for a session that is not active is refused', () async {
      final h = sessionHelper(active: false);
      final verifier = RelayAuthVerifierESCR('test inactive session', h);
      final response = await escrResponse(
        {'sid': relaySessionId, 'c': verifier.challenge, 'side': 'a'},
      );

      await expectLater(
        verifier.verifyChallengeResponse(response),
        refusedWith(RAVEReason.sessionNotActive, 'is not active'),
      );
      verifyNever(() => h.getRelayAuthAesKey(any()));
    });

    for (final side in ['c', null]) {
      test('a side other than "a" or "b" is refused (${side ?? 'absent'})',
          () async {
        final verifier = RelayAuthVerifierESCR('test side', sessionHelper());
        final response = await escrResponse({
          'sid': relaySessionId,
          'c': verifier.challenge,
          if (side != null) 'side': side,
        });

        await expectLater(
          verifier.verifyChallengeResponse(response),
          refusedWith(
            RAVEReason.malformedChallengeResponse,
            'must be either "a" or "b"',
          ),
        );
        expect(verifier.isSideA, isNull);
      });
    }

    for (final payload in [null, 'not a map']) {
      test('a signed payload that is not a map is refused ($payload)',
          () async {
        final verifier = RelayAuthVerifierESCR('test payload', sessionHelper());

        await expectLater(
          verifier.verifyChallengeResponse(await escrResponse(payload)),
          refusedWith(
            RAVEReason.malformedChallengeResponse,
            'does not contain signedPayload',
          ),
        );
      });
    }

    for (final (label, reshape) in [
      ('a trailing field', (String r) => '$r:extra'),
      ('no separator', (String r) => r.replaceFirst(':', '')),
    ]) {
      test('a response that is not <sid>:<payload> is refused ($label)',
          () async {
        final verifier = RelayAuthVerifierESCR('test shape', sessionHelper());
        final response = await escrResponse(
          {'sid': relaySessionId, 'c': verifier.challenge, 'side': 'a'},
        );

        await expectLater(
          verifier.verifyChallengeResponse(reshape(response)),
          refusedWith(
            RAVEReason.malformedChallengeResponse,
            'Expected <sid>:<payload>',
          ),
        );
      });
    }

    String b64(String s) => base64Encode(utf8.encode(s));
    for (final (label, authPayload64, reason, message) in [
      (
        'not base64',
        '!!!',
        RAVEReason.malformedChallengeResponse,
        'base64Decode',
      ),
      (
        'not JSON',
        b64('not json'),
        RAVEReason.jsonDecodeFailed,
        'Unable to decode',
      ),
      (
        'no iv',
        b64('{"e":"x"}'),
        RAVEReason.malformedChallengeResponse,
        'No iv',
      ),
      (
        'no e',
        b64('{"iv":"x"}'),
        RAVEReason.malformedChallengeResponse,
        'No envelopeEncrypted',
      ),
    ]) {
      test('a malformed encrypted envelope is refused ($label)', () async {
        final verifier = RelayAuthVerifierESCR('test envelope', sessionHelper());

        await expectLater(
          verifier.verifyChallengeResponse('$relaySessionId:$authPayload64'),
          refusedWith(reason, message),
        );
      });
    }
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
    late RsaKeyPair signingKP;
    late RelayAuthVerifyHelper helper;

    setUpAll(() {
      signingKP = RsaKeyPair.generate(keySize: 2048);
      publicSigningKeyUri = '_apsk.my_enrollment_id.a.__e@alice';
      relayAuthAesKey = AESKey.generate(32).key;
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
          signingAlgo: SigningAlgoType.rsa2048,
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
          signingAlgo: SigningAlgoType.rsa2048,
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
          signingAlgo: SigningAlgoType.rsa2048,
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

  group('Relay authentication signed with a post-quantum key', () {
    const uri = '_apsk.my_enrollment_id.a.__e@alice';
    final sessionId = Uuid().v4();
    final aesKey = AESKey.generate(32).key;
    final rsa = RsaKeyPair.generate();
    late MlDsa65KeyPair mlDsa;
    late MlDsa65KeyPair otherMlDsa;

    setUpAll(() async {
      mlDsa = await MlDsa65KeyPair.generate();
      otherMlDsa = await MlDsa65KeyPair.generate();
    });

    /// An `_apsk` advertisement of [keys], each active unless [retired].
    String advertising(
      Map<SigningAlgoType, List<String>> keys, {
      Set<String> retired = const {},
    }) =>
        jsonEncode(apskAdvertisement(keys: [
          for (final MapEntry(key: alg, value: pubs) in keys.entries)
            for (final pub in pubs)
              ApskSigningKey.forPublicKey(
                alg: alg,
                pub: pub,
                status: retired.contains(pub)
                    ? KeyEntryStatus.retired
                    : KeyEntryStatus.active,
              ),
        ]));

    /// [response], `<sessionId>:<payload>`, with its envelope's fields
    /// replaced by [fields].
    Future<String> rewritten(
      String response,
      Map<String, Object?> fields,
    ) async {
      final colon = response.indexOf(':');
      final outer = jsonDecode(
        utf8.decode(base64Decode(response.substring(colon + 1))),
      );
      final iv = InitialisationVector(base64Decode(outer['iv']));
      final envelope = jsonDecode(utf8.decode(base64Decode(
        await aesDecryptString(outer['e'], key: aesKey, iv: iv),
      )))
        ..addAll(fields);
      final payload = base64Encode(utf8.encode(jsonEncode({
        'iv': outer['iv'],
        'e': await aesEncryptString(
          base64Encode(utf8.encode(jsonEncode(envelope))),
          key: aesKey,
          iv: iv,
        ),
      })));
      return '${response.substring(0, colon)}:$payload';
    }

    /// Verifies a response signed with [privateKey] under [algo], naming
    /// [publicKey]'s kid, by a relay that fetches [apsk]. Any [fields] replace
    /// the response's own.
    Future<bool> verify(
      String apsk, {
      required SigningAlgoType algo,
      required String publicKey,
      required String privateKey,
      Map<String, Object?> fields = const {},
    }) async {
      final h = MockRelayAuthVerifyHelper();
      when(() => h.isSessionActive(sessionId)).thenAnswer((_) async => true);
      when(() => h.getRelayAuthAesKey(sessionId)).thenAnswer((_) async => aesKey);
      when(() => h.lookup(sessionId, uri)).thenAnswer((_) async => apsk);
      final verifier = RelayAuthVerifierESCR('post-quantum', h);
      return verifier.verifyChallengeResponse(await rewritten(
        await RelayAuthenticatorESCR(
          sessionId: sessionId,
          relayAuthAesKey: aesKey,
          publicSigningKeyUri: uri,
          publicSigningKey: publicKey,
          privateSigningKey: privateKey,
          signingAlgo: algo,
          isSideA: true,
        ).responseToChallenge(verifier.challenge),
        fields,
      ));
    }

    Matcher refused(String message) => throwsA(isA<RAVE>()
        .having((e) => e.reason, 'reason',
            RAVEReason.signatureVerificationFailed)
        .having((e) => e.message, 'message', contains(message)));

    test('an ML-DSA signature verifies against its advertised key', () async {
      expect(
        await verify(
          advertising({
            SigningAlgoType.mldsa65: [mlDsa.atPublicKey.publicKey],
          }),
          algo: SigningAlgoType.mldsa65,
          publicKey: mlDsa.atPublicKey.publicKey,
          privateKey: mlDsa.atPrivateKey.privateKey,
        ),
        true,
      );
    });

    test('an RSA signature is refused while an ML-DSA key is offered',
        () async {
      await expectLater(
        verify(
          advertising({
            SigningAlgoType.rsa2048: [rsa.atPublicKey.publicKey],
            SigningAlgoType.mldsa65: [mlDsa.atPublicKey.publicKey],
          }),
          algo: SigningAlgoType.rsa2048,
          publicKey: rsa.atPublicKey.publicKey,
          privateKey: rsa.atPrivateKey.privateKey,
        ),
        refused('advertises mldsa65'),
      );
    });

    test('an RSA signature verifies once the ML-DSA key is retired', () async {
      expect(
        await verify(
          advertising(
            {
              SigningAlgoType.rsa2048: [rsa.atPublicKey.publicKey],
              SigningAlgoType.mldsa65: [mlDsa.atPublicKey.publicKey],
            },
            retired: {mlDsa.atPublicKey.publicKey},
          ),
          algo: SigningAlgoType.rsa2048,
          publicKey: rsa.atPublicKey.publicKey,
          privateKey: rsa.atPrivateKey.privateKey,
        ),
        true,
      );
    });

    test('an ML-DSA signature is refused against a bare RSA key', () async {
      await expectLater(
        verify(
          rsa.atPublicKey.publicKey,
          algo: SigningAlgoType.mldsa65,
          publicKey: mlDsa.atPublicKey.publicKey,
          privateKey: mlDsa.atPrivateKey.privateKey,
        ),
        refused('advertises rsa2048'),
      );
    });

    test('a signature naming a key the advertisement lacks is refused',
        () async {
      await expectLater(
        verify(
          advertising({
            SigningAlgoType.mldsa65: [otherMlDsa.atPublicKey.publicKey],
          }),
          algo: SigningAlgoType.mldsa65,
          publicKey: mlDsa.atPublicKey.publicKey,
          privateKey: mlDsa.atPrivateKey.privateKey,
        ),
        refused('does not advertise'),
      );
    });

    test('a signature naming its key with something other than a string is'
        ' refused', () async {
      await expectLater(
        verify(
          rsa.atPublicKey.publicKey,
          algo: SigningAlgoType.rsa2048,
          publicKey: rsa.atPublicKey.publicKey,
          privateKey: rsa.atPrivateKey.privateKey,
          fields: {'kid': 7},
        ),
        refused('is not a string'),
      );
    });

    test('an ML-DSA response fits what the single-port relay reads from a'
        ' socket before it authenticates', () async {
      final h = MockRelayAuthVerifyHelper();
      when(() => h.isSessionActive(sessionId)).thenAnswer((_) async => true);
      when(() => h.getRelayAuthAesKey(sessionId)).thenAnswer((_) async => aesKey);
      when(() => h.lookup(sessionId, uri)).thenAnswer((_) async => advertising({
            SigningAlgoType.mldsa65: [mlDsa.atPublicKey.publicKey],
          }));
      final verifier = RelayAuthVerifierESCR('single-port', h);
      final response = await RelayAuthenticatorESCR(
        sessionId: sessionId,
        relayAuthAesKey: aesKey,
        publicSigningKeyUri: uri,
        publicSigningKey: mlDsa.atPublicKey.publicKey,
        privateSigningKey: mlDsa.atPrivateKey.privateKey,
        signingAlgo: SigningAlgoType.mldsa65,
        isSideA: true,
      ).responseToChallenge(verifier.challenge);
      final socket = MockSocket();
      when(() => socket.flush()).thenAnswer((_) async {});
      when(() => socket.listen(
            any(),
            onError: any(named: 'onError'),
            onDone: any(named: 'onDone'),
          )).thenAnswer((invocation) {
        final void Function(Uint8List) onData =
            invocation.positionalArguments[0];
        onData(Uint8List.fromList(utf8.encode('$response\n')));
        return MockStreamSubscription<Uint8List>();
      });

      final (authenticated, _) = await verifier.verifySocketAuth(socket);

      expect(response.length, greaterThan(4096),
          reason: 'larger than the limit a relay used to read');
      expect(authenticated, true);
    });

    test('a bare _apsk that is not base64 is refused', () async {
      await expectLater(
        verify(
          'not base64!',
          algo: SigningAlgoType.rsa2048,
          publicKey: rsa.atPublicKey.publicKey,
          privateKey: rsa.atPrivateKey.privateKey,
        ),
        refused('not base64'),
      );
    });

    test('an ML-DSA signature by another key is refused', () async {
      await expectLater(
        verify(
          advertising({
            SigningAlgoType.mldsa65: [mlDsa.atPublicKey.publicKey],
          }),
          algo: SigningAlgoType.mldsa65,
          publicKey: mlDsa.atPublicKey.publicKey,
          privateKey: otherMlDsa.atPrivateKey.privateKey,
        ),
        refused('Signatures did not match'),
      );
    });
  });
}
