import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_telemetry/at_telemetry.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/events/event_mixins.dart'
    show CompressionScheme, EncodingScheme;
import 'package:noports_core/src/events/event_models.dart' show AtEventConfig;
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/telemetry/opted_in_list.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry_names.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';

import '../../sshnp/sshnp_mocks.dart';
import 'telemetry_fakes.dart';

typedef N = RelayTelemetryNames;

void _exitAtOnce(Object? _) {}

/// Sends its port to main, then ignores every message, so it never reports
/// its session complete and never exits on its own.
void _deafWorker(SendPort toMain) {
  final fromMain = ReceivePort();
  toMain.send(fromMain.sendPort);
  fromMain.listen((_) {});
}

/// An srvd whose event logging waits until [gate] completes.
class _SlowLoggingSrvd extends SrvdImpl {
  _SlowLoggingSrvd({
    required super.atClient,
    required super.atSign,
    required super.homeDirectory,
    required super.atKeysFilePath,
    required super.managerAtsign,
    required super.ipAddress,
    required super.logTraffic,
    required super.verbose,
    required super.bind443,
    required super.localBindPort443,
    required super.relayAuthDetectWindowMs,
    required super.signingKeyCheckInterval,
  });

  final Completer<void> gate = Completer<void>();

  @override
  Future<void> logEvent(
    AtEventConfig config,
    Map<String, dynamic> json, {
    CompressionScheme compressionScheme = CompressionScheme.zlib,
    EncodingScheme encodingScheme = EncodingScheme.base2e15,
  }) =>
      gate.future;
}

/// An exporter whose shutdown waits until [gate] completes.
class _GatedExporter extends RecordingExporter {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> shutdown() async {
    await gate.future;
    await super.shutdown();
  }
}

/// Keeps the message of every log record it is given.
class _Capture implements LoggingHandler {
  _Capture(this.messages);

  final List<String> messages;

  @override
  void call(LogRecord record) => messages.add(record.message);
}

