import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:logging/logging.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/relay_messages.dart';
import 'package:noports_core/src/srvd/isolates/port_pair_isolate.dart';
import 'package:noports_core/src/srvd/isolates/relay_worker.dart';
import 'package:noports_core/src/srvd/isolates/shared_single_port_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'log_capture.dart';
import 'noports_harness.dart';

const _alice = NoPortsHarness.clientAtSign;
const _bob = NoPortsHarness.daemonAtSign;

/// A relay worker made by [create], logging at every level to the records it
/// returns, with the main isolate's end of its ports; closed after the test.
({W worker, StreamIterator<dynamic> fromWorker, List<LogRecord> records})
_worker<W extends RelayWorker>(W Function(SendPort toMain) create) {
  final handler = AtSignLogger.defaultLoggingHandler;
  final rootLevel = AtSignLogger.root_level;
  final toMain = ReceivePort();
  final worker = create(toMain.sendPort);
  AtSignLogger.defaultLoggingHandler = handler;
  AtSignLogger.root_level = rootLevel;
  addTearDown(() {
    worker.fromMain.close();
    toMain.close();
  });
  final records = <LogRecord>[];
  worker.logger.logger.onRecord.listen(records.add);
  worker.logger.level = 'all';
  return (worker: worker, fromWorker: StreamIterator(toMain), records: records);
}

/// What a port-pair worker logs when srvd's main isolate has it start the
/// session [params] describes.
Future<List<LogRecord>> _portPairWorkerStarting(
  SrvdSessionParams params,
) async {
  final (:worker, :fromWorker, :records) = _worker(
    (toMain) => PortPairWorker(
      toMain: toMain,
      logTraffic: false,
      verbose: true,
      loggingTag: 'request logs',
      relayAuthDetectWindowMs: 500,
    ),
  );
  addTearDown(() => worker.connector?.close());
  expect(await fromWorker.moveNext(), isTrue);
  (fromWorker.current as SendPort).send(IIRequest.create('start', params));
  expect(await fromWorker.moveNext(), isTrue);
  expect(
    fromWorker.current,
    isA<(int, int)>(),
    reason: 'the worker starts the session and reports its ports',
  );
  return records;
}

/// What the single-port worker logs when srvd's main isolate has it start
/// the session [params] describes.
Future<List<LogRecord>> _singlePortWorkerStarting(
  SrvdSessionParams params,
) async {
  final (:worker, :fromWorker, :records) = _worker(
    (toMain) => SinglePortWorker(
      toMain: toMain,
      logTraffic: false,
      verbose: true,
      loggingTag: 'request logs',
      address: '127.0.0.1',
      useTLS: false,
      bindPort: 0,
    ),
  );
  addTearDown(() => worker.sessions[params.sessionId]?.connector?.close());
  expect(await fromWorker.moveNext(), isTrue);
  (fromWorker.current as SendPort).send(IIRequest.create('start', params));
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!records.any((r) => r.message.contains(params.sessionId))) {
    if (DateTime.now().isAfter(deadline)) {
      fail('The single-port worker did not start ${params.sessionId}');
    }
    await Future.delayed(const Duration(milliseconds: 20));
  }
  return records;
}

/// A session request from the client atSign for [sessionId], carrying
/// [relayAuthAesKey], as sshnp and npt send it.
String _relayRequest(String sessionId, String relayAuthAesKey) => jsonEncode(
  RelayRequest(
    sessionId: sessionId,
    atSignA: _alice,
    atSignB: _bob,
    authenticateSocketA: true,
    authenticateSocketB: true,
    clientNonce: 'client-nonce',
    relayAuthMode: RelayAuthMode.escr,
    relayAuthAesKey: relayAuthAesKey,
    only443: false,
    multipleAcksOk: true,
    preFetch: [],
    sendJsonResponse: true,
  ).toJson(),
);

/// Sends [value] to the relay as [client]'s session request.
Future<void> _requestPorts(AtClient client, String value) =>
    client.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey()
          ..key = '${NoPortsHarness.device}.request_ports.${Srvd.namespace}'
          ..sharedBy = client.getCurrentAtSign()
          ..sharedWith = NoPortsHarness.relayAtSign
          ..metadata = (Metadata()
            ..namespaceAware = false
            ..ttl = 10000),
        value: value,
      ),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
    );

