import 'package:at_client/at_client.dart';
import 'package:at_client/sqlite.dart';
import 'package:test/test.dart';

import 'fake_atserver.dart';

void main() {
  Future<AtClient> open(FakeAtServer server, String atSign) async {
    final client = await Atsign(atSign).open(
      keys: InMemoryAtKeysIo.holding(atSign, server[atSign].firstEnrollment.keys),
      preference: AtClientPreference()
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