void main() {
  late MockAtClient atClient;
  late MockNotificationService notificationService;
  final sockets = <Socket>[];

  setUpAll(() {
    registerFallbackValue(AtKey());
    registerFallbackValue('@fallback'.toAtsign());
  });

  setUp(() {
    atClient = MockAtClient();
    notificationService = MockNotificationService();
    when(() => atClient.notificationService).thenReturn(notificationService);
    when(() => atClient.getCurrentAtSign()).thenReturn('@relay');
    when(() => atClient.enrollmentId).thenReturn(null);
    when(
      () => notificationService.subscribe(
        regex: any(named: 'regex'),
        shouldDecrypt: any(named: 'shouldDecrypt'),
      ),
    ).thenAnswer((_) => StreamController<AtNotification>.broadcast().stream);
  });

  tearDown(() {
    for (final s in sockets) {
      s.destroy();
    }
    sockets.clear();
  });

  SrvdImpl srvd(RelayTelemetry? telemetry) => SrvdImpl(
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
        signingKeyCheckInterval: Duration.zero,
        telemetry: telemetry,
      );

  Future<Srvd> fromArgs(List<String> extra) async {
    final Directory dir = await Directory.systemTemp.createTemp('srvd-tel');
    addTearDown(() => dir.delete(recursive: true));
    final File keys = File('${dir.path}/@relay_key.atKeys')..writeAsStringSync('{}');
    return Srvd.fromCommandLineArgs(
      ['-a', '@relay', '-k', keys.path, '-i', '127.0.0.1', ...extra],
      atClient: atClient,
    );
  }

  test('srvd without a collector Atsign sends no telemetry', () async {
    final without = await fromArgs([]) as SrvdImpl;
    final withCollector =
        await fromArgs(['--telemetry-collector-atsign', '@telemetry'])
            as SrvdImpl;

    expect(without.telemetry, isNull);
    expect(withCollector.telemetry, isNotNull,
        reason: 'the option turns telemetry on, the control');
    await expectLater(
      fromArgs(['--telemetry-collector-atsign', 'not an atsign']),
      throwsArgumentError,
    );
  });

  test('Records go to the collector as batched notifications', () async {
    expect(AtTelemetryNotificationExporter.defaultMaxBatchRecords, 50);
    final sent = <(String, String, String)>[];
    when(
      () => notificationService.send(
        to: any(named: 'to'),
        idAndNamespace: any(named: 'idAndNamespace'),
        body: any(named: 'body'),
        shouldEncrypt: any(named: 'shouldEncrypt'),
      ),
    ).thenAnswer((i) async {
      sent.add((
        i.namedArguments[#to].toString(),
        i.namedArguments[#idAndNamespace] as String,
        i.namedArguments[#body] as String,
      ));
      return 'notification id';
    });
    when(() => atClient.get(any(),
            getRequestOptions: any(named: 'getRequestOptions')))
        .thenAnswer((i) async {
      final AtKey key = i.positionalArguments.first as AtKey;
      final Object obj = key.key == CollectionOptedInListSource.manifestId
          ? {
              'builtAt': DateTime.timestamp().toUtc().toIso8601String(),
              'chunks': 1,
              'window': '30d',
            }
          : {
              'atsigns': ['@alice'],
            };
      return AtValue()..value = jsonEncode({'type': 'n/a', 'obj': obj});
    });
    final telemetry = SrvdImpl.relayTelemetryFor(
      atClient: atClient,
      collector: '@telemetry',
      version: 'srvd 9.9.9',
    );
    final Stopwatch sw = Stopwatch()..start();

    telemetry.start();
    await telemetry.list.firstGoodRead.timeout(const Duration(seconds: 2));
    for (int i = 0; i < 120; i++) {
      telemetry.connectionOpened(
        'session-$i',
        sessionInfo(sessionParams(sessionId: 'session-$i')),
        opened(1),
      );
    }
    await until(() => sent.isNotEmpty, what: 'a notification');
    sw.stop();
    await telemetry.stop();

    expect(sw.elapsed, lessThan(const Duration(milliseconds: 1500)),
        reason: 'a batch goes out within a second of its first record');
    final (to, idAndNamespace, body) = sent.first;
    expect(to, '@telemetry');
    expect(idAndNamespace, 'logs.at_telemetry');
    final records = const AtTelemetryLogsCodec().decode(body).single.records;
    expect(records.first.eventName, N.lifecycleStarted);
    expect(
        records,
        hasLength(AtTelemetryNotificationExporter.defaultMaxBatchRecords),
        reason: 'srvd caps each notification at the exporter default of 50');
  });

  test("A list srvd cannot read is logged at srvd's default level", () async {
    final String rootLevel = AtSignLogger.root_level;
    final LoggingHandler previousHandler = AtSignLogger.defaultLoggingHandler;
    final logged = <String>[];
    AtSignLogger.defaultLoggingHandler = _Capture(logged);
    AtSignLogger.root_level = 'SHOUT';
    addTearDown(() {
      AtSignLogger.root_level = rootLevel;
      AtSignLogger.defaultLoggingHandler = previousHandler;
    });
    when(() => atClient.get(any(),
            getRequestOptions: any(named: 'getRequestOptions')))
        .thenThrow(AtKeyNotFoundException('no list yet'));
    when(
      () => notificationService.send(
        to: any(named: 'to'),
        idAndNamespace: any(named: 'idAndNamespace'),
        body: any(named: 'body'),
        shouldEncrypt: any(named: 'shouldEncrypt'),
      ),
    ).thenAnswer((_) async => 'notification id');
    final telemetry = SrvdImpl.relayTelemetryFor(
      atClient: atClient,
      collector: '@telemetry',
      version: 'srvd 9.9.9',
    );

    telemetry.start();
    addTearDown(telemetry.stop);
    await until(() => logged.any((m) => m.contains('opted-in list')),
        what: 'the list warning');

    expect(logged.where((m) => m.contains('Could not read the opted-in list')),
        isNotEmpty);
  });

  test('A session ended for a withdrawn client data signing key says so',
      () async {
    final exporter = RecordingExporter();
    final telemetry =
        await startedTelemetry(exporter, ScriptedListSource(listOf(['@alice'])));
    final relay = srvd(telemetry);
    addTearDown(telemetry.stop);
    relay.sessions['the-session'] = sessionInfo(sessionParams())..ending = true;

    await relay.handleWorkerReport(IIRequest.create(
        'newConnection', {...opened(1), 'stats': Stats()}));
    await relay.handleWorkerReport(IIRequest.create('sessionComplete', {
      'sessionId': 'the-session',
      'at': nowMs(),
      'stats': Stats(),
      'connections': 1,
      'bytesClientToDevice': 0,
      'bytesDeviceToClient': 0,
      'connectionsUnclosed': 1,
    }));
    await pumpEventQueue();

    expect(exporter.named(N.sessionEnded).single.attributes[N.endReason],
        'signingKeyWithdrawn');
  });

  test('Every connection of a session reaches telemetry, not only the first',
      () async {
    final exporter = RecordingExporter();
    final telemetry =
        await startedTelemetry(exporter, ScriptedListSource(listOf(['@alice'])));
    final relay = srvd(telemetry);
    addTearDown(telemetry.stop);
    relay.sessions['the-session'] = sessionInfo(sessionParams());

    await relay.handleWorkerReport(IIRequest.create(
        'newConnection', {...opened(1), 'stats': Stats()}));
    await relay.handleWorkerReport(IIRequest.create(
        'newConnection', {...opened(2), 'stats': Stats()}));
    await until(() => exporter.named(N.sessionConnections).isNotEmpty,
        what: 'a connections record');

    final record = exporter.named(N.sessionConnections).single;
    expect(record.attributes[N.opens], 2,
        reason: 'the second connection is reported as well as the first');
  });

  test('A session whose worker exits without reporting it complete is ended',
      () async {
    final exporter = RecordingExporter();
    final telemetry =
        await startedTelemetry(exporter, ScriptedListSource(listOf(['@alice'])));
    final relay = srvd(telemetry);
    addTearDown(telemetry.stop);
    relay.sessions['the-session'] = sessionInfo(sessionParams());
    await relay.handleWorkerReport(IIRequest.create(
        'newConnection', {...opened(1), 'stats': Stats()}));
    final fromWorker = ReceivePort();
    final exitPort = ReceivePort();

    final worker =
        await Isolate.spawn(_exitAtOnce, null, onExit: exitPort.sendPort);
    relay.trackWorker(worker, fromWorker, exitPort, Completer<SendPort>().future,
        sessionId: 'the-session');
    await until(() => exporter.named(N.sessionEnded).isNotEmpty,
        what: 'session.ended');

    final ended = exporter.named(N.sessionEnded).single;
    expect(ended.attributes[N.endReason], 'workerExited');
    expect(ended.attributes[N.connectionsUnclosed], 1);
    expect(relay.sessions, isEmpty, reason: 'main forgets the session');
  });

  test(
      'A reported session on a worker killed at the stop bound is reported as'
      ' ended', () async {
    final exporter = RecordingExporter();
    final telemetry =
        await startedTelemetry(exporter, ScriptedListSource(listOf(['@alice'])));
    final relay = srvd(telemetry);
    await relay.init();
    relay.sessions['the-session'] = sessionInfo(sessionParams());
    await relay.handleWorkerReport(IIRequest.create(
        'newConnection', {...opened(1), 'stats': Stats()}));
    expect(exporter.named(N.sessionStarted), hasLength(1));
    final fromWorker = ReceivePort();
    final exitPort = ReceivePort();
    final toWorker = Completer<SendPort>();
    fromWorker.listen((m) {
      if (m is SendPort) toWorker.complete(m);
    });
    final deaf = await Isolate.spawn(_deafWorker, fromWorker.sendPort,
        onExit: exitPort.sendPort);
    relay.trackWorker(deaf, fromWorker, exitPort, toWorker.future,
        sessionId: 'the-session');
    await toWorker.future.timeout(const Duration(seconds: 2));

    await relay.stop();

    final ended = exporter.named(N.sessionEnded);
    expect(ended, hasLength(1),
        reason: 'the worker was killed without reporting the session complete');
    expect(ended.single.attributes[N.endReason], 'relayStopping');
    expect(exporter.records.last.eventName, N.lifecycleStopped);
  });

  test(
      'A completed session whose end is still being logged is not reported'
      ' lost when its worker exits', () async {
    final relay = _SlowLoggingSrvd(
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
      signingKeyCheckInterval: Duration.zero,
    );
    relay.sessions['the-session'] = sessionInfo(sessionParams())
      ..eventLoggingConfig = AtEventConfig(
          atSign: '@events'.toAtsign(), topic: 'x.events.sshnp', ttln: 1000);
    final logged = <String>[];
    relay.logger.logger.onRecord.listen((r) => logged.add(r.message));
    final completing = relay.handleWorkerReport(IIRequest.create(
        'sessionComplete', {
      'sessionId': 'the-session',
      'at': nowMs(),
      'stats': Stats(),
      'connections': 1,
      'connectionsUnclosed': 0,
    }));
    final exitPort = ReceivePort();
    final fromWorker = ReceivePort();
    final exitHandled = Completer<void>();
    fromWorker.listen((_) {}, onDone: exitHandled.complete);
    final worker =
        await Isolate.spawn(_exitAtOnce, null, onExit: exitPort.sendPort);
    relay.trackWorker(worker, fromWorker, exitPort,
        Completer<SendPort>().future,
        sessionId: 'the-session');
    await exitHandled.future.timeout(const Duration(seconds: 5),
        onTimeout: () => fail('srvd never handled the worker exit'));

    expect(logged.where((m) => m.contains('exited without reporting')),
        isEmpty,
        reason: 'the session was reported complete before its worker exited');
    relay.gate.complete();
    await completing;
  });

  group('A port-pair worker that dies', () {
    late RecordingExporter exporter;
    late SrvdImpl relay;

    setUp(() async {
      exporter = RecordingExporter();
      final telemetry = await startedTelemetry(
          exporter, ScriptedListSource(listOf(['@alice'])));
      addTearDown(telemetry.stop);
      relay = srvd(telemetry);
      await relay.init();
      await relay.run();
      addTearDown(relay.stop);
    });

    /// Spawns a real port-pair worker for session [id] and records the
    /// session against it, paired once.
    Future<Isolate> liveSession(String id) async {
      final params =
          sessionParams(sessionId: id, clientVerified: false, deviceVerified: false);
      final (_, worker, toWorker) = await relay.spawnNewPortPairIsolate(params);
      relay.sessions[id] =
          SessionInfo(params: params, connector: null, toWorker: toWorker);
      await relay.handleWorkerReport(IIRequest.create('newConnection',
          {...opened(1), 'sessionId': id, 'stats': Stats()}));
      return worker;
    }

    test('ends the session it carried as workerExited', () async {
      final worker = await liveSession('one');

      worker.kill(priority: Isolate.immediate);
      await until(() => exporter.named(N.sessionEnded).isNotEmpty,
          what: 'session.ended');

      expect(exporter.named(N.sessionEnded).single.attributes[N.endReason],
          'workerExited');
      expect(relay.sessions, isEmpty);
    });

    test('leaves a later session that reuses its session id', () async {
      final worker = await liveSession('one');
      final (_, other, otherPort) = await relay.spawnNewPortPairIsolate(
          sessionParams(sessionId: 'one', clientVerified: false, deviceVerified: false));
      addTearDown(() => other.kill(priority: Isolate.immediate));
      relay.sessions['one'] = SessionInfo(
          params: sessionParams(sessionId: 'one'),
          connector: null,
          toWorker: otherPort);
      final exitedFirst = ReceivePort();
      worker.addOnExitListener(exitedFirst.sendPort);

      worker.kill(priority: Isolate.immediate);
      await exitedFirst.first;
      await pumpEventQueue();

      expect(relay.sessions['one']?.toWorker, otherPort,
          reason: "the session is the other worker's, so it is kept");
    });
  });

  test('A second stop returns only once the first has finished', () async {
    final exporter = _GatedExporter();
    final telemetry =
        await startedTelemetry(exporter, ScriptedListSource(listOf(['@alice'])));
    final relay = srvd(telemetry);
    await relay.init();
    await relay.run();
    final first = relay.stop();

    bool secondReturned = false;
    final second = relay.stop().then((_) => secondReturned = true);
    await pumpEventQueue();

    expect(secondReturned, isFalse,
        reason: "the first stop's telemetry flush is still running");
    exporter.gate.complete();
    await Future.wait([first, second]);
    expect(exporter.shutDown, isTrue);
  });

  test('Live sessions are reported as ended when srvd stops', () async {
    expect(RelayTelemetry.defaultShutdownTimeout, const Duration(seconds: 5));
    final exporter = RecordingExporter();
    final telemetry =
        await startedTelemetry(exporter, ScriptedListSource(listOf(['@alice'])));
    final relay = srvd(telemetry);
    await relay.init();
    await relay.run();
    for (final id in ['one', 'two']) {
      final ((portA, portB), _, toWorker) =
          await relay.spawnNewPortPairIsolate(sessionParams(sessionId: id, clientVerified: false, deviceVerified: false));
      relay.sessions[id] = SessionInfo(
        params: sessionParams(sessionId: id, clientVerified: false, deviceVerified: false),
        connector: null,
        toWorker: toWorker,
      );
      final client = await Socket.connect(InternetAddress.loopbackIPv4, portA);
      final device = await Socket.connect(InternetAddress.loopbackIPv4, portB);
      client.listen((_) {}, onError: (_) {});
      device.listen((_) {}, onError: (_) {});
      sockets.addAll([client, device]);
    }
    await until(() => exporter.named(N.sessionStarted).length == 2,
        what: 'both sessions reported');

    await relay.stop();

    final ended = exporter.named(N.sessionEnded);
    expect(ended, hasLength(2));
    expect(ended.map((r) => r.attributes[N.endReason]).toSet(),
        {'relayStopping'});
    expect(ended.map((r) => r.attributes[N.clientSessionId]).toSet(),
        {'one', 'two'});
    final Iterable<String?> names = exporter.records.map((r) => r.eventName);
    expect(names.last, N.lifecycleStopped,
        reason: 'stopped comes after every ended record');
    expect(exporter.shutDown, isTrue);
    final Map<String, Object?> attributes = ended.first.attributes;
    expect(attributes[N.relaySessionId], isA<String>());
    expect(attributes[N.endedAtMs], isA<int>());
    expect(attributes[N.durationMs], greaterThanOrEqualTo(0));
    expect(attributes[N.tcpConnections], 1,
        reason: 'each session carried the one connection it paired');
    expect(attributes[N.connectionsUnclosed], 0,
        reason: 'the worker reported its connection closed before stopping');
  });
}
