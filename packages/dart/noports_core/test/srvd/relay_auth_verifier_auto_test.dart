import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class MockRelayAuthVerifyHelper extends Mock
    implements RelayAuthVerifyHelper {}

class MockSocket extends Mock implements Socket {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

/// Builds a legacy signature envelope, exactly as the legacy connecting side
/// would send it: `{"payload":..,"signature":..,"hashingAlgo":..,"signingAlgo":..}`.
String signLegacyPayload(AtChops atChops, Map payload) {
  final Map envelope = {'payload': payload};
  final AtSigningInput signingInput = AtSigningInput(jsonEncode(payload))
    ..signingMode = AtSigningMode.data;
  final AtSigningResult sr = atChops.sign(signingInput);
  envelope['signature'] = sr.result.toString();
  envelope['hashingAlgo'] = sr.atSigningMetaData.hashingAlgoType!.name;
  envelope['signingAlgo'] = sr.atSigningMetaData.signingAlgoType!.name;
  return jsonEncode(envelope);
}

/// Wires up a [MockSocket] whose `writeln` calls are captured into [written],
/// and whose `listen` handlers are exposed via [onData], [onDone] and
/// [onError] so the test can feed inbound bytes, EOF and errors on demand.
MockSocket makeMockSocket({
  required List<String> written,
  required void Function(void Function(Uint8List) fn) onData,
  void Function(void Function() fn)? onDone,
  void Function(void Function(Object, StackTrace) fn)? onError,
  StreamSubscription<Uint8List>? subscription,
}) {
  final mockSocket = MockSocket();
  when(() => mockSocket.writeln(any())).thenAnswer((invocation) {
    final args = invocation.positionalArguments;
    written.add(args.isEmpty ? '' : (args.first ?? '').toString());
  });
  when(() => mockSocket.flush()).thenAnswer((_) async {});
  when(() => mockSocket.destroy()).thenReturn(null);
  when(
    () => mockSocket.listen(
      any(),
      onError: any(named: 'onError'),
      onDone: any(named: 'onDone'),
    ),
  ).thenAnswer((invocation) {
    onData(invocation.positionalArguments[0] as void Function(Uint8List));
    onDone?.call(invocation.namedArguments[#onDone] as void Function());
    onError?.call(
      invocation.namedArguments[#onError] as void Function(Object, StackTrace),
    );
    return subscription ?? MockStreamSubscription<Uint8List>();
  });
  return mockSocket;
}

void main() {
  group('RelayAuthVerifierAuto', () {
    late AtChops atChops;
    late String legacyPublicKey;

    setUpAll(() {
      final kp = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      atChops = AtChopsImpl(AtChopsKeys.create(kp, null));
      legacyPublicKey = kp.atPublicKey.publicKey;
    });

    test('auto-detects LEGACY from a leading "{" (pre-supplied key)', () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      final helper = MockRelayAuthVerifyHelper();
      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        helper,
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5), // must not fire in this test
        publicKey: legacyPublicKey,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList(utf8.encode('$envelope\n')));

      final (authenticated, stream) = await resultFuture;
      expect(authenticated, true);
      expect(stream, isNotNull);
      // Legacy sends nothing back to the connecting side, so the relay must
      // not have written anything (a challenge would corrupt a legacy peer).
      expect(written, isEmpty);
      // Legacy branch must not have consulted the helper for a key lookup.
      verifyNever(() => helper.lookup(any(), any()));
    });

    test('auto-detects LEGACY and looks the public key up lazily', () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      final helper = MockRelayAuthVerifyHelper();
      when(
        () => helper.lookup(sessionId, 'public:publickey@alice'),
      ).thenAnswer((_) async => legacyPublicKey);

      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        helper,
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5),
        // no publicKey -> must be looked up
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList(utf8.encode('$envelope\n')));

      final (authenticated, _) = await resultFuture;
      expect(authenticated, true);
      expect(written, isEmpty);
      verify(() => helper.lookup(sessionId, 'public:publickey@alice')).called(1);
    });

