import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:at_chops/at_chops.dart';
import 'package:at_commons/atsign.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'socket_endings.dart';

void main() {
  late RsaKeyPair encryptionKeyPair;

  group('Tests of RelayAuthenticatorLegacy and RelayAuthVerifierLegacy', () {
    setUpAll(() {
      encryptionKeyPair = RsaKeyPair.generate(keySize: 2048);
    });

    test('too much data', () async {
      String rvdSessionNonce = DateTime.now().toIso8601String();
      Map payload = {
        'sessionId': Uuid().v4().toString(),
        'rvdNonce': rvdSessionNonce,
      };

      RelayAuthVerifierLegacy sa = RelayAuthVerifierLegacy(
        encryptionKeyPair.atPublicKey.publicKey,
        'some other payload',
        rvdSessionNonce,
        'legacy_test_overflow',
        '@alice'.toAtsign(),
        payload['sessionId'],
      );

      Random r = Random();
      Uint8List data = Uint8List.fromList(
        List.generate(
          RelayAuthVerifier.maxAuthBufferLength + 1,
          (i) => r.nextInt(256),
        ),
      );

      late Function(Uint8List data) socketOnDataFn;
      MockSocket mockSocket = MockSocket();

      when(
        () => mockSocket.listen(
          any(),
          onError: any(named: "onError"),
          onDone: any(named: "onDone"),
        ),
      ).thenAnswer((Invocation invocation) {
        socketOnDataFn = invocation.positionalArguments[0];

        // A socket delivers data after listen returns, never during it
        scheduleMicrotask(() => socketOnDataFn(data));

        return MockStreamSubscription<Uint8List>();
      });

      bool somethingThrown = false;
      try {
        await sa.verifySocketAuth(mockSocket);
      } catch (e) {
        print('Caught $e as expected');
        somethingThrown = true;
      }
      expect(somethingThrown, true);
    });

    test('signature verification success', () async {
      String rvdSessionNonce = DateTime.now().toIso8601String();
      Map payload = {'sessionId': Uuid().v4(), 'rvdNonce': rvdSessionNonce};

      late Function(Uint8List data) socketOnDataFn;
      MockSocket mockSocket = MockSocket();

      String signedEnvelope = signPayload(encryptionKeyPair, payload);
      RelayAuthVerifierLegacy sa = RelayAuthVerifierLegacy(
        encryptionKeyPair.atPublicKey.publicKey,
        jsonEncode(payload), // We'll verify the signature against this
        rvdSessionNonce,
        'test_for_success',
        '@alice'.toAtsign(),
        payload['sessionId'],
      );

      List<int> list = utf8.encode('$signedEnvelope\n');
      Uint8List data = Uint8List.fromList(list);

      when(
        () => mockSocket.listen(
          any(),
          onError: any(named: "onError"),
          onDone: any(named: "onDone"),
        ),
      ).thenAnswer((Invocation invocation) {
        socketOnDataFn = invocation.positionalArguments[0];

        // A socket delivers data after listen returns, never during it
        scheduleMicrotask(() => socketOnDataFn(data));

        return MockStreamSubscription<Uint8List>();
      });

      bool authenticated;
      Stream<Uint8List>? stream;

      (authenticated, stream) = await sa.verifySocketAuth(mockSocket);
      expect(authenticated, true);
      expect(stream, isNotNull);
    });

    test('signature verification failure', () async {
      String rvdSessionNonce = DateTime.now().toIso8601String();
      Map payload = {
        'sessionId': Uuid().v4().toString(),
        'rvdNonce': rvdSessionNonce,
      };

      String signedEnvelope = signPayload(encryptionKeyPair, payload);
      RelayAuthVerifierLegacy sa = RelayAuthVerifierLegacy(
        encryptionKeyPair.atPublicKey.publicKey,
        // using a different payload; signature verification will fail
        'some other payload',
        rvdSessionNonce,
        'test_for_failure',
        '@alice'.toAtsign(),
        payload['sessionId'],
      );

      List<int> list = utf8.encode('$signedEnvelope\n');
      Uint8List data = Uint8List.fromList(list);

      late Function(Uint8List data) socketOnDataFn;
      MockSocket mockSocket = MockSocket();

      when(
        () => mockSocket.listen(
          any(),
          onError: any(named: "onError"),
          onDone: any(named: "onDone"),
        ),
      ).thenAnswer((Invocation invocation) {
        socketOnDataFn = invocation.positionalArguments[0];

        // A socket delivers data after listen returns, never during it
        scheduleMicrotask(() => socketOnDataFn(data));

        return MockStreamSubscription<Uint8List>();
      });

      bool somethingThrown = false;
      try {
        await sa.verifySocketAuth(mockSocket);
      } catch (_) {
        somethingThrown = true;
      }
      expect(somethingThrown, true);
    });

    test('signature verification ok but mismatched nonce', () async {
      final uuidString = Uuid().v4().toString();
      String rvdSessionNonce = DateTime.now().toIso8601String();
      Map payload = {'sessionId': uuidString, 'rvdNonce': rvdSessionNonce};

      String signedEnvelope = signPayload(encryptionKeyPair, payload);
      RelayAuthVerifierLegacy sa = RelayAuthVerifierLegacy(
        encryptionKeyPair.atPublicKey.publicKey,
        jsonEncode(payload),
        rvdSessionNonce,
        'test_for_mismatch',
        '@alice'.toAtsign(),
        payload['sessionId'],
      );

      Map fakedEnvelope = jsonDecode(signedEnvelope);
      fakedEnvelope['payload']['rvdNonce'] = 'not the same nonce';
      List<int> list = utf8.encode('${jsonEncode(fakedEnvelope)}\n');
      Uint8List data = Uint8List.fromList(list);

      late Function(Uint8List data) socketOnDataFn;
      MockSocket mockSocket = MockSocket();

      when(
        () => mockSocket.listen(
          any(),
          onError: any(named: "onError"),
          onDone: any(named: "onDone"),
        ),
      ).thenAnswer((Invocation invocation) {
        socketOnDataFn = invocation.positionalArguments[0];

        // A socket delivers data after listen returns, never during it
        scheduleMicrotask(() => socketOnDataFn(data));

        return MockStreamSubscription<Uint8List>();
      });

      bool somethingThrown = false;
      try {
        await sa.verifySocketAuth(mockSocket);
      } catch (_) {
        somethingThrown = true;
      }
      expect(somethingThrown, true);
    });
  });

  group('RelayAuthVerifierLegacy when its socket ends', () {
    final String rvdNonce = DateTime.now().toIso8601String();
    final Map<String, String> payload = {
      'sessionId': Uuid().v4(),
      'rvdNonce': rvdNonce,
    };
    late Socket relaySide;
    late Socket peer;

    setUpAll(() {
      encryptionKeyPair = RsaKeyPair.generate(keySize: 2048);
    });

    setUp(() async {
      (relaySide, peer) = await loopbackPair();
    });

    tearDown(() {
      relaySide.destroy();
      peer.destroy();
    });

    RelayAuthVerifierLegacy verifier() => RelayAuthVerifierLegacy(
      encryptionKeyPair.atPublicKey.publicKey,
      jsonEncode(payload),
      rvdNonce,
      'legacy socket ends',
      '@alice'.toAtsign(),
      payload['sessionId']!,
    );

    test(
      'a socket its peer closes before sending its envelope fails at once',
      () async {
        final outcome = outcomeWithin(verifier().verifySocketAuth(relaySide));
        final lines = linesFrom(peer);
        unawaited(peer.close());

        expect(
          await outcome,
          'failed: Error during socket authentication:'
          ' the socket closed before it authenticated',
        );
        expect(
          await nextLineWithin(lines),
          'done',
          reason: 'the relay closes its side',
        );
      },
    );

    test('a socket its peer resets before sending its envelope fails at once'
        ' with the error', () async {
      relaySide.write('unread by the peer, so its close is a reset');
      await relaySide.flush();
      final outcome = outcomeWithin(verifier().verifySocketAuth(relaySide));
      await pumpEventQueue();
      peer.destroy();

      expect(
        await outcome,
        allOf(
          startsWith(
            'failed: Error during socket authentication:'
            ' the socket failed before it authenticated: ',
          ),
          contains('Connection reset by peer'),
        ),
      );
    });

    test(
      'a socket that authenticates and then closes ends without an error',
      () async {
        final verification = verifier().verifySocketAuth(relaySide);
        peer.writeln(signPayload(encryptionKeyPair, payload));
        await peer.flush();
        final (authenticated, stream) = await verification.timeout(hangGuard);
        expect(authenticated, isTrue, reason: 'the control: it authenticates');

        peer.destroy();

        expect(await endingWithin(stream!), 'done');
      },
    );
  });
}

String signPayload(RsaKeyPair keyPair, Map payload) {
  final signature = RsaSignatureAlgo.rsa2048().signBytesSync(
    utf8.encode(jsonEncode(payload)),
    secretKey: base64Decode(keyPair.atPrivateKey.privateKey),
  );
  return jsonEncode({
    'payload': payload,
    'signature': base64Encode(signature),
    'hashingAlgo': HashingAlgoType.sha256.name,
    'signingAlgo': SigningAlgoType.rsa2048.name,
  });
}

class MockSocket extends Mock implements Socket {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}
