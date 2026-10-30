import 'package:at_client/at_client.dart';
import 'package:at_commons/atsign.dart';
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

  group('each kind of rule', () {
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
        '$target: put and delete each log ruleChanged with the rule',
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
        },
      );
    });
  });

  group('a failed change', () {
    const alice = {'name': 'Alice', 'atSign': '@alice'};

    test('a duplicate put still throws, and logs ruleChangeFailed', () async {
      cache.putClient(Client(name: 'Alice', atSign: '@alice'));
      await expectLater(
        callbacks().handleRequest(
          req({'operation': 'put', 'target': 'Client', 'value': alice}),
          policy,
        ),
        throwsA(isA<Exception>()),
      );

      expect(cache.clients, hasLength(1));
      expect(events.single['event'], 'ruleChangeFailed');
      expect(events.single['operation'], 'put');
      expect(events.single['rule']['atSign'], '@alice');
      expect(events.single['error'], contains('already exists'));
    });

    test('a delete of an unknown id still throws, and logs ruleChangeFailed'
        ' with no rule', () async {
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
    });

    test(
      'a failed pre-put hook logs ruleChangeFailed and stores nothing',
      () async {
        final c = callbacks(
          hooks: NppOperationHooks(
            prePutClient: (_) async => throw Exception('disk full'),
          ),
        );

        final response = await c.handleRequest(
          req({'operation': 'put', 'target': 'Client', 'value': alice}),
          policy,
        );

        expect(response.respType, AtRpcRespType.error);
        expect(cache.clients, isEmpty);
        expect(events.single['event'], 'ruleChangeFailed');
        expect(events.single['error'], contains('disk full'));
      },
    );

    test('an unknown target logs ruleChangeFailed', () async {
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

  test('another Atsign is refused, changes nothing, and logs'
      ' managerRequestRefused without repeating its request', () async {
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
  });

  test('reads log nothing', () async {
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

  test('a payload cannot forge an event\'s fields', () async {
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
  });

  test('a failing event log does not change the answer', () async {
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
  });
}
