import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/src/npp/npp_persistence.dart'
    show nppPersistenceLogger;
import 'package:test/test.dart';

import '../harness/noports_harness.dart';
import '../sshnp/sshnp_mocks.dart';

void main() {
  const policy = '@policy';

  late Directory directory;
  late MockAtClient atClient;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('npp_persistence_test');
    atClient = MockAtClient();
    when(() => atClient.getCurrentAtSign()).thenReturn(policy);
  });

  tearDown(() => directory.delete(recursive: true));

  /// A manager RPC handler using [directory], as npp does with
  /// `--persistence-method file`.
  Future<ManagerRpcCallbacks> callbacks() async {
    final cache = await nppCacheFromFiles(policyDirectory: directory);
    return ManagerRpcCallbacks(
      atClient: atClient,
      nppCache: cache,
      binariesVersion: '1.2.3',
      handler: NppRequestHandler(nppCache: cache),
      nppOperationHooks: nppOperationHooksForFiles(policyDirectory: directory),
      policyAtsign: policy.toAtsign(),
      onEvent: (_) async {},
    );
  }

  Future<AtRpcResp> put(
    ManagerRpcCallbacks c,
    String target,
    Map<String, dynamic> value,
  ) => c.handleRequest(
    AtRpcReq(
      reqId: 1,
      payload: {'operation': 'put', 'target': target, 'value': value},
    ),
    policy,
  );

  /// The names of the files in [directory].
  List<String> savedFiles() =>
      directory.listSync().map((f) => f.uri.pathSegments.last).toList();

  const kinds = <(String, String, Map<String, dynamic>, Map<String, dynamic>)>[
    (
      'Client',
      'client',
      {'name': 'Alice', 'atSign': '@alice'},
      {'name': 'Mallory', 'atSign': '@mallory'},
    ),
    ('ClientGroup', 'client_group', {'name': 'g1'}, {'name': 'g2'}),
    (
      'ClientGroupMember',
      'client_group_member',
      {'clientId': 'named client', 'clientGroupId': 'named group'},
      {'clientId': 'named client', 'clientGroupId': 'named group'},
    ),
    ('Daemon', 'daemon', {'atSign': '@daemon'}, {'atSign': '@other'}),
    (
      'Service',
      'service',
      {
        'daemonId': 'named daemon',
        'deviceName': 'dev',
        'deviceGroupName': 'grp',
      },
      {
        'daemonId': 'named daemon',
        'deviceName': 'other',
        'deviceGroupName': 'grp',
      },
    ),
    (
      'ServiceACL',
      'service_acl',
      {
        'serviceId': 'named service',
        'clientGroupId': 'named group',
        'permitOpen': 'localhost:22',
      },
      {
        'serviceId': 'named service',
        'clientGroupId': 'named group',
        'permitOpen': 'localhost:9999',
      },
    ),
  ];

  /// The id npp gave the rule a successful put answers with.
  String idIn(AtRpcResp response) =>
      response.payload.values.whereType<String>().single;

  /// Puts the rules a member, service or service ACL in [kinds] names, and
  /// returns each one's id by the name [kinds] uses for it (`named client` …).
  Future<Map<String, String>> putNamedRules(ManagerRpcCallbacks c) async {
    final client = idIn(
      await put(c, 'Client', {'name': 'Carol', 'atSign': '@carol'}),
    );
    final group = idIn(await put(c, 'ClientGroup', {'name': 'g0'}));
    final daemon = idIn(await put(c, 'Daemon', {'atSign': '@named'}));
    final service = idIn(
      await put(c, 'Service', {
        'daemonId': daemon,
        'deviceName': 'named',
        'deviceGroupName': 'grp',
      }),
    );
    return {
      'named client': client,
      'named group': group,
      'named daemon': daemon,
      'named service': service,
    };
  }

  /// [value] with each rule name from [putNamedRules] swapped for its id.
  Map<String, dynamic> naming(
    Map<String, dynamic> value,
    Map<String, String> ids,
  ) => value.map((k, v) => MapEntry(k, ids[v] ?? v));

  group('Given a rule saved in a file', () {
    for (final (target, suffix, first, second) in kinds) {
      test('when a duplicate $target is put, then it is rejected and no second'
          ' file is saved', () async {
        final c = await callbacks();
        final value = naming(first, await putNamedRules(c));
        await put(c, target, value);
        final files = savedFiles();

        await expectLater(put(c, target, value), throwsA(isA<Exception>()));

        expect(savedFiles(), unorderedEquals(files));
      });

      test('when a $target with its id but other content is put, then it is'
          ' rejected and the saved rule is unchanged', () async {
        final c = await callbacks();
        final named = await putNamedRules(c);
        final value = naming(first, named);
        final id = idIn(await put(c, target, value));
        final files = savedFiles();

        final response = await put(c, target, {
          'id': id,
          ...naming(second, named),
        });

        expect(response.respType, AtRpcRespType.error);
        expect(savedFiles(), unorderedEquals(files));
        final saved = File('${directory.path}/${id}_$suffix.json');
        expect(jsonDecode(await saved.readAsString()), {'id': id, ...value});
      });
    }
  });

  /// The id key a delete of each kind of rule sends.
  const idKeys = {
    'Client': 'clientId',
    'ClientGroup': 'clientGroupId',
    'ClientGroupMember': 'clientGroupMemberId',
    'Daemon': 'daemonId',
    'Service': 'serviceId',
    'ServiceACL': 'serviceACLId',
  };

  Future<AtRpcResp> delete(ManagerRpcCallbacks c, String target, String id) =>
      c.handleRequest(
        AtRpcReq(
          reqId: 2,
          payload: {
            'operation': 'delete',
            'target': target,
            'value': {idKeys[target]!: id},
          },
        ),
        policy,
      );

  group('Given a rule saved in a file', () {
    for (final (target, _, first, _) in kinds) {
      test('when the $target is deleted, then its file is gone and it is not'
          ' loaded again', () async {
        final c = await callbacks();
        final named = await putNamedRules(c);
        final files = savedFiles();
        final id = idIn(await put(c, target, naming(first, named)));

        final response = await delete(c, target, id);

        expect(response.respType, AtRpcRespType.success);
        expect(savedFiles(), unorderedEquals(files));
        expect(
          ruleIds(await nppCacheFromFiles(policyDirectory: directory)),
          unorderedEquals(named.values),
        );
      });
    }
  });

  group('Given a rule saved on the atServer', () {
    late AtClient policyClient;

    setUp(() async {
      final harness = NoPortsHarness.create(atSigns: {policy});
      policyClient = await harness.openClient(policy, namespace: 'sshnp');
    });

    Future<NppCache> load() => nppCacheFromAtServer(
      atClient: policyClient,
      baseNamespace: 'sshnp',
      domainNamespace: 'npp',
    );

    /// A manager RPC handler saving to the atServer, as npp does with
    /// `--persistence-method atserver`.
    Future<ManagerRpcCallbacks> atServerCallbacks() async {
      final cache = await load();
      return ManagerRpcCallbacks(
        atClient: policyClient,
        nppCache: cache,
        binariesVersion: '1.2.3',
        handler: NppRequestHandler(nppCache: cache),
        nppOperationHooks: nppOperationHooksForAtServer(
          atClient: policyClient,
          domainNamespace: 'npp',
          baseNamespace: 'sshnp',
        ),
        policyAtsign: policy.toAtsign(),
        onEvent: (_) async {},
      );
    }

    for (final (target, _, first, _) in kinds) {
      test(
        'when the $target is deleted, then it is not loaded again',
        () async {
          final c = await atServerCallbacks();
          final named = await putNamedRules(c);
          final id = idIn(await put(c, target, naming(first, named)));
          expect(ruleIds(await load()), contains(id), reason: 'the put was saved');

          final response = await delete(c, target, id);

          expect(response.respType, AtRpcRespType.success);
          expect(ruleIds(await load()), unorderedEquals(named.values));
        },
      );
    }
  });

  /// A new, empty store of each kind npp can keep its rules in.
  Future<List<_Store>> newStores() async {
    final dir = await Directory.systemTemp.createTemp('npp_persistence_test');
    addTearDown(() => dir.delete(recursive: true));
    final harness = NoPortsHarness.create(atSigns: {policy});
    final policyClient = await harness.openClient(policy, namespace: 'sshnp');
    return [_FileStore(dir, atClient), _AtServerStore(policyClient)];
  }

  /// A manager RPC handler on the rules [store] holds now, as npp has after
  /// it starts.
  Future<ManagerRpcCallbacks> start(_Store store) async {
    final cache = await store.load();
    return ManagerRpcCallbacks(
      atClient: store.atClient,
      nppCache: cache,
      binariesVersion: '1.2.3',
      handler: NppRequestHandler(nppCache: cache),
      nppOperationHooks: store.hooks(),
      policyAtsign: policy.toAtsign(),
      onEvent: (_) async {},
    );
  }

  /// Puts [value] as a [target] and returns the id npp gave it.
  Future<String> putRule(
    ManagerRpcCallbacks c,
    String target,
    Map<String, dynamic> value,
  ) async {
    final response = await put(c, target, value);
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
    String id,
  ) => c.handleRequest(
    AtRpcReq(
      reqId: 2,
      payload: {
        'operation': 'delete',
        'target': target,
        'value': {idKeys[target]!: id},
      },
    ),
    policy,
  );

  /// The messages npp's rule loaders log at warning while [body] runs.
  Future<List<String>> warningsDuring(Future<void> Function() body) async {
    final logger = nppPersistenceLogger.logger;
    final level = logger.level;
    logger.level = Level.ALL;
    final warnings = <String>[];
    final subscription = logger.onRecord
        .where((r) => r.level == Level.WARNING)
        .listen((r) => warnings.add(r.message));
    try {
      await body();
    } finally {
      await subscription.cancel();
      logger.level = level;
    }
    return warnings;
  }

  group('Given each persistence method and a client with memberships', () {
    test('when the client is deleted and npp loads its rules again, then'
        ' neither the client nor its memberships are loaded', () async {
      for (final store in await newStores()) {
        final c = await start(store);
        final alice = await putRule(c, 'Client', {
          'name': 'Alice',
          'atSign': '@alice',
        });
        for (final name in ['admins', 'ops']) {
          final group = await putRule(c, 'ClientGroup', {'name': name});
          await putRule(c, 'ClientGroupMember', {
            'clientId': alice,
            'clientGroupId': group,
          });
        }

        final response = await deleteRule(c, 'Client', alice);

        expect(response.respType, AtRpcRespType.success, reason: store.name);
        final loaded = await store.load();
        expect(loaded.clients, isEmpty, reason: store.name);
        expect(loaded.clientGroupMembers, isEmpty, reason: store.name);
        expect(loaded.clientGroups, hasLength(2), reason: store.name);
        expect(await store.savedNames('client'), isEmpty, reason: store.name);
        expect(
          await store.savedNames('client_group_member'),
          isEmpty,
          reason: '${store.name}: membership rows left in storage',
        );
      }
    });
  });

  group('Given each persistence method and the client with the highest id'
      ' deleted', () {
    test('when npp loads its rules again and a new client is put, then its id'
        ' is one no rule has had', () async {
      for (final store in await newStores()) {
        if (store is _FileStore) {
          final had = await _inNewIsolate(
            store.directory.path,
            _putAndDeleteClient,
          );
          final bob = await _inNewIsolate(store.directory.path, _putClient);

          expect(had, isNot(contains(bob.single)), reason: store.name);
          continue;
        }
        final c = await start(store);
        final had = <String>{
          await putRule(c, 'ClientGroup', {'name': 'admins'}),
        };
        final alice = await putRule(c, 'Client', {
          'name': 'Alice',
          'atSign': '@alice',
        });
        had.add(alice);
        await deleteRule(c, 'Client', alice);

        final restarted = await start(store);
        final bob = await putRule(restarted, 'Client', {
          'name': 'Bob',
          'atSign': '@bob',
        });

        expect(had, isNot(contains(bob)), reason: store.name);
      }
    });
  });

  group("Given each persistence method and a stored membership naming a client"
      " that isn't stored", () {
    final cases = _missingReferenceCases();
    const rule = _rule;

    test('when npp loads its rules, then that membership is not loaded and a'
        ' warning names it', () async {
      for (final MapEntry(
            key: what,
            value: (stored: rules, :loads, :named),
          )
          in cases.entries) {
        for (final store in await newStores()) {
          final reason = '${store.name}: $what';
          for (final (kind, json) in rules) {
            await store.save(kind, json['id'] as String, json);
          }

          late NppCache loaded;
          final warnings = await warningsDuring(
            () async => loaded = await store.load(),
          );

          expect(ruleIds(loaded), unorderedEquals(loads), reason: reason);
          expect(
            warnings.where((w) => w.contains(rule) && w.contains(named)),
            isNotEmpty,
            reason: reason,
          );
        }
      }
    });
  });

  /// The targets of the kinds of rule npp can leave unloaded for naming a
  /// rule that isn't stored.
  const droppableTargets = {
    'client_group_member': 'ClientGroupMember',
    'service': 'Service',
    'service_acl': 'ServiceACL',
  };

  /// Whether [warning] is the load warning for the rule with id [id].
  bool warnsAbout(String warning, String id) =>
      warning.startsWith('Not loading ') && warning.contains('with id $id:');

  group("Given each persistence method and a stored rule naming a rule that"
      " isn't stored", () {
    test('when npp loads its rules, then that rule is not loaded and it is'
        ' still stored afterwards', () async {
      for (final MapEntry(key: what, value: (:stored, loads: _, named: _))
          in _missingReferenceCases().entries) {
        for (final store in await newStores()) {
          final reason = '${store.name}: $what';
          for (final (kind, json) in stored) {
            await store.save(kind, json['id'] as String, json);
          }
          final (kind, _) = stored.last;

          final loaded = await store.load();

          expect(ruleIds(loaded), isNot(contains(_rule)), reason: reason);
          expect(await store.savedNames(kind), contains(_rule),
              reason: reason);
        }
      }
    });

    test('when npp loads its rules, then the warning names where that rule is'
        ' stored and says deleting it there stops the warning', () async {
      for (final MapEntry(key: what, value: (:stored, loads: _, named: _))
          in _missingReferenceCases().entries) {
        for (final store in await newStores()) {
          final reason = '${store.name}: $what';
          for (final (kind, json) in stored) {
            await store.save(kind, json['id'] as String, json);
          }
          final (kind, _) = stored.last;

          final warnings = await warningsDuring(store.load);

          expect(
            warnings.where((w) => warnsAbout(w, _rule)),
            [store.storedAt(kind, _rule)],
            reason: reason,
          );
        }
      }
    });
  });

  group('Given each persistence method and a stored client group member or'
      ' service ACL that npp did not load because it names a rule that isn\'t'
      ' stored', () {
    test('when a manager deletes it by id, then the delete succeeds, its key'
        ' or file is gone, and the next load gives no warning for it',
        () async {
      final cases = _missingReferenceCases().entries.where(
        (c) => const {'client_group_member', 'service_acl'}
            .contains(c.value.stored.last.$1),
      );
      expect(cases, hasLength(5), reason: 'every member and ACL case');
      for (final MapEntry(key: what, value: (:stored, loads: _, named: _))
          in cases) {
        for (final store in await newStores()) {
          final reason = '${store.name}: $what';
          for (final (kind, json) in stored) {
            await store.save(kind, json['id'] as String, json);
          }
          final (kind, _) = stored.last;
          final c = await start(store);

          final response = await deleteRule(c, droppableTargets[kind]!, _rule);

          expect(response.respType, AtRpcRespType.success,
              reason: '$reason: ${response.message}');
          expect(await store.savedNames(kind), isNot(contains(_rule)),
              reason: reason);
          final again = await deleteRule(c, droppableTargets[kind]!, _rule);
          expect(again.message,
              'No ${droppableTargets[kind]} with id $_rule, so nothing is'
              ' deleted.',
              reason: '$reason: a second delete');
          final warnings = await warningsDuring(store.load);
          expect(warnings.where((w) => warnsAbout(w, _rule)), isEmpty,
              reason: reason);
        }
      }
    });
  });

  group('Given each persistence method and a stored service that npp did not'
      ' load because it names a daemon that isn\'t stored, with a service ACL'
      ' naming that service', () {
    test('when a manager deletes the service, then both are deleted from'
        ' storage and the answer lists the service ACL', () async {
      for (final store in await newStores()) {
        await store.save('client_group', 'g1', {'id': 'g1', 'name': 'g1'});
        await store.save('service', 's1', {
          'id': 's1',
          'daemonId': _missing,
          'deviceName': 'dev',
          'deviceGroupName': 'grp',
        });
        await store.save('service_acl', 'a1', {
          'id': 'a1',
          'serviceId': 's1',
          'clientGroupId': 'g1',
          'permitOpen': 'localhost:22',
        });
        final c = await start(store);

        final response = await deleteRule(c, 'Service', 's1');

        expect(response.respType, AtRpcRespType.success,
            reason: '${store.name}: ${response.message}');
        expect(await store.savedNames('service'), isEmpty, reason: store.name);
        expect(await store.savedNames('service_acl'), isEmpty,
            reason: store.name);
        expect(await store.savedNames('client_group'), ['g1'],
            reason: store.name);
        expect(
          response.payload['removed'],
          [
            {'target': 'ServiceACL', 'id': 'a1'},
          ],
          reason: store.name,
        );
      }
    });
  });

  group('Given each persistence method and a stored client group member or'
      ' service ACL that npp did not load, naming a client or client group'
      ' that it did load', () {
    test('when that client or client group is deleted, then the member or'
        ' service ACL is deleted from storage with it, and the answer lists'
        ' it', () async {
      final cases = <(String, String, String, List<(String, Map<String, dynamic>)>)>[
        (
          'Client',
          'c1',
          'client_group_member',
          [
            ('client', {'id': 'c1', 'name': 'Alice', 'atSign': '@alice'}),
            ('client_group_member', {
              'id': _rule,
              'clientId': 'c1',
              'clientGroupId': _missing,
            }),
          ],
        ),
        (
          'ClientGroup',
          'g1',
          'client_group_member',
          [
            ('client_group', {'id': 'g1', 'name': 'g1'}),
            ('client_group_member', {
              'id': _rule,
              'clientId': _missing,
              'clientGroupId': 'g1',
            }),
          ],
        ),
        (
          'ClientGroup',
          'g1',
          'service_acl',
          [
            ('client_group', {'id': 'g1', 'name': 'g1'}),
            ('service_acl', {
              'id': _rule,
              'serviceId': _missing,
              'clientGroupId': 'g1',
              'permitOpen': 'localhost:22',
            }),
          ],
        ),
      ];
      for (final (target, id, kind, stored) in cases) {
        for (final store in await newStores()) {
          final reason = '${store.name}: $target $id, $kind';
          for (final (k, json) in stored) {
            await store.save(k, json['id'] as String, json);
          }
          final c = await start(store);

          final response = await deleteRule(c, target, id);

          expect(response.respType, AtRpcRespType.success,
              reason: '$reason: ${response.message}');
          expect(await store.savedNames(kind), isEmpty, reason: reason);
          expect(
            response.payload['removed'],
            [
              {'target': droppableTargets[kind], 'id': _rule},
            ],
            reason: reason,
          );
        }
      }
    });
  });

  group('Given no rule of a kind has a given id, loaded or not', () {
    test('when a manager deletes that id, then the delete is answered "No'
        ' <Kind> with id <id>, so nothing is deleted." and nothing changes',
        () async {
      for (final store in await newStores()) {
        for (final (kind, json) in _missingReferenceCases()
            .values
            .expand((c) => c.stored)) {
          await store.save(kind, json['id'] as String, json);
        }
        Future<Map<String, List<String>>> saved() async => {
          for (final kind in _fileKindsInTest) kind: await store.savedNames(kind),
        };
        final before = await saved();
        final c = await start(store);

        for (final target in idKeys.keys) {
          final response = await deleteRule(c, target, 'nope');

          expect(response.respType, AtRpcRespType.error,
              reason: '${store.name}: $target');
          expect(response.message, 'No $target with id nope, so nothing is'
              ' deleted.', reason: '${store.name}: $target');
        }
        expect(await saved(), before, reason: store.name);
      }
    });
  });

  group('Given a rule npp did not load whose pre-delete hook fails', () {
    test('when a manager deletes it, then the answer is an error, the rule'
        ' stays stored and still deletable, and deleting it again removes it',
        () async {
      for (final store in await newStores()) {
        await store.save('client_group', 'g1', {'id': 'g1', 'name': 'g1'});
        await store.save('client_group_member', _rule, {
          'id': _rule,
          'clientId': _missing,
          'clientGroupId': 'g1',
        });
        final cache = await store.load();
        final hooks = store.hooks();
        final delete = hooks.preDeleteClientGroupMember!;
        var fail = true;
        hooks.preDeleteClientGroupMember = (member) async {
          if (fail) {
            fail = false;
            throw Exception('hook failed');
          }
          await delete(member);
        };
        final c = ManagerRpcCallbacks(
          atClient: store.atClient,
          nppCache: cache,
          binariesVersion: '1.2.3',
          handler: NppRequestHandler(nppCache: cache),
          nppOperationHooks: hooks,
          policyAtsign: policy.toAtsign(),
          onEvent: (_) async {},
        );

        final failed = await deleteRule(c, 'ClientGroupMember', _rule);

        expect(failed.respType, AtRpcRespType.error, reason: store.name);
        expect(await store.savedNames('client_group_member'), [_rule],
            reason: store.name);

        final retried = await deleteRule(c, 'ClientGroupMember', _rule);

        expect(retried.respType, AtRpcRespType.success,
            reason: '${store.name}: ${retried.message}');
        expect(await store.savedNames('client_group_member'), isEmpty,
            reason: store.name);
      }
    });
  });

  group('Given a policy directory holding a rule file named other than its id'
      ' and kind', () {
    test('when npp loads its rules, then that rule is not loaded and a warning'
        ' names the file', () async {
      const rules = <String, Map<String, dynamic>>{
        'client': {'id': '1', 'name': 'Alice', 'atSign': '@alice'},
        'client_group': {'id': '1', 'name': 'g1'},
        'client_group_member': {
          'id': '1',
          'clientId': 'none',
          'clientGroupId': 'none',
        },
        'daemon': {'id': '1', 'atSign': '@daemon'},
        'service': {
          'id': '1',
          'daemonId': 'none',
          'deviceName': 'dev',
          'deviceGroupName': 'grp',
        },
        'service_acl': {
          'id': '1',
          'serviceId': 'none',
          'clientGroupId': 'none',
          'permitOpen': 'localhost:22',
        },
      };
      for (final MapEntry(key: kind, value: json) in rules.entries) {
        await File(
          '${directory.path}/alice_$kind.json',
        ).writeAsString(jsonEncode(json));
      }

      final logger = nppPersistenceLogger.logger;
      final level = logger.level;
      logger.level = Level.ALL;
      final warnings = <String>[];
      final subscription = logger.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen((r) => warnings.add(r.message));
      late NppCache loaded;
      try {
        loaded = await nppCacheFromFiles(policyDirectory: directory);
      } finally {
        await subscription.cancel();
        logger.level = level;
      }

      expect(loaded.clients, isEmpty);
      expect(loaded.clientGroups, isEmpty);
      expect(loaded.clientGroupMembers, isEmpty);
      expect(loaded.daemons, isEmpty);
      expect(loaded.services, isEmpty);
      expect(loaded.serviceACLs, isEmpty);
      for (final kind in rules.keys) {
        expect(
          warnings.where((w) => w.contains('alice_$kind.json')),
          isNotEmpty,
          reason: 'a warning naming alice_$kind.json',
        );
      }
    });
  });

  group("Given each persistence method and a stored rule whose key or file"
      " name doesn't carry its id", () {
    test('when npp loads its rules, then that rule is not loaded and a warning'
        ' names it', () async {
      for (final store in await newStores()) {
        await store.save('client', 'alice', {
          'id': 'alice-id',
          'name': 'Alice',
          'atSign': '@alice',
        });
        await store.save('client', 'Bob-ID', {
          'id': 'Bob-ID',
          'name': 'Bob',
          'atSign': '@bob',
        });
        await store.save('client', 'carol-id', {
          'id': 'Carol-ID',
          'name': 'Carol',
          'atSign': '@carol',
        });
        await store.save('client', 'dave', {'name': 'Dave', 'atSign': '@dave'});

        late NppCache loaded;
        final warnings = await warningsDuring(
          () async => loaded = await store.load(),
        );

        expect(
          ruleIds(loaded),
          unorderedEquals(store.foldsNames ? ['Bob-ID', 'Carol-ID'] : ['Bob-ID']),
          reason: store.name,
        );
        expect(
          warnings.where((w) => w.contains('alice-id')),
          isNotEmpty,
          reason: store.name,
        );
        expect(
          warnings.where((w) => w.contains('dave')),
          isNotEmpty,
          reason: '${store.name}: a rule with no id',
        );
        if (!store.foldsNames) {
          expect(
            warnings.where((w) => w.contains('Carol-ID')),
            isNotEmpty,
            reason: store.name,
          );
        }
      }
    });
  });

  group("Given the policy atSign's atServer holds a `cached:`, `public:` or"
      " shared key in npp's namespace", () {
    test('when npp loads its rules from the atServer, then it loads only keys'
        ' the policy atSign owns, unshared, and skips the rest with a'
        ' warning', () async {
      const policy = '@policy';
      const other = '@other';
      final harness = NoPortsHarness.create(atSigns: {policy, other});
      final policyClient = await harness.openClient(policy, namespace: 'sshnp');
      final otherClient = await harness.openClient(other, namespace: 'sshnp');
      Map<String, dynamic> client(String id) =>
          {'id': id, 'name': id, 'atSign': '@$id'};

      await nppOperationHooksForAtServer(
        atClient: policyClient,
        domainNamespace: 'npp',
        baseNamespace: 'sshnp',
      ).prePutClient!(Client.fromJson(client('c0')));
      final cached = await otherClient.notificationService.notify(
        NotificationParams.forUpdate(
          AtKey()
            ..key = 'c1'
            ..namespace = 'client.npp.sshnp'
            ..sharedWith = policy
            ..sharedBy = other
            ..metadata = (Metadata()..ttr = 3600),
          value: jsonEncode(client('c1')),
        ),
        encryptValue: false,
      );
      expect(
        cached.notificationStatusEnum,
        NotificationStatusEnum.delivered,
        reason: 'notifying c1',
      );
      expect(
        await policyClient.put(
          AtKey.public('c2', namespace: 'client.npp.sshnp', sharedBy: policy)
              .build(),
          jsonEncode(client('c2')),
          putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
        ),
        isTrue,
        reason: 'saving a public key',
      );
      expect(
        await policyClient.put(
          AtKey()
            ..key = 'c3'
            ..namespace = 'client.npp.sshnp'
            ..sharedBy = policy
            ..sharedWith = other,
          jsonEncode(client('c3')),
          putRequestOptions: PutRequestOptions()
            ..shouldEncrypt = false
            ..useRemoteAtServer = true,
        ),
        isTrue,
        reason: 'saving a shared key',
      );
      harness.server[policy].storeAsIs(
        'c4.client.npp.sshnp@other',
        jsonEncode(client('c4')),
      );

      final logger = nppPersistenceLogger.logger;
      final level = logger.level;
      logger.level = Level.ALL;
      final warnings = <String>[];
      final subscription = logger.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen((r) => warnings.add(r.message));
      late NppCache loaded;
      try {
        loaded = await nppCacheFromAtServer(
          atClient: policyClient,
          baseNamespace: 'sshnp',
          domainNamespace: 'npp',
        );
      } finally {
        await subscription.cancel();
        logger.level = level;
      }

      expect(ruleIds(loaded), ['c0']);
      for (final skipped in [
        'cached:@policy:c1.client.npp.sshnp@other',
        'public:c2.client.npp.sshnp@policy',
        '@other:c3.client.npp.sshnp@policy',
        'c4.client.npp.sshnp@other',
      ]) {
        expect(
          warnings.where(
            (w) => w.contains(skipped) && w.contains('owns, unshared'),
          ),
          isNotEmpty,
          reason: 'a warning naming $skipped',
        );
      }
    });
  });
}

