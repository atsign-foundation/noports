import 'package:at_client/at_client.dart';
import 'package:at_client/sqlite.dart';
import 'package:test/test.dart';

import 'fake_atserver.dart';

void main() {
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
