import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/npp.dart';
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
      }
    });
  });

  group('Given each persistence method and the client with the highest id'
      ' deleted', () {
    test('when npp loads its rules again and a new client is put, then its id'
        ' is one no rule has had', () async {
      for (final store in await newStores()) {
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
  AtClient get atClient;
  Future<NppCache> load();
  NppOperationHooks hooks();

  /// Saves [json] as a [kind] rule (`client`, `service_acl` …) under [name],
  /// as something other than npp's own hooks might.
  Future<void> save(String kind, String name, Map<String, dynamic> json);
}

class _FileStore implements _Store {
  final Directory directory;
  @override
  final AtClient atClient;

  _FileStore(this.directory, this.atClient);

  @override
  String get name => 'file';

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
}

class _AtServerStore implements _Store {
  @override
  final AtClient atClient;

  _AtServerStore(this.atClient);

  @override
  String get name => 'atserver';

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
}
