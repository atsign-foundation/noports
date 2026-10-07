import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart' show RelayAuthMode;
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srvd/isolates/shared_single_port_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  const aliceKey = 'public:_apsk.alice-enrollment.a.__e@alice';
  const bobKey = 'public:_apsk.bob-enrollment.a.__e@bob';
  final relayAuthAesKey = AESKey.generate(32).key;

  SrvdSessionParams params(String sessionId, {required bool only443}) =>
      SrvdSessionParams(
        sessionId: sessionId,
        atSignA: '@alice',
        atSignB: '@bob',
        authenticateSocketA: true,
        authenticateSocketB: true,
        rvdNonce: 'rvd nonce',
        relayAuthMode: RelayAuthMode.escr,
        relayAuthAesKey: relayAuthAesKey,
        only443: only443,
        multipleAcksOk: true,
        preFetch: const [],
        sendJsonResponse: true,
      );

  /// The messages [port] receives within 300 ms.
  Future<List<Object?>> received(ReceivePort port) async {
    final messages = <Object?>[];
    final subscription = port.listen(messages.add);
    await Future.delayed(const Duration(milliseconds: 300));
    await subscription.cancel();
    return messages;
  }

  /// A relay on [atClient] that re-checks signing keys every [interval].
  SrvdImpl newRelay(
    MockAtClient atClient, {
    Duration interval = Duration.zero,
    bool bind443 = false,
    int localBindPort443 = 0,
  }) =>
      SrvdImpl(
        atClient: atClient,
        atSign: '@relay'.toAtsign(),
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        logTraffic: false,
        verbose: false,
        bind443: bind443,
        localBindPort443: localBindPort443,
        relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        signingKeyCheckInterval: interval,
      );

  group('SrvdImpl signing-key check', () {
    late MockAtClient atClient;
    late SrvdImpl relay;

    setUp(() {
      registerFallbackValue(AtKey());
      registerFallbackValue(GetRequestOptions());
      atClient = MockAtClient();
      when(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer((_) async => throw AtKeyNotFoundException('key not found'));
      relay = newRelay(atClient);
    });

    /// Answers a lookup of [key] with [answer].
    void lookupOf(String key, Future<AtValue> Function() answer) => when(
          () => atClient.get(
            any(that: predicate<AtKey>((k) => k.toString() == key)),
            getRequestOptions: any(named: 'getRequestOptions'),
          ),
        ).thenAnswer((_) => answer());

    Future<AtValue> published() async => AtValue()..value = 'a public key';

    /// Withdraws [key] as an atServer does, moving its record from `a.__e` to
    /// [to].
    void withdraw(String key, {String to = 'r.__e'}) =>
        lookupOf(key.replaceFirst('.a.__e@', '.$to@'), published);

    /// A two-port session signed with [keys], whose worker listens on the
    /// returned port.
    ReceivePort twoPortSession(String sessionId, Set<String> keys) {
      final worker = ReceivePort();
      addTearDown(worker.close);
      relay.sessions[sessionId] = SessionInfo(
        params: params(sessionId, only443: false),
        connector: null,
        toWorker: worker.sendPort,
      )..signingKeys.addAll(keys);
      return worker;
    }

    test('stops the worker of a two-port session whose signing key was'
        ' revoked', () async {
      final worker = twoPortSession('s', {aliceKey});
      withdraw(aliceKey);

      final messages = received(worker);
      await relay.checkSigningKeys();

      expect(
        (await messages).map((m) => (m as IIRequest).type),
        ['stop'],
      );
    });

    test('asks the port 443 worker to end a single-port session whose signing'
        ' key was deleted', () async {
      final isolate443 = ReceivePort();
      addTearDown(isolate443.close);
      relay.toIsolate443 = isolate443.sendPort;
      relay.sessions['s'] = SessionInfo(
        params: params('s', only443: true),
        connector: null,
      )..signingKeys.add(aliceKey);
      withdraw(aliceKey, to: 'd.__e');

      final messages = received(isolate443);
      await relay.checkSigningKeys();

      expect(
        [for (final m in await messages) ((m as IIRequest).type, m.payload)],
        [('endSession', 's')],
      );
    });

    test('ends only the sessions the withdrawn key signed', () async {
      final signedByAlice = twoPortSession('alice', {aliceKey, bobKey});
      final signedByBobOnly = twoPortSession('bob', {bobKey});
      withdraw(aliceKey);
      lookupOf(bobKey, published);

      final aliceMessages = received(signedByAlice);
      final bobMessages = received(signedByBobOnly);
      await relay.checkSigningKeys();

      expect(await aliceMessages, hasLength(1));
      expect(await bobMessages, isEmpty);
    });

    test('keeps a session whose signing key is missing but was not withdrawn',
        () async {
      final worker = twoPortSession('s', {aliceKey});

      final messages = received(worker);
      await relay.checkSigningKeys();

      expect(await messages, isEmpty);
    });

    test('keeps a session when its signing key lookup fails another way',
        () async {
      final worker = twoPortSession('s', {aliceKey});
      lookupOf(
        aliceKey,
        () async => throw SecondaryConnectException(
          'Unable to connect to secondary @alice',
        ),
      );

      final messages = received(worker);
      await relay.checkSigningKeys();

      expect(await messages, isEmpty);
    });

    test('keeps a session when its signing key is missing and the lookup of'
        ' where it went fails', () async {
      final worker = twoPortSession('s', {aliceKey});
      lookupOf(
        aliceKey.replaceFirst('.a.__e@', '.r.__e@'),
        () async => throw SecondaryConnectException(
          'Unable to connect to secondary @alice',
        ),
      );

      final messages = received(worker);
      await relay.checkSigningKeys();

      expect(await messages, isEmpty);
    });

    test('looks each signing key up once, however many sessions it signed',
        () async {
      twoPortSession('one', {aliceKey});
      twoPortSession('two', {aliceKey});
      lookupOf(aliceKey, published);

      await relay.checkSigningKeys();

      verify(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).called(1);
    });

    test('ends a session once, however many passes find its key withdrawn',
        () async {
      final worker = twoPortSession('s', {aliceKey});
      withdraw(aliceKey);

      final messages = received(worker);
      await relay.checkSigningKeys();
      await relay.checkSigningKeys();

      expect(await messages, hasLength(1));
      verify(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).called(2);
    });

    test('skips a pass that starts while one is still running', () async {
      twoPortSession('s', {aliceKey});
      final lookedUp = Completer<AtValue>();
      lookupOf(aliceKey, () => lookedUp.future);

      final first = relay.checkSigningKeys();
      final overlapping = relay.checkSigningKeys();
      lookedUp.complete(await published());
      await Future.wait([first, overlapping]);

      verify(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).called(1);
    });

    test('records one key for every spelling of a signing key', () async {
      twoPortSession('s', {});

      for (final spelling in [
        '_apsk.Alice-Enrollment.a.__e@Alice',
        'public:_apsk.alice-enrollment.a.__e@alice',
        'PUBLIC:_apsk.ALICE-ENROLLMENT.a.__e@ALICE',
      ]) {
        relay.recordSigningKey('s', spelling);
      }

      expect(relay.sessions['s']!.signingKeys, {aliceKey});
    });

    test('records at most ${SrvdImpl.maxSigningKeysPerSession} signing keys'
        ' for a session', () async {
      twoPortSession('s', {});

      for (var i = 0; i < SrvdImpl.maxSigningKeysPerSession + 2; i++) {
        relay.recordSigningKey('s', 'public:_apsk.enrollment-$i.a.__e@alice');
      }

      expect(
        relay.sessions['s']!.signingKeys,
        hasLength(SrvdImpl.maxSigningKeysPerSession),
      );
    });

    test('checks every interval once running, and stops when stopped',
        () async {
      final notificationService = MockNotificationService();
      when(() => atClient.notificationService).thenReturn(notificationService);
      when(
        () => notificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer((_) => const Stream.empty());
      var lookups = 0;
      lookupOf(aliceKey, () {
        lookups++;
        return published();
      });
      final running = newRelay(
        atClient,
        interval: const Duration(milliseconds: 50),
      );
      running.sessions['s'] = SessionInfo(
        params: params('s', only443: false),
        connector: null,
      )..signingKeys.add(aliceKey);
      Future<int> lookupsDuring(Duration period) async {
        final before = lookups;
        await Future.delayed(period);
        return lookups - before;
      }

      expect(await lookupsDuring(const Duration(milliseconds: 300)), 0,
          reason: 'nothing checks before run()');
      await running.init();
      await running.run();
      expect(await lookupsDuring(const Duration(milliseconds: 300)),
          greaterThanOrEqualTo(2));
      await running.stop();
      running.sessions['s'] = SessionInfo(
        params: params('s', only443: false),
        connector: null,
      )..signingKeys.add(aliceKey);
      expect(await lookupsDuring(const Duration(milliseconds: 300)), 0,
          reason: 'stop() ends the check');
    });

    test('records the signing key a port 443 socket was accepted with',
        () async {
      final signingKP = RsaKeyPair.generate();
      lookupOf(aliceKey, () async {
        return AtValue()..value = signingKP.atPublicKey.publicKey;
      });
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final relay443 = newRelay(atClient, bind443: true, localBindPort443: port);
      addTearDown(relay443.stop);
      await relay443.init();
      relay443.sessions['s'] = SessionInfo(
        params: params('s', only443: true),
        connector: null,
      );
      relay443.toIsolate443!
          .send(IIRequest.create('start', params('s', only443: true)));

      Socket? socket;
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (socket == null) {
        try {
          socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
        } on SocketException {
          if (DateTime.now().isAfter(deadline)) rethrow;
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
      addTearDown(socket.destroy);
      final (authenticated, _) = await RelayAuthenticatorESCR(
        sessionId: 's',
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: aliceKey,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        signingAlgo: SigningAlgoType.rsa2048,
        isSideA: true,
      ).authenticate(socket);
      expect(authenticated, isTrue);

      final recorded = DateTime.now().add(const Duration(seconds: 5));
      while (relay443.sessions['s']!.signingKeys.isEmpty &&
          DateTime.now().isBefore(recorded)) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      expect(relay443.sessions['s']!.signingKeys, {aliceKey});
    });
  });

  group('SrvdParams', () {
    Future<SrvdParams> parse(List<String> extra) =>
        SrvdParams.fromArgs(['-a', '@relay', '-i', '127.0.0.1', ...extra]);

    test('re-checks signing keys every 5 minutes by default', () async {
      expect((await parse([])).signingKeyCheckSecs, 300);
      expect(defaultSigningKeyCheckInterval, const Duration(minutes: 5));
    });

    test('takes --signing-key-check-secs, with 0 turning the check off',
        () async {
      expect(
        (await parse(['--signing-key-check-secs', '0'])).signingKeyCheckSecs,
        0,
      );
    });

    test('refuses a negative --signing-key-check-secs', () async {
      await expectLater(
        parse(['--signing-key-check-secs', '-1']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('srvd is built with the interval it was given', () async {
      final keys = File('${Directory.systemTemp.createTempSync().path}/k')
        ..createSync();
      addTearDown(() => keys.parent.deleteSync(recursive: true));

      final srvd = await SrvdImpl.fromCommandLineArgs([
        '-a', '@relay', '-i', '127.0.0.1', '-k', keys.path,
        '--signing-key-check-secs', '7',
      ], atClient: MockAtClient()) as SrvdImpl;

      expect(srvd.signingKeyCheckInterval, const Duration(seconds: 7));
    });
  });

  group('SinglePortWorker', () {
    final signingKP = RsaKeyPair.generate();

    /// A worker whose main isolate is this test: it answers every lookup with
    /// [signingKP]'s public key, and passes on every other request.
    Future<
        ({
          SinglePortWorker worker,
          SendPort toWorker,
          Stream<IIRequest> requests,
        })> startWorker({int bindPort = 0}) async {
      final main = ReceivePort();
      addTearDown(main.close);
      final toWorker = Completer<SendPort>();
      final requests = StreamController<IIRequest>.broadcast();
      main.listen((message) {
        if (message is SendPort) {
          toWorker.complete(message);
        } else if (message is IIRequest && message.type == 'lookup') {
          toWorker.future.then((port) => port.send(IIResponse(
                id: message.id,
                isError: false,
                payload: signingKP.atPublicKey.publicKey,
              )));
        } else if (message is IIRequest) {
          requests.add(message);
        }
      });
      final worker = SinglePortWorker(
        toMain: main.sendPort,
        logTraffic: false,
        verbose: false,
        loggingTag: 'test',
        address: '127.0.0.1',
        useTLS: false,
        bindPort: bindPort,
      );
      addTearDown(() => worker.stop());
      return (
        worker: worker,
        toWorker: await toWorker.future,
        requests: requests.stream,
      );
    }

    test('ends the session main tells it to end, and only that one', () async {
      final (:worker, :toWorker, :requests) = await startWorker();
      await worker.startSession(
        IIRequest.create('start', params('ended', only443: true)),
      );
      await worker.startSession(
        IIRequest.create('start', params('kept', only443: true)),
      );
      final completed = requests
          .firstWhere((r) => r.type == 'sessionComplete')
          .timeout(const Duration(seconds: 5));

      toWorker.send(IIRequest.create('endSession', 'ended'));

      expect((await completed).payload['sessionId'], 'ended');
      expect(worker.sessions.keys, ['kept']);
    });

    test('reports the signing key of each ESCR socket it accepts', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final (:worker, :toWorker, :requests) =
          await startWorker(bindPort: port);
      unawaited(worker.run());
      await worker.startSession(
        IIRequest.create('start', params('s', only443: true)),
      );
      final reported = requests
          .firstWhere((r) => r.type == 'signingKey')
          .timeout(const Duration(seconds: 10));

      Socket? socket;
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (socket == null) {
        try {
          socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
        } on SocketException {
          if (DateTime.now().isAfter(deadline)) rethrow;
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
      addTearDown(socket.destroy);
      final (authenticated, _) = await RelayAuthenticatorESCR(
        sessionId: 's',
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: aliceKey,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        signingAlgo: SigningAlgoType.rsa2048,
        isSideA: true,
      ).authenticate(socket);

      expect(authenticated, isTrue);
      expect(
        (await reported).payload,
        {'sessionId': 's', 'key': aliceKey},
      );
    });
  });
}