void main() {
  final capture = LogCapture.install();

  group('Given srvd logging at every level,', () {
    test('when it receives a session request carrying a relay-auth key, then'
        ' the log names the session and its atSigns, and no log line contains'
        ' the key.', () async {
      final harness = NoPortsHarness.create();
      final relay = await harness.startRelay();
      relay.logger.level = 'all';
      final alice = await harness.openClient(
        _alice,
        namespace: DefaultArgs.namespace,
      );
      final sessionId = Uuid().v4();
      final key = generateAes256Key();
      final response = alice.notificationService
          .subscribe(
            regex: '$sessionId.${Srvd.namespace}@',
            shouldDecrypt: true,
          )
          .where((n) => n.from == NoPortsHarness.relayAtSign)
          .first
          .timeout(const Duration(seconds: 10));

      await _requestPorts(alice, _relayRequest(sessionId, key));
      await response;
      final params = relay.sessions[sessionId]!.params;
      expect(params.relayAuthAesKey, key);

      final portPairWorker = await _portPairWorkerStarting(params);
      final singlePortWorker = await _singlePortWorkerStarting(params);
      final logs = {
        'srvd': capture.records.toList(),
        'its port-pair worker': portPairWorker,
        'its single-port worker': singlePortWorker,
      };

      expect(
        {
          for (final MapEntry(key: from, value: records) in logs.entries)
            from: recordsHoldingKey(records, key),
        }..removeWhere((_, holding) => holding.isEmpty),
        isEmpty,
        reason: 'no line srvd or its workers log holds the relay-auth key',
      );
      for (final MapEntry(key: from, value: records) in logs.entries) {
        expect(
          records.map((r) => r.message),
          contains(
            allOf(contains(sessionId), contains(_alice), contains(_bob)),
          ),
          reason: 'the log from $from names the session and its atSigns',
        );
      }
    });
  });

  group('Given srvd logging at every level', () {
    test('when it receives a session request cut short partway through its'
        ' relay-auth key, then the log says it could not read the request from'
        ' its sender, and no log line contains any of the key', () async {
      final harness = NoPortsHarness.create();
      final relay = await harness.startRelay();
      relay.logger.level = 'all';
      final alice = await harness.openClient(
        _alice,
        namespace: DefaultArgs.namespace,
      );
      final key = generateAes256Key();
      final request = _relayRequest(Uuid().v4(), key);

      await _requestPorts(
        alice,
        request.substring(0, request.indexOf(key) + key.length - 4),
      );
      await capture.waitFor(
        'refusing the request',
        (r) => r.message.contains('Unable to provide the socket pair'),
      );

      expect(
        recordsHoldingKey(capture.records, key),
        isEmpty,
        reason: 'no line srvd logs holds any of the relay-auth key',
      );
      expect(
        capture.records.map((r) => r.message),
        contains(
          allOf(
            contains('could not be read'),
            contains(_alice),
            contains('FormatException'),
          ),
        ),
        reason: "the log names the sender and the error's type",
      );
    });

    test('when a relay worker is handed a request it does not handle, carrying'
        " a session's params, then no log line contains the session's"
        ' relay-auth key', () async {
      final key = generateAes256Key();
      final (:worker, :fromWorker, :records) = _worker(
        (toMain) => SinglePortWorker(
          toMain: toMain,
          logTraffic: false,
          verbose: true,
          loggingTag: 'request logs',
          address: '127.0.0.1',
          useTLS: false,
          bindPort: 0,
        ),
      );
      expect(await fromWorker.moveNext(), isTrue);

      (fromWorker.current as SendPort).send(
        IIRequest.create(
          'no-such-request',
          SrvdSessionParams(
            sessionId: Uuid().v4(),
            atSignA: _alice,
            atSignB: _bob,
            authenticateSocketA: true,
            authenticateSocketB: true,
            rvdNonce: 'rvd-nonce',
            relayAuthMode: RelayAuthMode.escr,
            relayAuthAesKey: key,
            only443: true,
            multipleAcksOk: true,
            preFetch: [],
            sendJsonResponse: true,
          ),
        ),
      );
      await worker.stopped.future.timeout(const Duration(seconds: 10));

      expect(
        recordsHoldingKey([...records, ...capture.records], key),
        isEmpty,
        reason: "no line the worker logs holds the session's relay-auth key",
      );
      expect(
        records.map((r) => r.message),
        contains(
          allOf(contains('Received unhandled request'), contains(_alice)),
        ),
        reason: 'the worker logs the request it does not handle',
      );
    });
  });
}
