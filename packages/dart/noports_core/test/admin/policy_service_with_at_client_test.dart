import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/admin.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  group('Given a policy store whose atSign is @policy', () {
    const policy = '@policy';

    late Map<String, StreamController<AtNotification>> subscriptions;
    late PolicyServiceWithAtClient store;
    late List<Object> uncaught;
    late List<Map> events;

    /// Delivers [n] to every subscription whose regex matches its key, as
    /// at_client does.
    Future<void> deliver(AtNotification n) async {
      for (final MapEntry(key: regex, value: subscription)
          in subscriptions.entries) {
        if (RegExp(regex).hasMatch(n.key)) subscription.add(n);
      }
      await pumpEventQueue();
    }

    AtNotification groupChange(String id, UserGroup? group,
            {String from = policy, String operation = 'update'}) =>
        AtNotification(
          'group-$id',
          '$policy:$id.groups.policy.sshnp$from',
          from,
          policy,
          1,
          'key',
          true,
          value: group == null ? null : jsonEncode(group),
          operation: operation,
        );

    AtNotification groupValue(String id, String? value) => AtNotification(
          'group-$id',
          '$policy:$id.groups.policy.sshnp$policy',
          policy,
          policy,
          1,
          'key',
          true,
          value: value,
          operation: 'update',
        );

    AtNotification log(String? value, {String from = policy}) =>
        AtNotification(
          'log',
          '$policy:123.logs.policy.sshnp$from',
          from,
          policy,
          2,
          'key',
          true,
          value: value,
        );

    AtNotification heartbeat(String? value, {String from = '@daemon'}) =>
        AtNotification(
          'heartbeat',
          '$policy:dev1.devices.policy.sshnp$from',
          from,
          policy,
          3,
          'key',
          true,
          value: value,
        );

    UserGroup admins(String id) => UserGroup(
          id: id,
          name: 'admins',
          description: 'may reach dev1',
          userAtSigns: ['@alice'],
          daemonAtSigns: ['@daemon'],
          devices: [
            Device(name: 'dev1', permitOpens: ['localhost:22']),
          ],
          deviceGroups: [],
        );

    String policyLog(String clientAtsign) => jsonEncode({
          'daemon': '@daemon',
          'timestamp': 2,
          'payload': {
            'request': {
              'payload': {
                'daemonDeviceName': 'dev1',
                'daemonDeviceGroupName': '',
                'clientAtsign': clientAtsign,
              },
            },
            'response': {
              'payload': {
                'authorized': true,
                'message': 'ok',
                'permitOpen': ['localhost:22'],
              },
            },
          },
        });

    setUp(() async {
      registerFallbackValue(AtKey());
      subscriptions = {};
      uncaught = [];
      events = [];
      final atClient = MockAtClient();
      final notificationService = MockNotificationService();
      when(() => atClient.getCurrentAtSign()).thenReturn(policy);
      when(() => atClient.notificationService)
          .thenReturn(notificationService);
      when(
        () => notificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer(
        (invocation) => subscriptions
            .putIfAbsent(
              invocation.namedArguments[#regex] as String,
              () => StreamController<AtNotification>.broadcast(),
            )
            .stream,
      );
      when(
        () => atClient.getAtKeys(
          regex: any(named: 'regex'),
          sharedBy: any(named: 'sharedBy'),
        ),
      ).thenAnswer((_) async => []);

      store = PolicyServiceWithAtClient(atClient: atClient);
      final started = Completer<void>();
      unawaited(runZonedGuarded(() async {
        await store.init();
        store.eventStream.listen((e) => events.add(jsonDecode(e)));
        started.complete();
      }, (e, _) => uncaught.add(e)));
      await started.future;
    });

    test('when @policy notifies a group change, then the store holds the group',
        () async {
      await deliver(groupChange('7', admins('7')));

      expect(store.groups.keys, ['7']);
      expect(await store.getGroupsForUser('@alice'), hasLength(1));
      expect(uncaught, isEmpty);
    });

    test(
        'when another atSign notifies a group change, then the store is '
        'unchanged', () async {
      await deliver(groupChange('7', admins('7'), from: '@carol'));

      expect(store.groups, isEmpty);
      expect(await store.getGroupsForUser('@alice'), isEmpty);
      expect(uncaught, isEmpty);
    });

    test('when another atSign notifies a group delete, then the group stays',
        () async {
      await deliver(groupChange('7', admins('7')));
      expect(store.groups.keys, ['7'], reason: 'control: @policy added it');

      await deliver(
        groupChange('7', null, from: '@carol', operation: 'delete'),
      );

      expect(store.groups.keys, ['7']);
      expect(uncaught, isEmpty);
    });

    test(
        "when @policy notifies a change whose value isn't a group, then the "
        'store is unchanged and still takes the next change', () async {
      for (final value in [null, 'not json', '[]', '{"name": "admins"}']) {
        await deliver(groupValue('7', value));
      }

      expect(store.groups, isEmpty);
      await deliver(groupChange('8', admins('8')));
      expect(store.groups.keys, ['8']);
      expect(uncaught, isEmpty);
    });

    test(
        'when another atSign notifies a policy log, then no log event is '
        'raised', () async {
      await deliver(log(policyLog('@carol'), from: '@carol'));

      expect(events, isEmpty);
      expect(store.logEvents, isEmpty);

      await deliver(log(policyLog('@alice')));
      expect(events.map((e) => e['type']), ['PolicyCheck'],
          reason: "control: @policy's own log raises one");
      expect(uncaught, isEmpty);
    });

    test(
        'when a log or device heartbeat arrives with no value, a value that '
        "isn't JSON, or JSON missing what it should hold, then the store "
        'still takes the next group change', () async {
      for (final value in [null, 'not json', '[]', '{}', '{"payload": 1}']) {
        await deliver(log(value));
        await deliver(heartbeat(value));
      }

      await deliver(groupChange('7', admins('7')));
      expect(store.groups.keys, ['7']);
      expect(store.logEvents, isEmpty);
      expect(uncaught, isEmpty);
    });

    test(
        'when another atSign sends a device heartbeat, then a daemon event '
        'naming it is raised', () async {
      await deliver(
        heartbeat(jsonEncode({'devicename': 'dev1', 'deviceGroupName': ''})),
      );

      expect(events, hasLength(1));
      expect(events.single['type'], 'DaemonHeartbeat');
      expect(events.single['daemon'], '@daemon');
      expect(uncaught, isEmpty);
    });
  });
}
