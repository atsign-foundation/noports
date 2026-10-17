import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/relay_messages.dart';
import 'package:noports_core/src/srvd/isolates/port_pair_isolate.dart';
import 'package:noports_core/src/srvd/isolates/relay_worker.dart';
import 'package:noports_core/src/srvd/isolates/shared_single_port_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'log_capture.dart';
import 'noports_harness.dart';

const _alice = NoPortsHarness.clientAtSign;
const _bob = NoPortsHarness.daemonAtSign;
const _relayLogger = ' srvd main ';

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
/// [relayAuthAesKey], as sshnp and npt send it, or as older clients which
/// can't take several acknowledgements do unless [multipleAcksOk].
String _relayRequest(
  String sessionId,
  String relayAuthAesKey, {
  bool multipleAcksOk = true,
}) => jsonEncode(
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
    multipleAcksOk: multipleAcksOk,
    preFetch: [],
    sendJsonResponse: true,
  ).toJson(),
);

/// Sends [value] to the relay as [client]'s session request.
Future<void> _requestPorts(AtClient client, String value) =>
    _notifyRelay(client, 'request_ports', value);

/// Sends [value] to the relay as [client]'s notification of type [type].
Future<void> _notifyRelay(AtClient client, String type, String value) =>
    client.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey()
          ..key = '${NoPortsHarness.device}.$type.${Srvd.namespace}'
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

class _MockAtClient extends Mock implements AtClient {}

/// An srvd whose atClient fails, which allocates no real ports.
class _FailingSrvd extends SrvdImpl {
  _FailingSrvd(AtClient atClient)
    : super(
        atClient: atClient,
        atSign: NoPortsHarness.relayAtSign.toAtsign(),
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        logTraffic: false,
        verbose: false,
        bind443: false,
        localBindPort443: 443,
        relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
        signingKeyCheckInterval: Duration.zero,
      );

  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async {
    final port = ReceivePort();
    addTearDown(port.close);
    return ((1, 2), Isolate.current, port.sendPort);
  }
}

void main() {
  final capture = LogCapture.install();

  group('Given srvd logging at every level,', () {
    test('when it receives a session request carrying a relay-auth key,'
        ' whether it starts the session or its handling fails unexpectedly,'
        ' then the log names the session and its atSigns, and no log line'
        ' contains the key.', () async {
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
      final starting = capture.records.toList();
      final portPairWorker = await _portPairWorkerStarting(params);
      final singlePortWorker = await _singlePortWorkerStarting(params);

      final failingSessionId = Uuid().v4();
      final failingKey = generateAes256Key();
      final failingFrom = capture.records.length;
      final atClient = _MockAtClient();
      when(
        () => atClient.getCurrentAtSign(),
      ).thenThrow(StateError('the atClient has no atSign'));
      await (_FailingSrvd(atClient)..logger.level = 'all').notificationHandler(
        AtNotification(
          Uuid().v4(),
          '${NoPortsHarness.relayAtSign}:${NoPortsHarness.device}'
              '.request_ports.${Srvd.namespace}$_alice',
          _alice,
          NoPortsHarness.relayAtSign,
          DateTime.now().millisecondsSinceEpoch,
          'key',
          true,
          value: _relayRequest(
            failingSessionId,
            failingKey,
            multipleAcksOk: false,
          ),
        ),
      );
      final allRecords = [
        ...capture.records,
        ...portPairWorker,
        ...singlePortWorker,
      ];

      expect(
        {
          'starting the session': recordsHoldingKey(allRecords, key),
          'failing unexpectedly': recordsHoldingKey(allRecords, failingKey),
        }..removeWhere((_, holding) => holding.isEmpty),
        isEmpty,
        reason: 'no line srvd or its workers log holds a relay-auth key',
      );
      for (final (from, messages, session) in [
        (
          'srvd starting the session',
          messagesFrom(starting, _relayLogger),
          sessionId,
        ),
        (
          'its port-pair worker',
          [for (final r in portPairWorker) r.message],
          sessionId,
        ),
        (
          'its single-port worker',
          [for (final r in singlePortWorker) r.message],
          sessionId,
        ),
        (
          'srvd failing unexpectedly',
          messagesFrom(capture.records.skip(failingFrom), _relayLogger),
          failingSessionId,
        ),
      ]) {
        expect(
          messages,
          contains(allOf(contains(session), contains(_alice), contains(_bob))),
          reason: 'the log from $from names the session and its atSigns',
        );
      }
    });

    test("when it receives a session request it can't read, cut short"
        ' partway through its relay-auth key, then the log names the'
        " request's sender and the error's type, and no log line contains any"
        ' of the key.', () async {
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
        messagesFrom(capture.records, _relayLogger),
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

    test("when it receives a notification of a type it doesn't handle, then"
        ' the log names the type and its sender, and no log line contains the'
        " notification's value.", () async {
      final harness = NoPortsHarness.create();
      final relay = await harness.startRelay();
      relay.logger.level = 'all';
      final alice = await harness.openClient(
        _alice,
        namespace: DefaultArgs.namespace,
      );
      final requestValue = generateAes256Key();
      await _notifyRelay(alice, 'some_request', requestValue);
      await capture.waitFor(
        'reading the some_request',
        (r) => r.message.contains('unknown "some_request"'),
      );

      final sessionId = Uuid().v4();
      final response = alice.notificationService
          .subscribe(
            regex: '$sessionId.${Srvd.namespace}@',
            shouldDecrypt: true,
          )
          .where((n) => n.from == NoPortsHarness.relayAtSign)
          .first
          .timeout(const Duration(seconds: 10));
      await _requestPorts(alice, _relayRequest(sessionId, generateAes256Key()));
      await response;
      final sessionsValue = generateAes256Key();
      await relay.handleSessionMessages(
        'other.$sessionId',
        AtNotification(
          Uuid().v4(),
          '${NoPortsHarness.relayAtSign}:other.$sessionId.sessions'
              '.${Srvd.namespace}$_bob',
          _bob,
          NoPortsHarness.relayAtSign,
          DateTime.now().millisecondsSinceEpoch,
          'key',
          true,
          value: sessionsValue,
        ),
      );

      expect(
        {
          'an unknown request': recordsHoldingKey(
            capture.records,
            requestValue,
          ),
          'an unknown sessions message': recordsHoldingKey(
            capture.records,
            sessionsValue,
          ),
        }..removeWhere((_, holding) => holding.isEmpty),
        isEmpty,
        reason: "no line srvd logs holds the notification's value",
      );
      expect(
        messagesFrom(capture.records, _relayLogger),
        containsAll([
          allOf(contains('some_request'), contains(_alice)),
          allOf(contains('"other"'), contains(_bob)),
        ]),
        reason: 'the log names each type and its sender',
      );
    });
  });
}
