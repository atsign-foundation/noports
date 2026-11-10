import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/npa.dart';
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

    /// The rules the members, services and service ACLs above name.
    void putNamedRules() => cache
      ..putClient(Client(id: '1', name: 'Carol', atSign: '@carol'))
      ..putClientGroup(ClientGroup(id: '2', name: 'g0'))
      ..putDaemon(Daemon(id: '1', atSign: '@named'))
      ..putService(
        Service(
          id: '1',
          daemonId: '1',
          deviceName: 'named',
          deviceGroupName: 'grp',
        ),
      );

    kinds.forEach((target, kind) {
      final (idKey, value) = kind;

      test(
        'when a $target is put and deleted, then each logs ruleChanged with the rule',
        () async {
          putNamedRules();
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
          final String id = put.payload[idKey];

          await c.handleRequest(
            req({
              'operation': 'delete',
              'target': target,
              'value': {idKey: id},
            }, reqId: 6),
            policy,
          );

          final rule = {'id': id, ...value};
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
      'when a delete names an unknown id, then it is answered with an error and logs ruleChangeFailed with no rule',
      () async {
        final response = await callbacks().handleRequest(
          req({
            'operation': 'delete',
            'target': 'Client',
            'value': {'clientId': '9'},
          }),
          policy,
        );

        expect(response.respType, AtRpcRespType.error);
        expect(response.message, 'No Client with id 9, so nothing is deleted.');
        expect(events.single['event'], 'ruleChangeFailed');
        expect(events.single['error'], response.message);
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
      expect(event['rule'], {
        'id': cache.clients.single.id,
        'name': 'Alice',
        'atSign': '@alice',
      });
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
      final ids = cache.clients.map((c) => c.id).toSet();
      expect(ids, hasLength(2));
      expect(saved.keys, unorderedEquals(ids));
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
      final put = await c.handleRequest(
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
          'value': {'clientId': put.payload['clientId']},
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

  /// The key each kind of rule's id goes under, in a put's answer and in a
  /// delete's value.
  const idKeys = {
    'Client': 'clientId',
    'ClientGroup': 'clientGroupId',
    'ClientGroupMember': 'clientGroupMemberId',
    'Daemon': 'daemonId',
    'Service': 'serviceId',
    'ServiceACL': 'serviceACLId',
  };

  Future<AtRpcResp> putValue(
    ManagerRpcCallbacks c,
    String target,
    Map<String, dynamic> value, {
    int reqId = 1,
  }) => c.handleRequest(
    req({'operation': 'put', 'target': target, 'value': value}, reqId: reqId),
    policy,
  );

  /// Puts [value] as a [target] and returns the id npp gave it.
  Future<String> putRule(
    ManagerRpcCallbacks c,
    String target,
    Map<String, dynamic> value,
  ) async {
    final response = await putValue(c, target, value);
    expect(
      response.respType,
      AtRpcRespType.success,
      reason: 'putting $target $value: ${response.message}',
    );
    return response.payload[idKeys[target]!] as String;
  }

  Future<AtRpcResp> deleteRule(
    ManagerRpcCallbacks c,
    String target,
    String id, {
    int reqId = 1,
  }) => c.handleRequest(
    req({
      'operation': 'delete',
      'target': target,
      'value': {idKeys[target]!: id},
    }, reqId: reqId),
    policy,
  );

  /// Hooks keeping [stored] as the set of saved rules, each as `Kind:id`.
  NppOperationHooks storing(Set<String> stored) => NppOperationHooks(
    prePutClient: (r) async => stored.add('Client:${r.id}'),
    prePutClientGroup: (r) async => stored.add('ClientGroup:${r.id}'),
    prePutClientGroupMember: (r) async =>
        stored.add('ClientGroupMember:${r.id}'),
    prePutDaemon: (r) async => stored.add('Daemon:${r.id}'),
    prePutService: (r) async => stored.add('Service:${r.id}'),
    prePutServiceACL: (r) async => stored.add('ServiceACL:${r.id}'),
    preDeleteClient: (r) async => stored.remove('Client:${r.id}'),
    preDeleteClientGroup: (r) async => stored.remove('ClientGroup:${r.id}'),
    preDeleteClientGroupMember: (r) async =>
        stored.remove('ClientGroupMember:${r.id}'),
    preDeleteDaemon: (r) async => stored.remove('Daemon:${r.id}'),
    preDeleteService: (r) async => stored.remove('Service:${r.id}'),
    preDeleteServiceACL: (r) async => stored.remove('ServiceACL:${r.id}'),
  );

  /// Puts alice in groups admins and ops, with service dev on @daemon open to
  /// admins at localhost:22 and to ops at localhost:2222. Returns each rule's
  /// id by name, and clears [events].
  Future<Map<String, String>> putPolicy(ManagerRpcCallbacks c) async {
    final ids = <String, String>{};
    ids['alice'] = await putRule(c, 'Client', {
      'name': 'Alice',
      'atSign': '@alice',
    });
    ids['admins'] = await putRule(c, 'ClientGroup', {'name': 'admins'});
    ids['ops'] = await putRule(c, 'ClientGroup', {'name': 'ops'});
    ids['aliceAdmins'] = await putRule(c, 'ClientGroupMember', {
      'clientId': ids['alice'],
      'clientGroupId': ids['admins'],
    });
    ids['aliceOps'] = await putRule(c, 'ClientGroupMember', {
      'clientId': ids['alice'],
      'clientGroupId': ids['ops'],
    });
    ids['daemon'] = await putRule(c, 'Daemon', {'atSign': '@daemon'});
    ids['dev'] = await putRule(c, 'Service', {
      'daemonId': ids['daemon'],
      'deviceName': 'dev',
      'deviceGroupName': 'grp',
    });
    ids['admins22'] = await putRule(c, 'ServiceACL', {
      'serviceId': ids['dev'],
      'clientGroupId': ids['admins'],
      'permitOpen': 'localhost:22',
    });
    ids['ops2222'] = await putRule(c, 'ServiceACL', {
      'serviceId': ids['dev'],
      'clientGroupId': ids['ops'],
      'permitOpen': 'localhost:2222',
    });
    events.clear();
    return ids;
  }

  Iterable<String?> idsOf(Iterable<PolicyEntry> rules) =>
      rules.map((r) => r.id);

  Future<List<String>> permitOpenFor(String clientAtsign) async =>
      (await NppRequestHandler(nppCache: cache).doAuthCheck(
        NPAAuthCheckRequest(
          daemonAtsign: '@daemon',
          daemonDeviceName: 'dev',
          daemonDeviceGroupName: 'grp',
          clientAtsign: clientAtsign,
        ),
      )).permitOpen;

  group('Given a client who is a member of two groups', () {
    test('when the client is deleted, then its memberships are deleted with it'
        ' and both groups remain', () async {
      final c = callbacks();
      final ids = await putPolicy(c);

      final response = await deleteRule(c, 'Client', ids['alice']!, reqId: 4);

      expect(response.respType, AtRpcRespType.success);
      expect(cache.clients, isEmpty);
      expect(cache.clientGroupMembers, isEmpty);
      expect(
        idsOf(cache.clientGroups),
        unorderedEquals([ids['admins'], ids['ops']]),
      );
      expect(response.payload['removed'], [
        {'target': 'ClientGroupMember', 'id': ids['aliceAdmins']},
        {'target': 'ClientGroupMember', 'id': ids['aliceOps']},
      ]);
      expect(
        events.map((e) => (e['event'], e['target'], e['rule']['id'])),
        [
          ('ruleChanged', 'ClientGroupMember', ids['aliceAdmins']),
          ('ruleChanged', 'ClientGroupMember', ids['aliceOps']),
          ('ruleChanged', 'Client', ids['alice']),
        ],
      );
      expect(events.map((e) => e['reqId']), everyElement(4));
      expect(events.map((e) => e['operation']), everyElement('delete'));
    });
  });

  group('Given a group with members and service ACLs', () {
    test('when the group is deleted, then its memberships and service ACLs are'
        ' deleted with it and the clients and services remain', () async {
      final c = callbacks();
      final ids = await putPolicy(c);

      final response = await deleteRule(
        c,
        'ClientGroup',
        ids['admins']!,
        reqId: 5,
      );

      expect(response.respType, AtRpcRespType.success);
      expect(idsOf(cache.clientGroups), [ids['ops']]);
      expect(idsOf(cache.clientGroupMembers), [ids['aliceOps']]);
      expect(idsOf(cache.serviceACLs), [ids['ops2222']]);
      expect(idsOf(cache.clients), [ids['alice']]);
      expect(idsOf(cache.services), [ids['dev']]);
      expect(response.payload['removed'], [
        {'target': 'ClientGroupMember', 'id': ids['aliceAdmins']},
        {'target': 'ServiceACL', 'id': ids['admins22']},
      ]);
      expect(
        events.map((e) => (e['event'], e['target'], e['rule']['id'])),
        [
          ('ruleChanged', 'ClientGroupMember', ids['aliceAdmins']),
          ('ruleChanged', 'ServiceACL', ids['admins22']),
          ('ruleChanged', 'ClientGroup', ids['admins']),
        ],
      );
      expect(events.map((e) => e['reqId']), everyElement(5));
      expect(events.map((e) => e['operation']), everyElement('delete'));
    });
  });

  group('Given a service with service ACLs', () {
    test('when the service is deleted, then its service ACLs are deleted with'
        ' it and the daemon remains', () async {
      final c = callbacks();
      final ids = await putPolicy(c);

      final response = await deleteRule(c, 'Service', ids['dev']!);

      expect(response.respType, AtRpcRespType.success);
      expect(cache.services, isEmpty);
      expect(cache.serviceACLs, isEmpty);
      expect(idsOf(cache.daemons), [ids['daemon']]);
      expect(cache.clientGroupMembers, hasLength(2));
    });
  });

  group('Given a daemon that a service names', () {
    test('when the daemon is deleted, then the delete is refused, the answer'
        ' says how many services name it, and nothing is changed or stored',
        () async {
      final stored = <String>{};
      final c = callbacks(hooks: storing(stored));
      final ids = await putPolicy(c);
      final storedBefore = Set.of(stored);

      final response = await deleteRule(c, 'Daemon', ids['daemon']!);

      expect(response.respType, AtRpcRespType.error);
      expect(response.message, contains('1 service'));
      expect(idsOf(cache.daemons), [ids['daemon']]);
      expect(idsOf(cache.services), [ids['dev']]);
      expect(cache.serviceACLs, hasLength(2));
      expect(stored, storedBefore);
      expect(events.single['event'], 'ruleChangeFailed');
    });
  });

  group('Given a daemon no service names', () {
    test('when the daemon is deleted, then it is deleted', () async {
      final c = callbacks();
      final daemon = await putRule(c, 'Daemon', {'atSign': '@daemon'});

      final response = await deleteRule(c, 'Daemon', daemon);

      expect(response.respType, AtRpcRespType.success);
      expect(cache.daemons, isEmpty);
    });
  });

  group('Given a membership', () {
    test('when it is deleted, then the client and the group remain', () async {
      final c = callbacks();
      final ids = await putPolicy(c);

      final response = await deleteRule(
        c,
        'ClientGroupMember',
        ids['aliceAdmins']!,
      );

      expect(response.respType, AtRpcRespType.success);
      expect(idsOf(cache.clientGroupMembers), [ids['aliceOps']]);
      expect(idsOf(cache.clients), [ids['alice']]);
      expect(
        idsOf(cache.clientGroups),
        unorderedEquals([ids['admins'], ids['ops']]),
      );
    });
  });

  group("Given a pre-delete hook that fails for a client's second membership",
      () {
    test('when the client is deleted, then the answer is an error, the client'
        ' and that membership stay in the cache and in storage, the first'
        ' membership stays deleted, and deleting the client again removes the'
        ' rest', () async {
      final stored = <String>{};
      final hooks = storing(stored);
      var membershipDeletes = 0;
      var failSecond = true;
      hooks.preDeleteClientGroupMember = (r) async {
        membershipDeletes++;
        if (failSecond && membershipDeletes == 2) {
          throw Exception('disk full');
        }
        stored.remove('ClientGroupMember:${r.id}');
      };
      final c = callbacks(hooks: hooks);
      final ids = await putPolicy(c);

      final first = await deleteRule(c, 'Client', ids['alice']!);

      expect(first.respType, AtRpcRespType.error);
      expect(first.message, contains('disk full'));
      expect(idsOf(cache.clients), [ids['alice']]);
      expect(idsOf(cache.clientGroupMembers), [ids['aliceOps']]);
      expect(stored, contains('Client:${ids['alice']}'));
      expect(stored, contains('ClientGroupMember:${ids['aliceOps']}'));
      expect(stored, isNot(contains('ClientGroupMember:${ids['aliceAdmins']}')));

      failSecond = false;
      final second = await deleteRule(c, 'Client', ids['alice']!);

      expect(second.respType, AtRpcRespType.success);
      expect(cache.clients, isEmpty);
      expect(cache.clientGroupMembers, isEmpty);
      expect(stored, isNot(contains('Client:${ids['alice']}')));
      expect(stored, isNot(contains('ClientGroupMember:${ids['aliceOps']}')));
    });
  });

  group("Given a pre-delete hook that fails for a service's second service ACL",
      () {
    test('when the service is deleted, then the answer is an error, the service'
        ' and that service ACL stay in the cache and in storage, the first'
        ' service ACL stays deleted, and deleting the service again removes the'
        ' rest', () async {
      final stored = <String>{};
      final hooks = storing(stored);
      var serviceACLDeletes = 0;
      var failSecond = true;
      hooks.preDeleteServiceACL = (r) async {
        serviceACLDeletes++;
        if (failSecond && serviceACLDeletes == 2) {
          throw Exception('disk full');
        }
        stored.remove('ServiceACL:${r.id}');
      };
      final c = callbacks(hooks: hooks);
      final ids = await putPolicy(c);

      final first = await deleteRule(c, 'Service', ids['dev']!);

      expect(first.respType, AtRpcRespType.error);
      expect(first.message, contains('disk full'));
      expect(idsOf(cache.services), [ids['dev']]);
      expect(idsOf(cache.serviceACLs), [ids['ops2222']]);
      expect(stored, contains('Service:${ids['dev']}'));
      expect(stored, contains('ServiceACL:${ids['ops2222']}'));
      expect(stored, isNot(contains('ServiceACL:${ids['admins22']}')));

      failSecond = false;
      final second = await deleteRule(c, 'Service', ids['dev']!);

      expect(second.respType, AtRpcRespType.success);
      expect(cache.services, isEmpty);
      expect(cache.serviceACLs, isEmpty);
      expect(stored, isNot(contains('Service:${ids['dev']}')));
      expect(stored, isNot(contains('ServiceACL:${ids['ops2222']}')));
    });
  });

  group('Given the client with the highest id was deleted', () {
    test('when a new client is put, then its id is one no rule has had and it'
        ' is a member of no group', () async {
      final c = callbacks();
      final ids = await putPolicy(c);
      await deleteRule(c, 'Client', ids['alice']!);

      final bob = await putRule(c, 'Client', {'name': 'Bob', 'atSign': '@bob'});

      expect(ids.values, isNot(contains(bob)));
      expect(cache.getClientGroupMembersByClientId(bob), isEmpty);
      expect(await permitOpenFor('@bob'), isEmpty);
    });
  });

  group('Given a group, a service and a daemon, each the highest id of its kind'
      ' and each deleted', () {
    test('when a new one of each kind is put, then each gets an id no rule of'
        ' its kind has had', () async {
      final c = callbacks();
      final group = await putRule(c, 'ClientGroup', {'name': 'g1'});
      final daemon = await putRule(c, 'Daemon', {'atSign': '@daemon'});
      final service = await putRule(c, 'Service', {
        'daemonId': daemon,
        'deviceName': 'dev',
        'deviceGroupName': 'grp',
      });
      await deleteRule(c, 'Service', service);
      await deleteRule(c, 'ClientGroup', group);
      await deleteRule(c, 'Daemon', daemon);
      expect(cache.clientGroups, isEmpty);
      expect(cache.daemons, isEmpty);

      final newDaemon = await putRule(c, 'Daemon', {'atSign': '@daemon2'});
      final newService = await putRule(c, 'Service', {
        'daemonId': newDaemon,
        'deviceName': 'other',
        'deviceGroupName': 'grp',
      });
      final newGroup = await putRule(c, 'ClientGroup', {'name': 'g2'});

      expect(newGroup, isNot(group));
      expect(newDaemon, isNot(daemon));
      expect(newService, isNot(service));
    });
  });

  group('Given a membership and a service ACL, each the highest id of its'
      ' kind and each deleted', () {
    test('when a new one of each kind is put, then each gets an id no rule of'
        ' its kind has had', () async {
      final c = callbacks();
      final ids = await putPolicy(c);
      await deleteRule(c, 'ClientGroupMember', ids['aliceOps']!);
      await deleteRule(c, 'ServiceACL', ids['ops2222']!);

      final membership = await putRule(c, 'ClientGroupMember', {
        'clientId': ids['alice'],
        'clientGroupId': ids['ops'],
      });
      final serviceACL = await putRule(c, 'ServiceACL', {
        'serviceId': ids['dev'],
        'clientGroupId': ids['ops'],
        'permitOpen': 'localhost:2222',
      });

      expect(membership, isNot(anyOf(ids['aliceAdmins'], ids['aliceOps'])));
      expect(serviceACL, isNot(anyOf(ids['admins22'], ids['ops2222'])));
    });
  });

  group('Given a put that names its own id', () {
    test('when it is handled, then it is refused and nothing is stored',
        () async {
      final stored = <String>{};
      final c = callbacks(hooks: storing(stored));
      final alice = await putRule(c, 'Client', {
        'name': 'Alice',
        'atSign': '@alice',
      });
      final group = await putRule(c, 'ClientGroup', {'name': 'g1'});
      final daemon = await putRule(c, 'Daemon', {'atSign': '@daemon'});
      final service = await putRule(c, 'Service', {
        'daemonId': daemon,
        'deviceName': 'dev',
        'deviceGroupName': 'grp',
      });
      final storedBefore = Set.of(stored);
      final named = <String, Map<String, dynamic>>{
        'Client': {'name': 'Bob', 'atSign': '@bob'},
        'ClientGroup': {'name': 'g2'},
        'ClientGroupMember': {'clientId': alice, 'clientGroupId': group},
        'Daemon': {'atSign': '@daemon2'},
        'Service': {
          'daemonId': daemon,
          'deviceName': 'other',
          'deviceGroupName': 'grp',
        },
        'ServiceACL': {
          'serviceId': service,
          'clientGroupId': group,
          'permitOpen': 'localhost:22',
        },
      };

      for (final MapEntry(key: target, value: value) in named.entries) {
        final response = await putValue(c, target, {'id': '7', ...value});
        expect(response.respType, AtRpcRespType.error, reason: target);
      }

      expect(stored, storedBefore);
      expect(cache.clients, hasLength(1));
      expect(cache.clientGroups, hasLength(1));
      expect(cache.clientGroupMembers, isEmpty);
      expect(cache.daemons, hasLength(1));
      expect(cache.services, hasLength(1));
      expect(cache.serviceACLs, isEmpty);
    });
  });

  group('Given a manager holds the id of a client that has since been deleted',
      () {
    test('when it puts a membership naming that id, then the put is refused and'
        ' nothing is stored', () async {
      final stored = <String>{};
      final c = callbacks(hooks: storing(stored));
      final alice = await putRule(c, 'Client', {
        'name': 'Alice',
        'atSign': '@alice',
      });
      final admins = await putRule(c, 'ClientGroup', {'name': 'admins'});
      await deleteRule(c, 'Client', alice);
      await putRule(c, 'Client', {'name': 'Bob', 'atSign': '@bob'});
      final storedBefore = Set.of(stored);

      final response = await putValue(c, 'ClientGroupMember', {
        'clientId': alice,
        'clientGroupId': admins,
      });

      expect(response.respType, AtRpcRespType.error);
      expect(stored, storedBefore);
      expect(cache.clientGroupMembers, isEmpty);
    });
  });

  group('Given no rule has a given id', () {
    test('when a membership, service or service ACL naming that id is put, then'
        ' the put is refused and nothing is stored', () async {
      final stored = <String>{};
      final c = callbacks(hooks: storing(stored));
      final alice = await putRule(c, 'Client', {
        'name': 'Alice',
        'atSign': '@alice',
      });
      final group = await putRule(c, 'ClientGroup', {'name': 'g1'});
      final daemon = await putRule(c, 'Daemon', {'atSign': '@daemon'});
      final service = await putRule(c, 'Service', {
        'daemonId': daemon,
        'deviceName': 'dev',
        'deviceGroupName': 'grp',
      });
      final storedBefore = Set.of(stored);
      const missing = 'no-such-id';
      final puts = <String, (String, Map<String, dynamic>)>{
        'membership naming a missing client': (
          'ClientGroupMember',
          {'clientId': missing, 'clientGroupId': group},
        ),
        'membership naming a missing group': (
          'ClientGroupMember',
          {'clientId': alice, 'clientGroupId': missing},
        ),
        'service naming a missing daemon': (
          'Service',
          {'daemonId': missing, 'deviceName': 'other', 'deviceGroupName': 'grp'},
        ),
        'service ACL naming a missing service': (
          'ServiceACL',
          {
            'serviceId': missing,
            'clientGroupId': group,
            'permitOpen': 'localhost:22',
          },
        ),
        'service ACL naming a missing group': (
          'ServiceACL',
          {
            'serviceId': service,
            'clientGroupId': missing,
            'permitOpen': 'localhost:22',
          },
        ),
      };

      for (final MapEntry(key: what, value: (target, value)) in puts.entries) {
        final response = await putValue(c, target, value);
        expect(response.respType, AtRpcRespType.error, reason: what);
        expect(response.message, contains(missing), reason: what);
      }

      expect(stored, storedBefore);
      expect(cache.clientGroupMembers, isEmpty);
      expect(cache.services, hasLength(1));
      expect(cache.serviceACLs, isEmpty);
    });
  });

  group('Given a put of a membership naming a client is waiting in its pre-put'
      ' hook', () {
    test('when the client is deleted, then the delete runs after the put and'
        ' removes that membership too', () async {
      final gate = Completer<void>();
      final hooks = NppOperationHooks();
      final c = callbacks(hooks: hooks);
      final alice = await putRule(c, 'Client', {
        'name': 'Alice',
        'atSign': '@alice',
      });
      final admins = await putRule(c, 'ClientGroup', {'name': 'admins'});
      hooks.prePutClientGroupMember = (_) => gate.future;
      final order = <String>[];

      final put = putValue(c, 'ClientGroupMember', {
        'clientId': alice,
        'clientGroupId': admins,
      }, reqId: 2).then((r) {
        order.add('put');
        return r;
      });
      await Future<void>.delayed(Duration.zero);
      final delete = deleteRule(c, 'Client', alice, reqId: 3).then((r) {
        order.add('delete');
        return r;
      });
      await Future<void>.delayed(Duration.zero);
      gate.complete();

      expect((await put).respType, AtRpcRespType.success);
      expect((await delete).respType, AtRpcRespType.success);
      expect(order, ['put', 'delete']);
      expect(cache.clients, isEmpty);
      expect(cache.clientGroupMembers, isEmpty);
    });
  });

  group("Given a pre-delete hook that waits while a client's memberships are"
      ' being deleted', () {
    test('when an auth check for that client runs during the wait, then it'
        ' grants no more than it did before the delete began', () async {
      final reached = Completer<void>();
      final gate = Completer<void>();
      final c = callbacks(
        hooks: NppOperationHooks(
          preDeleteClientGroupMember: (_) async {
            if (!reached.isCompleted) reached.complete();
            await gate.future;
          },
        ),
      );
      final ids = await putPolicy(c);
      final before = await permitOpenFor('@alice');
      expect(before, unorderedEquals(['localhost:22', 'localhost:2222']));

      final delete = deleteRule(c, 'Client', ids['alice']!);
      await Future.any([reached.future, delete]);
      expect(
        reached.isCompleted,
        isTrue,
        reason: 'the delete reaches the memberships before it finishes',
      );
      final during = await permitOpenFor('@alice');
      final clientIds = idsOf(cache.clients).toSet();

      expect(during, everyElement(isIn(before)));
      expect(
        cache.clientGroupMembers.map((m) => m.clientId),
        everyElement(isIn(clientIds)),
        reason: 'every membership names a client that exists',
      );
      gate.complete();
      expect((await delete).respType, AtRpcRespType.success);
      expect(await permitOpenFor('@alice'), isEmpty);
    });
  });
}
