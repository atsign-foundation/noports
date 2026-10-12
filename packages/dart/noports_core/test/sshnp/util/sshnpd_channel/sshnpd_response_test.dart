import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';
import 'sshnpd_channel_mocks.dart';

void main() {
  group("Given a client waiting for @daemon's response to its session request",
      () {
    const daemon = '@daemon';
    const device = 'my_device1';
    const namespace = '$device.sshnp';

    late String sessionId;
    late StreamController<AtNotification> notifications;
    late List<AtNotification> delivered;
    late List<Object> uncaught;
    late List<Completer<SshnpdAck>> payloads;
    late StubbedSshnpdChannel channel;

    setUp(() {
      sessionId = Uuid().v4();
      notifications = StreamController<AtNotification>.broadcast();
      delivered = [];
      uncaught = [];
      payloads = [];
      final params = MockSshnpParams();
      when(() => params.verbose).thenReturn(false);
      when(() => params.device).thenReturn(device);
      when(() => params.clientAtSign).thenReturn('@client');
      when(() => params.sshnpdAtSign).thenReturn(daemon);
      registerFallbackValue(AtKey());
      final atClient = MockAtClient();
      when(() => atClient.get(any())).thenThrow(AtKeyNotFoundException('none'));
      channel = StubbedSshnpdChannel(
        atClient: atClient,
        params: params,
        sessionId: sessionId,
        namespace: namespace,
        notify: (_, __,
                {required checkForFinalDeliveryStatus,
                required waitForFinalDeliveryStatus,
                required ttln,
                maxTries = 3}) async =>
            NotificationResult(),
        // Delivers what the regex matches, as at_client does.
        subscribe: ({regex, shouldDecrypt = false}) => notifications.stream
            .where((n) => RegExp(regex ?? '').hasMatch(n.key))
            .map((n) {
          delivered.add(n);
          return n;
        }),
        // Each response's payload resolves when the test completes it.
        handleSshnpdPayload: (_) {
          final payload = Completer<SshnpdAck>();
          payloads.add(payload);
          return payload.future;
        },
      );
    });

    tearDown(() => notifications.close());

    /// Starts listening for the daemon's response, recording any error that
    /// escapes the listener.
    Future<void> listen() async {
      await runZonedGuarded(channel.initialize, (e, _) => uncaught.add(e));
    }

    AtNotification response({String from = daemon, String value = '{}'}) =>
        AtNotification(
          Uuid().v4(),
          '$sessionId.$namespace$from',
          from,
          '@client',
          1,
          'key',
          true,
          value: value,
        );

    /// A signed response envelope whose payload names session [id].
    String envelopeFor(String id) => jsonEncode({
          'signature': 'c2lnbmF0dXJl',
          'hashingAlgo': 'sha256',
          'signingAlgo': 'rsa2048',
          'payload': {'sessionId': id},
        });

    Future<void> send(AtNotification n) async {
      notifications.add(n);
      await pumpEventQueue();
    }

    test('when @daemon responds, then the client acts on that response',
        () async {
      await listen();
      final answer = channel.waitForDaemonResponse(maxWaitMillis: 1000);

      await send(response());
      payloads.single.complete(SshnpdAck.acknowledged);

      expect(await answer, SshnpdAck.acknowledged);
      expect(delivered, hasLength(1));
      expect(uncaught, isEmpty);
    });

    test(
        'when @daemon2 sends a response for the session, then the client\'s'
        " subscription doesn't deliver it, and the client keeps waiting",
        () async {
      await listen();
      final answer = channel.waitForDaemonResponse(maxWaitMillis: 200);

      await send(response(from: '@daemon2'));

      expect(delivered, isEmpty);
      expect(payloads, isEmpty);
      expect(await answer, SshnpdAck.notAcknowledged);
    });

    test(
        'when @daemon responds twice, then the client acts on the first'
        ' response and ignores the second', () async {
      await listen();
      final answer = channel.waitForDaemonResponse(maxWaitMillis: 1000);

      await send(response());
      payloads.single.complete(SshnpdAck.acknowledged);
      await pumpEventQueue();
      await send(response());
      for (final payload in payloads.skip(1)) {
        payload.complete(SshnpdAck.acknowledgedWithErrors);
      }
      await pumpEventQueue();

      expect(await answer, SshnpdAck.acknowledged);
      expect(payloads, hasLength(1), reason: 'the second is never read');
      expect(channel.sshnpdAck, SshnpdAck.acknowledged);
      expect(uncaught, isEmpty);
    });

    test(
        'when a daemon-signed response for another session arrives first, then'
        " the client ignores it, keeps waiting, and acts on its own session's"
        ' response', () async {
      await listen();
      final answer = channel.waitForDaemonResponse(maxWaitMillis: 1000);

      await send(response(value: envelopeFor(Uuid().v4())));
      expect(payloads, isEmpty, reason: "another session's response is not read");
      await send(response(value: envelopeFor(sessionId)));
      payloads.single.complete(SshnpdAck.acknowledged);

      expect(await answer, SshnpdAck.acknowledged);
      expect(delivered, hasLength(2));
      expect(uncaught, isEmpty);
    });

    test("when its own session's response arrives, then the client acts on it",
        () async {
      await listen();
      final answer = channel.waitForDaemonResponse(maxWaitMillis: 1000);

      await send(response(value: envelopeFor(sessionId)));
      payloads.single.complete(SshnpdAck.acknowledged);

      expect(await answer, SshnpdAck.acknowledged);
    });

    test(
        'when reading the session keys or the event-logging config fails, then'
        ' the client reports the response as failed at once', () async {
      await listen();
      final started = DateTime.now();
      final answer = channel.waitForDaemonResponse(maxWaitMillis: 5000);

      await send(response(value: envelopeFor(sessionId)));
      payloads.single.completeError(Exception('cannot decrypt'));

      expect(await answer, SshnpdAck.acknowledgedWithErrors);
      expect(DateTime.now().difference(started).inMilliseconds, lessThan(2000),
          reason: 'the client does not wait out its timeout');
      expect(channel.errorReceived, isNotNull);
      expect(uncaught, isEmpty);
    });

    test(
        'when a second response arrives while the first is still being'
        ' verified, then the client acts on the first, and the second changes'
        ' nothing', () async {
      await listen();
      final answer = channel.waitForDaemonResponse(maxWaitMillis: 1000);

      await send(response());
      await send(response());
      for (final payload in payloads.skip(1)) {
        payload.complete(SshnpdAck.acknowledgedWithErrors);
      }
      payloads.first.complete(SshnpdAck.acknowledged);
      await pumpEventQueue();

      expect(await answer, SshnpdAck.acknowledged);
      expect(payloads, hasLength(1), reason: 'the second is never read');
      expect(channel.sshnpdAck, SshnpdAck.acknowledged);
      expect(uncaught, isEmpty);
    });
  });
}