/// The ids of every rule [cache] holds.
List<String?> ruleIds(NppCache cache) => [
  ...cache.clients,
  ...cache.clientGroups,
  ...cache.clientGroupMembers,
  ...cache.daemons,
  ...cache.services,
  ...cache.serviceACLs,
].map((r) => r.id).toList();

/// Where npp keeps its rules, as `--persistence-method` chooses.
abstract class _Store {
  String get name;

  /// Whether names are folded, as atServer keys are, so `carol-id` names the
  /// rule `Carol-ID`.
  bool get foldsNames;
  AtClient get atClient;
  Future<NppCache> load();
  NppOperationHooks hooks();

  /// Saves [json] as a [kind] rule (`client`, `service_acl` …) under [name],
  /// as something other than npp's own hooks might.
  Future<void> save(String kind, String name, Map<String, dynamic> json);

  /// The names of the [kind] rules the store holds, read from the store
  /// itself rather than through npp's loader.
  Future<List<String>> savedNames(String kind);
  /// The end of npp's load warning for the [kind] rule stored under [name]:
  /// where it is stored and how to remove it.
  Matcher storedAt(String kind, String name);
}

class _FileStore implements _Store {
  final Directory directory;
  @override
  final AtClient atClient;

  _FileStore(this.directory, this.atClient);

