/// Catalogue: features/srvd/signing_key_check.feature. Each test named for a
/// scenario there proves it.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:fake_async/fake_async.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/public_lookup.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';
import 'package:noports_core/src/srvd/telemetry/opted_in_list.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry_names.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';
import 'telemetry/telemetry_fakes.dart';

typedef N = RelayTelemetryNames;

const aliceKey = 'public:_apsk.alice-enrollment.a.__e@alice';
const bobKey = 'public:_apsk.bob-enrollment.a.__e@bob';

String revoked(String key) => key.replaceFirst('.a.__e@', '.r.__e@');

/// What the atServers hold, and the two lookups a relay reaches them
/// through.
class _AtServers {
  _AtServers(this.now);

  /// The time, for a lookup to note when it was asked.
  final Duration Function() now;
  final Set<String> _held = {};

  /// The lookup of the 3-second re-checks.
  late final _Lookup fast = _Lookup(this);

  /// The lookup of everything else, the 300-second re-checks among it.
  late final _Lookup slow = _Lookup(this);

  void publish(String key) => _held.add(key);

  /// Withdraws [key] as an atServer does on a revoke, moving its record from
  /// `a.__e` to `r.__e`.
  void revoke(String key) => _held
    ..remove(key)
    ..add(revoked(key));

  void reinstate(String key) => _held
    ..remove(revoked(key))
    ..add(key);

  /// Loses [key] without withdrawing it.
  void lose(String key) => _held.remove(key);
}

/// One lookup's way to the [_AtServers]: each answers with what it held when
/// asked, after its Atsign's delay. A lookup of a silent one fails after
/// [deadline], as a lookup with a deadline does.
class _Lookup extends PublicLookup {
  _Lookup(this._atServers);

  static const deadline = Duration(seconds: 2);

  final _AtServers _atServers;

  /// How long each Atsign's atServer takes to answer; at once when absent.
  final Map<String, Duration> delays = {};

  /// The Atsigns whose atServers never answer.
  final Set<String> silent = {};

  /// The records whose lookup fails at once.
  final Set<String> failing = {};

  /// Every record looked up and when, in order.
  final List<(String, Duration)> asked = [];

  void Function(String uri, Duration took)? onAnswered;

  int closes = 0;

  @override
  void close() => closes++;

  int lookupsOf(String key) => timesOf(key).length;

  List<Duration> timesOf(String key) => [
    for (final (uri, at) in asked)
      if (uri == key) at,
  ];

  @override
  Future<String?> lookup(String uri) => lookupDirect(uri);

  @override
  Future<String?> lookupDirect(String uri) {
    asked.add((uri, _atServers.now()));
    final String atsign = uri.substring(uri.lastIndexOf('@'));
    if (failing.contains(uri)) {
      return Future.error(const SocketException('Connection refused'));
    }
    if (silent.contains(atsign)) {
      return Future.delayed(
        deadline,
        () => throw TimeoutException('No answer from $atsign', deadline),
      );
    }
    final String? answer = _atServers._held.contains(uri) ? 'a key' : null;
    final Duration takes = delays[atsign] ?? Duration.zero;
    return Future.delayed(takes, () {
      onAnswered?.call(uri, takes);
      return answer;
    });
  }
}

/// A relay under fake time with the atServers its lookups reach.
class _Rig {
  _Rig(this.relay, this.atServers, this.exporter, this.list);

  final SrvdImpl relay;
  final _AtServers atServers;
  final RecordingExporter exporter;
  final ScriptedListSource list;

  _Lookup get fast => atServers.fast;

  _Lookup get slow => atServers.slow;
}

/// Finds every Atsign in [ports] on loopback.
class _LoopbackFinder implements SecondaryAddressFinder {
  _LoopbackFinder(this.ports);

  final Map<String, int> ports;

  @override
  Future<SecondaryAddress> findSecondary(String atSign, {Duration? timeout}) =>
      Future.value(SecondaryAddress('127.0.0.1', ports[atSign]!));
}

/// Keeps the message of every log record it is given.
class _Capture implements LoggingHandler {
  _Capture(this.messages);

  final List<String> messages;

  @override
  void call(LogRecord record) => messages.add(record.message);
}

const s3 = Duration(seconds: 3);

List<Duration> seconds(List<int> s) => [
  for (final n in s) Duration(seconds: n),
];

