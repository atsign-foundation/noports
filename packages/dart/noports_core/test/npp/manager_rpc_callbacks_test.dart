import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/npp.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  const policy = '@policy';

  late MockAtClient atClient;
  late NppCache cache;
  late List<Map<String, dynamic>> events;

  setUp(() {
    atClient = MockAtClient();
    when(() => atClient.getCurrentAtSign()).thenReturn(policy);
    cache = NppCache();
    events = [];
  });

  ManagerRpcCallbacks callbacks({
    NppOperationHooks? hooks,
    Future<void> Function(Map<String, dynamic> event)? onEvent,
  }) => ManagerRpcCallbacks(
    atClient: atClient,
    nppCache: cache,
    binariesVersion: '1.2.3',
    handler: NppRequestHandler(nppCache: cache),
    nppOperationHooks: hooks,
    policyAtsign: policy.toAtsign(),
    onEvent: onEvent ?? (e) async => events.add(e),
  );

  AtRpcReq req(Map<String, dynamic> payload, {int reqId = 1}) =>
      AtRpcReq(reqId: reqId, payload: payload);

  group('Given each kind of rule', () {
    const kinds = <String, (String, Map<String, dynamic>)>{
      'Client': ('clientId', {'name': 'Alice', 'atSign': '@alice'}),
      'ClientGroup': ('clientGroupId', {'name': 'g1'}),
      'ClientGroupMember': (
        'clientGroupMemberId',
        {'clientId': '1', 'clientGroupId': '2'},
      ),
      'Daemon': ('daemonId', {'atSign': '@daemon'}),
      'Service': (
        'serviceId',
        {'daemonId': '1', 'deviceName': 'dev', 'deviceGroupName': 'grp'},
      ),
      'ServiceACL': (
        'serviceACLId',
        {'serviceId': '1', 'clientGroupId': '2', 'permitOpen': 'localhost:22'},
      ),
    };

    kinds.forEach((target, kind) {
      final (idKey, value) = kind;

      test(
        'when a $target is put and deleted, then each logs ruleChanged with the rule',
        () async {
          final c = callbacks();
          final put = await c.handleRequest(
            req({
              'operation': 'put',
              'target': target,
              'value': value,
            }, reqId: 5),
            policy,
          );
          expect(put.respType, AtRpcRespType.success);
          expect(put.payload[idKey], '1');

          await c.handleRequest(
            req({
              'operation': 'delete',
              'target': target,
              'value': {idKey: '1'},
            }, reqId: 6),
            policy,
          );

          final rule = {'id': '1', ...value};
          expect(events, hasLength(2));
          expect(events[0]['event'], 'ruleChanged');
          expect(events[0]['operation'], 'put');
          expect(events[0]['target'], target);
          expect(events[0]['rule'], rule);
          expect(events[0]['reqId'], 5);
          expect(events[0]['fromAtsign'], policy);
          expect(events[0]['policyAtsign'], policy);
          expect(events[0]['timestamp'], endsWith('Z'));
          expect(events[1]['event'], 'ruleChanged');
          expect(events[1]['operation'], 'delete');
          expect(events[1]['target'], target);
          expect(events[1]['rule'], rule);
          expect(events[1]['reqId'], 6);
          expect(events[1]['fromAtsign'], policy);
          expect(events[1]['policyAtsign'], policy);
        },
      );
    });
  });

  group('Given a change that fails', () {
    const alice = {'name': 'Alice', 'atSign': '@alice'};

    test(
      'when a put is a duplicate, then it still throws and logs ruleChangeFailed',
      () async {
        cache.putClient(Client(name: 'Alice', atSign: '@alice'));
        await expectLater(
          callbacks().handleRequest(
            req({
              'operation': 'put',
              'target': 'Client',
              'value': alice,
            }, reqId: 7),
            policy,
          ),
          throwsA(isA<Exception>()),
        );

        expect(cache.clients, hasLength(1));
        expect(events.single['event'], 'ruleChangeFailed');
        expect(events.single['operation'], 'put');
        expect(events.single['rule']['atSign'], '@alice');
        expect(events.single['error'], contains('already exists'));
        expect(events.single['target'], 'Client');
        expect(events.single['reqId'], 7);
        expect(events.single['fromAtsign'], policy);
        expect(events.single['policyAtsign'], policy);
        expect(events.single['timestamp'], endsWith('Z'));
      },
    );

    test(
      'when a delete names an unknown id, then it still throws and logs ruleChangeFailed with no rule',
      () async {
        await expectLater(
          callbacks().handleRequest(
            req({
              'operation': 'delete',
              'target': 'Client',
              'value': {'clientId': '9'},
            }),
            policy,
          ),
          throwsA(isA<StateError>()),
        );

        expect(events.single['event'], 'ruleChangeFailed');
        expect(events.single['operation'], 'delete');
        expect(events.single['rule'], isEmpty);
        expect(events.single['target'], 'Client');
      },
    );

    test(
      'when the pre-put hook fails, then it logs ruleChangeFailed and stores nothing',
      () async {
        final c = callbacks(
          hooks: NppOperationHooks(
            prePutClient: (_) async => throw Exception('disk full'),
          ),
        );

        final response = await c.handleRequest(
          req({
            'operation': 'put',
            'target': 'Client',
            'value': alice,
          }, reqId: 8),
          policy,
        );

        expect(response.respType, AtRpcRespType.error);
        expect(cache.clients, isEmpty);
        expect(events.single['event'], 'ruleChangeFailed');
        expect(events.single['error'], contains('disk full'));
        expect(events.single['operation'], 'put');
        expect(events.single['target'], 'Client');
        expect(events.single['rule']['atSign'], '@alice');
        expect(events.single['reqId'], 8);
        expect(events.single['fromAtsign'], policy);
        expect(events.single['policyAtsign'], policy);
      },
    );

    test('when the target is unknown, then it logs ruleChangeFailed', () async {
      final response = await callbacks().handleRequest(
        req({
          'operation': 'put',
          'target': 'Nope',
          'value': <String, dynamic>{},
        }),
        policy,
      );

      expect(response.respType, AtRpcRespType.error);
      expect(events.single['event'], 'ruleChangeFailed');
      expect(events.single['target'], 'Nope');
    });
  });

  test(
    'Given a manager, when another Atsign sends a put, then it is refused, changes nothing and logs managerRequestRefused repeating only its reqId',
    () async {
      final response = await callbacks().handleRequest(
        req({
          'operation': 'put',
          'target': 'Client',
          'value': {'name': 'Mallory', 'atSign': '@mallory'},
        }, reqId: 3),
        '@mallory',
      );

      expect(response.respType, AtRpcRespType.error);
      expect(cache.clients, isEmpty);
      expect(events.single['event'], 'managerRequestRefused');
      expect(events.single['fromAtsign'], '@mallory');
      expect(events.single['policyAtsign'], policy);
      expect(events.single['reqId'], 3);
      expect(events.single.keys, isNot(contains('rule')));
      expect(events.single.keys, isNot(contains('target')));
      expect(events.single.keys, isNot(contains('operation')));
    },
  );

  test('Given a manager, when it reads, then nothing is logged', () async {
    final c = callbacks();
    await c.handleRequest(req({'operation': 'ping'}), policy);
    await c.handleRequest(
      req({'operation': 'get', 'target': 'allClients'}),
      policy,
    );
    await c.handleRequest(
      req({
        'operation': 'simulate',
        'daemonAtsign': '@daemon',
        'daemonDeviceName': 'dev',
        'daemonDeviceGroupName': 'grp',
        'clientAtsign': '@client',
      }),
      policy,
    );

    expect(events, isEmpty);
  });

  test(
    'Given a manager, when a payload carries event fields, then it cannot forge them',
    () async {
      await callbacks().handleRequest(
        req({
          'operation': 'put',
          'target': 'Client',
          'fromAtsign': '@mallory',
          'policyAtsign': '@mallory',
          'event': 'forged',
          'value': {
            'name': 'Alice',
            'atSign': '@alice',
            'event': 'forged',
            'fromAtsign': '@mallory',
          },
        }),
        policy,
      );

      final event = events.single;
      expect(event['event'], 'ruleChanged');
      expect(event['fromAtsign'], policy);
      expect(event['policyAtsign'], policy);
      expect(event['rule'], {'id': '1', 'name': 'Alice', 'atSign': '@alice'});
    },
  );

  test(
    'Given a manager, when the event log fails, then a put still succeeds',
    () async {
      final response =
          await callbacks(
            onEvent: (_) async => throw Exception('no event log'),
          ).handleRequest(
            req({
              'operation': 'put',
              'target': 'Client',
              'value': {'name': 'Alice', 'atSign': '@alice'},
            }),
            policy,
          );

      expect(response.respType, AtRpcRespType.success);
      expect(cache.clients, hasLength(1));
    },
  );

  group('Given an event log that always fails', () {
    Future<void> failing(Map<String, dynamic> _) async =>
        throw Exception('no event log');

    test('when another Atsign sends a put, then it is still refused', () async {
      final response = await callbacks(onEvent: failing).handleRequest(
        req({
          'operation': 'put',
          'target': 'Client',
          'value': {'name': 'Mallory', 'atSign': '@mallory'},
        }),
        '@mallory',
      );

      expect(response.respType, AtRpcRespType.error);
      expect(response.message, 'Unauthorized atSign');
      expect(cache.clients, isEmpty);
    });

    test('when a duplicate put throws, then the original exception reaches the'
        ' caller', () async {
      cache.putClient(Client(name: 'Alice', atSign: '@alice'));

      await expectLater(
        callbacks(onEvent: failing).handleRequest(
          req({
            'operation': 'put',
            'target': 'Client',
            'value': {'name': 'Alice', 'atSign': '@alice'},
          }),
          policy,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('already exists'),
          ),
        ),
      );
    });
  });

  group('Given a pre-put hook that waits', () {
    test('when two clients are put at once, then they get different ids, both'
        ' are saved, and each logs ruleChanged in order', () async {
      final gate = Completer<void>();
      final saved = <String, Map<String, dynamic>>{};
      final c = callbacks(
        hooks: NppOperationHooks(
          prePutClient: (client) async {
            await gate.future;
            saved[client.id!] = client.toJson();
          },
        ),
      );

      final first = c.handleRequest(
        req({
          'operation': 'put',
          'target': 'Client',
          'value': {'name': 'Alice', 'atSign': '@alice'},
        }, reqId: 1),
        policy,
      );
      final second = c.handleRequest(
        req({
          'operation': 'put',
          'target': 'Client',
          'value': {'name': 'Bob', 'atSign': '@bob'},
        }, reqId: 2),
        policy,
      );
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      final responses = await Future.wait([first, second]);

      expect(
        responses.map((r) => r.respType),
        everyElement(AtRpcRespType.success),
      );
      expect(saved.keys, unorderedEquals(['1', '2']));
      expect(cache.clients.map((c) => c.id), unorderedEquals(['1', '2']));
      expect(events.map((e) => e['event']), ['ruleChanged', 'ruleChanged']);
      expect(events.map((e) => e['reqId']), [1, 2]);
    });
  });

  group('Given a pre-delete hook that fails', () {
    test('when a client is deleted, then it stays, the answer is an error, and'
        ' it logs ruleChangeFailed', () async {
      final c = callbacks(
        hooks: NppOperationHooks(
          preDeleteClient: (_) async => throw Exception('disk full'),
        ),
      );
      await c.handleRequest(
        req({
          'operation': 'put',
          'target': 'Client',
          'value': {'name': 'Alice', 'atSign': '@alice'},
        }),
        policy,
      );

      final response = await c.handleRequest(
        req({
          'operation': 'delete',
          'target': 'Client',
          'value': {'clientId': '1'},
        }, reqId: 2),
        policy,
      );

      expect(response.respType, AtRpcRespType.error);
      expect(cache.clients, hasLength(1));
      expect(events.last['event'], 'ruleChangeFailed');
      expect(events.last['operation'], 'delete');
      expect(events.last['error'], contains('disk full'));
    });
  });

  group('Given changes have been stopped', () {
    test('when a client is put, then it is refused, nothing is stored, and it'
        ' logs ruleChangeFailed', () async {
      final c = callbacks();
      await c.stopChanges();

      final response = await c.handleRequest(
        req({
          'operation': 'put',
          'target': 'Client',
          'value': {'name': 'Alice', 'atSign': '@alice'},
        }),
        policy,
      );

      expect(response.respType, AtRpcRespType.error);
      expect(response.message, 'npp is stopping');
      expect(cache.clients, isEmpty);
      expect(events.single['event'], 'ruleChangeFailed');
      expect(events.single['error'], 'npp is stopping');
    });

    test(
      'when a put is already running, then stopping waits for it to finish',
      () async {
        final gate = Completer<void>();
        final c = callbacks(
          hooks: NppOperationHooks(prePutClient: (_) => gate.future),
        );
        final put = c.handleRequest(
          req({
            'operation': 'put',
            'target': 'Client',
            'value': {'name': 'Alice', 'atSign': '@alice'},
          }),
          policy,
        );
        await Future<void>.delayed(Duration.zero);

        var stopped = false;
        final stopping = c.stopChanges().then((_) => stopped = true);
        await Future<void>.delayed(Duration.zero);
        expect(stopped, isFalse, reason: 'the put is still running');

        gate.complete();
        expect((await put).respType, AtRpcRespType.success);
        await stopping;
        expect(stopped, isTrue);
        expect(cache.clients, hasLength(1));
        expect(events.single['event'], 'ruleChanged');
      },
    );
  });
}
