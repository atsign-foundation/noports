import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/session_crypto.dart'
    show generateAes256Key;
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srvd/isolates/port_pair_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../sshnp/sshnp_mocks.dart';

const String relayAtSign = '@relay';
const String clientAtSign = '@alice';
const String daemonAtSign = '@bob';
const String clientNonce = 'client nonce';

class FakeNotificationParams extends Fake implements NotificationParams {}

String apskUri(String atSign) => '_apsk.relay_test.a.__e$atSign';

/// An srvd whose sessions each run in a [PortPairWorker] in this isolate, on
/// real sockets on localhost, and whose port 443 isolate is a port the test
/// reads.
class ScenarioSrvd extends SrvdImpl {
  ScenarioSrvd({
    required super.atClient,
    required this.authTimeout,
    required this.records,
    super.bind443 = false,
  }) : super(
         atSign: relayAtSign.toAtsign(),
         homeDirectory: Directory.current.path,
         atKeysFilePath: Directory.current.path,
         managerAtsign: 'open',
         ipAddress: '127.0.0.1',
         logTraffic: false,
         verbose: false,
         localBindPort443: 0,
         signingKeyCheckInterval: Duration.zero,
       );

  final Duration authTimeout;

  /// What a worker's lookups find, by key.
  final Map<String, String> records;

  final List<PortPairWorker> workers = [];
  final List<ReceivePort> _ports = [];
  final ReceivePort port443 = ReceivePort();
  final List<IIRequest> sentTo443 = [];

  int allocations = 0;

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async {
    allocations++;
    final toMain = ReceivePort();
    _ports.add(toMain);
    late final PortPairWorker worker;
    toMain.listen((m) {
      if (m is IIRequest && m.type == 'lookup') {
        final String? value = records[m.payload['key']];
        worker.fromMain.sendPort.send(
          IIResponse(
            id: m.id,
            isError: value == null,
            payload: value ?? 'no record ${m.payload['key']}',
          ),
        );
      }
    });
    worker = PortPairWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'deterministic relay auth',
      authTimeout: authTimeout,
    );
    workers.add(worker);
    await worker.startSession(IIRequest.create('start', sessionParams));
    return (
      (worker.portA!, worker.portB!),
      Isolate.current,
      worker.fromMain.sendPort,
    );
  }

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewSinglePortIsolate(
    String address,
    bool useTLS,
    int bindPort,
  ) async {
    port443.listen((m) {
      if (m is IIRequest) sentTo443.add(m);
    });
    return ((443, 443), Isolate.current, port443.sendPort);
  }

  void close() {
    for (final worker in workers) {
      worker.connector?.close();
      worker.fromMain.close();
    }
    for (final port in _ports) {
      port.close();
    }
    port443.close();
  }
}

/// A socket to one of a session's relay ports, recording what the relay
/// sends it and when the relay closes it.
class Peer {
  Peer._(this.socket) {
    socket.listen(
      received.addAll,
      onDone: _close,
      onError: (_) => _close(),
      cancelOnError: true,
    );
  }

  static Future<Peer> connect(int port) async =>
      Peer._(await Socket.connect(InternetAddress.loopbackIPv4, port));

  final Socket socket;
  final List<int> received = [];
  final Completer<void> closed = Completer<void>();
  int _read = 0;

  void _close() {
    if (!closed.isCompleted) closed.complete();
  }

  String get text => utf8.decode(received, allowMalformed: true);

  void send(String line) => socket.write('$line\n');

  /// The next line the relay sends, within [within].
  Future<String> line({Duration within = const Duration(seconds: 5)}) async {
    await until(
      () => received.indexOf(10, _read) != -1 || closed.isCompleted,
      within: within,
      what: 'a line from the relay',
    );
    final int newline = received.indexOf(10, _read);
    if (newline == -1) fail('the relay closed the socket before a line');
    final String l = utf8.decode(received.sublist(_read, newline));
    _read = newline + 1;
    return l;
  }

  /// Whether the relay closes this socket within [within].
  Future<bool> closedWithin(Duration within) =>
      closed.future.then((_) => true).timeout(within, onTimeout: () => false);
}