  @override
  String get name => 'file';

  @override
  bool get foldsNames => false;

  @override
  Future<NppCache> load() => nppCacheFromFiles(policyDirectory: directory);

  @override
  NppOperationHooks hooks() =>
      nppOperationHooksForFiles(policyDirectory: directory);

  @override
  Future<void> save(String kind, String name, Map<String, dynamic> json) =>
      File('${directory.path}/${name}_$kind.json').writeAsString(
        jsonEncode(json),
      );

  @override
  Matcher storedAt(String kind, String name) => endsWith(
    'It is still stored, as the file ${directory.path}/${name}_$kind.json;'
    " delete it through npp's manager RPC, or delete that file, to stop this"
    ' warning.',
  );

  @override
  Future<List<String>> savedNames(String kind) async => directory
      .listSync()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.endsWith('_$kind.json'))
      .map((n) => n.substring(0, n.length - '_$kind.json'.length))
      .toList();
}

class _AtServerStore implements _Store {
  @override
  final AtClient atClient;

  _AtServerStore(this.atClient);

  @override
  String get name => 'atserver';

  @override
  bool get foldsNames => true;

  @override
  Future<NppCache> load() => nppCacheFromAtServer(
    atClient: atClient,
    baseNamespace: 'sshnp',
    domainNamespace: 'npp',
  );