    test('auto-detects ESCR after silence, then challenges & verifies', () async {
      final sessionId = Uuid().v4();
      final relayAuthAesKey =
          AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;
      final signingKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      const publicSigningKeyUri = '_apsk.my_enrollment_id.a.__e@alice';

      final helper = MockRelayAuthVerifyHelper();
      when(
        () => helper.isSessionActive(sessionId),
      ).thenAnswer((_) async => true);
      when(
        () => helper.getRelayAuthAesKey(sessionId),
      ).thenAnswer((_) async => relayAuthAesKey);
      when(
        () => helper.lookup(sessionId, publicSigningKeyUri),
      ).thenAnswer((_) async => signingKP.atPublicKey.publicKey);

      // The connecting (client) side which will answer the relay's challenge.
      final authenticator = RelayAuthenticatorESCR(
        sessionId: sessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        isSideA: true,
      );

      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        helper,
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: 'unused for escr',
        rvdNonce: 'unused for escr',
        detectWindow: const Duration(milliseconds: 50),
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);

      // Stay silent past the detection window: the relay should conclude ESCR
      // and write the challenge.
      await Future.delayed(const Duration(milliseconds: 250));
      expect(
        written,
        hasLength(1),
        reason: 'relay should have written exactly the challenge',
      );
      final challenge = written.first;

      // Client answers the challenge; relay verifies and replies "ok".
      final response = await authenticator.responseToChallenge(challenge);
      feed(Uint8List.fromList(utf8.encode('$response\n')));

      final (authenticated, stream) = await resultFuture;
      expect(authenticated, true);
      expect(stream, isNotNull);
      expect(written, [challenge, 'ok']);
      expect(verifier.sessionId, sessionId);
      expect(verifier.atSign, '@alice');
    });

    test('rejects an unexpected first byte (neither "{" nor silence)', () async {
      final helper = MockRelayAuthVerifyHelper();
      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        helper,
        atSign: '@alice',
        sessionId: Uuid().v4(),
        dataToVerify: 'x',
        rvdNonce: 'x',
        detectWindow: const Duration(seconds: 5),
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList(utf8.encode('not json\n')));

      await expectLater(resultFuture, throwsA(anything));
      expect(written, isEmpty, reason: 'an unchallenged peer reads nothing');
      verify(() => mockSocket.destroy()).called(1);
    });

    test('a failed LEGACY envelope is refused without writing to the peer',
        () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);
      final otherKey = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048)
          .atPublicKey
          .publicKey;

      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        MockRelayAuthVerifyHelper(),
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5),
        publicKey: otherKey,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList(utf8.encode('$envelope\n')));

      await expectLater(resultFuture, throwsA(anything));
      expect(
        written,
        isEmpty,
        reason: 'a legacy peer forwards anything written to its local app',
      );
      verify(() => mockSocket.destroy()).called(1);
    });

    test('a failed ESCR response is told so before the socket is destroyed',
        () async {
      final fx = escrFixture();
      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        fx.helper,
        atSign: '@alice',
        sessionId: fx.sessionId,
        dataToVerify: 'unused for escr',
        rvdNonce: 'unused for escr',
        detectWindow: const Duration(seconds: 5),
        knownMode: RelayAuthMode.escr,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(written, hasLength(1));
      feed(Uint8List.fromList(utf8.encode('${fx.sessionId}:bogus\n')));

      await expectLater(resultFuture, throwsA(anything));
      expect(written, [written.first, 'Socket auth failed']);
      verify(() => mockSocket.destroy()).called(1);
    });

    test('known-ESCR side is challenged immediately, not after the window',
        () async {
      final fx = escrFixture();
      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        fx.helper,
        atSign: '@alice',
        sessionId: fx.sessionId,
        dataToVerify: 'unused for escr',
        rvdNonce: 'unused for escr',
        detectWindow: const Duration(seconds: 5), // must NOT be waited out
        knownMode: RelayAuthMode.escr,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      // Well under the 5s window: the challenge must already be out.
      await Future.delayed(const Duration(milliseconds: 100));
      expect(
        written,
        hasLength(1),
        reason: 'a known-ESCR side must be challenged without waiting',
      );

      final response = await fx.authenticator.responseToChallenge(written.first);
      feed(Uint8List.fromList(utf8.encode('$response\n')));

      final (authenticated, _) = await resultFuture;
      expect(authenticated, true);
      expect(written, [written.first, 'ok']);
    });

    test('known-LEGACY side is never challenged, even past the window',
        () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      final helper = MockRelayAuthVerifyHelper();
      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        helper,
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(milliseconds: 50), // short on purpose
        publicKey: legacyPublicKey,
        knownMode: RelayAuthMode.payload,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      // Wait well past the (short) window: a known-legacy side must not be
      // challenged (the timer must have been cancelled).
      await Future.delayed(const Duration(milliseconds: 200));
      expect(written, isEmpty, reason: 'known-legacy side must not be challenged');

      feed(Uint8List.fromList(utf8.encode('$envelope\n')));
      final (authenticated, _) = await resultFuture;
      expect(authenticated, true);
      expect(written, isEmpty);
    });

    test('setKnownMode(escr) resolves an in-flight detection immediately',
        () async {
      final fx = escrFixture();
      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideB',
        fx.helper,
        atSign: '@alice',
        sessionId: fx.sessionId,
        dataToVerify: 'unused for escr',
        rvdNonce: 'unused for escr',
        detectWindow: const Duration(seconds: 5),
        // no knownMode: it arrives later, as the notification would
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      // Let the detection window timer start, then deliver the hint (as the
      // client's definitive auth-modes notification would).
      await Future.delayed(const Duration(milliseconds: 50));
      expect(written, isEmpty);
      verifier.setKnownMode(RelayAuthMode.escr);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(
        written,
        hasLength(1),
        reason: 'setKnownMode(escr) should challenge without waiting the window',
      );

      final response = await fx.authenticator.responseToChallenge(written.first);
      feed(Uint8List.fromList(utf8.encode('$response\n')));
      final (authenticated, _) = await resultFuture;
      expect(authenticated, true);
    });

    test('setKnownMode is ignored once the socket has committed to legacy',
        () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      final helper = MockRelayAuthVerifyHelper();
      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideB',
        helper,
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5),
        publicKey: legacyPublicKey,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList(utf8.encode('$envelope\n'))); // commits to legacy
      final (authenticated, _) = await resultFuture;
      expect(authenticated, true);

      // A late (and here, wrong) hint must be a no-op — never challenge a socket
      // that has already spoken legacy.
      verifier.setKnownMode(RelayAuthMode.escr);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(
        written,
        isEmpty,
        reason: 'must not challenge a socket that already committed to legacy',
      );
    });

    test('memoises the mode: a later connection on the same side skips the window',
        () async {
      final fx = escrFixture();
      final verifier = RelayAuthVerifierAuto(
        'auto sideB',
        fx.helper,
        atSign: '@alice',
        sessionId: fx.sessionId,
        dataToVerify: 'unused for escr',
        rvdNonce: 'unused for escr',
        detectWindow: const Duration(milliseconds: 300),
      );

      // Connection 1: mode unknown -> auto-detect via silence -> ESCR, which
      // only challenges after the window elapses.
      final written1 = <String>[];
      late void Function(Uint8List) feed1;
      final sock1 = makeMockSocket(
        written: written1,
        onData: (fn) => feed1 = fn,
      );
      final f1 = verifier.verifySocketAuth(sock1);
      await Future.delayed(const Duration(milliseconds: 380)); // past the window
      expect(
        written1,
        hasLength(1),
        reason: 'first connection is challenged only after the window',
      );
      feed1(
        Uint8List.fromList(
          utf8.encode(
            '${await fx.authenticator.responseToChallenge(written1.first)}\n',
          ),
        ),
      );
      expect((await f1).$1, true);

      // Connection 2: SAME verifier, new socket. The mode is now memoised, so
      // the challenge must appear well before the 300ms window would elapse.
      final written2 = <String>[];
      late void Function(Uint8List) feed2;
      final sock2 = makeMockSocket(
        written: written2,
        onData: (fn) => feed2 = fn,
      );
      final f2 = verifier.verifySocketAuth(sock2);
      await Future.delayed(const Duration(milliseconds: 30)); // << 300ms window
      expect(
        written2,
        hasLength(1),
        reason: 'later connection is challenged immediately (memoised ESCR)',
      );
      feed2(
        Uint8List.fromList(
          utf8.encode(
            '${await fx.authenticator.responseToChallenge(written2.first)}\n',
          ),
        ),
      );
      expect((await f2).$1, true);
    });

    test('forwards pause and resume of the verified stream to the socket',
        () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      final socketSubscription = MockStreamSubscription<Uint8List>();
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: <String>[],
        onData: (fn) => feed = fn,
        subscription: socketSubscription,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        MockRelayAuthVerifyHelper(),
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5),
        publicKey: legacyPublicKey,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList(utf8.encode('$envelope\n')));
      final (authenticated, stream) = await resultFuture;
      expect(authenticated, true);

      final consumer = stream!.listen((_) {});
      consumer.pause();
      verify(() => socketSubscription.pause()).called(1);
      consumer.resume();
      verify(() => socketSubscription.resume()).called(1);
      await consumer.cancel();
    });

    test('LEGACY: residual bytes bundled with the envelope arrive before a '
        'later chunk, in order', () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: <String>[],
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        MockRelayAuthVerifyHelper(),
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5),
        publicKey: legacyPublicKey,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      // No `await` between the two chunks, so the second arrives while the
      // first is still authenticating, as a legacy peer's data does.
      feed(Uint8List.fromList([...utf8.encode('$envelope\n'), 1, 2, 3]));
      feed(Uint8List.fromList([4, 5, 6]));

      final (authenticated, stream) = await resultFuture;
      expect(authenticated, true);

      expect(await collect(stream!, 6), [1, 2, 3, 4, 5, 6]);
    });

    test('ESCR: residual bytes bundled with the response arrive before a '
        'later chunk, in order', () async {
      final fx = escrFixture();
      final written = <String>[];
      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: written,
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        fx.helper,
        atSign: '@alice',
        sessionId: fx.sessionId,
        dataToVerify: 'unused for escr',
        rvdNonce: 'unused for escr',
        detectWindow: const Duration(seconds: 5),
        knownMode: RelayAuthMode.escr,
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(written, hasLength(1));

      final response = await fx.authenticator.responseToChallenge(written.first);
      feed(Uint8List.fromList([...utf8.encode('$response\n'), 7, 8, 9]));
      feed(Uint8List.fromList([10, 11, 12]));

      final (authenticated, stream) = await resultFuture;
      expect(authenticated, true);

      expect(await collect(stream!, 6), [7, 8, 9, 10, 11, 12]);
    });

    test('a post-auth chunk never overtakes one still queued on the mutex',
        () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      final lookup = Completer<String>();
      final helper = MockRelayAuthVerifyHelper();
      when(
        () => helper.lookup(sessionId, 'public:publickey@alice'),
      ).thenAnswer((_) => lookup.future);

      late void Function(Uint8List) feed;
      final mockSocket = makeMockSocket(
        written: <String>[],
        onData: (fn) => feed = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideA',
        helper,
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5),
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList([...utf8.encode('$envelope\n'), 1, 2, 3]));
      feed(Uint8List.fromList([4, 5, 6]));
      lookup.complete(legacyPublicKey);
      // One chunk per microtask turn, so some arrive after authentication
      // completes but while [4, 5, 6] is still queued on the mutex.
      final trailing = List<int>.generate(20, (i) => 100 + i);
      for (final b in trailing) {
        feed(Uint8List.fromList([b]));
        await Future<void>.value();
      }

      final (authenticated, stream) = await resultFuture;
      expect(authenticated, true);
      expect(
        await collect(stream!, 26),
        [1, 2, 3, 4, 5, 6, ...trailing],
      );
    });

    test('EOF while the legacy key lookup is pending keeps the bytes before it',
        () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      final lookup = Completer<String>();
      final helper = MockRelayAuthVerifyHelper();
      when(
        () => helper.lookup(sessionId, 'public:publickey@alice'),
      ).thenAnswer((_) => lookup.future);

      late void Function(Uint8List) feed;
      late void Function() eof;
      final mockSocket = makeMockSocket(
        written: <String>[],
        onData: (fn) => feed = fn,
        onDone: (fn) => eof = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideB',
        helper,
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5),
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList([...utf8.encode('$envelope\n'), 1, 2, 3]));
      feed(Uint8List.fromList([4, 5, 6]));
      eof();
      lookup.complete(legacyPublicKey);

      final (authenticated, stream) = await resultFuture;
      expect(authenticated, true);
      expect(
        await stream!
            .expand((chunk) => chunk)
            .toList()
            .timeout(const Duration(seconds: 1)),
        [1, 2, 3, 4, 5, 6],
      );
    });

    test('a socket error while the legacy key lookup is pending follows the '
        'bytes before it', () async {
      final rvdNonce = DateTime.now().toIso8601String();
      final sessionId = Uuid().v4();
      final payload = {'sessionId': sessionId, 'rvdNonce': rvdNonce};
      final envelope = signLegacyPayload(atChops, payload);

      final lookup = Completer<String>();
      final helper = MockRelayAuthVerifyHelper();
      when(
        () => helper.lookup(sessionId, 'public:publickey@alice'),
      ).thenAnswer((_) => lookup.future);

      late void Function(Uint8List) feed;
      late void Function(Object, StackTrace) fail;
      final mockSocket = makeMockSocket(
        written: <String>[],
        onData: (fn) => feed = fn,
        onError: (fn) => fail = fn,
      );

      final verifier = RelayAuthVerifierAuto(
        'auto sideB',
        helper,
        atSign: '@alice',
        sessionId: sessionId,
        dataToVerify: jsonEncode(payload),
        rvdNonce: rvdNonce,
        detectWindow: const Duration(seconds: 5),
      );

      final resultFuture = verifier.verifySocketAuth(mockSocket);
      feed(Uint8List.fromList([...utf8.encode('$envelope\n'), 1, 2, 3]));
      feed(Uint8List.fromList([4, 5, 6]));
      fail(const SocketException('reset'), StackTrace.current);
      lookup.complete(legacyPublicKey);

      final (authenticated, stream) = await resultFuture;
      expect(authenticated, true);
      final events = <Object>[];
      final done = Completer<void>();
      stream!.listen(
        events.addAll,
        onError: (Object e) => events.add('error'),
        onDone: done.complete,
      );
      await done.future.timeout(const Duration(seconds: 1));
      expect(events, [1, 2, 3, 4, 5, 6, 'error']);
    });

    test('structural: no await between authenticated=true and the residual '
        'flush', () {
      final source = File(
        'lib/src/srvd/relay_auth_verifiers.dart',
      ).readAsStringSync();
      final autoSection = source.substring(
        source.indexOf('class RelayAuthVerifierAuto'),
      );
      final flipIdx = autoSection.indexOf('authenticated = true;');
      final flushIdx = autoSection.indexOf('if (buffer.isNotEmpty) {', flipIdx);
      expect(flipIdx, greaterThan(-1));
      expect(flushIdx, greaterThan(flipIdx));
      expect(
        autoSection.substring(flipIdx, flushIdx).contains('await'),
        isFalse,
      );
    });
  });
}

