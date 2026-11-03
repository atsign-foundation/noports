import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/npp.dart';
import 'package:test/test.dart';

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
}