  @override
  NppOperationHooks hooks() => nppOperationHooksForAtServer(
    atClient: atClient,
    domainNamespace: 'npp',
    baseNamespace: 'sshnp',
  );

  @override
  Future<void> save(String kind, String name, Map<String, dynamic> json) async {
    final bool saved = await atClient.put(
      AtKey()
        ..key = name
        ..namespace = '$kind.npp.sshnp'
        ..sharedBy = atClient.getCurrentAtSign(),
      jsonEncode(json),
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = true
        ..useRemoteAtServer = true,
    );
    expect(saved, isTrue, reason: 'saving $kind $name');
  }

  @override
  Matcher storedAt(String kind, String name) => allOf(
    contains('It is still stored, as the key '),
    contains('$name.$kind.npp.sshnp'),
    endsWith(
      "; delete it through npp's manager RPC, or delete that key, to stop"
      ' this warning.',
    ),
  );

  @override
  Future<List<String>> savedNames(String kind) async => [
    for (final AtKey key in await atClient.getAtKeys(
      regex: '.*\\.$kind\\.npp\\.sshnp',
      useRemoteAtServer: true,
    ))
      key.key.substring(0, key.key.length - '.$kind.npp'.length),
  ];
}

/// Runs [npp] in a new isolate, as a new npp process on the policy files in
/// [directory] would, and returns the ids it reports.
Future<List<String>> _inNewIsolate(
  String directory,
  Future<List<String>> Function(String directory) npp,
) => Isolate.run(() => npp(directory));