/// Sets up the helper stubs and a client-side [RelayAuthenticatorESCR] for an
/// ESCR exchange, sharing one session id / key material.
({
  RelayAuthVerifyHelper helper,
  RelayAuthenticatorESCR authenticator,
  String sessionId,
})
escrFixture() {
  final sessionId = Uuid().v4();
  final relayAuthAesKey =
      AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;
  final signingKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
  const publicSigningKeyUri = '_apsk.my_enrollment_id.a.__e@alice';

  final helper = MockRelayAuthVerifyHelper();
  when(() => helper.isSessionActive(sessionId)).thenAnswer((_) async => true);
  when(
    () => helper.getRelayAuthAesKey(sessionId),
  ).thenAnswer((_) async => relayAuthAesKey);
  when(
    () => helper.lookup(sessionId, publicSigningKeyUri),
  ).thenAnswer((_) async => signingKP.atPublicKey.publicKey);

  final authenticator = RelayAuthenticatorESCR(
    sessionId: sessionId,
    relayAuthAesKey: relayAuthAesKey,
    publicSigningKeyUri: publicSigningKeyUri,
    publicSigningKey: signingKP.atPublicKey.publicKey,
    privateSigningKey: signingKP.atPrivateKey.privateKey,
    isSideA: true,
  );

  return (helper: helper, authenticator: authenticator, sessionId: sessionId);
}

/// Collects bytes from [stream] until [count] have arrived or a second has
/// passed, so a late chunk shows up as a reorder rather than a missing tail.
Future<List<int>> collect(Stream<Uint8List> stream, int count) async {
  final received = <int>[];
  final enough = Completer<void>();
  final sub = stream.listen((data) {
    received.addAll(data);
    if (received.length >= count && !enough.isCompleted) enough.complete();
  });
  await enough.future.timeout(const Duration(seconds: 1), onTimeout: () {});
  await sub.cancel();
  return received;
}
