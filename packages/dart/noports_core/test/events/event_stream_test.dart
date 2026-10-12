import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/events.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  group('Given npevents listening on its event topic', () {
    late StreamController<AtNotification> notifications;
    late AtEventListenerService events;
    final config = AtEventConfig(
      atSign: '@events'.toAtsign(),
      topic: 'abcd1234.events.logging.sshnp',
      ttln: 60000,
    );

    setUp(() {
      notifications = StreamController<AtNotification>.broadcast();
      final notificationService = MockNotificationService();
      when(
        () => notificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer((_) => notifications.stream);
      final atClient = MockAtClient();
      when(() => atClient.notificationService).thenReturn(notificationService);
      events = AtEventListenerService(atClient: atClient);
    });

    tearDown(() => notifications.close());

    AtNotification event(String from, Object? payload) => AtNotification(
          Uuid().v4(),
          '@events:${config.topic}$from',
          from,
          '@events',
          1,
          'key',
          true,
          value: jsonEncode(
            AtEventEnvelope(
              payload: jsonEncode(payload),
              compressionScheme: CompressionScheme.zlib,
              encodingScheme: EncodingScheme.base2e15,
            ).toJson(),
          ),
        );

    test(
        "when @daemon sends a session event, then npevents prints the event"
        ' with an added "sender": "@daemon" field, and the event\'s own fields'
        ' unchanged', () async {
      final printed = events.getJsonStream(config).first;
      await pumpEventQueue();

      notifications.add(event('@daemon', {'sessionId': 's1', 'state': 'done'}));

      expect(
        jsonDecode(await printed),
        {'sessionId': 's1', 'state': 'done', 'sender': '@daemon'},
      );
    });

    test(
        "when an event's payload carries a sender naming another atSign, then"
        ' npevents prints the atSign the notification came from as its sender',
        () async {
      final printed = events.getJsonStream(config).first;
      await pumpEventQueue();

      notifications.add(event(
          '@daemon', {'sessionId': 's3', 'state': 'done', 'sender': '@other'}));

      expect(jsonDecode(await printed)['sender'], '@daemon');
    });

    test(
        "when an event's payload isn't a JSON object, then npevents skips it,"
        ' logs why, and keeps printing later events', () async {
      final printed = events.getJsonStream(config).first;
      await pumpEventQueue();

      notifications
        ..add(event('@daemon', ['not', 'an', 'object']))
        ..add(event('@relay', {'sessionId': 's2', 'state': 'connected'}));

      expect(
        jsonDecode(await printed),
        {'sessionId': 's2', 'state': 'connected', 'sender': '@relay'},
      );
    });
  });
}