/// A manager RPC handler on the rules in [directory], as npp has after it
/// starts with `--persistence-method file`.
Future<ManagerRpcCallbacks> _startOnFiles(String directory) async {
  final cache = await nppCacheFromFiles(policyDirectory: Directory(directory));
  return ManagerRpcCallbacks(
    atClient: _PolicyAtClient(),
    nppCache: cache,
    binariesVersion: '1.2.3',
    handler: NppRequestHandler(nppCache: cache),
    nppOperationHooks: nppOperationHooksForFiles(
      policyDirectory: Directory(directory),
    ),
    policyAtsign: '@policy'.toAtsign(),
    onEvent: (_) async {},
  );
}

Future<String> _putOnFiles(
  ManagerRpcCallbacks c,
  String target,
  Map<String, dynamic> value,
) async {
  final response = await c.handleRequest(
    AtRpcReq(
      reqId: 1,
      payload: {'operation': 'put', 'target': target, 'value': value},
    ),
    '@policy',
  );
  return response.payload.values.whereType<String>().single;
}

/// Puts group admins and client alice, deletes alice, and returns both ids.
Future<List<String>> _putAndDeleteClient(String directory) async {
  final c = await _startOnFiles(directory);
  final group = await _putOnFiles(c, 'ClientGroup', {'name': 'admins'});
  final alice = await _putOnFiles(c, 'Client', {
    'name': 'Alice',
    'atSign': '@alice',
  });
  await c.handleRequest(
    AtRpcReq(
      reqId: 2,
      payload: {
        'operation': 'delete',
        'target': 'Client',
        'value': {'clientId': alice},
      },
    ),
    '@policy',
  );
  return [group, alice];
}

