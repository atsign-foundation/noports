import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_client/sqlite.dart';
import 'package:test/test.dart';

import 'fake_atserver.dart';

void main() {
  Future<AtClient> open(
    FakeAtServer server,
    String atSign, {
    PqPosture posture = PqPosture.legacy,
    SigningAlgoType? authenticationKeyAlgorithm,
  }) async {
    final client = await Atsign(atSign).open(
      keys: InMemoryAtKeysIo.holding(atSign, server[atSign].firstEnrollment.keys),
      preference: AtClientPreference(
        posture: posture,
        authenticationKeyAlgorithm: authenticationKeyAlgorithm,
      )
        ..namespace = 'test'
        ..rootDomain = 'fake.atserver.test'
        ..fetchOfflineNotifications = false,
      storage: InMemoryAtClientStorage(atSign: atSign),
      lookUps: server.lookUps,
      serviceFactory: server.serviceFactory,
    );
    addTearDown(client.stop);
    return client;
  }

  test('a post-quantum client retrofits itself to an ML-DSA enrollment and'
      ' seeds its namespace', () async {
    final server = FakeAtServer()..addAtSign('@alice');
    final client = await open(server, '@alice', posture: PqPosture.pqReady);
    // ignore: experimental_member_use
    await (client as AtClientImpl).pqBootstrap!.startupComplete;

    final alice = server['@alice'];
    final successor = alice.enrollments.values
        .singleWhere((e) => e.retrofitPredecessor == alice.firstEnrollment);
    expect(successor.signingAlgo, 'mldsa65');
    expect(client.enrollmentId, successor.id);
    expect(
      server.connections
          .where((c) => c.enrollment == successor)
          .expand((c) => c.commands),
      contains(startsWith('pkam:signingAlgo:mldsa65:')),
    );
    expect(alice.firstEnrollment.status, 'approved',
        reason: 'a root predecessor keeps its life');
    expect(alice.recordAt('public:__nskey.test@alice'), isNotNull,
        reason: "a * grant seeds the client's own namespace");
    expect(server.unhandled, isEmpty);
  });

  test("enroll:update merges metadata into the caller's own enrollment only",
      () async {
    final server = FakeAtServer()..addAtSign('@alice');
    final alice = server['@alice'];
    final other = alice.enroll(
      appName: 'other',
      deviceName: 'elsewhere',
      namespaces: const {'test': 'rw'},
    );
    final remote = (await open(server, '@alice')).getRemoteSecondary()!;
    final own = alice.firstEnrollment.id;
    Future<String?> update(String id, Map<String, dynamic> metadata) =>
        remote.executeCommand(
          'enroll:update:${jsonEncode({
                'enrollmentId': id,
                'metadata': metadata,
              })}\n',
          auth: true,
        );

    final answer = await update(own, {'a': 1});
    await update(own, {'b': 2});

    expect(answer, contains('{"enrollmentId":"$own","status":"approved"}'));
    expect(alice.firstEnrollment.metadata, {'a': 1, 'b': 2});
    await expectLater(
      update(other.id, {'a': 1}),
      throwsA(isA<InternalServerException>()),
    );
    expect(other.metadata, isNull);
    expect(server.unhandled, isEmpty);
  });

  test('a client reads a key another atSign shared with it', () async {
    final server = FakeAtServer()
      ..addAtSign('@alice')
      ..addAtSign('@bob');
    final alice = await open(server, '@alice');
    final bob = await open(server, '@bob');
    await alice.put(
      AtKey.fromString('@bob:greeting.test@alice'),
      'hello bob',
      putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
    );

    final read = await bob.get(AtKey.fromString('@bob:greeting.test@alice'));

    expect(read.value, 'hello bob');
    expect(server.unhandled, isEmpty);
    expect(
      server.connections
          .where((c) => c.atSign.atSign == '@bob')
          .expand((c) => c.commands),
      contains(startsWith('lookup:')),
    );
  });

  test('a client opens on the fake and authenticates as its enrollment',
      () async {
    final server = FakeAtServer();
    final alice = server.addAtSign('@alice');

    final client = await Atsign('@alice').open(
      keys: InMemoryAtKeysIo.holding('@alice', alice.firstEnrollment.keys),
      preference: AtClientPreference()
        ..namespace = 'sshnp'
        ..rootDomain = 'fake.atserver.test'
        ..fetchOfflineNotifications = false,
      storage: InMemoryAtClientStorage(atSign: '@alice'),
      lookUps: server.lookUps,
      serviceFactory: server.serviceFactory,
    );
    addTearDown(client.stop);

    expect(server.unhandled, isEmpty);
    expect(
      server.connections.map((c) => c.enrollment?.id),
      contains(alice.firstEnrollment.id),
    );
  });
}
