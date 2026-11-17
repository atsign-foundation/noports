import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/src/srvd/isolates/connection_tracker.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';

/// Keeps every log record it is given.
class _CapturingHandler implements LoggingHandler {
  final List<LogRecord> records = [];

  @override
  void call(LogRecord record) => records.add(record);
}

void main() {
  late ReceivePort toMain;
  late List<IIRequest> reports;
  late StreamController<Connection> opened;
  late StreamController<Connection> closed;
  late ServerSocket server;
  late _CapturingHandler log;
  late LoggingHandler previousHandler;
  final sockets = <Socket>[];

  setUp(() async {
    toMain = ReceivePort();
    reports = [];
    toMain.listen((m) {
      if (m is IIRequest) reports.add(m);
    });
    opened = StreamController<Connection>();
    closed = StreamController<Connection>();
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(sockets.add);
    previousHandler = AtSignLogger.defaultLoggingHandler;
    log = _CapturingHandler();
    AtSignLogger.defaultLoggingHandler = log;
  });

  tearDown(() async {
    AtSignLogger.defaultLoggingHandler = previousHandler;
    for (final s in sockets) {
      s.destroy();
    }
    sockets.clear();
    await server.close();
    if (!opened.isClosed) await opened.close();
    if (!closed.isClosed) await closed.close();
    toMain.close();
  });

  /// A connection whose sides are real loopback sockets.
  Future<Connection> connection() async {
    final a = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
    final b = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
    sockets.addAll([a, b]);
    return Connection(Side(a, true), Side(b, false));
  }

  ConnectionTracker tracker({
    Duration closeFlushTimeout = const Duration(milliseconds: 300),
    Duration progressInterval = const Duration(days: 1),
  }) =>
      ConnectionTracker(
        sessionId: 'S',
        toMain: toMain.sendPort,
        opened: opened.stream,
        closed: closed.stream,
        stats: Stats.new,
        closeFlushTimeout: closeFlushTimeout,
        progressInterval: progressInterval,
      );

  /// The [nth] report of [type], waiting up to 5 seconds for it.
  Future<IIRequest> report(String type, {int nth = 1}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final of = reports.where((r) => r.type == type).toList();
      if (of.length >= nth) return of[nth - 1];
      await Future.delayed(const Duration(milliseconds: 10));
    }
    fail('no $type report (${reports.map((r) => r.type).toList()})');
  }

  test('A peer socket_connector did not record is left out of the report',
      () async {
    final c = await connection();
    c.sideA.remoteHost = 'n/a';
    c.sideA.remotePort = -1;
    tracker();

    opened.add(c);

    final r = await report('newConnection');
    expect(r.payload['index'], 1);
    expect(r.payload.containsKey('client'), isFalse);
    expect(r.payload['device'], {'ip': '127.0.0.1', 'port': c.sideB.remotePort});
  });

  test(
      'A connection opened after an earlier one closed is waited for at'
      ' completion', () async {
    final t = tracker();
    final c1 = await connection();
    final c2 = await connection();
    opened.add(c1);
    await report('newConnection');
    closed.add(c1);
    await report('connectionClosed');
    opened.add(c2);
    await report('newConnection', nth: 2);

    final completing = t.complete();
    await Future.delayed(const Duration(milliseconds: 150));
    closed.add(c2);
    await completing;

    final r = await report('sessionComplete');
    expect(r.payload['connectionsUnclosed'], 0,
        reason: 'the second connection is waited for, not counted unclosed');
    expect((await report('connectionClosed', nth: 2)).payload['index'], 2);
  });

  test("Only the first newConnection carries the connector's stats",
      () async {
    tracker();
    opened.add(await connection());
    opened.add(await connection());

    final first = await report('newConnection');
    final second = await report('newConnection', nth: 2);

    expect(first.payload.containsKey('stats'), isTrue);
    expect(second.payload.containsKey('stats'), isFalse,
        reason: 'main reads the stats of the first connection only');
  });

  test('A worker reports progress every 15 minutes', () async {
    expect(defaultProgressInterval, const Duration(minutes: 15));
    final t = tracker(progressInterval: const Duration(milliseconds: 50));
    final c1 = await connection();
    final c2 = await connection();
    c1.sideA.rcvd = 100;
    c1.sideB.rcvd = 100;
    opened.add(c1);
    opened.add(c2);
    final before = DateTime.timestamp().millisecondsSinceEpoch;

    final r = await report('progress');

    expect(r.payload['sessionId'], 'S');
    expect(r.payload['openConnections'], 2);
    expect(r.payload['connections'], 2);
    expect(r.payload['bytesClientToDevice'], 100);
    expect(r.payload['bytesDeviceToClient'], 100);
    expect(r.payload['at'], greaterThanOrEqualTo(before));

    final second = await report('progress', nth: 2);
    expect(second.payload['openConnections'], 2);
    expect(second.payload['at'], greaterThan(r.payload['at'] as int),
        reason: 'progress keeps being reported, not only once per session');
    await t.complete();
  });

  test(
      "A closed connection's bytes stay in the session's totals, and its close"
      " time is the later of its sides'", () async {
    final t = tracker();
    final c = await connection();
    opened.add(c);
    await report('newConnection');
    c.sideA.rcvd = 100;
    c.sideB.rcvd = 7;
    final later = DateTime.timestamp().subtract(const Duration(minutes: 1));
    c.sideA.closedAt = later;
    c.sideB.closedAt = later.subtract(const Duration(minutes: 1));

    closed.add(c);
    final r = await report('connectionClosed');
    await t.complete();
    final done = await report('sessionComplete');

    expect(r.payload['closedAt'], later.millisecondsSinceEpoch,
        reason: "the later side's close time, not the time it was reported");
    expect(done.payload['bytesClientToDevice'], 100,
        reason: 'a closed connection is no longer open, and its bytes count');
    expect(done.payload['bytesDeviceToClient'], 7);
  });

  test('sessionComplete is sent at the bound when a close is never reported',
      () async {
    const flush = Duration(milliseconds: 300);
    final t = tracker(closeFlushTimeout: flush);
    final c1 = await connection();
    final c2 = await connection();
    opened.add(c1);
    opened.add(c2);
    await report('newConnection', nth: 2);
    closed.add(c1);
    await report('connectionClosed');
    final stopwatch = Stopwatch()..start();

    await t.complete();

    stopwatch.stop();
    expect(
      stopwatch.elapsed,
      lessThan(flush + const Duration(seconds: 2)),
      reason: 'completion is bounded at the flush timeout plus a second',
    );
    expect(
      stopwatch.elapsed,
      greaterThanOrEqualTo(flush + const Duration(seconds: 1)),
      reason: 'it waited the whole bound for the missing close',
    );
    final r = await report('sessionComplete');
    expect(r.payload['connections'], 2);
    expect(r.payload['connectionsUnclosed'], 1);
    expect(
      log.records.where((r) =>
          r.level == Level.WARNING &&
          r.message.contains('1 connection(s) of session S were not reported')),
      hasLength(1),
    );
  });
}
