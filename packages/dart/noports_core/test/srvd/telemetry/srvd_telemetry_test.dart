import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_telemetry/at_telemetry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry_names.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';

import '../../sshnp/sshnp_mocks.dart';
import 'telemetry_fakes.dart';

typedef N = RelayTelemetryNames;

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
        .thenThrow(AtKeyNotFoundException('no list yet'));
    final telemetry = SrvdImpl.relayTelemetryFor(
      atClient: atClient,
      collector: '@telemetry',
      version: 'srvd 9.9.9',
    );
    final Stopwatch sw = Stopwatch()..start();

    telemetry.start();
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
  });

  test('A session ended for a withdrawn signing key says so', () async {
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
    expect(jsonEncode(ended.first.attributes), isNotEmpty);
  });
}
