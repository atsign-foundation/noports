import 'package:at_telemetry/at_telemetry.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry_names.dart';
import 'package:test/test.dart';

import 'telemetry_fakes.dart';

typedef N = RelayTelemetryNames;

class _CapturingHandler implements LoggingHandler {
  final List<LogRecord> records = [];

  @override
  void call(LogRecord record) => records.add(record);
}

void main() {
  late RecordingExporter exporter;
  late ScriptedListSource source;

  setUp(() {
    exporter = RecordingExporter();
    source = ScriptedListSource(listOf(['@alice', '@bob']));
  });

  Future<RelayTelemetry> telemetry({
    Duration window = const Duration(milliseconds: 100),
    Duration maxWindow = const Duration(milliseconds: 400),
    int maxEntries = RelayTelemetry.defaultMaxEntries,
    int Function()? backlog,
    Duration listInterval = const Duration(days: 1),
    Duration heartbeatInterval = const Duration(days: 1),
  }) async {
    final t = await startedTelemetry(
      exporter,
      source,
      window: window,
      maxWindow: maxWindow,
      maxEntries: maxEntries,
      backlog: backlog,
      listInterval: listInterval,
      heartbeatInterval: heartbeatInterval,
    );
    addTearDown(t.stop);
    return t;
  }

  List<AtTelemetryLogRecord> sessionRecords() => exporter.records
      .where((r) => !(r.eventName ?? '').startsWith('noports.relay.lifecycle'))
      .toList();

  Map<String, dynamic> complete({
    int connections = 1,
    int unclosed = 0,
    int c2d = 0,
    int d2c = 0,
  }) =>
      {
        'sessionId': 'the-session',
        'at': nowMs(),
        'connections': connections,
        'bytesClientToDevice': c2d,
        'bytesDeviceToClient': d2c,
        'connectionsUnclosed': unclosed,
      };

  /// Pairs, connects once and ends session the-session of [si].
  Future<void> wholeSession(RelayTelemetry t, SessionInfo si) async {
    final o = opened(1);
    t.connectionOpened('the-session', si, o);
    t.connectionClosed(
      'the-session',
      closed(1, openedAt: o['at'], c2d: 5, d2c: 7),
    );
    t.sessionCompleted(
      'the-session',
      complete(c2d: 5, d2c: 7),
      RelaySessionEndReason.connectionsClosed,
    );
    await pumpEventQueue();
  }

  /// Runs session the-session of [si] through a pair, a progress report, a
  /// close and its end, then pairs a reported witness session, and returns
  /// once the witness's connections record is out: a window the-session
  /// opened first, of the same length, has closed by then.
  Future<void> wholeSessionBesideWitness(RelayTelemetry t, SessionInfo si) async {
    final o = opened(1);
    t.connectionOpened('the-session', si, o);
    t.progress('the-session', {
      'at': nowMs(),
      'openConnections': 1,
      'connections': 1,
      'bytesClientToDevice': 0,
      'bytesDeviceToClient': 0,
    });
    t.connectionClosed(
      'the-session',
      closed(1, openedAt: o['at'], c2d: 5, d2c: 7),
    );
    t.sessionCompleted(
      'the-session',
      complete(c2d: 5, d2c: 7),
      RelaySessionEndReason.connectionsClosed,
    );
    t.connectionOpened(
      'witness',
      sessionInfo(sessionParams(sessionId: 'witness', client: '@alice')),
      opened(1),
    );
    await until(() => exporter.named(N.sessionConnections).isNotEmpty,
        what: "the witness's connections record");
  }

  /// The session records that name the client session id the-session.
  List<AtTelemetryLogRecord> theSessionRecords() => sessionRecords()
      .where((r) => r.attributes[N.clientSessionId] == 'the-session')
      .toList();

  test('srvd sends lifecycle records whatever the list says', () async {
    expect(RelayTelemetry.defaultHeartbeatInterval, const Duration(seconds: 60));
    source.list = null;
    await telemetry(heartbeatInterval: const Duration(milliseconds: 50));

    await until(
      () => exporter.named(N.lifecycleHeartbeat).length >= 2,
      what: 'two heartbeats',
    );

    expect(exporter.records.first.eventName, N.lifecycleStarted);
    for (final r in exporter.named(N.lifecycleHeartbeat)) {
      expect(r.attributes[N.openSessions], 0);
      expect(
        r.attributes.keys.where(
            (k) => k.contains('atsign') || k.contains('ip') || k.contains('name')),
        isEmpty,
      );
    }
    final resource = exporter.resource!.attributes;
    expect(resource[AtTelemetryAttributes.serviceName], 'srvd');
    expect(resource[AtTelemetryAttributes.serviceVersion],
        'srvd 9.9.9 (core 9.9.9)');
    expect(resource[AtTelemetryAttributes.serviceInstanceId], isA<String>());
  });

  test(
      'A session whose client-side Atsign is listed is reported from first'
      ' pair to end', () async {
    final t = await telemetry();

    await wholeSession(t, sessionInfo(sessionParams(device: '@carol')));

    expect(
      sessionRecords().map((r) => r.eventName),
      [N.sessionStarted, N.sessionConnections, N.sessionEnded],
    );
    final ids = sessionRecords().map((r) => r.attributes[N.relaySessionId]);
    expect(ids.toSet(), hasLength(1));
    for (final r in sessionRecords()) {
      expect(r.attributes[N.clientAtsign], '@alice');
      expect(r.attributes[N.deviceAtsign], '@carol');
    }
    final List<Object?> body =
        exporter.named(N.sessionConnections).single.body as List<Object?>;
    expect(body.first, containsPair('c', {'ip': '10.0.0.1', 'port': 40001}));
    expect(body.first, containsPair('d', {'ip': '10.0.0.2', 'port': 50001}));
  });

  test(
      'A session whose verified device-side Atsign is listed is reported with'
      " both parties' details", () async {
    final t = await telemetry();

    await wholeSession(
      t,
      sessionInfo(sessionParams(client: '@dave', device: '@bob')),
    );

    final started = exporter.named(N.sessionStarted).single;
    expect(started.attributes[N.clientAtsign], '@dave');
    expect(started.attributes[N.deviceAtsign], '@bob');
    expect(started.attributes[N.deviceVerified], isTrue);
    final List<Object?> body =
        exporter.named(N.sessionConnections).single.body as List<Object?>;
    expect(body.first, containsPair('c', {'ip': '10.0.0.1', 'port': 40001}));
    expect(body.first, containsPair('d', {'ip': '10.0.0.2', 'port': 50001}));
  });

  test(
      'A session whose device-side Atsign is listed but not verified is not'
      ' reported', () async {
    final t = await telemetry();

    await wholeSessionBesideWitness(
      t,
      sessionInfo(sessionParams(
          client: '@dave', device: '@bob', deviceVerified: false)),
    );

    expect(theSessionRecords(), isEmpty);
    expect(
      exporter.named(N.sessionStarted).map((r) => r.attributes[N.clientSessionId]),
      ['witness'],
      reason: 'the witness, the control, is reported',
    );
  });

  test('A session with neither party listed is not reported', () async {
    final t = await telemetry();

    await wholeSessionBesideWitness(
      t,
      sessionInfo(sessionParams(client: '@dave', device: '@erin')),
    );

    expect(theSessionRecords(), isEmpty);
    expect(
      exporter.named(N.sessionStarted).map((r) => r.attributes[N.clientSessionId]),
      ['witness'],
      reason: 'the witness, the control, is reported',
    );
  });

  test('The decision is taken once, at first pair', () async {
    final t = await telemetry(listInterval: const Duration(milliseconds: 30));
    final unreported = sessionInfo(sessionParams(
        sessionId: 'unreported', client: '@dave', device: '@erin'));
    final reported =
        sessionInfo(sessionParams(sessionId: 'reported', client: '@alice'));
    t.connectionOpened('unreported', unreported, opened(1));
    t.connectionOpened('reported', reported, opened(1));
    expect(t.reporting('unreported'), isFalse);
    expect(t.reporting('reported'), isTrue);

    source.list = listOf(['@dave']);
    final int readsBefore = source.reads;
    await until(() => source.reads >= readsBefore + 2, what: 'two re-reads');

    expect(t.list.listed('@dave'), isTrue, reason: 'the new list is held');
    expect(t.reporting('unreported'), isFalse);
    expect(t.reporting('reported'), isTrue);
    t.sessionCompleted('unreported', complete(), RelaySessionEndReason.connectionsClosed);
    t.sessionCompleted('reported', complete(), RelaySessionEndReason.connectionsClosed);
    await pumpEventQueue();
    final ended = exporter.named(N.sessionEnded);
    expect(ended, hasLength(1));
    expect(ended.single.attributes[N.clientAtsign], '@alice');
  });

  test('A session that never pairs gets no records', () async {
    final t = await telemetry();

    t.sessionCompleted(
      'the-session',
      complete(connections: 0),
      RelaySessionEndReason.connectionsClosed,
    );
    await pumpEventQueue();

    expect(sessionRecords(), isEmpty);
  });

  test('A connection reported after telemetry stops gets no records',
      () async {
    final t = await telemetry();
    await t.stop();
    final int sent = exporter.records.length;

    t.connectionOpened('the-session', sessionInfo(sessionParams()), opened(1));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(exporter.records, hasLength(sent),
        reason: 'nothing is sent once the stopped record has gone');
  });

  test('session.started carries the session set', () async {
    final t = await telemetry();
    final si = sessionInfo(
      sessionParams(sessionId: 'abc-123', device: '@bob'),
      deviceName: 'gateway-1',
    );
    final int at = nowMs();

    t.connectionOpened('abc-123', si, opened(1, at: at));
    await pumpEventQueue();

    final a = exporter.named(N.sessionStarted).single.attributes;
    expect(a[N.relaySessionId], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(a[N.sequence], 1);
    expect(a[N.clientAtsign], '@alice');
    expect(a[N.deviceAtsign], '@bob');
    expect(a[N.clientVerified], isTrue);
    expect(a[N.deviceVerified], isTrue);
    expect(a[N.portMode], 'pair');
    expect(a[N.requestedAtMs], si.requestTime.millisecondsSinceEpoch);
    expect(a[N.establishedAtMs], at);
    expect(a[N.deviceName], 'gateway-1');
    expect(a[N.clientSessionId], 'abc-123');
  });

  test('A client session id outside the allowed shape is left out', () async {
    final t = await telemetry();
    final String long = 'a' * 70;

    t.connectionOpened(long, sessionInfo(sessionParams(sessionId: long)),
        opened(1));
    await pumpEventQueue();

    final a = exporter.named(N.sessionStarted).single.attributes;
    expect(a.containsKey(N.clientSessionId), isFalse);
    expect(a[N.clientAtsign], '@alice');
  });

  test(
      'Every session record carries the client-side and device-side Atsigns,'
      ' canonical', () async {
    final t = await telemetry();

    await wholeSession(
      t,
      sessionInfo(sessionParams(
          client: '@Alice', device: '@C.arol', deviceVerified: false)),
    );

    expect(sessionRecords(), hasLength(3),
        reason: 'started, connections and ended, reported for @alice');
    for (final r in sessionRecords()) {
      expect(r.attributes[N.clientAtsign], '@alice',
          reason: '${r.eventName} carries the client-side Atsign');
      expect(r.attributes[N.deviceAtsign], '@carol',
          reason: '${r.eventName} carries the device-side Atsign');
    }
  });

  test(
      'Connections that open together are reported in one record a window'
      ' later', () async {
    expect(RelayTelemetry.defaultWindow, const Duration(seconds: 2));
    final t = await telemetry(window: const Duration(milliseconds: 200));
    final si = sessionInfo(sessionParams());
    final Stopwatch sw = Stopwatch()..start();

    for (int i = 1; i <= 6; i++) {
      t.connectionOpened('the-session', si, opened(i));
    }
    await until(() => exporter.named(N.sessionConnections).isNotEmpty);
    sw.stop();

    final record = exporter.named(N.sessionConnections).single;
    expect(sw.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 190)));
    final List<Object?> body = record.body as List<Object?>;
    expect(body.map((e) => (e as Map)['i']), [1, 2, 3, 4, 5, 6]);
    expect(body.every((e) => (e as Map)['e'] == 'open'), isTrue);
    expect(record.attributes[N.opens], 6);
    expect(record.attributes[N.closes], 0);
    expect(record.attributes[N.openConnections], 6);
  });

  test(
      'Connections that close together are reported in one record a window'
      ' later', () async {
    final t = await telemetry(window: const Duration(milliseconds: 100));
    final si = sessionInfo(sessionParams());
    final int openedAt = nowMs();
    for (int i = 1; i <= 6; i++) {
      t.connectionOpened('the-session', si, opened(i, at: openedAt));
    }
    await until(() => exporter.named(N.sessionConnections).length == 1);

    for (int i = 1; i <= 6; i++) {
      t.connectionClosed(
        'the-session',
        closed(i, openedAt: openedAt, c2d: 10, d2c: 20),
      );
    }
    await until(() => exporter.named(N.sessionConnections).length == 2);

    final record = exporter.named(N.sessionConnections).last;
    final List<Object?> body = record.body as List<Object?>;
    expect(body, hasLength(6));
    for (final e in body.cast<Map>()) {
      expect(e['e'], 'close');
      expect(e['dur'], greaterThanOrEqualTo(0));
      expect(e['c2d'], 10);
      expect(e['d2c'], 20);
    }
    expect(record.attributes[N.opens], 0);
    expect(record.attributes[N.closes], 6);
    expect(record.attributes[N.openConnections], 0);
    expect(record.attributes[N.bytesClientToDevice], 60);
    expect(record.attributes[N.bytesDeviceToClient], 120);
  });

  test('A window is not extended by later entries', () async {
    final t = await telemetry(window: const Duration(milliseconds: 200));
    final si = sessionInfo(sessionParams());

    for (int i = 1; i <= 10; i++) {
      t.connectionOpened('the-session', si, opened(i));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await until(() =>
        exporter
            .named(N.sessionConnections)
            .fold<int>(0, (n, r) => n + (r.body as List).length) ==
        10);

    expect(exporter.named(N.sessionConnections).length, greaterThanOrEqualTo(2),
        reason: 'an extended window would have held all 10 in one record');
  });

  test('A window closes at 100 entries', () async {
    expect(RelayTelemetry.defaultMaxEntries, 100);
    final t = await telemetry(window: const Duration(milliseconds: 300));
    final si = sessionInfo(sessionParams());

    for (int i = 1; i <= 150; i++) {
      t.connectionOpened('the-session', si, opened(i));
    }
    await pumpEventQueue();
    expect(exporter.named(N.sessionConnections), hasLength(1),
        reason: 'the first 100 go out at once');
    expect(exporter.named(N.sessionConnections).single.body, hasLength(100));

    await until(() => exporter.named(N.sessionConnections).length == 2);
    expect(exporter.named(N.sessionConnections).last.body, hasLength(50));
  });

  test('Windows widen while the exporter is backed up', () async {
    expect(RelayTelemetry.defaultBacklogThreshold, 10);
    expect(RelayTelemetry.defaultMaxWindow, const Duration(seconds: 60));
    int backlog = 11;
    final t = await telemetry(
      window: const Duration(milliseconds: 50),
      maxWindow: const Duration(milliseconds: 400),
      backlog: () => backlog,
    );
    final si = sessionInfo(sessionParams());

    Future<Duration> oneWindow(int index) async {
      final int before = exporter.named(N.sessionConnections).length;
      final Stopwatch sw = Stopwatch()..start();
      t.connectionOpened('the-session', si, opened(index));
      await until(() => exporter.named(N.sessionConnections).length > before);
      return sw.elapsed;
    }

    final d1 = await oneWindow(1);
    final d2 = await oneWindow(2);
    final d3 = await oneWindow(3);
    final d4 = await oneWindow(4);
    backlog = 0;
    final d5 = await oneWindow(5);

    expect(d1, greaterThanOrEqualTo(const Duration(milliseconds: 95)));
    expect(d2.inMicroseconds, greaterThan(d1.inMicroseconds * 1.6));
    expect(d3.inMicroseconds, greaterThan(d2.inMicroseconds * 1.6));
    expect(d4, lessThan(const Duration(milliseconds: 520)),
        reason: 'capped at the maximum window');
    expect(d5, lessThan(const Duration(milliseconds: 150)),
        reason: 'back to the base window once the backlog clears');
  });

  test('still_running goes out every 15 minutes while the session is open',
      () async {
    final t = await telemetry(window: const Duration(milliseconds: 50));
    final si = sessionInfo(sessionParams());
    t.connectionOpened('the-session', si, opened(1));
    t.connectionOpened('the-session', si, opened(2));
    await until(() => exporter.named(N.sessionConnections).isNotEmpty);

    for (final int bytes in [10, 30]) {
      t.progress('the-session', {
        'at': nowMs(),
        'openConnections': 2,
        'connections': 2,
        'bytesClientToDevice': bytes,
        'bytesDeviceToClient': bytes + 10,
      });
    }
    await pumpEventQueue();

    final running = exporter.named(N.sessionStillRunning);
    expect(running, hasLength(2), reason: 'one at each tick');
    expect(running.last.attributes[N.openConnections], 2);
    expect(running.last.attributes[N.tcpConnections], 2);
    expect(running.last.attributes[N.bytesClientToDevice], 30);
    expect(running.last.attributes[N.bytesDeviceToClient], 40);
  });

  test(
      'still_running goes out at the tick even when a connections record went'
      ' out in the window', () async {
    final t = await telemetry(window: const Duration(milliseconds: 50));
    final si = sessionInfo(sessionParams());
    t.connectionOpened('the-session', si, opened(1));
    await until(() => exporter.named(N.sessionConnections).isNotEmpty);

    t.progress('the-session', {'at': nowMs(), 'openConnections': 1,
        'connections': 1, 'bytesClientToDevice': 0, 'bytesDeviceToClient': 0});
    await pumpEventQueue();

    expect(exporter.named(N.sessionStillRunning), hasLength(1),
        reason: 'a busy session is still shown as running');
  });

  test('session.ended carries the totals and the reason', () async {
    final t = await telemetry(window: const Duration(seconds: 10));
    final si = sessionInfo(sessionParams());
    final int start = nowMs();
    for (int i = 1; i <= 3; i++) {
      t.connectionOpened('the-session', si, opened(i, at: start));
    }
    t.connectionClosed('the-session', closed(1, openedAt: start, c2d: 1, d2c: 2));
    t.connectionClosed('the-session', closed(2, openedAt: start, c2d: 3, d2c: 4));

    t.sessionCompleted(
      'the-session',
      complete(connections: 3, unclosed: 1, c2d: 9, d2c: 11),
      RelaySessionEndReason.connectionsClosed,
    );
    await pumpEventQueue();

    expect(sessionRecords().map((r) => r.eventName),
        [N.sessionStarted, N.sessionConnections, N.sessionEnded],
        reason: 'pending entries go out before the end');
    final a = exporter.named(N.sessionEnded).single.attributes;
    expect(a[N.endedAtMs], isA<int>());
    expect(a[N.durationMs], greaterThanOrEqualTo(0));
    expect(a[N.bytesClientToDevice], 9);
    expect(a[N.bytesDeviceToClient], 11);
    expect(a[N.tcpConnections], 3);
    expect(a[N.connectionsUnclosed], 1);
    expect(a[N.endReason], 'connectionsClosed');
    expect(a[N.sequence], 3);
  });

  test('Sequence numbers count every record of a session', () async {
    final t = await telemetry(window: const Duration(milliseconds: 30));
    final si = sessionInfo(sessionParams());
    final o = opened(1);
    t.connectionOpened('the-session', si, o);
    await until(() => exporter.named(N.sessionConnections).length == 1);
    t.connectionClosed('the-session', closed(1, openedAt: o['at']));
    await until(() => exporter.named(N.sessionConnections).length == 2);
    t.progress('the-session', {'at': nowMs(), 'openConnections': 0,
        'connections': 1, 'bytesClientToDevice': 0, 'bytesDeviceToClient': 0});
    t.progress('the-session', {'at': nowMs(), 'openConnections': 0,
        'connections': 1, 'bytesClientToDevice': 0, 'bytesDeviceToClient': 0});

    t.sessionCompleted('the-session', complete(),
        RelaySessionEndReason.connectionsClosed);
    await pumpEventQueue();

    expect(sessionRecords().map((r) => r.eventName), [
      N.sessionStarted,
      N.sessionConnections,
      N.sessionConnections,
      N.sessionStillRunning,
      N.sessionStillRunning,
      N.sessionEnded,
    ]);
    expect(sessionRecords().map((r) => r.attributes[N.sequence]),
        [1, 2, 3, 4, 5, 6]);
  });

  test('Dropped records are counted and reported once a minute', () async {
    expect(RelayTelemetry.defaultDropReportInterval, const Duration(minutes: 1));
    expect(AtTelemetryNotificationExporter.defaultMaxUnsentBatches, 100);
    final log = _CapturingHandler();
    final previous = AtSignLogger.defaultLoggingHandler;
    AtSignLogger.defaultLoggingHandler = log;
    addTearDown(() => AtSignLogger.defaultLoggingHandler = previous);
    final real = AtTelemetryNotificationExporter(
      notify: (_, __) async => throw StateError('the atServer refused it'),
      maxBatchRecords: 1,
      maxUnsentBatches: 2,
      flushInterval: const Duration(milliseconds: 10),
      shutdownTimeout: const Duration(milliseconds: 100),
    );
    final t = RelayTelemetry(
      exporter: real,
      backlog: () => real.unsentBatches,
      serviceVersion: 'v',
      dropReportInterval: const Duration(milliseconds: 100),
      list: (await startedTelemetry(RecordingExporter(), source)).list,
    );
    t.start();
    final si = sessionInfo(sessionParams());
    for (int i = 1; i <= 6; i++) {
      t.connectionOpened('s$i', si, opened(1));
    }

    await until(
      () => log.records.any((r) =>
          r.level == Level.SHOUT &&
          r.message.contains('telemetry record(s) in the last minute')),
      what: 'the drop report',
    );
    await t.stop();
    final reports = log.records
        .where((r) => r.message.contains('telemetry record(s) in the last minute'))
        .toList();
    expect(reports.first.message, matches(RegExp(r'Lost [1-9]\d* telemetry')));
  });

  test('Only the instance that paired a session reports it', () async {
    final pairing = await telemetry();
    final otherExporter = RecordingExporter();
    final other = await startedTelemetry(otherExporter, ScriptedListSource(listOf(['@alice'])));
    addTearDown(other.stop);
    final si = sessionInfo(sessionParams());

    pairing.connectionOpened('the-session', si, opened(1));
    other.sessionCompleted('the-session', complete(connections: 0),
        RelaySessionEndReason.connectionsClosed);
    await pumpEventQueue();

    expect(exporter.named(N.sessionStarted), hasLength(1));
    expect(
      otherExporter.records.where((r) => r.eventName != N.lifecycleStarted),
      isEmpty,
      reason: 'the instance whose ports nobody connected to sends nothing',
    );
  });
}