Future<void> until(
  bool Function() condition, {
  Duration within = const Duration(seconds: 5),
  required String what,
}) async {
  final DateTime giveUp = DateTime.now().add(within);
  while (!condition()) {
    if (DateTime.now().isAfter(giveUp)) {
      fail('timed out waiting for $what ($within)');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// A session srvd has served, with what its client and daemon sign with.
class Session {
  Session(this.id, this.relayAuthAesKey, this.response, this.worker);

  final String id;
  final String? relayAuthAesKey;
  final Map<String, dynamic> response;
  final PortPairWorker worker;

  String get rvdNonce => response['rvdNonce'];

  RelayAuthVerifierAuto get verifierB => worker.authVerifierB!;
}

/// Catalogue: features/srvd/deterministic_relay_auth.feature
void main() {
  late final Map<String, RsaKeyPair> legacyKeys;
  late final Map<String, RsaKeyPair> signingKeys;
  late ScenarioSrvd srvd;
  late List<NotificationParams> sent;
  final peers = <Peer>[];

  setUpAll(() {
    registerFallbackValue(FakeNotificationParams());
    registerFallbackValue(AtKey());
    legacyKeys = {
      for (final a in [clientAtSign, daemonAtSign])
        a: RsaKeyPair.generate(keySize: 2048),
    };
    signingKeys = {
      for (final a in [clientAtSign, daemonAtSign])
        a: RsaKeyPair.generate(keySize: 2048),
    };
  });

  Future<void> startRelay({
    Duration authTimeout = SocketConnector.defaultTimeout,
    bool bind443 = false,
  }) async {
    sent = [];
    final atClient = MockAtClient();
    final notificationService = MockNotificationService();
    when(() => atClient.notificationService).thenReturn(notificationService);
    when(
      () => notificationService.notify(
        any(),
        checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
        waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        onSentToSecondary: any(named: 'onSentToSecondary'),
      ),
    ).thenAnswer((i) async {
      sent.add(i.positionalArguments.first as NotificationParams);
      return NotificationResult()
        ..notificationStatusEnum = NotificationStatusEnum.delivered;
    });
    when(
      () => atClient.get(
        any(),
        getRequestOptions: any(named: 'getRequestOptions'),
      ),
    ).thenAnswer((i) async {
      final key = i.positionalArguments.first as AtKey;
      return AtValue()..value = legacyKeys[key.sharedBy]!.atPublicKey.publicKey;
    });
    srvd = ScenarioSrvd(
      atClient: atClient,
      authTimeout: authTimeout,
      bind443: bind443,
      records: {
        for (final a in [clientAtSign, daemonAtSign]) ...{
          apskUri(a): signingKeys[a]!.atPublicKey.publicKey,
          'public:publickey$a': legacyKeys[a]!.atPublicKey.publicKey,
        },
      },
    );
    await srvd.init();
  }

  tearDown(() {
    for (final p in peers) {
      p.socket.destroy();
    }
    peers.clear();
    srvd.close();
  });

  /// The fields of a request from @alice for a session with @bob, both sides
  /// authenticating; [relayAuthModes] is sent as given when not null.
  Map<String, Object?> fields({
    required String id,
    required RelayAuthMode relayAuthMode,
    String? relayAuthAesKey,
    Object? relayAuthModes,
    bool only443 = false,
    bool multipleAcksOk = true,
  }) => {
    'sessionId': id,
    'atSignA': clientAtSign,
    'atSignB': daemonAtSign,
    'clientNonce': clientNonce,
    'authenticateSocketA': true,
    'authenticateSocketB': true,
    'relayAuthMode': relayAuthMode.name,
    'relayAuthAesKey': ?relayAuthAesKey,
    'relayAuthModes': ?relayAuthModes,
    'only443': only443,
    'multipleAcksOk': multipleAcksOk,
    'sendJsonResponse': true,
  };

  Future<void> send(Map<String, Object?> request) async {
    await srvd.handleRequestPorts(
      AtNotification(
        'notif-id',
        '$relayAtSign:gateway-1.request_ports.sshrvd$clientAtSign',
        clientAtSign,
        relayAtSign,
        DateTime.now().millisecondsSinceEpoch,
        'key',
        true,
        value: jsonEncode(request),
      ),
    );
    await pumpEventQueue();
  }

  NotificationParams? responseTo(String id) =>
      sent.where((n) => n.atKey.key == id).firstOrNull;

  NotificationParams? nackFor(String id) =>
      sent.where((n) => n.atKey.key == 'nack.$id').firstOrNull;

  /// Sends a request with these [fields] and returns the session srvd
  /// served for it.
  Future<Session> request({
    required RelayAuthMode relayAuthMode,
    bool withKey = false,
    Map<String, String>? relayAuthModes,
  }) async {
    final String id = Uuid().v4();
    final String? key = withKey ? generateAes256Key() : null;
    await send(
      fields(
        id: id,
        relayAuthMode: relayAuthMode,
        relayAuthAesKey: key,
        relayAuthModes: relayAuthModes,
      ),
    );
    final NotificationParams? response = responseTo(id);
    expect(
      response,
      isNotNull,
      reason: 'srvd answers the request (nack: ${nackFor(id)?.value})',
    );
    return Session(id, key, jsonDecode(response!.value!), srvd.workers.last);
  }

  Future<Peer> connect(Session s, {required bool sideA}) async {
    final Peer p = await Peer.connect(
      sideA ? s.response['portA'] : s.response['portB'],
    );
    peers.add(p);
    return p;
  }

  String envelope(Session s, {required bool sideA}) {
    final payload = {
      'sessionId': s.id,
      'clientNonce': clientNonce,
      'rvdNonce': s.rvdNonce,
    };
    final RsaKeyPair kp = legacyKeys[sideA ? clientAtSign : daemonAtSign]!;
    final signature = RsaSignatureAlgo.rsa2048().signBytesSync(
      utf8.encode(jsonEncode(payload)),
      secretKey: base64Decode(kp.atPrivateKey.privateKey),
    );
    return jsonEncode({
      'payload': payload,
      'signature': base64Encode(signature),
      'hashingAlgo': HashingAlgoType.sha256.name,
      'signingAlgo': SigningAlgoType.rsa2048.name,
    });
  }

  RelayAuthenticatorESCR escr(Session s, {required bool sideA}) {
    final String atSign = sideA ? clientAtSign : daemonAtSign;
    return RelayAuthenticatorESCR(
      sessionId: s.id,
      relayAuthAesKey: s.relayAuthAesKey!,
      publicSigningKeyUri: apskUri(atSign),
      publicSigningKey: signingKeys[atSign]!.atPublicKey.publicKey,
      privateSigningKey: signingKeys[atSign]!.atPrivateKey.privateKey,
      signingAlgo: SigningAlgoType.rsa2048,
      isSideA: sideA,
    );
  }

  /// Answers the challenge [p] has been sent, and expects the relay's ok.
  Future<void> answerChallenge(Session s, Peer p, {required bool sideA}) async {
    final String challenge = await p.line();
    p.send(await escr(s, sideA: sideA).responseToChallenge(challenge));
    expect(await p.line(), 'ok', reason: 'the relay accepts the response');
  }

  /// Authenticates [p] by [mode] as its side does.
  Future<void> authenticate(
    Session s,
    Peer p, {
    required bool sideA,
    required RelayAuthMode mode,
  }) async {
    if (mode == RelayAuthMode.escr) {
      await answerChallenge(s, p, sideA: sideA);
    } else {
      p.send(envelope(s, sideA: sideA));
    }
  }

  /// Expects data to pass from [client] to [daemon] and back, which the relay
  /// does only once it has verified both.
  Future<void> expectRelayed(Peer client, Peer daemon) async {
    for (final (from, to) in [(client, daemon), (daemon, client)]) {
      final String marker = 'relayed ${Uuid().v4()}';
      from.socket.write(marker);
      await until(
        () => to.text.contains(marker),
        what: 'data relayed between the verified sockets',
      );
    }
  }

  Future<void> authModes({
    required Session session,
    String from = clientAtSign,
    String? rvdNonce,
    String? sessionId,
    String? sideA = 'escr',
    String? sideB,
  }) => srvd.handleAuthModes(
    AtNotification(
      'auth-modes-id',
      '$relayAtSign:gateway-1.auth_modes.sshrvd$from',
      from,
      relayAtSign,
      DateTime.now().millisecondsSinceEpoch,
      'key',
      true,
      value: jsonEncode({
        'sessionId': sessionId ?? session.id,
        'rvdNonce': rvdNonce ?? session.rvdNonce,
        'sideA': ?sideA,
        'sideB': ?sideB,
      }),
    ),
  );

  /// Gives an auth_modes notification that reached the worker time to land.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  RelayAuthMode modeNamed(String name) =>
      name == 'ESCR' ? RelayAuthMode.escr : RelayAuthMode.payload;

  String wireName(String name) => modeNamed(name).name;

  group('A request that names both sides\' modes is applied as given', () {
    for (final (String sideA, String sideB) in [
      ('ESCR', 'ESCR'),
      ('ESCR', 'legacy'),
      ('legacy', 'legacy'),
      ('legacy', 'ESCR'),
    ]) {
      test('$sideA | $sideB', () async {
        await startRelay();
        // NOTE: relayAuthMode alone would give at least one side another
        // mode, so a relay ignoring relayAuthModes fails each row.
        final s = await request(
          relayAuthMode: sideB == 'legacy'
              ? RelayAuthMode.escr
              : RelayAuthMode.payload,
          withKey: true,
          relayAuthModes: {'sideA': wireName(sideA), 'sideB': wireName(sideB)},
        );
        final client = await connect(s, sideA: true);
        final daemon = await connect(s, sideA: false);

        await Future.wait([
          authenticate(s, client, sideA: true, mode: modeNamed(sideA)),
          authenticate(s, daemon, sideA: false, mode: modeNamed(sideB)),
        ]);
        await expectRelayed(client, daemon);

        for (final (Peer p, String mode) in [
          (client, sideA),
          (daemon, sideB),
        ]) {
          if (mode == 'legacy') {
            expect(
              p.text,
              startsWith('relayed '),
              reason: 'a legacy socket is sent nothing but the relayed data',
            );
          } else {
            expect(
              p.text.split('\n')[1],
              'ok',
              reason: 'an ESCR socket is challenged and told ok',
            );
          }
        }
      });
    }
  });

  test('The relay says when it applied relayAuthModes', () async {
    await startRelay();
    final s = await request(
      relayAuthMode: RelayAuthMode.payload,
      withKey: true,
      relayAuthModes: {'sideA': 'escr', 'sideB': 'escr'},
    );

    expect(
      s.response['appliedRelayAuthModes'],
      true,
      reason: 'the response says relayAuthModes was applied',
    );
    expect(
      s.response['autoDetectsRelayAuth'],
      true,
      reason: 'released clients send auth_modes only when this is true',
    );
  });

  test(
    'A request without relayAuthModes gets no appliedRelayAuthModes',
    () async {
      await startRelay();
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
      );

      expect(
        s.response.containsKey('appliedRelayAuthModes'),
        isFalse,
        reason: 'a request with no relayAuthModes has none applied',
      );
      expect(
        s.response['autoDetectsRelayAuth'],
        true,
        reason: 'released clients send auth_modes only when this is true',
      );
    },
  );

  group('A request with an invalid relayAuthModes is refused before any port is'
      ' allocated', () {
    for (final (String row, Object modes, bool withKey, String why) in [
      ('not a map', 'escr', true, 'relayAuthModes must be a map'),
      (
        'missing sideB',
        {'sideA': 'escr'},
        true,
        'relayAuthModes must name a mode for sideB',
      ),
      (
        'naming a mode that does not exist for side A',
        {'sideA': 'rsa', 'sideB': 'escr'},
        true,
        'relayAuthModes must name a relay auth mode for sideA',
      ),
      (
        'naming ESCR for a side, with no relayAuthAesKey',
        {'sideA': 'payload', 'sideB': 'escr'},
        false,
        'relayAuthAesKey is required when a side authenticates by ESCR',
      ),
    ]) {
      test(row, () async {
        await startRelay();
        for (final bool multipleAcksOk in [true, false]) {
          final String id = Uuid().v4();
          await send(
            fields(
              id: id,
              relayAuthMode: RelayAuthMode.payload,
              relayAuthAesKey: withKey ? generateAes256Key() : null,
              relayAuthModes: modes,
              multipleAcksOk: multipleAcksOk,
            ),
          );

          expect(srvd.allocations, 0, reason: 'no ports are allocated');
          expect(srvd.sessions.containsKey(id), isFalse);
          expect(responseTo(id), isNull, reason: 'no ports are sent');
          if (multipleAcksOk) {
            expect(
              nackFor(id)?.value,
              contains(why),
              reason: 'a request that accepts a NACK is sent one saying why',
            );
            expect(nackFor(id)?.atKey.sharedWith, clientAtSign);
          } else {
            expect(
              nackFor(id),
              isNull,
              reason: 'a request that accepts no NACK is sent none',
            );
          }
        }

        await request(
          relayAuthMode: RelayAuthMode.payload,
          withKey: true,
          relayAuthModes: {'sideA': 'escr', 'sideB': 'payload'},
        );
        expect(
          srvd.allocations,
          1,
          reason: 'the control: a valid relayAuthModes is allocated ports',
        );
      });
    }
  });

  test('A request for ESCR by relayAuthMode with no relayAuthAesKey is refused'
      ' before any port is allocated', () async {
    await startRelay();
    final String id = Uuid().v4();
    await send(fields(id: id, relayAuthMode: RelayAuthMode.escr));

    expect(srvd.allocations, 0, reason: 'no ports are allocated');
    expect(
      nackFor(id)?.value,
      contains('relayAuthAesKey is required when a side authenticates'),
      reason: 'the NACK says why',
    );

    await request(relayAuthMode: RelayAuthMode.escr, withKey: true);
    expect(srvd.allocations, 1, reason: 'the control: with a key it is served');
  });

  test('A request whose relayAuthModes names ESCR for side A only, with no'
      ' relayAuthAesKey, is refused before any port is allocated', () async {
    await startRelay();
    final String id = Uuid().v4();
    await send(
      fields(
        id: id,
        relayAuthMode: RelayAuthMode.payload,
        relayAuthModes: {'sideA': 'escr', 'sideB': 'payload'},
      ),
    );

    expect(srvd.allocations, 0, reason: 'no ports are allocated');
    expect(
      nackFor(id)?.value,
      contains('relayAuthAesKey is required when a side authenticates'),
      reason: 'the NACK says why',
    );

    await request(
      relayAuthMode: RelayAuthMode.payload,
      withKey: true,
      relayAuthModes: {'sideA': 'escr', 'sideB': 'payload'},
    );
    expect(srvd.allocations, 1, reason: 'the control: with a key it is served');
  });

  group('A request without relayAuthModes is applied to both sides', () {
    for (final (String relayAuthMode, String key, String mode) in [
      ('payload', 'no relayAuthAesKey', 'legacy'),
      ('escr', 'a relayAuthAesKey', 'ESCR'),
    ]) {
      test('$relayAuthMode | $key | $mode', () async {
        await startRelay();
        final s = await request(
          relayAuthMode: RelayAuthMode.values.byName(relayAuthMode),
          withKey: key == 'a relayAuthAesKey',
        );
        final client = await connect(s, sideA: true);
        final daemon = await connect(s, sideA: false);

        await Future.wait([
          authenticate(s, client, sideA: true, mode: modeNamed(mode)),
          authenticate(s, daemon, sideA: false, mode: modeNamed(mode)),
        ]);
        await expectRelayed(client, daemon);

        for (final p in [client, daemon]) {
          if (mode == 'legacy') {
            expect(
              p.text,
              startsWith('relayed '),
              reason: 'a legacy socket is sent nothing but the relayed data',
            );
          } else {
            expect(p.text.split('\n')[1], 'ok');
          }
        }
      });
    }
  });

  test('A request for payload without a key accepts slow legacy envelopes on'
      ' both sides', () async {
    await startRelay();
    final s = await request(relayAuthMode: RelayAuthMode.payload);
    final client = await connect(s, sideA: true);
    final daemon = await connect(s, sideA: false);

    await Future<void>.delayed(const Duration(seconds: 5));
    expect(
      client.received,
      isEmpty,
      reason: "the client's socket is sent nothing before its envelope",
    );
    expect(
      daemon.received,
      isEmpty,
      reason: "the daemon's socket is sent nothing before its envelope",
    );
    client.send(envelope(s, sideA: true));
    daemon.send(envelope(s, sideA: false));

    await expectRelayed(client, daemon);
    expect(client.text, startsWith('relayed '));
    expect(daemon.text, startsWith('relayed '));
  });

  test('A request for ESCR whose daemon sends a legacy envelope has that socket'
      ' refused', () async {
    await startRelay();
    final s = await request(relayAuthMode: RelayAuthMode.escr, withKey: true);
    final daemon = await connect(s, sideA: false);
    daemon.send(envelope(s, sideA: false));

    expect(
      await daemon.closedWithin(const Duration(seconds: 5)),
      isTrue,
      reason: 'the relay closes the socket',
    );
    expect(daemon.text, endsWith('Socket auth failed\n'));
  });

  test("A request for payload with a key has its client's socket challenged at"
      ' once', () async {
    await startRelay();
    final s = await request(
      relayAuthMode: RelayAuthMode.payload,
      withKey: true,
    );
    final stopwatch = Stopwatch()..start();
    final client = await connect(s, sideA: true);

    final String challenge = await client.line(
      within: const Duration(milliseconds: 400),
    );
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(milliseconds: 400)),
      reason:
          'no auth_modes notification was sent and nothing was waited'
          ' for',
    );
    expect(base64Decode(challenge), hasLength(32));
  });

  test(
    'A legacy envelope on a client socket the request makes ESCR is refused',
    () async {
      await startRelay();
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
      );
      final client = await connect(s, sideA: true);
      client.send(envelope(s, sideA: true));

      expect(
        await client.closedWithin(const Duration(seconds: 5)),
        isTrue,
        reason: 'the relay closes the socket',
      );
      expect(client.text, endsWith('Socket auth failed\n'));
    },
  );

  test(
    "The daemon's silent socket is challenged only once the client says ESCR",
    () async {
      await startRelay();
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
      );
      final daemon = await connect(s, sideA: false);
      await until(
        () => s.verifierB.waitingSockets == 1,
        what: 'the daemon socket waiting',
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(
        daemon.received,
        isEmpty,
        reason: 'the socket is sent nothing before the client says',
      );

      await authModes(session: s, sideB: 'escr');

      await answerChallenge(s, daemon, sideA: false);
    },
  );

  test(
    'A legacy daemon whose envelope is slow is still verified as legacy',
    () async {
      await startRelay();
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
      );
      await authModes(session: s, sideB: 'payload');
      await until(
        () => s.verifierB.knownMode == RelayAuthMode.payload,
        what: "the client's word reaching side B",
      );
      final client = await connect(s, sideA: true);
      await answerChallenge(s, client, sideA: true);
      final daemon = await connect(s, sideA: false);

      await Future<void>.delayed(const Duration(seconds: 5));
      expect(
        daemon.received,
        isEmpty,
        reason: 'the daemon socket is sent nothing before its envelope',
      );
      daemon.send(envelope(s, sideA: false));

      await expectRelayed(client, daemon);
      expect(daemon.text, startsWith('relayed '));
    },
  );

  test(
    "A daemon's envelope that arrives before the client's word is verified as"
    ' legacy',
    () async {
      await startRelay();
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
      );
      final client = await connect(s, sideA: true);
      await answerChallenge(s, client, sideA: true);
      final daemon = await connect(s, sideA: false);
      daemon.send(envelope(s, sideA: false));

      await expectRelayed(client, daemon);
      expect(
        s.verifierB.knownMode,
        isNull,
        reason: 'no auth_modes notification has arrived',
      );
      expect(daemon.text, startsWith('relayed '));
    },
  );

  test(
    "The client's word does not re-mode a socket that has already committed",
    () async {
      await startRelay();
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
      );
      final client = await connect(s, sideA: true);
      await answerChallenge(s, client, sideA: true);
      final daemon = await connect(s, sideA: false);
      daemon.send(envelope(s, sideA: false));
      await expectRelayed(client, daemon);
      final int before = daemon.received.length;

      await authModes(session: s, sideB: 'escr');
      await until(
        () => s.verifierB.knownMode == RelayAuthMode.escr,
        what: "the client's word reaching side B",
      );
      await settle();

      expect(
        daemon.received.length,
        before,
        reason: 'the committed socket is sent no challenge',
      );
      await expectRelayed(client, daemon);
    },
  );

  test('A daemon socket that has begun a legacy envelope keeps legacy when the'
      ' client then says ESCR', () async {
    await startRelay();
    final s = await request(
      relayAuthMode: RelayAuthMode.payload,
      withKey: true,
    );
    final client = await connect(s, sideA: true);
    await answerChallenge(s, client, sideA: true);
    final daemon = await connect(s, sideA: false);
    await until(
      () => s.verifierB.waitingSockets == 1,
      what: 'the daemon socket waiting',
    );
    final String signed = envelope(s, sideA: false);
    final int half = signed.length ~/ 2;
    daemon.socket.write(signed.substring(0, half));
    await settle();

    await authModes(session: s, sideB: 'escr');
    await until(
      () => s.verifierB.knownMode == RelayAuthMode.escr,
      what: "the client's word reaching side B",
    );
    await settle();
    expect(
      daemon.received,
      isEmpty,
      reason: 'a socket that has begun its envelope is sent no challenge',
    );

    daemon.send(signed.substring(half));
    await expectRelayed(client, daemon);
    expect(
      daemon.text,
      startsWith('relayed '),
      reason: 'the socket is verified as legacy',
    );
  });

  test('A daemon socket whose first byte is neither silence nor an envelope is'
      ' refused', () async {
    await startRelay();
    final s = await request(
      relayAuthMode: RelayAuthMode.payload,
      withKey: true,
    );
    final daemon = await connect(s, sideA: false);
    // NOTE: no newline, so only the first byte can get it refused.
    daemon.socket.write('x');

    expect(
      await daemon.closedWithin(const Duration(seconds: 5)),
      isTrue,
      reason: 'the relay closes the socket',
    );
    expect(
      daemon.received,
      isEmpty,
      reason: 'an unchallenged socket is sent nothing, a refusal included',
    );
  });

  test(
    'A daemon socket the client never speaks for is never challenged',
    () async {
      const limit = Duration(seconds: 2);
      await startRelay(authTimeout: limit);
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
      );
      final stopwatch = Stopwatch()..start();
      final daemon = await connect(s, sideA: false);

      expect(
        await daemon.closedWithin(limit * 3),
        isTrue,
        reason: 'the relay closes it at the authentication limit',
      );
      stopwatch.stop();
      expect(
        stopwatch.elapsed,
        greaterThan(limit * 0.75),
        reason: 'it is held until the limit',
      );
      expect(daemon.received, isEmpty, reason: 'it is sent nothing');
      await until(
        () => s.verifierB.waitingSockets == 0,
        what: 'the closed socket to stop waiting',
      );
    },
  );

  test("The client's word reaches every socket waiting on that side", () async {
    await startRelay();
    final s = await request(
      relayAuthMode: RelayAuthMode.payload,
      withKey: true,
    );
    final first = await connect(s, sideA: false);
    final second = await connect(s, sideA: false);
    await until(
      () => s.verifierB.waitingSockets == 2,
      what: 'both daemon-port sockets waiting',
    );

    await authModes(session: s, sideB: 'escr');

    final [String c1, String c2] = await Future.wait([
      first.line(),
      second.line(),
    ]);
    expect(c1, isNot(c2), reason: 'each is sent its own challenge');
  });

  test(
    "A socket that connects after the client's word gets its mode at once",
    () async {
      await startRelay();
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
      );
      await authModes(session: s, sideB: 'escr');
      await until(
        () => s.verifierB.knownMode == RelayAuthMode.escr,
        what: "the client's word reaching side B",
      );
      final stopwatch = Stopwatch()..start();
      final daemon = await connect(s, sideA: false);

      await daemon.line(within: const Duration(milliseconds: 400));
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 400)));
      expect(s.verifierB.waitingSockets, 0, reason: 'it never waits');
    },
  );

  test(
    'An auth_modes notification does not change a mode the request set',
    () async {
      await startRelay();
      final s = await request(
        relayAuthMode: RelayAuthMode.payload,
        withKey: true,
        relayAuthModes: {'sideA': 'escr', 'sideB': 'escr'},
      );
      await authModes(session: s, sideB: 'payload');
      await settle();
      final daemon = await connect(s, sideA: false);

      await answerChallenge(s, daemon, sideA: false);
    },
  );

  test('A legacy envelope on a side named ESCR is refused', () async {
    await startRelay();
    final s = await request(
      relayAuthMode: RelayAuthMode.payload,
      withKey: true,
      relayAuthModes: {'sideA': 'payload', 'sideB': 'escr'},
    );
    final daemon = await connect(s, sideA: false);
    daemon.send(envelope(s, sideA: false));

    expect(
      await daemon.closedWithin(const Duration(seconds: 5)),
      isTrue,
      reason: 'the relay closes the socket',
    );
    expect(daemon.text, endsWith('Socket auth failed\n'));
  });

  group("An auth_modes notification the relay cannot tie to the requester's"
      ' session is ignored', () {
    for (final (String row, String? from, bool otherNonce, bool otherId) in [
      ('from an Atsign other than the requester', '@carol', false, false),
      ("with an rvdNonce that is not this relay's", null, true, false),
      ('for a session id this relay does not know', null, false, true),
    ]) {
      test(row, () async {
        await startRelay();
        final s = await request(
          relayAuthMode: RelayAuthMode.payload,
          withKey: true,
        );
        final daemon = await connect(s, sideA: false);
        await until(
          () => s.verifierB.waitingSockets == 1,
          what: 'the daemon socket waiting',
        );

        await authModes(
          session: s,
          from: from ?? clientAtSign,
          rvdNonce: otherNonce ? 'another relay instance' : null,
          sessionId: otherId ? Uuid().v4() : null,
          sideB: 'escr',
        );
        // NOTE: the worker takes its messages in order, so once this one
        // has given side B legacy, any ESCR forwarded before it has landed.
        await authModes(session: s, sideB: 'payload');
        await until(
          () => s.verifierB.knownMode == RelayAuthMode.payload,
          what: "the requester's own word reaching side B",
        );
        await settle();

        expect(
          daemon.received,
          isEmpty,
          reason: 'the daemon socket is sent nothing',
        );
        daemon.send(envelope(s, sideA: false));
        final client = await connect(s, sideA: true);
        await answerChallenge(s, client, sideA: true);
        await expectRelayed(client, daemon);
      });
    }
  });

  test('Each ESCR socket of a session gets its own challenge', () async {
    await startRelay();
    final s = await request(
      relayAuthMode: RelayAuthMode.payload,
      withKey: true,
      relayAuthModes: {'sideA': 'escr', 'sideB': 'payload'},
    );
    final first = await connect(s, sideA: true);
    final second = await connect(s, sideA: true);

    final [String c1, String c2] = await Future.wait([
      first.line(),
      second.line(),
    ]);
    expect(c1, isNot(c2), reason: 'each socket is sent its own challenge');
  });

  Future<String> request443(Map<String, String> relayAuthModes) async {
    final String id = Uuid().v4();
    await send(
      fields(
        id: id,
        relayAuthMode: RelayAuthMode.payload,
        relayAuthAesKey: generateAes256Key(),
        relayAuthModes: relayAuthModes,
        only443: true,
      ),
    );
    return id;
  }

  bool startSent(String id) =>
      srvd.sentTo443.any((m) => m.type == 'start' && m.payload.sessionId == id);

  test('A 443 request that names ESCR for both sides is accepted', () async {
    await startRelay(bind443: true);
    // NOTE: relayAuthMode payload, which the 443 path refuses, so only the
    // applied relayAuthModes lets this through.
    final String id = await request443({'sideA': 'escr', 'sideB': 'escr'});

    expect(nackFor(id)?.value, isNull, reason: 'the request is not refused');
    expect(
      jsonDecode(responseTo(id)!.value!)['portA'],
      443,
      reason: 'the client is sent port 443',
    );
    expect(
      srvd.sessions.containsKey(id),
      isTrue,
      reason: 'the session is recorded',
    );
    await until(() => startSent(id), what: 'the session started on 443');
  });

  test('A 443 request that names legacy for a side is refused', () async {
    await startRelay(bind443: true);
    final String id = await request443({'sideA': 'escr', 'sideB': 'payload'});

    expect(
      nackFor(id)?.value,
      contains('relayAuthModes may not name "payload" on port 443'),
      reason: 'the NACK says why',
    );
    expect(responseTo(id), isNull, reason: 'the client is sent no ports');
    expect(
      srvd.sessions.containsKey(id),
      isFalse,
      reason: 'no session is recorded',
    );
    await pumpEventQueue();
    expect(startSent(id), isFalse, reason: 'no session starts on 443');
  });

  test('A 443 request that names legacy for side A is refused', () async {
    await startRelay(bind443: true);
    final String id = await request443({'sideA': 'payload', 'sideB': 'escr'});

    expect(
      nackFor(id)?.value,
      contains('relayAuthModes may not name "payload" on port 443'),
      reason: 'the NACK says why',
    );
    expect(responseTo(id), isNull, reason: 'the client is sent no ports');
    expect(
      srvd.sessions.containsKey(id),
      isFalse,
      reason: 'no session is recorded',
    );
  });
}
