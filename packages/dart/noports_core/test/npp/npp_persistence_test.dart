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
      {'clientId': '1', 'clientGroupId': '2'},
      {'clientId': '3', 'clientGroupId': '4'},
    ),
    ('Daemon', 'daemon', {'atSign': '@daemon'}, {'atSign': '@other'}),
    (
      'Service',
      'service',
      {'daemonId': '1', 'deviceName': 'dev', 'deviceGroupName': 'grp'},
      {'daemonId': '1', 'deviceName': 'other', 'deviceGroupName': 'grp'},
    ),
    (
      'ServiceACL',
      'service_acl',
      {'serviceId': '1', 'clientGroupId': '2', 'permitOpen': 'localhost:22'},
      {'serviceId': '1', 'clientGroupId': '2', 'permitOpen': 'localhost:9999'},
    ),
  ];

  group('Given a rule saved in a file', () {
    for (final (target, suffix, first, second) in kinds) {
      test('when a duplicate $target is put, then it is rejected and no second'
          ' file is saved', () async {
        final c = await callbacks();
        await put(c, target, first);

        await expectLater(put(c, target, first), throwsA(isA<Exception>()));

        expect(savedFiles(), ['1_$suffix.json']);
      });

      test('when a $target with its id but other content is put, then it is'
          ' rejected and the saved rule is unchanged', () async {
        final c = await callbacks();
        await put(c, target, first);

        await expectLater(
          put(c, target, {'id': '1', ...second}),
          throwsA(isA<Exception>()),
        );

        expect(savedFiles(), ['1_$suffix.json']);
        final saved = File('${directory.path}/1_$suffix.json');
        expect(jsonDecode(await saved.readAsString()), {'id': '1', ...first});
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

  Future<AtRpcResp> delete(ManagerRpcCallbacks c, String target) =>
      c.handleRequest(
        AtRpcReq(
          reqId: 2,
          payload: {
            'operation': 'delete',
            'target': target,
            'value': {idKeys[target]!: '1'},
          },
        ),
        policy,
      );

  /// How many rules of any kind [cache] holds.
  int ruleCount(NppCache cache) =>
      cache.clients.length +
      cache.clientGroups.length +
      cache.clientGroupMembers.length +
      cache.daemons.length +
      cache.services.length +
      cache.serviceACLs.length;

  group('Given a rule saved in a file', () {
    for (final (target, _, first, _) in kinds) {
      test('when the $target is deleted, then its file is gone and it is not'
          ' loaded again', () async {
        final c = await callbacks();
        await put(c, target, first);

        final response = await delete(c, target);

        expect(response.respType, AtRpcRespType.success);
        expect(savedFiles(), isEmpty);
        expect(
          ruleCount(await nppCacheFromFiles(policyDirectory: directory)),
          0,
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
          await put(c, target, first);
          expect(ruleCount(await load()), 1, reason: 'the put was saved');

          final response = await delete(c, target);

          expect(response.respType, AtRpcRespType.success);
          expect(ruleCount(await load()), 0);
        },
      );
    }
  });
}