void main() {
  late MockAtClient atClient;
  late List<String> logged;
  late LoggingHandler previousHandler;

  setUpAll(() {
    registerFallbackValue(AtKey());
    registerFallbackValue('@fallback'.toAtsign());
  });

  setUp(() {
    atClient = MockAtClient();
    final notificationService = MockNotificationService();
    when(() => atClient.notificationService).thenReturn(notificationService);
    when(() => atClient.getCurrentAtSign()).thenReturn('@relay');
    when(() => atClient.enrollmentId).thenReturn(null);
    when(
      () => notificationService.subscribe(
        regex: any(named: 'regex'),
        shouldDecrypt: any(named: 'shouldDecrypt'),
      ),
    ).thenAnswer((_) => StreamController<AtNotification>.broadcast().stream);
    logged = [];
    previousHandler = AtSignLogger.defaultLoggingHandler;
    AtSignLogger.defaultLoggingHandler = _Capture(logged);
  });

  tearDown(() => AtSignLogger.defaultLoggingHandler = previousHandler);

  Iterable<String> said(String what) => logged.where((m) => m.contains(what));

  RelayTelemetry telemetryOver(
    RecordingExporter exporter,
    ScriptedListSource list,
  ) => RelayTelemetry(
    exporter: exporter,
    serviceVersion: 'srvd 9.9.9 (core 9.9.9)',
    heartbeatInterval: const Duration(days: 1),
    list: OptedInListPoller(
      source: list,
      interval: const Duration(seconds: 60),
      onWarning: (_) {},
    ),
  );

  SrvdImpl relayWith({
    required PublicLookup publicLookup,
    PublicLookup? reportedKeyLookup,
    RelayTelemetry? telemetry,
    Duration every = defaultSigningKeyCheckInterval,
    Duration reportedEvery = defaultReportedSigningKeyCheckInterval,
    Duration deadline = SrvdImpl.defaultReportedSigningKeyCheckDeadline,
    Duration prompt = SrvdImpl.defaultReportedSigningKeyPromptAnswer,
  }) => SrvdImpl(
    atClient: atClient,
    atSign: '@relay'.toAtsign(),
    homeDirectory: Directory.current.path,
    atKeysFilePath: Directory.current.path,
    managerAtsign: 'open',
    ipAddress: '127.0.0.1',
    logTraffic: false,
    verbose: false,
    bind443: false,
    localBindPort443: 0,
    relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
    signingKeyCheckInterval: every,
    reportedSigningKeyCheckInterval: reportedEvery,
    reportedSigningKeyCheckDeadline: deadline,
    reportedSigningKeyPromptAnswer: prompt,
    publicLookup: publicLookup,
    reportedKeyLookup: reportedKeyLookup,
    telemetry: telemetry,
  );

  /// A relay under [async]'s time, running, which sends telemetry for the
  /// Atsigns [optedIn] unless [collector] is false. Its 3-second re-checks
  /// go through the atServers' `fast` lookup, which tells it how long each
  /// answer took, and everything else through `slow`, unless [oneLookup].
  _Rig running(
    FakeAsync async, {
    Iterable<String> optedIn = const [],
    bool collector = true,
    bool oneLookup = false,
    Duration every = defaultSigningKeyCheckInterval,
    Duration reportedEvery = defaultReportedSigningKeyCheckInterval,
  }) {
    final atServers = _AtServers(() => async.elapsed);
    final exporter = RecordingExporter();
    final list = ScriptedListSource(listOf(optedIn));
    final relay = relayWith(
      publicLookup: atServers.slow,
      reportedKeyLookup: oneLookup ? null : atServers.fast,
      telemetry: collector ? telemetryOver(exporter, list) : null,
      every: every,
      reportedEvery: reportedEvery,
    );
    atServers.fast.onAnswered = relay.reportedKeyAnswered;
    relay.init();
    async.flushMicrotasks();
    relay.run();
    async.flushMicrotasks();
    for (final String atsign in optedIn) {
      expect(
        relay.telemetry!.list.listed(atsign),
        isTrue,
        reason: '$atsign is on the list the relay read',
      );
    }
    return _Rig(relay, atServers, exporter, list);
  }

  Map<String, dynamic> firstPair(String sessionId) => {
    ...opened(1),
    'sessionId': sessionId,
    'stats': Stats(),
  };

  /// A live session of [rig]'s relay whose sockets were accepted with
  /// [keys], all published, and whose first pair its worker has reported
  /// unless [paired] is false.
  SessionInfo session(
    FakeAsync async,
    _Rig rig,
    String sessionId, {
    String client = '@alice',
    String device = '@bob',
    Set<String> keys = const {aliceKey, bobKey},
    SendPort? toWorker,
    bool paired = true,
  }) {
    keys.forEach(rig.atServers.publish);
    final si = SessionInfo(
      params: sessionParams(
        sessionId: sessionId,
        client: client,
        device: device,
      ),
      connector: null,
      toWorker: toWorker,
    )..signingKeys.addAll(keys);
    rig.relay.sessions[sessionId] = si;
    if (paired) {
      rig.relay.handleWorkerReport(
        IIRequest.create('newConnection', firstPair(sessionId)),
      );
      async.flushMicrotasks();
    }
    return si;
  }

  /// Lets time pass, 10 ms at a time, until [si] is being ended or [atMost]
  /// has passed; how long that took, or null when it was not ended.
  Duration? endedWithin(FakeAsync async, SessionInfo si, Duration atMost) {
    final Duration from = async.elapsed;
    while (!si.ending && async.elapsed - from < atMost) {
      async.elapse(const Duration(milliseconds: 10));
    }
    return si.ending ? async.elapsed - from : null;
  }

  void stop(FakeAsync async, SrvdImpl relay) {
    relay.stop();
    async.elapse(Srvd.stopBound);
  }

  for (final (side, key, atsign) in [
    ('device-side', bobKey, '@bob'),
    ('client-side', aliceKey, '@alice'),
  ]) {
    test('A reported session ends within 10 seconds of its $side enrollment'
        ' being revoked', () async {
      final worker = ReceivePort();
      addTearDown(worker.close);
      final received = <Object?>[];
      worker.listen(received.add);

      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        final si = session(async, rig, 's', toWorker: worker.sendPort);
        expect(
          rig.relay.telemetry!.reporting('s'),
          isTrue,
          reason: 'the session is reported',
        );
        rig.fast.delays[atsign] = const Duration(milliseconds: 990);
        async.elapse(const Duration(milliseconds: 3010));
        rig.atServers.revoke(key);

        final Duration? took = endedWithin(
          async,
          si,
          const Duration(seconds: 11),
        );

        expect(took, isNotNull, reason: 'the relay ends the session');
        expect(took, lessThanOrEqualTo(const Duration(seconds: 10)));
        expect(
          took,
          greaterThan(const Duration(seconds: 4)),
          reason:
              'the longest path for an atServer that answers promptly:'
              ' the revoke lands just after a re-check began, then 3 s to'
              ' the next and two answers of nearly a second',
        );
        expect(
          rig.slow.asked,
          isEmpty,
          reason:
              'every lookup of the re-check, the two that find the key'
              ' withdrawn among them, went through the lookup kept for it',
        );

        rig.relay.handleWorkerReport(
          IIRequest.create('sessionComplete', {
            'sessionId': 's',
            'at': nowMs(),
            'stats': Stats(),
            'connections': 1,
            'bytesClientToDevice': 0,
            'bytesDeviceToClient': 0,
            'connectionsUnclosed': 1,
          }),
        );
        async.elapse(const Duration(seconds: 1));
        expect(
          rig.exporter.named(N.sessionEnded).single.attributes[N.endReason],
          'signingKeyWithdrawn',
        );
        stop(async, rig.relay);
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        [for (final m in received) (m as IIRequest).type],
        ['end'],
        reason:
            "the session's worker, which holds both sockets, is told"
            ' once to end it at once',
      );
    });
  }

  test('A reported session whose atServer does not answer in time carries'
      ' on', () {
    fakeAsync((async) {
      final rig = running(async, optedIn: ['@alice']);
      final si = session(async, rig, 's', keys: {bobKey});
      rig.fast.silent.add('@bob');
      Iterable<String> couldNot() =>
          said('Could not re-check signing key $bobKey');

      async.elapse(const Duration(milliseconds: 4900));
      expect(
        rig.fast.lookupsOf(bobKey),
        1,
        reason: 'the re-check at 3 s is waiting',
      );
      expect(couldNot(), isEmpty, reason: 'its 2 seconds are not up');
      async.elapse(const Duration(milliseconds: 200));

      expect(si.ending, isFalse);
      expect(
        couldNot(),
        hasLength(1),
        reason: "at srvd's default level, which is all this logger passes",
      );
      async.elapse(const Duration(seconds: 1));
      expect(
        rig.fast.lookupsOf(bobKey),
        2,
        reason: 'the re-check at 6 s looks the key up again',
      );
      stop(async, rig.relay);
    });
  });

  test(
    'A re-check still waiting when the next is due is not started twice',
    () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', keys: {bobKey});
        rig.atServers.lose(bobKey);
        rig.fast.delays['@bob'] = const Duration(milliseconds: 1900);

        async.elapse(const Duration(milliseconds: 6500));

        expect(
          rig.fast.lookupsOf(bobKey),
          1,
          reason:
              'missing but not withdrawn, so the re-check begun at 3 s is'
              ' still making its second lookups at 6 s',
        );
        async.elapse(s3);
        expect(
          rig.fast.lookupsOf(bobKey),
          2,
          reason: 'once it has finished, the re-check at 9 s starts',
        );
        stop(async, rig.relay);
      });
    },
  );

  test(
    'A key revoked and reinstated between two re-checks keeps its session',
    () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        final si = session(async, rig, 's');

        async.elapse(const Duration(milliseconds: 3500));
        rig.atServers.revoke(bobKey);
        async.elapse(const Duration(seconds: 2));
        rig.atServers.reinstate(bobKey);
        async.elapse(const Duration(milliseconds: 24500));

        expect(si.ending, isFalse);
        expect(
          rig.fast.lookupsOf(bobKey),
          10,
          reason: 'it was re-checked every 3 seconds for 30',
        );
        stop(async, rig.relay);
      });
    },
  );

  test('A slow atServer delays only the re-checks of its own keys', () {
    fakeAsync((async) {
      final atsigns = [for (var i = 0; i < 100; i++) '@c$i'];
      String keyOf(int i) => 'public:_apsk.enrollment-$i.a.__e@c$i';
      final rig = running(async, optedIn: atsigns);
      final sessions = [
        for (var i = 0; i < 100; i++)
          session(
            async,
            rig,
            's$i',
            client: atsigns[i],
            device: '@device',
            keys: {keyOf(i)},
          ),
      ];
      rig.fast.delays['@c0'] = const Duration(seconds: 2);

      async.elapse(const Duration(milliseconds: 5500));
      rig.atServers.revoke(keyOf(57));
      final Duration? took = endedWithin(
        async,
        sessions[57],
        const Duration(seconds: 11),
      );

      expect(took, lessThanOrEqualTo(const Duration(seconds: 10)));
      expect(
        took,
        lessThanOrEqualTo(const Duration(seconds: 1)),
        reason:
            'its own atServer answers at once, so the re-check at 6 s'
            ' ends it without waiting for the slow one',
      );
      expect(
        rig.fast.lookupsOf(keyOf(0)),
        greaterThan(0),
        reason: 'the slow atServer was being asked',
      );
      expect(
        [for (final si in sessions) si.ending].where((e) => e),
        hasLength(1),
      );
      stop(async, rig.relay);
    });
  });

  test('A key that keeps failing its re-check is re-checked less often', () {
    fakeAsync((async) {
      final rig = running(async, optedIn: ['@alice']);
      session(async, rig, 's', keys: {bobKey});
      rig.fast.silent.add('@bob');

      async.elapse(const Duration(seconds: 340));

      expect(
        rig.fast.timesOf(bobKey),
        seconds([3, 6, 12, 24, 48, 96, 156, 216, 276, 336]),
        reason: '3, 6, 12, 24 and 48 seconds apart, then once a minute',
      );
      expect(
        rig.slow.timesOf(bobKey),
        seconds([300]),
        reason: "and at 300 seconds like any other session's",
      );
      stop(async, rig.relay);
    });
  });

  test('A key whose atServer answers promptly again goes back to every 3'
      ' seconds', () {
    fakeAsync((async) {
      final rig = running(async, optedIn: ['@alice']);
      session(async, rig, 's', keys: {bobKey});
      rig.fast.silent.add('@bob');
      async.elapse(const Duration(seconds: 100));
      expect(
        rig.fast.timesOf(bobKey).last,
        const Duration(seconds: 96),
        reason: 'the key is re-checked once a minute by now',
      );

      rig.fast.silent.clear();
      async.elapse(const Duration(seconds: 63));

      expect(
        rig.fast
            .timesOf(bobKey)
            .where((at) => at > const Duration(seconds: 100)),
        seconds([156, 159, 162]),
      );
      stop(async, rig.relay);
    });
  });

  // NOTE: real time and real HTTP, at a fifth of the scenario's times, so
  // that the lookups srvd builds for itself carry the re-checks
  test("Many slow atServers do not hold up another key's re-check", () async {
    const int fifth = 5;
    final ports = <String, int>{};
    final servers = <HttpServer>[];
    final asked = <String, int>{};
    var fastKeyRevoked = false;
    Future<void> serve(String atsign, Duration takes) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servers.add(server);
      ports[atsign] = server.port;
      server.listen((request) async {
        asked[atsign] = (asked[atsign] ?? 0) + 1;
        await Future<void>.delayed(takes);
        final bool approved = request.uri.path.contains('.a.__e');
        final bool held = atsign == '@fast' && fastKeyRevoked
            ? request.uri.path.contains('.r.__e')
            : approved;
        request.response
          ..statusCode = held ? HttpStatus.ok : HttpStatus.notFound
          ..write(held ? 'a key' : '');
        await request.response.close();
      });
    }

    const fastKey = 'public:_apsk.fast-enrollment.a.__e@fast';
    await serve('@fast', Duration.zero);
    for (var i = 0; i < 80; i++) {
      await serve('@slow$i', const Duration(milliseconds: 1800 ~/ fifth));
    }
    final telemetry = telemetryOver(
      RecordingExporter(),
      ScriptedListSource(listOf(['@alice'])),
    );
    final relay = relayWith(
      publicLookup: DirectPublicLookup(
        atClient,
        addressFinder: _LoopbackFinder(ports),
        scheme: 'http',
      ),
      telemetry: telemetry,
      reportedEvery: const Duration(milliseconds: 3000 ~/ fifth),
      deadline: const Duration(milliseconds: 2000 ~/ fifth),
      prompt: const Duration(milliseconds: 1000 ~/ fifth),
    );
    addTearDown(() async {
      await relay.stop();
      for (final server in servers) {
        await server.close(force: true);
      }
    });
    await relay.init();
    await relay.run();
    await telemetry.list.firstGoodRead.timeout(const Duration(seconds: 2));
    SessionInfo live(String id, String device, String key) {
      final si = SessionInfo(
        params: sessionParams(sessionId: id, device: device),
        connector: null,
      )..signingKeys.add(key);
      relay.sessions[id] = si;
      relay.handleWorkerReport(
        IIRequest.create('newConnection', firstPair(id)),
      );
      return si;
    }

    for (var i = 0; i < 80; i++) {
      live('slow$i', '@slow$i', 'public:_apsk.enrollment-$i.a.__e@slow$i');
    }
    final si = live('fast', '@fast', fastKey);
    expect(relay.telemetry!.reporting('fast'), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 3000));
    final int slowAskedBefore = asked['@slow0'] ?? 0;
    fastKeyRevoked = true;
    final Stopwatch took = Stopwatch()..start();
    while (!si.ending && took.elapsed < const Duration(seconds: 4)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(si.ending, isTrue);
    expect(
      took.elapsed,
      lessThan(const Duration(seconds: 10) ~/ fifth),
      reason: "the scenario's 10 seconds, at a fifth",
    );
    expect(
      slowAskedBefore,
      inInclusiveRange(1, 3),
      reason:
          'in its first 3 seconds a slow atServer was asked at 0.6,'
          ' 1.2 and 2.4 s, where every 0.6 s would be 5 times',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  /// Revokes the device-side enrollment of [si] 10 seconds in, and expects
  /// the relay to look no key up before its 300-second re-check, which
  /// ends the session.
  void endsAtThe300SecondRecheck(FakeAsync async, _Rig rig, SessionInfo si) {
    async.elapse(const Duration(seconds: 10));
    rig.atServers.revoke(bobKey);
    async.elapse(const Duration(seconds: 289));
    expect(
      [rig.fast.asked, rig.slow.asked],
      [isEmpty, isEmpty],
      reason: 'nothing is re-checked in the first 299 seconds',
    );
    expect(si.ending, isFalse);
    async.elapse(const Duration(seconds: 2));
    expect(si.ending, isTrue);
    expect(rig.fast.asked, isEmpty);
  }

  test('A session that is not reported is re-checked every 300 seconds', () {
    fakeAsync((async) {
      final rig = running(async, optedIn: ['@zara']);
      final si = session(async, rig, 's');
      expect(
        rig.relay.telemetry!.reporting('s'),
        isFalse,
        reason: 'the session is not reported',
      );

      endsAtThe300SecondRecheck(async, rig, si);
      stop(async, rig.relay);
    });
  });

  test('A relay that sends no telemetry re-checks every session every 300'
      ' seconds', () async {
    final Directory dir = await Directory.systemTemp.createTemp('srvd-keys');
    addTearDown(() => dir.delete(recursive: true));
    final File keys = File('${dir.path}/k')..writeAsStringSync('{}');
    final started =
        await Srvd.fromCommandLineArgs([
              '-a',
              '@relay',
              '-k',
              keys.path,
              '-i',
              '127.0.0.1',
            ], atClient: atClient)
            as SrvdImpl;
    expect(started.telemetry, isNull);
    expect(started.signingKeyCheckInterval, const Duration(seconds: 300));

    fakeAsync((async) {
      final rig = running(
        async,
        collector: false,
        every: started.signingKeyCheckInterval,
        reportedEvery: started.reportedSigningKeyCheckInterval,
      );
      final si = session(async, rig, 's');

      endsAtThe300SecondRecheck(async, rig, si);
      stop(async, rig.relay);
    });
  });

  test('A session that started before its Atsigns opted in keeps the'
      ' 300-second re-check', () {
    fakeAsync((async) {
      const bobsNextKey = 'public:_apsk.bob-next-enrollment.a.__e@bob';
      final rig = running(async);
      session(async, rig, 's');
      expect(rig.relay.telemetry!.reporting('s'), isFalse);

      rig.list.list = listOf(['@bob']);
      async.elapse(const Duration(seconds: 90));
      expect(
        rig.relay.telemetry!.list.listed('@bob'),
        isTrue,
        reason:
            '@bob is on the list the relay now holds, read again within'
            ' 66 seconds: 60 and its jitter',
      );
      session(async, rig, 'next', client: '@carol', keys: {bobsNextKey});
      expect(rig.relay.telemetry!.reporting('next'), isTrue);
      async.elapse(const Duration(seconds: 9));

      expect(rig.fast.lookupsOf(bobKey), 0);
      expect(rig.fast.timesOf(bobsNextKey), seconds([93, 96, 99]));
      async.elapse(const Duration(seconds: 202));
      expect(rig.slow.timesOf(bobKey), seconds([300]));
      expect(rig.fast.lookupsOf(bobKey), 0);
      stop(async, rig.relay);
    });
  });

  test('The faster re-check can be turned off on its own', () {
    fakeAsync((async) {
      final rig = running(
        async,
        optedIn: ['@alice'],
        reportedEvery: Duration.zero,
      );
      final si = session(async, rig, 's');
      expect(
        rig.relay.telemetry!.reporting('s'),
        isTrue,
        reason: 'the session is reported',
      );

      endsAtThe300SecondRecheck(async, rig, si);
      stop(async, rig.relay);
    });
  });

  test('Turning the 300-second re-check off turns every re-check off', () {
    fakeAsync((async) {
      final rig = running(async, optedIn: ['@alice'], every: Duration.zero);
      final reported = session(async, rig, 'reported');
      final other = session(
        async,
        rig,
        'other',
        client: '@carol',
        keys: {bobKey},
      );
      expect(
        [
          rig.relay.telemetry!.reporting('reported'),
          rig.relay.telemetry!.reporting('other'),
        ],
        [true, false],
      );

      rig.atServers.revoke(bobKey);
      async.elapse(const Duration(hours: 1));

      expect([rig.fast.asked, rig.slow.asked], [isEmpty, isEmpty]);
      expect([reported.ending, other.ending], [false, false]);
      stop(async, rig.relay);
    });
  });

  group('Given a relay that sends telemetry and a live reported session', () {
    test('when 300 seconds pass, then its keys are looked up every 3 seconds'
        ' through the lookup kept for that, and once through the other', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', keys: {bobKey});

        async.elapse(const Duration(seconds: 301));

        expect(rig.fast.lookupsOf(bobKey), 100);
        expect(rig.slow.timesOf(bobKey), seconds([300]));
        stop(async, rig.relay);
        expect([rig.slow.closes, rig.fast.closes], [1, 1]);
      });
    });

    test('when its atServer is too slow for the 3-second re-check and its'
        ' enrollment is revoked, then the 300-second re-check ends it', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        final si = session(async, rig, 's', keys: {bobKey});
        rig.fast.silent.add('@bob');
        rig.slow.delays['@bob'] = const Duration(seconds: 5);

        async.elapse(const Duration(seconds: 10));
        rig.atServers.revoke(bobKey);
        async.elapse(const Duration(seconds: 289));
        expect(si.ending, isFalse);
        async.elapse(const Duration(seconds: 12));

        expect(
          si.ending,
          isTrue,
          reason: 'two answers of 5 seconds after the re-check at 300 s',
        );
        stop(async, rig.relay);
      });
    });

    test('when its atServer takes more than a second to answer, then its'
        " re-checks are spaced out as a failing key's are, and nothing is"
        ' logged', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', keys: {bobKey});
        rig.fast.delays['@bob'] = const Duration(milliseconds: 1500);

        async.elapse(const Duration(seconds: 50));

        expect(rig.fast.timesOf(bobKey), seconds([3, 6, 12, 24, 48]));
        expect(said(bobKey), isEmpty);
        stop(async, rig.relay);
      });
    });

    test('when its key cannot be re-checked for three minutes, then that is'
        ' logged at first and at each re-check a minute after the last', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', keys: {bobKey});
        rig.fast.silent.add('@bob');
        Iterable<String> couldNot() =>
            said('Could not re-check signing key $bobKey');

        async.elapse(const Duration(milliseconds: 97900));
        expect(
          couldNot(),
          hasLength(1),
          reason:
              'the failure at 5 s; those at 8, 14, 26 and 50 s come'
              ' within a minute of it',
        );
        async.elapse(const Duration(milliseconds: 200));
        expect(couldNot(), hasLength(2), reason: 'and the one at 98 s');
        expect(couldNot().last, endsWith('(re-check 6 in a row to end so)'));
        async.elapse(const Duration(seconds: 60));
        expect(couldNot(), hasLength(3), reason: 'and the one at 158 s');
        stop(async, rig.relay);
      });
    });

    for (final (why, arrange, line) in <(String, void Function(_Rig), String)>[
      (
        'its atServer does not answer',
        (rig) => rig.fast.silent.add('@bob'),
        'Could not re-check signing key $bobKey',
      ),
      (
        'its key is missing but not withdrawn',
        (rig) => rig.atServers.lose(bobKey),
        'Signing key $bobKey is missing but has not been withdrawn',
      ),
      (
        'where its key went cannot be told',
        (rig) {
          rig.atServers.lose(bobKey);
          rig.fast.failing.add(revoked(bobKey));
        },
        'Could not tell whether signing key $bobKey was withdrawn',
      ),
    ]) {
      test('when $why, then that is said once in the first minute, at'
          " srvd's default level", () {
        fakeAsync((async) {
          final rig = running(async, optedIn: ['@alice']);
          final si = session(async, rig, 's', keys: {bobKey});
          arrange(rig);

          async.elapse(const Duration(seconds: 59));

          expect(said(line), hasLength(1));
          expect(said(bobKey), hasLength(1));
          expect(si.ending, isFalse);
          stop(async, rig.relay);
        });
      });
    }

    test('when its atServer answers again, then that is logged once', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        final si = session(async, rig, 's', keys: {bobKey});
        rig.fast.silent.add('@bob');
        Iterable<String> again() => logged.where(
          (m) => m == 'Client data signing key $bobKey can be re-checked again',
        );

        async.elapse(const Duration(seconds: 10));
        expect(again(), isEmpty);
        rig.fast.silent.clear();
        async.elapse(const Duration(seconds: 30));

        expect(again(), hasLength(1));
        expect(si.ending, isFalse);
        stop(async, rig.relay);
      });
    });

    test('when its atServer fails every other re-check for ten minutes, then'
        ' at most two lines a minute are logged about its key', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', keys: {bobKey});

        for (var i = 0; i < 200; i++) {
          i.isEven ? rig.fast.silent.add('@bob') : rig.fast.silent.clear();
          async.elapse(s3);
        }

        expect(said(bobKey).length, inInclusiveRange(2, 22));
        expect(
          rig.fast.lookupsOf(bobKey),
          greaterThan(150),
          reason: 'it was failing and answering by turns throughout',
        );
        stop(async, rig.relay);
      });
    });

    test('when the last session its key signed has gone and another starts,'
        " then the key's next failure is logged as a first one", () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', keys: {bobKey});
        rig.fast.silent.add('@bob');
        Iterable<String> couldNot() =>
            said('Could not re-check signing key $bobKey');
        async.elapse(const Duration(milliseconds: 8100));
        expect(couldNot(), hasLength(1), reason: 'two failures, one line');

        rig.relay.sessions.remove('s');
        async.elapse(s3);
        session(async, rig, 'next', keys: {bobKey});
        async.elapse(const Duration(seconds: 6));

        expect(couldNot(), hasLength(2));
        expect(couldNot().last, isNot(contains('in a row')));
        stop(async, rig.relay);
      });
    });

    test('when its key also signed a session that is not reported and is'
        ' withdrawn, then both end at the 3-second re-check, and the key is'
        ' looked up no more', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        final reported = session(async, rig, 'reported');
        final other = session(
          async,
          rig,
          'other',
          client: '@carol',
          keys: {bobKey},
        );
        expect(rig.relay.telemetry!.reporting('other'), isFalse);

        rig.atServers.revoke(bobKey);
        async.elapse(const Duration(milliseconds: 3100));

        expect([reported.ending, other.ending], [true, true]);
        final int asked = rig.fast.asked.length;
        async.elapse(const Duration(seconds: 9));
        expect(
          rig.fast.asked,
          hasLength(asked),
          reason: 'a session being ended is re-checked no further',
        );
        stop(async, rig.relay);
      });
    });

    test('when the 300-second re-check of its key is still waiting, then its'
        ' 3-second re-checks go on', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', keys: {bobKey});
        rig.slow.delays['@bob'] = const Duration(seconds: 30);

        async.elapse(const Duration(milliseconds: 300500));
        expect(
          rig.slow.lookupsOf(bobKey),
          1,
          reason: 'the 300-second re-check has begun and is waiting',
        );
        final int before = rig.fast.lookupsOf(bobKey);
        async.elapse(const Duration(seconds: 9));

        expect(rig.fast.lookupsOf(bobKey), before + 3);
        stop(async, rig.relay);
      });
    });

    test('when its first pair has not been reported, then its keys wait for'
        ' the 300-second re-check', () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', paired: false);
        expect(rig.relay.telemetry!.reporting('s'), isNull);

        async.elapse(const Duration(seconds: 30));

        expect(rig.fast.asked, isEmpty);
        stop(async, rig.relay);
      });
    });

    test(
      'when the relay stops, then both its re-check timers are cancelled',
      () {
        fakeAsync((async) {
          final rig = running(async, optedIn: ['@alice']);
          session(async, rig, 's');
          async.elapse(const Duration(milliseconds: 3100));
          expect(
            rig.fast.asked,
            isNotEmpty,
            reason: 'it was re-checking before the stop',
          );
          final int before = async.periodicTimerCount;

          rig.relay.stop();
          async.flushMicrotasks();

          expect(
            before - async.periodicTimerCount,
            2,
            reason: 'the 300-second timer and the 3-second one',
          );
        });
      },
    );

    test('when the relay stops with a re-check under way, then that'
        " re-check's failure is not logged", () {
      fakeAsync((async) {
        final rig = running(async, optedIn: ['@alice']);
        session(async, rig, 's', keys: {bobKey});
        rig.fast.silent.add('@bob');
        async.elapse(const Duration(milliseconds: 3500));
        expect(rig.fast.lookupsOf(bobKey), 1);

        rig.relay.stop();
        async.elapse(const Duration(seconds: 5));

        expect(said(bobKey), isEmpty);
      });
    });
  });

  group('Given a relay whose one lookup serves every re-check', () {
    for (final bool collector in [true, false]) {
      test('when it stops, ${collector ? 'sending' : 'not sending'}'
          ' telemetry, then it closes that lookup once', () {
        fakeAsync((async) {
          final rig = running(
            async,
            optedIn: [if (collector) '@alice'],
            collector: collector,
            oneLookup: true,
          );
          session(async, rig, 's', keys: {bobKey});
          async.elapse(const Duration(milliseconds: 3100));
          expect(
            rig.slow.lookupsOf(bobKey),
            collector ? 1 : 0,
            reason: 'a reported key is re-checked through it at 3 s',
          );

          stop(async, rig.relay);

          expect([rig.slow.closes, rig.fast.closes], [1, 0]);
        });
      });
    }
  });

  group("Given srvd's options", () {
    Future<SrvdImpl> fromArgs(List<String> extra) async {
      final Directory dir = await Directory.systemTemp.createTemp('srvd-keys');
      addTearDown(() => dir.delete(recursive: true));
      final File keys = File('${dir.path}/k')..writeAsStringSync('{}');
      return await Srvd.fromCommandLineArgs([
            '-a',
            '@relay',
            '-k',
            keys.path,
            '-i',
            '127.0.0.1',
            ...extra,
          ], atClient: atClient)
          as SrvdImpl;
    }

    test('when none is given, then reported sessions are re-checked every 3'
        ' seconds, each lookup given 2 and counted prompt within 1', () async {
      final srvd = await fromArgs([]);

      expect(srvd.reportedSigningKeyCheckInterval, s3);
      expect(srvd.reportedSigningKeyCheckDeadline, const Duration(seconds: 2));
      expect(srvd.reportedSigningKeyPromptAnswer, const Duration(seconds: 1));
    });

    test('when --reported-signing-key-check-secs is given, then srvd is built'
        ' with it', () async {
      final srvd = await fromArgs(['--reported-signing-key-check-secs', '7']);

      expect(srvd.reportedSigningKeyCheckInterval, const Duration(seconds: 7));
    });

    test('when --signing-key-check-secs is 0, then the faster re-check keeps'
        ' its own value', () async {
      final srvd = await fromArgs(['--signing-key-check-secs', '0']);

      expect(srvd.signingKeyCheckInterval, Duration.zero);
      expect(srvd.reportedSigningKeyCheckInterval, s3);
    });

    test('when --reported-signing-key-check-secs is negative, then it is'
        ' refused', () async {
      await expectLater(
        fromArgs(['--reported-signing-key-check-secs', '-1']),
        throwsArgumentError,
      );
    });

    test('when SrvdParams is built without the faster interval, then it is 3'
        ' seconds', () {
      final params = SrvdParams(
        atSign: '@relay',
        homeDirectory: '.',
        atKeysFilePath: 'k',
        passPhrase: '',
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        verbose: false,
        logTraffic: false,
        rootDomain: 'root.example',
        perSessionStorage: true,
        bind443: false,
        localBindPort443: 443,
        relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        signingKeyCheckSecs: 300,
        debug: false,
      );

      expect(params.reportedSigningKeyCheckSecs, 3);
    });

    test(
      'when srvd is built with no lookups of its own, then reported'
      ' sessions are re-checked through a second lookup: 2 seconds for a'
      ' whole lookup, 64 at once, and told how long each answer took',
      () async {
        final srvd = await fromArgs(['--telemetry-collector-atsign', '@tel']);

        final first = srvd.publicLookup as DirectPublicLookup;
        final second = srvd.reportedKeyLookup as DirectPublicLookup;
        expect(identical(first, second), isFalse);
        expect(
          [first.timeout, first.timeoutCoversAddress, first.maxConcurrent],
          [DirectPublicLookup.defaultTimeout, false, 16],
        );
        expect(
          [second.timeout, second.timeoutCoversAddress, second.maxConcurrent],
          [const Duration(seconds: 2), true, 64],
        );
        expect(second.maxPerAtSign, first.maxPerAtSign);
        expect(second.onAnswered, isNotNull);
      },
    );
  });
}