/// Puts client bob and returns its id.
Future<List<String>> _putClient(String directory) async => [
  await _putOnFiles(await _startOnFiles(directory), 'Client', {
    'name': 'Bob',
    'atSign': '@bob',
  }),
];

/// The policy Atsign's client, as far as a manager RPC handler on files
/// asks it anything.
class _PolicyAtClient implements AtClient {
  @override
  String? getCurrentAtSign() => '@policy';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

/// Stored rules naming a rule that isn't stored, each with the ids that
/// load and the missing rule its warning names. In each, the rule under
/// test, [_rule], is the last one stored.
Map<String, _MissingReferenceCase> _missingReferenceCases() {
  const rule = _rule;
  const missing = _missing;
  const group = {'id': 'g1', 'name': 'g1'};
  const client = {'id': 'c1', 'name': 'Alice', 'atSign': '@alice'};
  const daemon = {'id': 'd1', 'atSign': '@daemon'};
  const service = {
    'id': 's1',
    'daemonId': 'd1',
    'deviceName': 'dev',
    'deviceGroupName': 'grp',
  };
  return <String, _MissingReferenceCase>{
    'membership naming a missing client': (
      stored: [
        ('client_group', group),
        ('client_group_member', {
          'id': rule,
          'clientId': missing,
          'clientGroupId': 'g1',
        }),
      ],
      loads: ['g1'],
      named: 'Client with id $missing',
    ),
    'membership naming a missing group': (
      stored: [
        ('client', client),
        ('client_group_member', {
          'id': rule,
          'clientId': 'c1',
          'clientGroupId': missing,
        }),
      ],
      loads: ['c1'],
      named: 'ClientGroup with id $missing',
    ),
    'service naming a missing daemon': (
      stored: [
        ('service', {...service, 'id': rule, 'daemonId': missing}),
      ],
      loads: [],
      named: 'Daemon with id $missing',
    ),
    'service ACL naming a missing service': (
      stored: [
        ('client_group', group),
        ('service_acl', {
          'id': rule,
          'serviceId': missing,
          'clientGroupId': 'g1',
          'permitOpen': 'localhost:22',
        }),
      ],
      loads: ['g1'],
      named: 'Service with id $missing',
    ),
    'service ACL naming a missing group': (
      stored: [
        ('daemon', daemon),
        ('service', service),
        ('service_acl', {
          'id': rule,
          'serviceId': 's1',
          'clientGroupId': missing,
          'permitOpen': 'localhost:22',
        }),
      ],
      loads: ['d1', 's1'],
      named: 'ClientGroup with id $missing',
    ),
    'service ACL naming a service that names a missing daemon': (
      stored: [
        ('client_group', group),
        ('service', {...service, 'daemonId': missing}),
        ('service_acl', {
          'id': rule,
          'serviceId': 's1',
          'clientGroupId': 'g1',
          'permitOpen': 'localhost:22',
        }),
      ],
      loads: ['g1'],
      named: 'Service with id s1',
    ),
  };
}

const _rule = 'rule-under-test';
const _missing = 'missing-id';

typedef _MissingReferenceCase = ({
  List<(String, Map<String, dynamic>)> stored,
  List<String> loads,
  String named,
});

/// The kinds of rule npp stores, as their keys and file names end.
const _fileKindsInTest = [
  'client',
  'client_group',
  'client_group_member',
  'daemon',
  'service',
  'service_acl',
];
